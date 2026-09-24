#requires -Version 5.1
<#[Windows PowerShell 5.1] Start desktop Photoshop on the operator's instruction, wait until COM attaches, print the
inventory. Executable: -PhotoshopPath, else tools.photoshop.path in -LocalConfig (tool-paths JSON), else the
Photoshop.Application COM registration. Never starts a second copy beside a running Photoshop.exe unless
-AllowSecondInstance; never kills, saves or closes anything.#>
[CmdletBinding()]
param(
    [string]$PhotoshopPath,
    [string]$LocalConfig,
    [int]$TimeoutSec = 180,
    [switch]$AllowSecondInstance
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Run with Windows PowerShell: powershell.exe -NoProfile -NonInteractive -STA -File <this-script>. PowerShell 7 lacks the GetActiveObject API used here.'
}
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    throw 'Run powershell.exe with -STA.'
}
$inventory = Join-Path $PSScriptRoot 'photoshop.ps1'

function Test-Attach {
    try {
        $app = [Runtime.InteropServices.Marshal]::GetActiveObject('Photoshop.Application')
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($app)
        return $true
    } catch { return $false }
}

# 1. Already attachable: nothing to start.
if (Test-Attach) {
    Write-Host 'Photoshop is already running and attachable; nothing started.'
    & $inventory
    exit 0
}

# 2. A Photoshop.exe that does not attach (starting up, modal dialog, windowless, other elevation): report, do not stack a copy.
$running = @(Get-CimInstance Win32_Process -Filter "Name='Photoshop.exe'")
if ($running.Count -gt 0 -and -not $AllowSecondInstance) {
    $list = ($running | ForEach-Object { '  PID ' + $_.ProcessId + '  started ' + $_.CreationDate + '  ' + $_.CommandLine }) -join [Environment]::NewLine
    throw ('Photoshop.exe is running but does not attach over COM, so nothing was started:' + [Environment]::NewLine + $list +
        [Environment]::NewLine + 'It may still be loading or blocked by a dialog. Ask the operator; start a second copy only with -AllowSecondInstance on their word.')
}

# 3. Resolve the executable.
$source = $null
if ($PhotoshopPath) {
    $source = '-PhotoshopPath'
} elseif ($LocalConfig) {
    $cfgPath = (Resolve-Path -LiteralPath $LocalConfig).ProviderPath
    $cfg = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
    if ($cfg.tools -and $cfg.tools.photoshop -and $cfg.tools.photoshop.path) {
        $PhotoshopPath = [string]$cfg.tools.photoshop.path
        $source = $cfgPath
    }
}
if (-not $PhotoshopPath) {
    $clsid = (Get-ItemProperty -LiteralPath 'Registry::HKEY_CLASSES_ROOT\Photoshop.Application\CLSID' -ErrorAction SilentlyContinue).'(default)'
    if ($clsid) {
        $server = (Get-ItemProperty -LiteralPath ('Registry::HKEY_CLASSES_ROOT\CLSID\' + $clsid + '\LocalServer32') -ErrorAction SilentlyContinue).'(default)'
        if ($server -match '^\s*"([^"]+)"' -or $server -match '^\s*(\S+\.exe)') {
            $PhotoshopPath = $Matches[1]
            $source = 'COM registration ' + $clsid
        }
    }
}
if (-not $PhotoshopPath -or -not (Test-Path -LiteralPath $PhotoshopPath -PathType Leaf)) {
    throw ('No Photoshop executable found (path: ' + $PhotoshopPath + '). Pass -PhotoshopPath or set tools.photoshop.path in the local tool-paths file. Nothing was started.')
}

# 4. Start the normal desktop application and wait for COM.
Write-Host ('Starting ' + $PhotoshopPath + ' (from ' + $source + ')')
$proc = Start-Process -FilePath $PhotoshopPath -PassThru
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    if (Test-Attach) {
        Write-Host ('Attached (PID ' + $proc.Id + ').')
        & $inventory
        exit 0
    }
}
throw ('Photoshop (PID ' + $proc.Id + ') started but did not attach within ' + $TimeoutSec + ' s. A startup, sign-in or update dialog may be open; ask the operator. Do not kill it or start another copy.')
