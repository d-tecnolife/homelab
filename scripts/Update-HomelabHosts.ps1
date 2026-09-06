[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InventoryPath = (Join-Path $PSScriptRoot '..\ansible\inventory\hosts.yml'),
    [string]$HostsPath = (Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'),
    [switch]$SyncOpsRouteOnly
)

$ErrorActionPreference = 'Stop'
$beginMarker = '# BEGIN HOMELAB MANAGED HOSTS'
$endMarker = '# END HOMELAB MANAGED HOSTS'
$edgeAddress = '192.168.1.199'
$opsRouteTaskName = 'Homelab sync local Ops route'

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

function Sync-OpsLocalRoute {
    param([string]$OpsAddress)

    $destinationPrefix = "$OpsAddress/32"
    $homeInterface = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -like '192.168.1.*' -and $_.PrefixLength -eq 24 } |
        Select-Object -First 1
    $managedRoutes = Get-NetRoute -PolicyStore ActiveStore -DestinationPrefix $destinationPrefix -ErrorAction SilentlyContinue |
        Where-Object { $_.NextHop -eq $edgeAddress }

    if ($homeInterface) {
        $routeExists = $managedRoutes | Where-Object { $_.InterfaceIndex -eq $homeInterface.InterfaceIndex }
        if (-not $routeExists -and $PSCmdlet.ShouldProcess($destinationPrefix, "Route through Edge on $($homeInterface.InterfaceAlias)")) {
            New-NetRoute -PolicyStore ActiveStore -DestinationPrefix $destinationPrefix `
                -InterfaceIndex $homeInterface.InterfaceIndex -NextHop $edgeAddress -RouteMetric 5 | Out-Null
            Write-Host "Routed Ops ($OpsAddress) locally through Edge on $($homeInterface.InterfaceAlias)"
        }
        return
    }

    foreach ($route in $managedRoutes) {
        if ($PSCmdlet.ShouldProcess($destinationPrefix, 'Remove inactive local Edge route')) {
            Remove-NetRoute -InputObject $route -Confirm:$false
            Write-Host "Removed the local Ops route because this device is off the home LAN"
        }
    }
}

function Install-OpsRouteSyncTask {
    $scriptPath = [System.Security.SecurityElement]::Escape($PSCommandPath)
    $userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>Synchronizes the home-LAN route to Ops when network connectivity changes.</Description></RegistrationInfo>
  <Triggers>
    <LogonTrigger><Enabled>true</Enabled></LogonTrigger>
    <EventTrigger><Enabled>true</Enabled><Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=10000 or EventID=10001 or EventID=10002)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription></EventTrigger>
  </Triggers>
  <Principals><Principal id="CurrentUser"><UserId>$userSid</UserId><LogonType>InteractiveToken</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><AllowHardTerminate>true</AllowHardTerminate><StartWhenAvailable>true</StartWhenAvailable><RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><Hidden>true</Hidden><ExecutionTimeLimit>PT5M</ExecutionTimeLimit><Priority>7</Priority></Settings>
  <Actions Context="CurrentUser"><Exec><Command>powershell.exe</Command><Arguments>-NoProfile -ExecutionPolicy Bypass -File &quot;$scriptPath&quot; -SyncOpsRouteOnly</Arguments></Exec></Actions>
</Task>
"@

    if ($PSCmdlet.ShouldProcess($opsRouteTaskName, 'Install network-change task')) {
        Register-ScheduledTask -TaskName $opsRouteTaskName -Xml $taskXml -Force | Out-Null
        Write-Host "Installed '$opsRouteTaskName' to update the local Ops route automatically"
    }
}

$opsEntry = $entries | Where-Object Name -eq 'ops' | Select-Object -First 1
if (-not $opsEntry) {
    throw "The inventory does not contain an 'ops' host."
}

Sync-OpsLocalRoute -OpsAddress $opsEntry.Address

if (-not $SyncOpsRouteOnly) {
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

    Install-OpsRouteSyncTask
}
