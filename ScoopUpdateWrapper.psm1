# 使用点 sourcing 加载类定义文件
. "$PSScriptRoot/classes/scoop-scope.ps1"
. "$PSScriptRoot/classes/firewall-rule.ps1"
. "$PSScriptRoot/classes/scoop-app.ps1"
. "$PSScriptRoot/modules/utility.ps1"
. "$PSScriptRoot/modules/scoop-manager.ps1"
. "$PSScriptRoot/modules/firewall-manager.ps1"


Write-Debug "Verbose: SkipScoopUpdate=$SkipScoopUpdate"

function Invoke-ScoopUpdater {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter()]
        [Alias("S")]
        [switch]$SkipScoopUpdate
    )
    Write-Debug "Verbose: SkipScoopUpdate=$SkipScoopUpdate" # 用 Write-Debug 替换
    [PrivilegeDemotion]::EnsureNotAdmin()

    if (!$SkipScoopUpdate) {
        Write-Host "Updating Scoop..." -ForegroundColor Cyan
        $output = scoop update *>&1
        if ($LASTEXITCODE -ne 0) {
            # 如果失败了，把捕获到的所有输出作为错误信息展示出来
            Write-Error "Scoop update failed. Full output below:`n$($output | Out-String)"
            exit 1
        }
    }
    else {
        Write-Warning "You seem to be using the -S parameter to skip the scoop manifest update, which may break the script if you haven't used "“scoop update"” to update the app manifest recently, since scoop takes it upon itself to try to automatically update the manifest before updating the app."
    }
    # scoop status outputs PSObject, so we can work with it directly
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
    $updateResults = @{
        Succeeded = [System.Collections.Generic.List[string]]::new()
        Failed    = [System.Collections.Generic.List[string]]::new()
    }
        
    $status | ForEach-Object {
    
        $appName = $_.Name
        # $oldVersion = $_."Install Version"
        $newVersion = $_."Latest Version"
        
        try {
            $app = [ScoopManager]::GetAppInfo($appName)
            [ScoopManager]::UpdateApp($app)
            [FirewallManager]::UpdateFirewallRules($app, [string]$newVersion)
            $updateResults.Succeeded.Add($appName)
        }
        catch {
            Write-Error "Update $appName failed: $_"
            $updateResults.Failed.Add($appName)
            continue
        }
            
    }
        
    if ($updateResults.Succeeded.Count -gt 0) {
        Write-Host "`nSuccessfully updated apps:" -ForegroundColor Green
        $updateResults.Succeeded | ForEach-Object { Write-Host "- $_" -ForegroundColor Green }
    }
        
    if ($updateResults.Failed.Count -gt 0) {
        Write-Host "`nFailed:" -ForegroundColor Red
        $updateResults.Failed | ForEach-Object { Write-Host "- $_" -ForegroundColor Green }
    }
}

Export-ModuleMember -Function Invoke-ScoopUpdater