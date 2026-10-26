Add-Type -AssemblyName System.Drawing
$kopiRoot = Split-Path -Parent $PSScriptRoot
$kopiTargets = @{'web/favicon.png'=64; 'web/icons/Icon-192.png'=192; 'web/icons/Icon-512.png'=512; 'web/icons/Icon-maskable-192.png'=192; 'web/icons/Icon-maskable-512.png'=512}
$kopiIos = Get-Content -Raw (Join-Path $kopiRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') | ConvertFrom-Json
foreach ($kopiItem in $kopiIos.images) {
    $kopiSize = [double]($kopiItem.size -split 'x')[0] * [double]($kopiItem.scale -replace 'x','')
    $kopiTargets['ios/Runner/Assets.xcassets/AppIcon.appiconset/' + $kopiItem.filename] = [int]$kopiSize
}
foreach ($kopiEntry in $kopiTargets.GetEnumerator()) {
    $kopiDim = [int]$kopiEntry.Value
    $kopiBmp = [System.Drawing.Bitmap]::new($kopiDim, $kopiDim)
    $kopiGraphics = [System.Drawing.Graphics]::FromImage($kopiBmp)
    $kopiGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $kopiGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#FCFAF8'))
    $kopiPetal = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#E0B9CC'))
    $kopiCenter = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#FCFAF8'))
    $kopiRadius = $kopiDim * 0.14
    for ($kopiIndex = 0; $kopiIndex -lt 5; $kopiIndex++) {
        $kopiAngle = -[Math]::PI / 2 + $kopiIndex * 2 * [Math]::PI / 5
        $kopiX = $kopiDim / 2 + [Math]::Cos($kopiAngle) * $kopiDim * 0.22 - $kopiRadius
        $kopiY = $kopiDim / 2 + [Math]::Sin($kopiAngle) * $kopiDim * 0.22 - $kopiRadius
        $kopiGraphics.FillEllipse($kopiPetal, [single]$kopiX, [single]$kopiY, [single]($kopiRadius * 2), [single]($kopiRadius * 2))
    }
    $kopiGraphics.FillEllipse($kopiCenter, [single]($kopiDim * 0.38), [single]($kopiDim * 0.38), [single]($kopiDim * 0.24), [single]($kopiDim * 0.24))
    $kopiBmp.Save((Join-Path $kopiRoot $kopiEntry.Key), [System.Drawing.Imaging.ImageFormat]::Png)
    $kopiGraphics.Dispose(); $kopiPetal.Dispose(); $kopiCenter.Dispose(); $kopiBmp.Dispose()
}
