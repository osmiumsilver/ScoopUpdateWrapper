# ScoopUpdateWrapper.ps1

<#
.SYNOPSIS
    Scoop Update Wrapper
.DESCRIPTION
    This PowerShell script updates scoop apps while updating the firewall rules correspondingly for you.
.LINK
    https://github.com/osmiumsilver/ScoopUpdateWrapper
.NOTES
    Author: osmiumsilver | License: GNU GPLv3
    Version: Beta 0.2.0
#>

#Requires -Version 5.1

using namespace System.Security.Principal

param(
    [Parameter()]
    [Alias("M")]
    [switch]$ManualMode,
    [Parameter()]
    [Alias("S")]
    [switch]$SkipScoopUpdate,
    [Parameter()]
    [Alias("V")]
    [switch]$VerboseMode
)

if ($VerboseMode) {
    $DebugPreference = 'Continue'
}
# Scoop App Class
class ScoopApp {
    [string]$Name
    [string[]]$UserVersions
    [string[]]$GlobalVersions
    [string]$CurrentUserVersion
    [string]$CurrentGlobalVersion
    [bool]$IsUserInstalled
    [bool]$IsGlobalInstalled
    [System.Collections.Generic.List[FirewallRule]]$FirewallRules

    ScoopApp([string]$name) {
        
        $this.Name = $name
        Write-Debug "Creating new ScoopApp instance for: $($this.Name)"
        $this.FirewallRules = [System.Collections.Generic.List[FirewallRule]]::new()
    }

    [string[]] GetAllVersions() {
        Write-Debug "Getting all versions for $($this.Name)"
        $allVersions = @()
        if ($this.IsUserInstalled) { 
            Write-Debug "User versions: $($this.UserVersions -join ', ')"
            $allVersions += $this.UserVersions }
        if ($this.IsGlobalInstalled) { 
            Write-Debug "Global versions: $($this.GlobalVersions -join ', ')"
            $allVersions += $this.GlobalVersions }
            
        $result = $allVersions | Select-Object -Unique | Sort-Object
        Write-Debug "Final versions list: $($result -join ', ')"
        return $result
    }
}

# Firewall Rule Class
class FirewallRule {
    [string]$InstanceID
    [string]$Program
    [string]$Action
    [string]$Direction
    [string]$RemoteAddress
    [string]$Version # Versions
    [string]$DisplayName

    FirewallRule([string]$instanceID, [string]$program) {
        $this.InstanceID = $instanceID
        $this.Program = $program
    }

    [FirewallRule] Clone() {
        $newRule = [FirewallRule]::new($this.InstanceID, $this.Program)
        Write-Debug "Creating new firewall instance for: $($this.InstanceID)"
        
        $newRule.Action = $this.Action
        $newRule.Direction = $this.Direction
        $newRule.RemoteAddress = $this.RemoteAddress
        $newRule.Version = $this.Version
        $newRule.DisplayName = $this.DisplayName
        Write-Debug $newRule
        return $newRule
    }
}



class FirewallManager {
    static [void] LoadFirewallRules([ScoopApp]$app) {
        Write-Debug "Loading existing firewall rules for app: $($app.Name)"
        $app.FirewallRules.Clear()
        $rules = gsudo { 
            $appName = $args[0]
            Get-NetFirewallApplicationFilter | Where-Object {
                $_.Program -like "*$appName*" } | ForEach-Object {
                $rule = Get-NetFirewallRule -AssociatedNetFirewallApplicationFilter $_
                $addressFilter = ($rule | Get-NetFirewallAddressFilter)
                @{
                    InstanceID    = $rule.Name
                    DisplayName   = $rule.DisplayName
                    Program       = $_.Program
                    Action        = $rule.Action
                    Direction     = $rule.Direction
                    RemoteAddress = $addressFilter.RemoteAddress
                } 
            }
        } -args $app.Name
        Write-Debug "Found $(($rules | Measure-Object).Count) firewall rules"
        foreach ($rule in $rules) {
            Write-Debug "Processing rule: $($rule.InstanceID)"
            $fwRule = [FirewallRule]::new($rule.InstanceID, $rule.Program)
            $fwRule.Action = $rule.Action
            $fwRule.Direction = $rule.Direction
            $fwRule.RemoteAddress = $rule.RemoteAddress
            $fwRule.DisplayName = $rule.DisplayName
            
            if ($rule.Program -match "\\$($app.Name)\\([\d.]+)\\") {
                $fwRule.Version = $matches[1]
                Write-Debug "   Extracted version from path: $($fwRule.Version)"
            }
            
            $app.FirewallRules.Add($fwRule)
        }
    }

    static [void] UpdateFirewallRules([ScoopApp]$app, [string]$newVersion) {
        Write-Debug "Starting the process of updating firewall rules for $($app.Name) to version $newVersion"
        [FirewallManager]::LoadFirewallRules($app)
        $templateRules = [FirewallManager]::GetTemplateRules($app)
        Write-Debug "Found $(($templateRules | Measure-Object).Count) template rules"
        if ($templateRules.Count -gt 0) {
            Write-Host "Creating new firewall rule for version $newVersion ..." -ForegroundColor Green
            foreach ($template in $templateRules) {
                [FirewallManager]::CreateRuleFromTemplate($app, $template, $newVersion)
            }
        }
        else {
            Write-Host "$($app.Name) does not have a pre-existing firewall rule, so there is nothing to update."
        }
    }

    static [FirewallRule[]] GetTemplateRules([ScoopApp]$app) {
        Write-Debug "Getting template rules for $($app.Name)"
        $templates = @()
        $versions = $app.GetAllVersions()
        
        foreach ($version in $versions) {
            $versionRules = $app.FirewallRules | Where-Object { $_.Version -eq $version }
            if ($versionRules) {
                 Write-Debug "Using version $version as template"
                $templates += $versionRules
                break
            }
        }
        
        return $templates
    }

    static [void] CreateRuleFromTemplate([ScoopApp]$app, [FirewallRule]$template, [string]$newVersion) {
        Write-Debug "Creating new rule from template: $($template.InstanceID)"
        $newRule = $template.Clone()
        Write-Debug "newRule: $($newRule)"
        # Update Rule name and version
        $newRule.InstanceID = $template.InstanceID -replace $template.Version, $newVersion
        $newRule.Program = $template.Program -replace $template.Version, $newVersion
        $newRule.Version = $newVersion
        Write-Debug "New rule id: $($newRule.InstanceID)"
        Write-Debug "New rule program path: $($newRule.Program)"
        Write-Debug "New rule program version: $($newRule.Version)"
        
        # Check if the path is existed or not
        if (Test-Path $newRule.Program) {
            Write-Host "Program path exists, creating firewall rule" -ForegroundColor Green
            try {
                gsudo {
                    New-NetFirewallRule `
                        -DisplayName $args[0] `
                        -Direction $args[1] `
                        -Action $args[2] `
                        -Program $args[3] `
                        -RemoteAddress $args[4]
                } -args @(
                    $newRule.DisplayName,
                    $newRule.Direction,
                    $newRule.Action,
                    $newRule.Program,
                    $newRule.RemoteAddress
                )
                Write-Host "Successfully created rule: $($newRule.DisplayName)" -ForegroundColor Green
            }
            catch {
                Write-Error "Rule creation failed: $_"
            }
        }
        else {
            Write-Host "Path doesn't exists, Skipping for $($newRule.Program)"
        }
    }

    static [void] CleanupFirewallRules([ScoopApp]$app) {
        [FirewallManager]::LoadFirewallRules($app)
        $validVersions = $app.GetAllVersions()
        
        foreach ($rule in $app.FirewallRules) {
            if ($rule.Version -and -not ($validVersions -contains $rule.Version)) {
                Write-Host "删除无效版本 $($rule.Version) 的防火墙规则: $($rule.InstanceID)" -ForegroundColor Yellow
                try {
                    gsudo { Remove-NetFirewallRule -Name $args[0] } -args $rule.InstanceID
                }
                catch {
                    Write-Error "删除防火墙规则失败: $_"
                }
            }
        }
    }
}
class PathManager {
    static [string]$UserScoopPath
    static [string]$GlobalScoopPath

    static PathManager() {
        [PathManager]::UserScoopPath = Join-Path $env:USERPROFILE "scoop\apps"
        [PathManager]::GlobalScoopPath = Join-Path $env:ProgramData "scoop\apps"
    }

    static [string] GetUserAppPath([string]$appName) {
        $path = Join-Path -Path ([PathManager]::UserScoopPath) -ChildPath $appName
        Write-Debug "User app path for $($appName): $path"
        return $path
    }

    static [string] GetGlobalAppPath([string]$appName) {
        $path = Join-Path -Path ([PathManager]::GlobalScoopPath) -ChildPath $appName
        Write-Debug "Global app path for $($appName): $path"
        return $path
    }
}

class ScoopManager {
    static [System.Collections.Generic.List[ScoopApp]] GetAllInstalledApps() {
        Write-Debug "Getting all installed apps"
        $apps = [System.Collections.Generic.List[ScoopApp]]::new()
        $userApps = @()
        $globalApps = @()
        $userPath = [PathManager]::UserScoopPath
        $globalPath = [PathManager]::GlobalScoopPath
        
        Write-Debug "Checking user path: $userPath"
        Write-Debug "Checking global path: $globalPath"
        if (Test-Path ([PathManager]::UserScoopPath)) {
            $userApps = Get-ChildItem -Path ([PathManager]::UserScoopPath) -Directory -Exclude "scoop" | Select-Object -ExpandProperty Name
            Write-Debug "Found user apps: $($userApps -join ', ')"
        }
        if (Test-Path ([PathManager]::GlobalScoopPath)) {
            $globalApps = Get-ChildItem -Path ([PathManager]::GlobalScoopPath) -Directory -Exclude "scoop" | Select-Object -ExpandProperty Name
            Write-Debug "Found global apps: $($globalApps -join ', ')"
            
        }
        
        $allApps = ($userApps + $globalApps) | Select-Object -Unique
        Write-Debug "Total unique apps found: $($allApps -join ', ')"
        
        foreach ($appName in $allApps) {
            $apps.Add([ScoopManager]::GetAppInfo($appName))
        }
        
        return $apps
    }

    static [ScoopApp] GetAppInfo([string]$appName) {
        Write-Debug "Getting app info for: $appName"
        $app = [ScoopApp]::new($appName)
        
        function Check-Installation {
            param (
                [string]$path,
                [string]$scope
            )
        
            if (Test-Path $path) {
                $app."Is${scope}Installed" = $true
                $app."${scope}Versions" = (Get-ChildItem -Path $path -Directory | Where-Object { $_.Name -ne "current" }).Name
                Write-Debug "${scope} versions: $($app."${scope}Versions" -join ', ')"
                
                $currentLink = Join-Path $path "current"
                if (Test-Path $currentLink) {
                    $target = (Get-Item $currentLink).Target
                    if (Test-Path $target) {
                        $app."Current${scope}Version" = Split-Path $target -Leaf
                        Write-Debug "Current ${scope} version: $($app."Current${scope}Version")"
                    } else {
                        throw "It seems like the current shortcut folder for $appName is broken, skipping this one..."
                    }
                }
            }
        }
        
        # Check both user and global installations
        $userPath = [PathManager]::GetUserAppPath($appName)
        Check-Installation -path $userPath -scope "User"
        
        $globalPath = [PathManager]::GetGlobalAppPath($appName)
        Check-Installation -path $globalPath -scope "Global"

        return $app
    }
    static [void] UpdateApp([ScoopApp]$app) {
        Write-Debug "Starting update for app: $($app.Name)"
        if ($app.IsGlobalInstalled) {
            Write-Host "Updating globally installed $($app.Name)..." -ForegroundColor Cyan
            $GlobalInstallStatus = ""
                (gsudo { scoop update -g $args[0] } -args $app.Name) *>&1 | Tee-Object -Variable GlobalInstallStatus
            if ($GlobalInstallStatus -match "error|fail") {
                throw "Update failure: $GlobalInstallStatus"
            }
        }
        if ($app.IsUserInstalled) {
            Write-Host "Updating locally installed $($app.Name)..." -ForegroundColor Cyan
            $LocalInstallStatus = ""
                (scoop update $app.Name) *>&1 | Tee-Object -Variable LocalInstallStatus
            if ($LocalInstallStatus -match "error|fail") {
                throw "Update failure: $LocalInstallStatus"
            }
        }
    }
}

class PrivilegeManager {
    static [bool] IsAdministrator() {
        $identity = [WindowsIdentity]::GetCurrent()
        $principal = [WindowsPrincipal]::new($identity)
        return $principal.IsInRole([WindowsBuiltInRole]::Administrator)
    }

    static [void] EnsureNotAdmin() {
        if ([PrivilegeManager]::IsAdministrator()) {
            Write-Warning "This script should not be run with administrator privileges"
            Write-Warning "Please run this script with normal user privileges, and it will automatically request a privilege elevation if needed."
            $continue = Read-Host "Continue? (y/N)"
            if ($continue -ne "y") {
                exit
            }
        }
    }
}

Write-Debug "Script started with parameters: ManualMode=$ManualMode, SkipScoopUpdate=$SkipScoopUpdate, Verbose=$VerboseMode"
if ($ManualMode) {
    $appName = "syncthing"
    $app = [ScoopManager]::GetAppInfo($appName)
    Write-Host "Manual mode engaged: Stored info for $appName"
    exit 0
}

    [PrivilegeManager]::EnsureNotAdmin()

    if (!$SkipScoopUpdate) {
        Write-Host "Updating Scoop..." -ForegroundColor Cyan
        $result = scoop update *>&1
        if ($result -match "error|fail") {
            Write-Error "Scoop update failed: $result"
            exit 1
        }
    }
    else{
         Write-Warning "You seem to be using the -S parameter to skip the scoop manifest update, which may break the script if you haven't used "“scoop update"” to update the app manifest recently, since scoop takes it upon itself to try to automatically update the manifest before updating the app."
    }
    
    $status = scoop status -l
    Write-Host $status
    
    if (!$status) {
        Write-Host "No updates required." -ForegroundColor Green
        $choice = Read-Host "Would you like to cleanup old firewall rules? (Y/N)"
            
        if ($choice -eq 'Y') {
            # $apps = [ScoopManager]::GetAllInstalledApps()
            # foreach ($app in $apps) {
            #     Write-Host "`nChecking firewall rule for : $($app.Name) ..." -ForegroundColor Cyan
            #     [FirewallManager]::CleanupFirewallRules($app)
            # }
            # Write-Host "`nSuccessfully cleaned firewall rules!" -ForegroundColor Green
            Write-Host "The feature is still being tested!"
        }
        return
    }
        
    $updatedApps = @()
    $failedApps = @()
        
    foreach ($line in $status) {
            
        $appName = $line."Name"
        # $oldVersion = $line."Install Version"
        $newVersion = $line."Latest Version"
       
                
        try {
            $app = [ScoopManager]::GetAppInfo($appName)
            [ScoopManager]::UpdateApp($app)
            [FirewallManager]::UpdateFirewallRules($app, [string]$newVersion)
            $updatedApps += $appName
        }
        catch {
            Write-Error "Update $appName failed: $_"
            $failedApps += $appName
            continue
        }
            
    }
        
    if ($updatedApps.Count -gt 0) {
        Write-Host "`nSuccessfully updated apps:" -ForegroundColor Green
        $updatedApps | ForEach-Object { Write-Host "- $_" -ForegroundColor Green }
    }
        
    if ($failedApps.Count -gt 0) {
        Write-Host "`nFailed:" -ForegroundColor Red
        $failedApps | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    }



