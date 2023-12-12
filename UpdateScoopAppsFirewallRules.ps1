 # 2023 osmiumsilver osmiumsilver v1.2
$scoopPath = (Get-Command scoop).Source | Split-Path -Parent | Split-Path -Parent
 try {
    # Update scoop buckets
    scoop update
 }
  catch {
    Write-Error "Failed to update buckets : $($_.Exception.Message)"
  }


# Create an array to store the results
$results = @(scoop status)



# Update the firewall rules for each updated app
foreach ($app in $results) {

try {
Write-Host "Updating" $app.Name
    sudo scoop update $app.Name
        # Step 3: Get a list of installed Scoop apps
    # $installedApps = Get-ChildItem -Directory -Path "$scoopPath\apps" | Select-Object -ExpandProperty Name
    # Get the path of the updated app
   Write-Warning "Updating firewall rules for $app"




      # Update firewall rules for the app
      $appRootPath = scoop prefix $app.Name | Split-Path -Parent
      $appRootPath = "$appRootPath\*"

   $existingAppPathFilterRules = sudo {Get-NetFirewallApplicationFilter} |  Where-Object { $_.Program -like $appRootPath}
      foreach ($rule in $existingAppPathFilterRules) {
        # if ($rule.Program -match "^$appRootPath(\d+\.\d+\.\d+)$") {
          if ($rule.Program -match $app."Installed Version"){
            echo  $app."Installed Version"
          # Concat filePATH with new path with new version
          $newFilePath = [regex]::Replace($rule.Program, "\d+(\.\d+)*", $app."Latest Version")

          # Update the existing rule with the new app path and set the remote address to LocalSubnet
        $FirewallRules = $existingAppPathFilterRules | sudo {$input | Get-NetFirewallRule}
 
          foreach ($FirewallRule in $FirewallRules) {
           $originalRemoteAddress = $FirewallRule | gsudo { $input |Get-NetFirewallAddressFilter}  | Select-Object -ExpandProperty RemoteAddress
           if ($originalRemoteAddress -eq 'LocalSubnet') {
          
          
          
      $FirewallRule | sudo {$input | Set-NetFirewallRule -Program $args[0] -RemoteAddress LocalSubnet} -args $newFilePath
      }
      
      else{  $FirewallRule | sudo {$input | Set-NetFirewallRule -Program $args[0]} -args $newFilePath}
          }
        }
        else {

                # Create a new rule for the app using the executable name as the rule name
                New-NetFirewallRule -DisplayName $app.Name -Program $appPath -Action Allow
            }
      }

}

catch{

Failed to update app : $($_.Exception.Message)
}
}