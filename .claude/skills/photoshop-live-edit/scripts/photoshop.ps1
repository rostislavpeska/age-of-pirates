#requires -Version 5.1
<#[Windows PowerShell 5.1] Default: inspect only. -ScriptPath: execute reviewed JSX.#>
[CmdletBinding()]
param([string]$ScriptPath)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Run with Windows PowerShell: powershell.exe -NoProfile -NonInteractive -STA -File <this-script>. PowerShell 7 lacks the GetActiveObject API used here.'
}
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    throw 'Run powershell.exe with -STA.'
}
$taskJsx = if ($ScriptPath) {
    (Resolve-Path -LiteralPath $ScriptPath).ProviderPath
} else {
    Join-Path $PSScriptRoot 'inspect.jsx'
}
if ([IO.Path]::GetExtension($taskJsx) -ne '.jsx' -or
    -not (Test-Path -LiteralPath $taskJsx -PathType Leaf)) {
    throw 'Expected an existing .jsx file. UXP .psjs files use a different runtime.'
}
try {
    $photoshopApp = [Runtime.InteropServices.Marshal]::GetActiveObject('Photoshop.Application')
} catch {
    throw ('Cannot attach to the running Photoshop COM instance. Check that Photoshop is open in the same Windows user/session and privilege level. No application was started. Original error: ' + $_.Exception.Message)
}
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $photoshopApp.DoJavaScriptFile($taskJsx)
} catch {
    throw ('Photoshop script failed. Do not blindly retry a mutating script; inspect the live result first. Original error: ' + $_.Exception.Message)
} finally {
    if ($null -ne $photoshopApp -and [Runtime.InteropServices.Marshal]::IsComObject($photoshopApp)) {
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($photoshopApp)
    }
}
