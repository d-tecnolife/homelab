[CmdletBinding()]
param(
    # Resume at a later phase instead of starting from the beginning.
    [ValidateSet("gateway-rebuild", "gateway-install", "gateway-finalize", "ops-bootstrap")]
    [string]$StartAt = "gateway-rebuild"
)

# Single guided path through a fresh-hardware or Gateway-replacement rebuild.
# It composes the existing per-phase scripts in this directory; it adds no new
# Terraform logic and no new safety behavior. Every apply below still requires
# a typed "yes" — this script only removes the need to remember which of the
# three scripts runs next, in which order, with which flags. The one step it
# cannot do for you is the console-attended OPNsense install itself: this
# script pauses immediately before it and immediately after it.
#
# Read docs/gateway-configuration.md and docs/environment-bootstrap.md before
# running this for the first time. This script assumes:
#   - terraform.tfvars is already filled in (see terraform.tfvars.example)
#   - the OPNsense DVD ISO is already uploaded to Proxmox ISO storage
#   - the encrypted Gateway input already exists and the bootstrap ISO has
#     already been built (scripts/gateway/create-gateway-secret.sh,
#     scripts/gateway/build-opnsense-bootstrap-iso.sh)

$ErrorActionPreference = "Stop"
$scriptDirectory = $PSScriptRoot
$environmentDirectory = Join-Path $scriptDirectory "..\..\terraform\environments\labyrinthian-estate"

function Confirm-Phase {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
    $response = Read-Host 'Type "yes" to continue, anything else to stop'
    if ($response -ne "yes") {
        throw "Stopped before: $Message"
    }
}

function Invoke-TerraformApply {
    param([Parameter(Mandatory)][string]$PlanFile)
    Push-Location $environmentDirectory
    try {
        & terraform.exe apply $PlanFile
        if ($LASTEXITCODE -ne 0) {
            throw "terraform apply failed for $PlanFile"
        }
    }
    finally {
        Pop-Location
    }
}

# Checked once up front so an unreachable API fails here with its cause named,
# instead of mid-phase after a confirmation has already been typed.
& (Join-Path $scriptDirectory "Test-ProxmoxReachable.ps1")

$phases = @("gateway-rebuild", "gateway-install", "gateway-finalize", "ops-bootstrap")
$startIndex = $phases.IndexOf($StartAt)

if ($startIndex -le $phases.IndexOf("gateway-rebuild")) {
    Confirm-Phase "Phase 1/4: plan Gateway replacement (destroys VMID 100 and its disk)"
    & (Join-Path $scriptDirectory "plan-gateway-rebuild.ps1")
    Write-Host "Review gateway-rebuild.tfplan above." -ForegroundColor Yellow
    Confirm-Phase "Apply the Gateway replacement plan"
    Invoke-TerraformApply -PlanFile "gateway-rebuild.tfplan"
}

if ($startIndex -le $phases.IndexOf("gateway-install")) {
    Write-Host ""
    Write-Host "=== Manual step: complete the OPNsense install ===" -ForegroundColor Magenta
    Write-Host "Open VMID 100 in the Proxmox console and finish the attended DVD install" -ForegroundColor Magenta
    Write-Host "using the bootstrap ISO's imported config.xml. Do not touch boot order or" -ForegroundColor Magenta
    Write-Host "eject media in the Proxmox UI -- the next phase does that through Terraform." -ForegroundColor Magenta
    Confirm-Phase "The OPNsense installer has finished and Gateway has rebooted into it"
}

if ($startIndex -le $phases.IndexOf("gateway-finalize")) {
    Confirm-Phase "Phase 3/4: plan the post-install finalize (eject installer media, fix boot order)"
    & (Join-Path $scriptDirectory "plan-gateway-install-finalize.ps1")
    Write-Host "Review gateway-install-finalize.tfplan above." -ForegroundColor Yellow
    Confirm-Phase "Apply the Gateway finalize plan"
    Invoke-TerraformApply -PlanFile "gateway-install-finalize.tfplan"
}

if ($startIndex -le $phases.IndexOf("ops-bootstrap")) {
    Confirm-Phase "Phase 4/4: plan Ops (VMID 1010), the sole controller exception"
    & (Join-Path $scriptDirectory "plan-ops-bootstrap.ps1")
    Write-Host "Review ops-bootstrap.tfplan above." -ForegroundColor Yellow
    Confirm-Phase "Apply the Ops bootstrap plan"
    Invoke-TerraformApply -PlanFile "ops-bootstrap.tfplan"
}

Write-Host ""
Write-Host "Terraform phases complete." -ForegroundColor Green
Write-Host "Next: open VMID 1010's Proxmox xterm.js console and follow" -ForegroundColor Green
Write-Host "docs/environment-bootstrap.md sections 4-5 (Ops identity and Tailscale," -ForegroundColor Green
Write-Host "then bootstrap-lab.sh). Workloads stay gated until gateway_policy_ready = true." -ForegroundColor Green
