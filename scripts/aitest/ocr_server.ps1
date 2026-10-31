# OCR server for the test harness (Windows.Media.Ocr, the OCR built into Windows 10/11; no install).
# Reads one image path per stdin line, writes one JSON line per image:
#   {"path": "...", "ms": 312, "lines": [{"text": "ZPMARK HP75", "x": 120, "y": 340, "w": 410, "h": 38}, ...]}
# An empty line or EOF ends the server. Used by scripts/aitest/destruction_bench.py.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime]
$null = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]

$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, [Type]$type) {
    $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
    $null = $t.Wait(-1)
    $t.Result
}

$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new('en-US'))
if ($null -eq $engine) { $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages() }
[Console]::Out.WriteLine('{"ready": true}')
[Console]::Out.Flush()

while ($true) {
    $path = [Console]::In.ReadLine()
    if ([string]::IsNullOrWhiteSpace($path)) { break }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile])
        $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
        $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
        $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
        # OCR accepts Gray8/BGRA8 only; the harness's GDI screenshots are 32-bit ARGB PNGs, so convert every frame
        $bitmap = [Windows.Graphics.Imaging.SoftwareBitmap]::Convert($bitmap, [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8,
                                                                    [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied)
        $max = [Windows.Media.Ocr.OcrEngine]::MaxImageDimension
        if ($bitmap.PixelWidth -gt $max -or $bitmap.PixelHeight -gt $max) { throw "image larger than OCR max $max" }
        $result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
        $lines = @()
        foreach ($ln in $result.Lines) {
            $xs = $ln.Words | ForEach-Object { $_.BoundingRect }
            $x0 = ($xs | Measure-Object -Property X -Minimum).Minimum
            $y0 = ($xs | Measure-Object -Property Y -Minimum).Minimum
            $x1 = ($xs | ForEach-Object { $_.X + $_.Width } | Measure-Object -Maximum).Maximum
            $y1 = ($xs | ForEach-Object { $_.Y + $_.Height } | Measure-Object -Maximum).Maximum
            $lines += [ordered]@{ text = $ln.Text; x = [int]$x0; y = [int]$y0; w = [int]($x1 - $x0); h = [int]($y1 - $y0) }
        }
        $stream.Dispose()
        $out = [ordered]@{ path = $path; ms = $sw.ElapsedMilliseconds; lines = $lines }
    } catch {
        $out = [ordered]@{ path = $path; ms = $sw.ElapsedMilliseconds; error = $_.Exception.Message; lines = @() }
    }
    [Console]::Out.WriteLine(($out | ConvertTo-Json -Compress -Depth 4))
    [Console]::Out.Flush()
}
