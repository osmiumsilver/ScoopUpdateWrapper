class ScoopApp {
    [string]$Name
    [string[]]$UserVersions=@()
    [string[]]$GlobalVersions=@()
    [string]$CurrentUserVersion=""
    [string]$CurrentGlobalVersion=""
    [System.Collections.Generic.List[FirewallRule]]$FirewallRules=[System.Collections.Generic.List[FirewallRule]]::new()

    ScoopApp([string]$name) {
        $this.Name = $name
        Write-Debug "Creating new ScoopApp instance for: $($this.Name)"
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

class ScoopManager {
    # WIP
    # static [System.Collections.Generic.List[ScoopApp]] GetAllInstalledApps() {
    #     Write-Debug "Getting all installed apps"
    #     $apps = [System.Collections.Generic.List[ScoopApp]]::new()
    #     $userApps = @()
    #     $globalApps = @()
    #     $userPath = [PathManager]::UserScoopPath
    #     $globalPath = [PathManager]::GlobalScoopPath
        
    #     Write-Debug "Checking user path: $userPath"
    #     Write-Debug "Checking global path: $globalPath"
    #     if (Test-Path ([PathManager]::UserScoopPath)) {
    #         $userApps = Get-ChildItem -Path ([PathManager]::UserScoopPath) -Directory -Exclude "scoop" | Select-Object -ExpandProperty Name
    #         Write-Debug "Found user apps: $($userApps -join ', ')"
    #     }
    #     if (Test-Path ([PathManager]::GlobalScoopPath)) {
    #         $globalApps = Get-ChildItem -Path ([PathManager]::GlobalScoopPath) -Directory -Exclude "scoop" | Select-Object -ExpandProperty Name
    #         Write-Debug "Found global apps: $($globalApps -join ', ')"
            
    #     }
        
    #     $allApps = ($userApps + $globalApps) | Select-Object -Unique
    #     Write-Debug "Total unique apps found: $($allApps -join ', ')"
        
    #     foreach ($appName in $allApps) {
    #         $apps.Add([ScoopManager]::GetAppInfo($appName))
    #     }
        
    #     return $apps
    # }
    hidden static void _FillAppScopeInfo([ScoopApp]$app, [string]$path, [string]$scopeName) {
        if (-not (Test-Path $path)) {
            return # 如果路径不存在，直接返回
        }

        # 填充版本信息
        $versions = Get-ChildItem -Path $path -Directory |
                    Where-Object { $_.Name -ne "current" } |
                    Select-Object -ExpandProperty Name
        
        $app."${scopeName}Versions" = $versions
        Write-Debug "$scopeName versions found: $($versions -join ', ')"

        # 填充 Current 版本信息
        # （注意：Current 版本的逻辑我们后面需要重新考虑，因为 User 和 Global 的 current 只能有一个生效）
        $currentLink = Join-Path $path "current"
        if (Test-Path $currentLink) {
            $target = (Get-Item $currentLink).Target
            if (Test-Path $target) {
                $app."Current${scope}Version" = Split-Path $target -Leaf
                Write-Debug "Current ${scope} version: $($app."Current${scope}Version")"
            } else {
                throw "It seems like the current shortcut folder for $($app.Name) is broken, skipping this one..."
            }
        }
    }
    hidden static [ScoopApp] _CheckInstallations([ScoopApp]$app) {
        $appName = $app.Name
        Write-Debug "Checking installations for app: $appName"
        $userPath = [PathManager]::GetAppPath([ScoopScope]::User,$appName,"User")
        [AppManager]::_FillAppScopeInfo($app, $userPath)
        $globalPath = [PathManager]::GetAppPath([ScoopScope]::Global,$appName,"Global")
        [AppManager]::_FillAppScopeInfo($app, $globalPath)
        }


    static [ScoopApp] GetAppInfo([string]$appName) {
        # input appName, output ScoopApp object
        Write-Debug "Getting app info for: $appName"        
        return [AppManager]::_CheckInstallations([ScoopApp]::new($appName))
    }

    static [void] UpdateApp([ScoopApp]$app) {
        Write-Debug "Starting update for app: $($app.Name)"
        if ($app.GlobalVersions.Count -eq 0) {
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