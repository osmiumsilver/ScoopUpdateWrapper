using module './common.ps1'

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