$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = [System.Drawing.Bitmap]::new((Join-Path $projectRoot 'assets\images\TrendKicks-Logo.png'))

# These rectangles select the supplied artwork, preserving its original pixels.
# No replacement logo is drawn; only layout crops and platform sizes are generated.
$full = [System.Drawing.Rectangle]::new(104, 242, 1062, 750)
$wordmark = [System.Drawing.Rectangle]::new(104, 842, 1062, 150)
$mark = [System.Drawing.Rectangle]::new(184, 242, 858, 582)

function New-BrandBitmap([int]$width, [int]$height, [System.Drawing.Rectangle]$sourceRect, [double]$padding = 0) {
    # Opaque RGB also satisfies Apple's no-alpha requirement for app icons.
    $bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::Black)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $scale = [math]::Min($width * (1 - 2 * $padding) / $sourceRect.Width, $height * (1 - 2 * $padding) / $sourceRect.Height)
        $targetWidth = [single]($sourceRect.Width * $scale)
        $targetHeight = [single]($sourceRect.Height * $scale)
        $targetRect = [System.Drawing.RectangleF]::new([single](($width - $targetWidth) / 2), [single](($height - $targetHeight) / 2), $targetWidth, $targetHeight)
        $graphics.DrawImage($source, $targetRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    } finally { $graphics.Dispose() }
    return $bitmap
}

function Save-BrandPng([string]$relativePath, [int]$width, [int]$height, [System.Drawing.Rectangle]$sourceRect, [double]$padding = 0) {
    $destination = Join-Path $projectRoot $relativePath
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($destination)) | Out-Null
    $bitmap = New-BrandBitmap $width $height $sourceRect $padding
    try { $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }
}

function Save-BrandIco([string]$relativePath) {
    $sizes = @(16, 24, 32, 48, 64, 128, 256)
    $images = [System.Collections.Generic.List[byte[]]]::new()
    foreach ($size in $sizes) {
        $bitmap = New-BrandBitmap $size $size $mark 0.08
        $stream = [System.IO.MemoryStream]::new()
        try { $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png); $images.Add($stream.ToArray()) }
        finally { $bitmap.Dispose(); $stream.Dispose() }
    }
    $file = [System.IO.File]::Create((Join-Path $projectRoot $relativePath))
    $writer = [System.IO.BinaryWriter]::new($file)
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
        $offset = 6 + 16 * $sizes.Count
        for ($i = 0; $i -lt $sizes.Count; $i++) {
            $dimension = if ($sizes[$i] -eq 256) { 0 } else { $sizes[$i] }
            $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
            $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([uint16]1); $writer.Write([uint16]24)
            $writer.Write([uint32]$images[$i].Length); $writer.Write([uint32]$offset)
            $offset += $images[$i].Length
        }
        foreach ($bytes in $images) { $writer.Write([byte[]]$bytes) }
    } finally { $writer.Dispose(); $file.Dispose() }
}

try {
    Save-BrandPng 'assets\branding\logo.png' 1062 750 $full
    Save-BrandPng 'assets\branding\wordmark.png' 1062 150 $wordmark
    Save-BrandPng 'assets\branding\mark.png' 858 582 $mark
    foreach ($density in @(@('mdpi',1),@('hdpi',1.5),@('xhdpi',2),@('xxhdpi',3),@('xxxhdpi',4))) {
        $iconSize = [int](48 * $density[1])
        Save-BrandPng "android\app\src\main\res\mipmap-$($density[0])\ic_launcher.png" $iconSize $iconSize $mark 0.08
        Save-BrandPng "android\app\src\main\res\drawable-$($density[0])\trendkicks_splash.png" ([int](240 * $density[1])) ([int](166 * $density[1])) $full
    }
    Save-BrandPng 'android\app\src\main\res\drawable\trendkicks_launcher.png' 432 432 $mark 0.2
    foreach ($platform in @('ios','macos')) {
        $catalog = "$platform\Runner\Assets.xcassets\AppIcon.appiconset"
        $contents = Get-Content -LiteralPath (Join-Path $projectRoot "$catalog\Contents.json") -Raw | ConvertFrom-Json
        foreach ($entry in $contents.images) {
            if (!$entry.filename) { continue }
            $size = [int]([double]($entry.size -split 'x')[0] * [double]($entry.scale.TrimEnd('x')))
            Save-BrandPng "$catalog\$($entry.filename)" $size $size $mark 0.08
        }
    }
    foreach ($scale in @(1,2,3)) {
        $suffix = if ($scale -eq 1) { '' } else { "@$($scale)x" }
        Save-BrandPng "ios\Runner\Assets.xcassets\LaunchImage.imageset\LaunchImage$suffix.png" (180 * $scale) (125 * $scale) $full
    }
    foreach ($size in @(192,512)) {
        Save-BrandPng "web\icons\Icon-$size.png" $size $size $mark 0.08
        Save-BrandPng "web\icons\Icon-maskable-$size.png" $size $size $mark 0.2
    }
    Save-BrandPng 'web\icons\apple-touch-icon.png' 180 180 $mark 0.08
    Save-BrandPng 'web\favicon.png' 48 48 $mark 0.08
    Save-BrandIco 'windows\runner\resources\app_icon.ico'
    Write-Output 'Generated app logos, launcher icons, splash images, favicon, and desktop icons from TrendKicks-Logo.png.'
} finally { $source.Dispose() }
