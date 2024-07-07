# ScoopUpdater.ps1

# 2024 osmiumsilver v1.4
# $scoopPath = (Get-Command scoop).Source | Split-Path -Parent | Split-Path -Parent
<#
.SYNOPSIS
    Scoop Updater
.DESCRIPTION
    This PowerShell script updates the firewall rules while updating the apps for you.
.LINK
    https://gist.github.com/osmiumsilver/4707fb236dca64e13a793da70532a668
.NOTES
    Author: osmiumsilver | License: CC0
#>

function UpdateApps($app) {
    $updateResult = Update($app)
    # i need this cuz i encounter some lolz unexpected behaviour from PS
    # Write-Host "---- Back in UpdateApps ----"
    # Write-Host "$updateResult" # More specific logging
    # Write-Host "---- End in UpdateApps ----"
    $updateResult = $updateResult[-1] -as [int] # this shit works like a charm 
   switch ($updateResult) {
    1 { 
        Write-Error "UpdateApps: Update is failed for $($app.Name), and no firewall rules are changed." 
    }
    2 {
        Write-Error "UpdateApps: Update is ignored for $($app.Name), and no firewall rules are changed."
    }
    default { # Or you could use 0 explicitly if you prefer
        Write-Host "$($app.Name) update success. Updating firewall rules..." -ForegroundColor Green
        ApplyFirewall $app.Name $app."Installed Version" $app."Latest Version"
    }
}
}

function Update($app) {
    Write-Host "Trying to update $($app.Name)"
    $info = scoop info $app.Name
    $output = @()
    if ($info | Select-Object -ExpandProperty Installed | Where-Object { $_ -match '.*global\.*' }) {
        gsudo { scoop update -g $args[0] } -args $app.Name | Tee-Object -Variable output
    } else {
        scoop update $app.Name 2>&1 | Tee-Object -Variable output
    }
    Write-Host "---- write $output from update ----"

    if ([string]::IsNullOrWhiteSpace($output)) {
    $global:unupdatedApps += $app.Name
        return 2 
    } 
    elseif ($output | Where-Object {$_ -match '(?i)Error'}) { 
        Write-Host $output -ForegroundColor Red
        $global:failedApps += $app.Name
        return 1 
    } else {
        return 0
    }
}

function ApplyFirewall {
     param (
        [string]$appName,
        [string]$installedVersion,
        [string]$lasestVersion 
    )
    $appRootPath = scoop prefix $appName | Split-Path -Parent
    $appRootPath = "$appRootPath\*"

     $AppFilters = sudo { Get-NetFirewallApplicationFilter } |  Where-Object { $_.Program -like $appRootPath }

    if ($AppFilters) {
        foreach ($AppFilter in $AppFilters) {
            if ($AppFilter.Program -match $installedVersion) {
                Write-Host "Detected $appName, Current version $installedVersion, Refactoring to $latestVersion ..."
                $newFilePath = [regex]::Replace($AppFilter.Program, "\d+(\.\d+)*", $latestVersion)
                $FirewallRule = $AppFilter | sudo { $input | Get-NetFirewallRule }
                 $originalRemoteAddress = $FirewallRule | gsudo { $input | Get-NetFirewallAddressFilter }  | Select-Object -ExpandProperty $originalRemoteAddress
                # $FirewallRule = gsudo powershell -Command "Get-NetFirewallRule -AssociatedNetFirewallApplicationFilter $AppFilter
                # $originalRemoteAddress = gsudo powershell -Command "Get-NetFirewallAddressFilter -AssociatedNetFirewallRule '$($FirewallRule.Name)' | Select-Object -ExpandProperty RemoteAddress"

                try {
                    # if ($originalRemoteAddress -eq 'LocalSubnet') {
                    #     gsudo powershell -Command "Set-NetFirewallRule -Name '$($FirewallRule.Name)' -Program '$newFilePath' -RemoteAddress LocalSubnet"
                    # } else { 
                    #     gsudo powershell -Command "Set-NetFirewallRule -Name '$($FirewallRule.Name)' -Program '$newFilePath'"
                    # }
                    if ($originalRemoteAddress -eq 'LocalSubnet') {
            $FirewallRule | sudo { $input | Set-NetFirewallRule -Program $args[0] -RemoteAddress LocalSubnet } -args $newFilePath
          }
          else { 
            $FirewallRule | sudo { $input | Set-NetFirewallRule -Program $args[0] } -args $newFilePath 
              
          }
                    Write-Host "Success!!"
                } catch {
                    Write-Host "Changing firewall rule for $appName failed: $_"
                }
            } else {
                Write-Host "There are no firewall rules for version $installedVersion of $appName"
            }
        }
    } else {
        Write-Warning "THERE ARE NO Firewall rules for $appName"
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $global:failedApps = @()
    $global:unupdatedApps = @()
    gsudo cache on
    Write-Host "Updating Scoop..."
    $scoopOutput = scoop update *>&1

    try {if ($scoopOutput -match "error|fail" -or $LASTEXITCODE -ne 0) {
        throw "Scoop update has encountered errors! `nDetails:$scoopOutput" 
    }
    Write-Host "Scoop update completed successfully!" -ForegroundColor Green
    }catch{
       exit 1
    }
    $results = scoop status
    Write-Host $results
    foreach ($app in $results) {
        UpdateApps($app)
    }

   if ($failedApps.Count -gt 0 -or $global:unupdatedApps.Count -gt 0) { 
    if ($failedApps.Count -gt 0) {
        Write-Host "The following apps could not be updated:"
        $failedApps | ForEach-Object { Write-Host "-$_" -ForegroundColor Red }
    }

    if ($global:unupdatedApps.Count -gt 0) {
        Write-Host "The following apps were not updated (UAC likely not confirmed):"
        $global:unupdatedApps | ForEach-Object { Write-Host "-$_" -ForegroundColor Yellow } 
    }
} else {
    Write-Host "All apps updated successfully!" 
}
    Pause
}
