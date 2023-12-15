# 2023 osmiumsilver osmiumsilver v1.2
# $scoopPath = (Get-Command scoop).Source | Split-Path -Parent | Split-Path -Parent
#Didnt really know how to try to catch this error ,cuz no error handling was done by Write-Error in sccop's code
# try {
# Update scoop buckets
scoop update
# }
# catch {
#   Write-Error "Failed to update buckets : $($_.Exception.Message)"
# }
# Create an array to store the results
$results = @(scoop status)
# Update the firewall rules for each updated app
foreach ($app in $results) {
  Write-Host "Updating " $app.Name
  try {
    $output = gsudo scoop update $app.Name
    # Sadly, the error that scoop 'throws' is not done by 'Write-Error' so it cannot be caught :(
    if ($output -match "^ERROR") {
      Write-Output $output
      throw "The app cannot be updated"
    }
    Write-Warning "Updating firewall rules for $app"
    # Fina All Update firewall rules for the app
    $appRootPath = scoop prefix $app.Name | Split-Path -Parent
    $appRootPath = "$appRootPath\*"
    $existingAppPathFilterRules = sudo { Get-NetFirewallApplicationFilter } |  Where-Object { $_.Program -like $appRootPath }
    if ($existingAppPathFilterRules) {
      foreach ($rule in $existingAppPathFilterRules) {
        if ($rule.Program -match $app."Installed Version") {
          Write-Output ("Detected " + $app.Name + " Version " + $app."Installed Version" + " , Changing to " + $app."Latest Version" +" ...")
          # Update the existing rule with the new app path and set the remote address to LocalSubnet
          $newFilePath = [regex]::Replace($rule.Program, "\d+(\.\d+)*", $app."Latest Version")
          $FirewallRule = $rule | sudo { $input | Get-NetFirewallRule }
          $originalRemoteAddress = $FirewallRule | gsudo { $input | Get-NetFirewallAddressFilter }  | Select-Object -ExpandProperty RemoteAddress
          try {
            if ($originalRemoteAddress -eq 'LocalSubnet') {
              $FirewallRule | sudo { $input | Set-NetFirewallRule -Program $args[0] -RemoteAddress LocalSubnet } -args $newFilePath
            }
            else { 
              $FirewallRule | sudo { $input | Set-NetFirewallRule -Program $args[0] } -args $newFilePath 
              
            }
            Write-Host ("Success!!")
          }
          catch {
            Write-Host ("Changing firewall rule for " + $app.Name + " goes wrong!")
          }
        }
        else {
          Write-Host ("There is no firewall rules for this version " + $app.'Installed Version' + " for " + $app.Name)
        }
      }
    }
    else {
      Write-Warning ("THERE IS ABSOLUTELY NO Firewall rules for " + $app.Name)
    }
  }
  catch {
    Write-Output "Failed to update app : $($_.Exception.Message)"
    continue
  }
}
Pause