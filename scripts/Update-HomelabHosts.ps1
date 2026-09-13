[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$CatalogPath = (Join-Path $PSScriptRoot '..\topology\workloads.yaml'),
    [string]$GatewayBaselinePath = (Join-Path $PSScriptRoot '..\gateway\baseline.yaml'),
    [string]$HostsPath = (Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'),
    [string]$Python = 'python'
)

# Maps every homelab host name to its address in this machine's hosts file,
# as <name> and <name>.dscim.dev. VM and Proxmox addresses come from the same
# inventory Ansible uses, rendered fresh from the catalog; Gateway is API-managed
# and absent from that inventory, so its Infra address comes from its baseline.

$ErrorActionPreference = 'Stop'
$beginMarker = '# BEGIN HOMELAB MANAGED HOSTS'
$endMarker = '# END HOMELAB MANAGED HOSTS'

foreach ($path in $CatalogPath, $GatewayBaselinePath) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required input not found: $path"
    }
}

$inventoryPath = [System.IO.Path]::GetTempFileName()
try {
    & $Python (Join-Path $PSScriptRoot 'ops\render-inventory.py') --catalog $CatalogPath --output $inventoryPath
    if ($LASTEXITCODE -ne 0) {
        throw "render-inventory.py failed; it needs Python with PyYAML."
    }

    # Parsed with PyYAML rather than by indentation, which broke silently
    # whenever the rendered layout changed.
    $extract = @'
import sys, yaml
inventory = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
for group in inventory["all"]["children"].values():
    for name, host in (group.get("hosts") or {}).items():
        print(name, host["ansible_host"])
baseline = yaml.safe_load(open(sys.argv[2], encoding="utf-8"))
print(baseline["system"]["hostname"], baseline["interfaces"]["infra"]["address"].split("/")[0])
'@
    $lines = @($extract | & $Python - $inventoryPath $GatewayBaselinePath)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not read host addresses from the inventory or Gateway baseline."
    }
}
finally {
    # The temp file is ours, so a -WhatIf preview must still clean it up.
    Remove-Item -LiteralPath $inventoryPath -ErrorAction SilentlyContinue -WhatIf:$false
}

$entries = foreach ($line in $lines) {
    $name, $address = $line -split '\s+', 2
    $parsedAddress = $null
    if (-not [System.Net.IPAddress]::TryParse($address, [ref]$parsedAddress)) {
        throw "Invalid address '$address' for host '$name'."
    }
    [pscustomobject]@{ Name = $name; Address = $address }
}

if (-not $entries) {
    throw 'No homelab host addresses were found.'
}

$existing = Get-Content -LiteralPath $HostsPath -Raw
$escapedBegin = [regex]::Escape($beginMarker)
$escapedEnd = [regex]::Escape($endMarker)
$withoutManagedBlock = [regex]::Replace(
    $existing,
    "(?ms)^$escapedBegin\r?\n.*?^$escapedEnd\r?\n?",
    ''
).TrimEnd()

$managedLines = foreach ($entry in $entries | Sort-Object Name) {
    "{0} {1} {1}.dscim.dev" -f $entry.Address, $entry.Name
}
$managedLines | ForEach-Object { Write-Verbose $_ }

$managedBlock = @($beginMarker) + $managedLines + @($endMarker)
$newContent = $withoutManagedBlock + [Environment]::NewLine * 2 +
    ($managedBlock -join [Environment]::NewLine) + [Environment]::NewLine

if ($PSCmdlet.ShouldProcess($HostsPath, 'Update homelab hostname mappings')) {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Writing the hosts file requires an elevated PowerShell. Preview with -WhatIf -Verbose.'
    }
    [System.IO.File]::WriteAllText($HostsPath, $newContent, [System.Text.Encoding]::ASCII)
    Write-Host "Updated $(@($entries).Count) homelab hostnames in $HostsPath"
}
