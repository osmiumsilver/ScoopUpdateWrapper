using namespace System.Security.Principal
using module "../classes/scoop-scope.ps1"
class PathManager {
    static [string]$UserScoopPath
    static [string]$GlobalScoopPath

    static PathManager() {
        [PathManager]::UserScoopPath = Join-Path $env:USERPROFILE "scoop\apps"
        [PathManager]::GlobalScoopPath = Join-Path $env:ProgramData "scoop\apps"
    }

    static [string] GetAppPath([ScoopScope]$Scope, [string]$appName) {
        switch ($Scope) {
            User {
                $path = Join-Path -Path [PathManager]::UserScoopPath -ChildPath $appName
                Write-Debug "User app path for $($appName): $path"
                return $path
            }
            Global {
                $path = Join-Path -Path [PathManager]::GlobalScoopPath -ChildPath $appName
                Write-Debug "Global app path for $($appName): $path"
                return $path
            }
            Default {
                Write-Warning "Unknown scope: $Scope"
                return $null
            }
        }
        # Ensure a return value for any unexpected code path
        return $null
    }
}
class PrivilegeDemotion {
    static [bool] IsAdministrator() {
        $identity = [WindowsIdentity]::GetCurrent()
        $principal = [WindowsPrincipal]::new($identity)
        return $principal.IsInRole([WindowsBuiltInRole]::Administrator)
    }

    static [void] EnsureNotAdmin() {
        if ([PrivilegeDemotion]::IsAdministrator()) {
            Write-Warning "This script should not be run with administrator privileges"
            Write-Warning "Please run this script with normal user privileges, and it will automatically request a privilege elevation if needed."
            $continue = Read-Host "Continue? (y/N)"
            if ($continue -ne "y") {
                exit
            }
        }
    }
}