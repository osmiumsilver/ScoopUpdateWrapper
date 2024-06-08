# 2024 osmiumsilver v1.3
# $scoopPath = (Get-Command scoop).Source | Split-Path -Parent | Split-Path -Parent

function UpdateApps($app) {
  $updateResult = Update($app)
  if ($updateResult -eq 0) {
    Write-Host "$($app.Name) update success. Updating firewall rules..." -ForegroundColor Green
    ApplyFirewall(${app.Name})
  }
  else {
    Write-Error "Update is failed for $($app.Name), no firewall rules are changed."
  }
}

function Update($app) {
  Write-Host "Trying to update $($app.Name)"
  $info = scoop info $app.Name
  if ($info | Select-Object -ExpandProperty Installed | Where-Object { $_ -match '.*global\.*' }) {
    gsudo scoop update -g $app.Name 2>&1 | Tee-Object -Variable output
  }
  else {
    # add *>&1 because scoop skip the pipeline
    scoop update $app.Name 2>&1 | Tee-Object -Variable output
  }
  # Sadly, the error that scoop 'throws' is not done by 'Write-Error' so it cannot be caught :(
  if ($output -match "^Error") {
    Write-Host $output -ForegroundColor Red
    $global:failedApps += $app.Name
    return 1
  }
  else {
    # WIN
    return 0
  }
}

function ApplyFirewall($appName) {
  # Fina All Update firewall rules for the app
  $appRootPath = scoop prefix $appName | Split-Path -Parent
  $appRootPath = "$appRootPath\*"
  $existingAppPathFilterRules = sudo { Get-NetFirewallApplicationFilter } |  Where-Object { $_.Program -like $appRootPath }
  if ($existingAppPathFilterRules) {
    foreach ($rule in $existingAppPathFilterRules) {
      if ($rule.Program -match $app."Installed Version") {
        Write-Host ("Detected " + $app.Name + " Version " + $app."Installed Version" + " , Changing to " + $app."Latest Version" + " ...")
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
 


$global:failedApps = @()
# Update scoop buckets
gsudo cache on
$scoopOutput = scoop update *>&1
if ($scoopOutput -match "error|fail" -or $LASTEXITCODE -ne 0) {
  throw "Scoop update has encountered errors! \nDetails:$scoopOutput" 
}
Write-Host "Scoop update completed successfully!" -ForegroundColor Green
# Create an array to store the results
$results = scoop status
Write-Host $results

foreach ($app in $results) {
  UpdateApps($app)
}

if ($failedApps.Count -gt 0) {
  Write-Host "The following apps could not be updated:"
  $failedApps | ForEach-Object { Write-Host "-$_" -ForegroundColor Red }
}
else {
  Write-Host "All apps updated successfully!"
}

Pause