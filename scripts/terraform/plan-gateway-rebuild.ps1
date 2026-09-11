[CmdletBinding()]
param(
    [string]$Out = "gateway-rebuild.tfplan",
    [string]$GatewaySourceIso = "local:iso/OPNsense-26.7-dvd-amd64.iso",
    [string]$GatewayBootstrapIso = "local:iso/homelab-opnsense-gateway-bootstrap.iso",
    [string]$ProxmoxSshUser = "terraform"
)

$ErrorActionPreference = "Stop"
$environmentDirectory = Join-Path $PSScriptRoot "..\..\terraform\environments\labyrinthian-estate"
$terraformVars = Join-Path $environmentDirectory "terraform.tfvars"

if ($GatewayBootstrapIso -notmatch '^local:iso/[A-Za-z0-9._-]+\.iso$') {
    throw "GatewayBootstrapIso must be a local:iso/<simple-name>.iso volume ID."
}
if (-not (Test-Path -LiteralPath $terraformVars)) {
    throw "Missing $terraformVars; cannot preflight the required bootstrap ISO."
}

# Terraform validates the volume ID syntax but Proxmox does not reject a
# missing ISO until after it destroys the replacement VM. Check storage first.
$varsContent = Get-Content -LiteralPath $terraformVars -Raw
if ($varsContent -notmatch '(?m)^\s*proxmox_endpoint\s*=\s*"([^"]+)"') {
    throw "terraform.tfvars must define proxmox_endpoint for the ISO preflight."
}
$proxmoxHost = ([uri]$Matches[1]).Host
$bootstrapIsoName = $GatewayBootstrapIso.Substring('local:iso/'.Length)
& ssh.exe -o BatchMode=yes -o ConnectTimeout=5 "$ProxmoxSshUser@$proxmoxHost" "test -r '/var/lib/vz/template/iso/$bootstrapIsoName'"
if ($LASTEXITCODE -ne 0) {
    throw "Gateway bootstrap ISO $GatewayBootstrapIso is missing on Proxmox. Build it before creating a Gateway rebuild plan."
}

Push-Location $environmentDirectory
try {
    terraform.exe fmt -check
    terraform.exe validate

    # This is the network-foundation checkpoint: replace VMID 100 only.
    # Workload DNS updates and Terraform state-address moves happen later,
    # after Gateway is installed and connectivity has been verified.
    $terraformArguments = @(
        "plan",
        "-refresh=false",
        "-replace=proxmox_virtual_environment_vm.gateway",
        "-target=proxmox_virtual_environment_vm.gateway",
        "-var=gateway_iso_file_id=$GatewaySourceIso",
        "-var=gateway_bootstrap_iso_file_id=$GatewayBootstrapIso",
        "-out=$Out"
    )
    & terraform.exe @terraformArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform did not produce a Gateway rebuild plan."
    }

    Write-Host "Saved the Gateway replacement plan to $Out. Review it; apply it only after explicit confirmation."
}
finally {
    Pop-Location
}
