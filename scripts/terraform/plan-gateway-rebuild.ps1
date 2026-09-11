[CmdletBinding()]
param(
    [string]$Out = "gateway-rebuild.tfplan"
)

$ErrorActionPreference = "Stop"
$environmentDirectory = Join-Path $PSScriptRoot "..\..\terraform\environments\labyrinthian-estate"

Push-Location $environmentDirectory
try {
    terraform.exe fmt -check
    terraform.exe validate

    # This is a deliberately scoped, destructive phase: it migrates the state
    # address and replaces only VMID 100. Workload creation follows only after
    # the Gateway baseline/policy is restored and verified.
    $terraformArguments = @(
        "plan",
        "-refresh=false",
        "-target=proxmox_virtual_environment_vm.gateway",
        "-replace=proxmox_virtual_environment_vm.gateway",
        "-out=$Out"
    )
    & terraform.exe @terraformArguments

    Write-Host "Saved the destructive Gateway-only plan to $Out. Review it; apply it only after explicit confirmation."
}
finally {
    Pop-Location
}
