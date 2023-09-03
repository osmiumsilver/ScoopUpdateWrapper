# 2023 osmiumsilver osmiumsilver
$scoopPath = (Get-Command scoop).Source | Split-Path -Parent | Split-Path -Parent

# # Get the list of updated apps Run the scoop update command and capture its output
$output = scoop update * | Out-String

# Define a regular expression pattern to match the app name, old version, and new version
$pattern = "Updating '(.+?)' \((.+?) -> (.+?)\)"

# Create an array to store the results
$results = @() 


# Use the -match operator to find all matches in the output
$output -split "`n" | ForEach-Object {
    if ($_ -match $pattern) {
        # Create a custom object to store the app name, old version, and new version
        $result = New-Object PSObject -Property @{
            AppName    = $Matches[1]
            OldVersion = $Matches[2]
            NewVersion = $Matches[3]
        }

        # Add the result to the array
        $results += $result
    }
}


# Update the firewall rules for each updated app
foreach ($app in $results) {


    # Step 3: Get a list of installed Scoop apps
    # $installedApps = Get-ChildItem -Directory -Path "$scoopPath\apps" | Select-Object -ExpandProperty Name
    Write-Host "Applying firewall rules for updated $app..."
    # Get the path of the updated app
    $appRootPath = scoop prefix $app.AppName | Split-Path -Parent
    $appRootPath = $appRootPath + "\*"


    # Get the firewall rule for the app based on its path
    $existingAppPathFilterRules = Get-NetFirewallApplicationFilter | Where-Object { $_.Program -like $appRootPath }

    foreach ($rule in $existingAppPathFilterRules) {
        
        if ($rule.Program -match $app.OldVersion) {
         
            #Concat filePATH with new path with new version
            $newFilePath = [regex]::Replace($rule.Program, "\d+\.\d+\.\d+", $app.NewVersion)

            $FirewallRules = $existingAppPathFilterRules | Get-NetFirewallRule

            foreach ($FirewallRule in $FirewallRules) {

                # Update the existing rule with the new app path and set the remote address to LocalSubnet
                $FirewallRule   | Set-NetFirewallRule -Program $newFilePath -RemoteAddress LocalSubnet
            }
            else {

                # Create a new rule for the app using the executable name as the rule name
                New-NetFirewallRule -DisplayName $app.AppName -Program $appPath -Action Allow
            }
        }
    }

}


