[CmdletBinding()]
param(
    [string]$Out = "gateway-rebuild.tfplan",
    [string]$GatewaySourceIso = "local:iso/OPNsense-26.7-dvd-amd64.iso",
    [string]$GatewayBootstrapIso = "local:iso/homelab-opnsense-gateway-bootstrap.iso"
)

$ErrorActionPreference = "Stop"
$environmentDirectory = Join-Path $PSScriptRoot "..\..\terraform\environments\labyrinthian-estate"

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
