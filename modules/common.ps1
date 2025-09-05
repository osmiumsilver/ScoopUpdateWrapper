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

enum ScoopScope {
    User
    Global
}