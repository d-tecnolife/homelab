[CmdletBinding()]
param(
    [string]$TfvarsPath = (Join-Path $PSScriptRoot "..\..\terraform\environments\labyrinthian-estate\terraform.tfvars")
)

# Fail fast when the Terraform runner cannot reach the Proxmox API. Terraform
# itself only reports this deep inside a refresh, as a generic dial timeout on
# the first resource it touches, which reads like a Proxmox outage. The real
# cause here has been the runner's own routing: a VPN client (NetBird) installed
# a /32 route for the Proxmox host, sending API traffic down its tunnel while
# SSH to the same host still worked.
$ErrorActionPreference = "Stop"
if (-not (Test-Path $TfvarsPath)) {
    throw "Missing $TfvarsPath; copy terraform.tfvars.example and fill it in."
}
$match = Select-String -Path $TfvarsPath -Pattern '^\s*proxmox_endpoint\s*=\s*"([^"]+)"' | Select-Object -First 1
if (-not $match) {
    throw "proxmox_endpoint is not set in $TfvarsPath."
}
$endpoint = [Uri]$match.Matches[0].Groups[1].Value
$port = if ($endpoint.Port -gt 0) { $endpoint.Port } else { 8006 }

$result = Test-NetConnection -ComputerName $endpoint.Host -Port $port -WarningAction SilentlyContinue
if ($result.TcpTestSucceeded) {
    return
}

$route = Find-NetRoute -RemoteIPAddress $result.RemoteAddress -ErrorAction SilentlyContinue | Select-Object -Last 1
$interface = if ($route) { (Get-NetAdapter -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue).Name } else { "unknown" }
throw ("Cannot reach the Proxmox API at {0}:{1}. The route to it leaves through interface '{2}'. " +
       "If that is a VPN tunnel rather than your LAN adapter, that client is capturing the Proxmox address; " +
       "disconnect it and retry.") -f $endpoint.Host, $port, $interface
