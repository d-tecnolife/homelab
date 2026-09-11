[CmdletBinding()]
param(
    [switch]$Apply
)

$ErrorActionPreference = "Stop"
$environmentDirectory = Join-Path $PSScriptRoot "..\..\terraform\environments\labyrinthian-estate"

# These are Terraform-address moves only. They preserve the same remote VM IDs
# while allowing the Gateway rebuild to be planned independently of workloads.
$moves = [ordered]@{
    "proxmox_virtual_environment_vm.pfsense"    = "proxmox_virtual_environment_vm.gateway"
    "proxmox_virtual_environment_vm.apps"       = 'proxmox_virtual_environment_vm.workload["apps"]'
    "proxmox_virtual_environment_vm.door"       = 'proxmox_virtual_environment_vm.workload["door"]'
    "proxmox_virtual_environment_vm.games"      = 'proxmox_virtual_environment_vm.workload["games"]'
    "proxmox_virtual_environment_vm.gitea"      = 'proxmox_virtual_environment_vm.workload["gitea"]'
    "proxmox_virtual_environment_vm.k3s"        = 'proxmox_virtual_environment_vm.workload["k3s"]'
    "proxmox_virtual_environment_vm.monitoring" = 'proxmox_virtual_environment_vm.workload["monitoring"]'
    "proxmox_virtual_environment_vm.nolife"     = 'proxmox_virtual_environment_vm.workload["nolife"]'
}

Push-Location $environmentDirectory
try {
    $state = @(& terraform.exe state list)
    foreach ($move in $moves.GetEnumerator()) {
        $fromExists = $state -contains $move.Key
        $toExists = $state -contains $move.Value
        if ($fromExists -and $toExists) {
            throw "Both state addresses exist: $($move.Key) and $($move.Value). Resolve this manually; no state was changed."
        }
        if (-not $fromExists) {
            continue
        }
        if (-not $Apply) {
            Write-Host "Would move $($move.Key) -> $($move.Value)"
            continue
        }
        & terraform.exe state mv $move.Key $move.Value
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to move Terraform state from $($move.Key)."
        }
        $state = @(& terraform.exe state list)
    }

    if ($Apply) {
        Write-Host "Terraform state addresses are ready. No Proxmox resource was changed."
    }
    else {
        Write-Host "Dry run only. Re-run with -Apply to make these local state-address moves."
    }
}
finally {
    Pop-Location
}
