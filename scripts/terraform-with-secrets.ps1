[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("proxmox", "tailscale")]
    [string]$Component,

    [Parameter(Mandatory = $true)]
    [ValidateSet("init", "fmt", "validate", "plan", "apply", "output", "import")]
    [string]$Action,

    # import takes an address and an ID; plan/apply take flags such as -target.
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments = @()
)

# PowerShell counterpart of terraform-with-secrets.sh. The documented Terraform
# runner is Windows, so the secrets path has to exist here and not only in bash.
$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$secretFile = Join-Path $repositoryRoot "secrets\infrastructure.sops.env"

$environmentDirectory = switch ($Component) {
    "proxmox" { Join-Path $repositoryRoot "terraform\environments\labyrinthian-estate" }
    "tailscale" { Join-Path $repositoryRoot "terraform\environments\labyrinthian-estate\tailscale" }
}

# fmt reads no secrets, so it never needs the age identity.
if ($Action -eq "fmt") {
    & terraform.exe -chdir="$environmentDirectory" fmt -check
    exit $LASTEXITCODE
}

if (-not (Test-Path $secretFile)) {
    throw "missing encrypted Terraform secrets: $secretFile"
}

# Restored age identities are not named identically on every host, so accept
# either known name rather than failing with sops' opaque decryption error.
if (-not $env:SOPS_AGE_KEY_FILE) {
    $candidates = @(
        (Join-Path $HOME ".config\sops\age\keys.txt"),
        (Join-Path $HOME ".config\sops\age\ops-keys.txt")
    )
    $found = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $found) {
        throw "no age identity found; set SOPS_AGE_KEY_FILE or restore one of: $($candidates -join ', ')"
    }
    $env:SOPS_AGE_KEY_FILE = $found
}

$command = (@("terraform", "-chdir=$environmentDirectory", $Action) + $Arguments) -join " "
& sops exec-env "$secretFile" "$command"
exit $LASTEXITCODE
