using module '../classes/scoop-scope.ps1'
using module './utility.ps1'

class ScoopManager {
    
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

}