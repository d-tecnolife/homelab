[CmdletBinding()]
param(
    [string]$Out = "ops-bootstrap.tfplan"
)

$ErrorActionPreference = "Stop"
$environmentDirectory = Join-Path $PSScriptRoot "..\..\terraform\environments\labyrinthian-estate"

Push-Location $environmentDirectory
try {
    terraform.exe fmt -check
    terraform.exe validate

    # Ops is the only guest allowed in phase two. It provides the private
    # management path to Gateway; workloads remain gated by gateway_policy_ready.
    & terraform.exe plan -refresh=false -target=proxmox_virtual_environment_vm.ops "-out=$Out"
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform did not produce an Ops bootstrap plan."
    }
    Write-Host "Saved the Ops-only plan to $Out. Review it; apply it only after explicit confirmation."
}
finally {
    Pop-Location
}
