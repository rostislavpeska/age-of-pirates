param(
 [Parameter(Mandatory=$true)][string]$InputFbx,
 [Parameter(Mandatory=$true)][string]$OutputDirectory,
 [Parameter(Mandatory=$true)][string]$ConverterPath,
 [ValidateRange(10,600)][int]$TimeoutSeconds=60
)
$ErrorActionPreference='Stop'
$converterTask=(Resolve-Path -LiteralPath $ConverterPath).Path
$sourceTask=(Resolve-Path -LiteralPath $InputFbx).Path
if([IO.Path]::GetExtension($sourceTask) -ne '.fbx'){throw 'Input must be an FBX file.'}
if((Test-Path -LiteralPath $OutputDirectory) -and (Get-ChildItem -LiteralPath $OutputDirectory -Force | Select-Object -First 1)){throw 'Use an empty fresh staging directory.'}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$destinationTask=(Resolve-Path -LiteralPath $OutputDirectory).Path
$inputTask=Join-Path $destinationTask ([IO.Path]::GetFileName($sourceTask))
if($sourceTask -ne $inputTask){Copy-Item -LiteralPath $sourceTask -Destination $inputTask}
$resultTask=[IO.Path]::ChangeExtension($inputTask,'.gr2')
if(Test-Path -LiteralPath $resultTask){throw 'Output GR2 already exists. Use a fresh output directory to preserve it.'}
$processTask=Start-Process -FilePath $converterTask -ArgumentList @('--format=gr2','--bang',('"'+$inputTask+'"')) -WorkingDirectory ([IO.Path]::GetDirectoryName($converterTask)) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $destinationTask 'converter.stdout.log') -RedirectStandardError (Join-Path $destinationTask 'converter.stderr.log')
if(-not $processTask.WaitForExit($TimeoutSeconds*1000)){throw "Converter did not finish. Inspect its dialog/process $($processTask.Id); do not retry or install output."}
$processTask.Refresh()
if($processTask.ExitCode -ne 0){throw "Converter exited with $($processTask.ExitCode)"}
if(!(Test-Path -LiteralPath $resultTask)){throw 'Converter produced no GR2 despite successful process exit.'}
$dataTask=[IO.File]::ReadAllBytes($resultTask)
if($dataTask.Length -lt 104){throw 'GR2 is truncated.'}
$magicTask=([BitConverter]::ToString($dataTask,0,16)).Replace('-','').ToLowerInvariant()
if($magicTask -notin @('29de6cc0baa4532b25f5b7a5f666e2ee','e59b495e6f631f141e13eba990beedc4')){throw 'Unexpected GR2 header.'}
Get-Item -LiteralPath $resultTask | Select-Object FullName,Length
Get-FileHash -LiteralPath $resultTask -Algorithm SHA256

