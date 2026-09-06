[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InventoryPath = (Join-Path $PSScriptRoot '..\ansible\inventory\hosts.yml'),
    [string]$HostsPath = (Join-Path $env:SystemRoot 'System32\drivers\etc\hosts')
)

$ErrorActionPreference = 'Stop'
$beginMarker = '# BEGIN HOMELAB MANAGED HOSTS'
$endMarker = '# END HOMELAB MANAGED HOSTS'

if (-not (Test-Path -LiteralPath $InventoryPath)) {
    $examplePath = "$InventoryPath.example"
    if (Test-Path -LiteralPath $examplePath) {
        $InventoryPath = $examplePath
    }
    else {
        throw "Inventory not found: $InventoryPath. Copy hosts.yml.example to hosts.yml first."
    }
}

$entries = [System.Collections.Generic.List[object]]::new()
$currentHost = $null

foreach ($line in Get-Content -LiteralPath $InventoryPath) {
    if ($line -match '^\s{8}([A-Za-z0-9][A-Za-z0-9_.-]*):\s*$') {
        $currentHost = $Matches[1]
        continue
    }

    if ($currentHost -and $line -match '^\s{10}ansible_host:\s*([0-9.]+)\s*$') {
        $address = $Matches[1]
        $parsedAddress = $null
        if (-not [System.Net.IPAddress]::TryParse($address, [ref]$parsedAddress)) {
            throw "Invalid address '$address' for host '$currentHost'."
        }

        $entries.Add([pscustomobject]@{ Name = $currentHost; Address = $address })
        $currentHost = $null
    }
}

if ($entries.Count -eq 0) {
    throw "No managed VM addresses were found in $InventoryPath."
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

$managedBlock = @($beginMarker) + $managedLines + @($endMarker)
$newContent = $withoutManagedBlock + [Environment]::NewLine * 2 +
    ($managedBlock -join [Environment]::NewLine) + [Environment]::NewLine

if ($PSCmdlet.ShouldProcess($HostsPath, 'Update homelab hostname mappings')) {
    [System.IO.File]::WriteAllText($HostsPath, $newContent, [System.Text.Encoding]::ASCII)
    Write-Host "Updated $($entries.Count) homelab hostnames in $HostsPath"
}
