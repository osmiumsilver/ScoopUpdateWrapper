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
function Test-IsWindows {
    # $IsWindows 是 PowerShell 7+ 中的一个内置变量，非常可靠。
    # 对于 PowerShell 5.1，我们可以检查操作系统描述。
    # 组合起来可以兼容两个版本。
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        return $IsWindows
    }
    else {
        # 'Windows_NT' 是 System.Environment.OSVersion.Platform 的值
        return ($env:OSVER -like '*Windows*') -or ([System.Environment]::OSVersion.Platform -eq 'Win32NT')
    }
}

function Test-ScoopInstallation {
    <#
    .SYNOPSIS
        Checks if Scoop is installed and available in the PATH.
    .DESCRIPTION
        This function verifies the existence of scoop.ps1 in the expected directory
        and also checks if the 'scoop' command is recognized by PowerShell.
    .EXAMPLE
        if (Test-ScoopInstallation) { ... }
    .RETURNS
        $true if Scoop is installed and accessible, otherwise $false.
    #>

    $scoopCommand = Get-Command scoop -ErrorAction SilentlyContinue
    
    if ($null -ne $scoopCommand) {
        # 进一步验证路径是否看起来像一个标准的 scoop 安装
        # scoop 命令通常指向 ~\scoop\shims\scoop.ps1
        # 这是一个可选的、更严格的检查
        if ($scoopCommand.Source -like "*scoop\shims\scoop.ps1") {
            return $true
        }
        Write-Warning "A command named 'scoop' was found, but it does not appear to be a standard Scoop installation, the script might not work at all. Check your `$PATH configuration."
        return $true
    }
    
    return $false
}