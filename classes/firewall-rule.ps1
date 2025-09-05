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