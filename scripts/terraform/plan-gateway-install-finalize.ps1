[CmdletBinding()]
param(
    [string]$Out = "gateway-install-finalize.tfplan",
    [string]$GatewaySourceIso = "local:iso/OPNsense-26.7-dvd-amd64.iso",
    [string]$GatewayBootstrapIso = "local:iso/homelab-opnsense-gateway-bootstrap.iso"
)

$ErrorActionPreference = "Stop"
$environmentDirectory = Join-Path $PSScriptRoot "..\..\terraform\environments\labyrinthian-estate"

Push-Location $environmentDirectory
try {
    terraform.exe fmt -check
    terraform.exe validate

    # Run only after the attended OPNsense installer has written the system
    # disk. This produces a reviewable, Gateway-only plan: eject the installer
    # ISO and make the installed disk the first boot device.
    $terraformArguments = @(
        "plan",
        "-refresh=false",
        "-target=proxmox_virtual_environment_vm.gateway",
        "-var=gateway_iso_file_id=$GatewaySourceIso",
        "-var=gateway_bootstrap_iso_file_id=$GatewayBootstrapIso",
        "-var=gateway_bootstrap_media_attached=false",
        "-out=$Out"
    )
    & terraform.exe @terraformArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform did not produce the Gateway installation finalization plan."
    }

    Write-Host "Saved $Out. Review it, then apply it only after explicit confirmation."
}
finally {
    Pop-Location
}
