# Generates the site's "AI" monogram icon set: favicon.svg, favicon-32.png,
# favicon-192.png, apple-touch-icon.png and a 3-frame favicon.ico.
#
# Run from anywhere:  powershell -File tools\make-favicon.ps1
#
# The letter outline is built once with GraphicsPath.AddString and then used for
# BOTH outputs -- emitted as the SVG path 'd' attribute and rasterised for the
# PNGs -- so the vector and raster icons are guaranteed to be the same shape.
# To recolour the mark, change $FIELD / $MARK below and re-run.

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot

# ---- design tokens (match assets/css/style.css) ----
$FIELD = "#0B0F14"   # tile: the page background
$MARK  = "#C9A86A"   # letters: the site accent
$S     = 512.0       # master coordinate space / SVG viewBox
$R     = 112.0       # tile corner radius
$FONT  = "Georgia"
$EM    = 292.0       # glyph em size -> cap height ~40% of the tile
$TRACK = 26.0        # extra tracking between A and I, for 16px legibility

# ---- build the "AI" outline, letter by letter so tracking can be widened ----
$fam = New-Object System.Drawing.FontFamily($FONT)
$sf  = New-Object System.Drawing.StringFormat([System.Drawing.StringFormat]::GenericTypographic)

function New-Letter([string]$ch) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddString($ch, $fam, [int][System.Drawing.FontStyle]::Bold, $EM,
                 (New-Object System.Drawing.PointF(0, 0)), $sf)
    return $p
}

$pA = New-Letter "A"
$pI = New-Letter "I"
$bA = $pA.GetBounds(); $bI = $pI.GetBounds()
$shift = New-Object System.Drawing.Drawing2D.Matrix
$shift.Translate(($bA.Right + $TRACK) - $bI.X, 0)
$pI.Transform($shift)

$glyph = New-Object System.Drawing.Drawing2D.GraphicsPath
$glyph.AddPath($pA, $false)
$glyph.AddPath($pI, $false)
$pA.Dispose(); $pI.Dispose()

# centre the combined outline in the tile
$b = $glyph.GetBounds()
$centre = New-Object System.Drawing.Drawing2D.Matrix
$centre.Translate(((($S - $b.Width) / 2.0) - $b.X), ((($S - $b.Height) / 2.0) - $b.Y))
$glyph.Transform($centre)
Write-Host ("glyph: {0:N1} x {1:N1} in a {2} tile" -f $b.Width, $b.Height, $S)

# ---- GraphicsPath -> SVG path data ----
function ConvertTo-SvgPath {
    param([System.Drawing.Drawing2D.GraphicsPath]$Path)
    $pts = $Path.PathPoints; $types = $Path.PathTypes
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $pts.Length; $i++) {
        $t = $types[$i] -band 0x07
        $close = ($types[$i] -band 0x80) -ne 0
        $p = $pts[$i]
        switch ($t) {
            0 { $s = "M{0:N2} {1:N2}" -f $p.X, $p.Y; [void]$sb.Append($s) }
            1 { $s = "L{0:N2} {1:N2}" -f $p.X, $p.Y; [void]$sb.Append($s) }
            3 {
                # cubic bezier: three consecutive points
                $c1 = $pts[$i]; $c2 = $pts[$i + 1]; $e = $pts[$i + 2]
                $close = ($types[$i + 2] -band 0x80) -ne 0
                $s = "C{0:N2} {1:N2} {2:N2} {3:N2} {4:N2} {5:N2}" -f `
                     $c1.X, $c1.Y, $c2.X, $c2.Y, $e.X, $e.Y
                [void]$sb.Append($s)
                $i += 2
            }
        }
        if ($close) { [void]$sb.Append("Z") }
    }
    return $sb.ToString()
}

$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-label="Amin Izadyar">
  <rect width="512" height="512" rx="$R" ry="$R" fill="$FIELD"/>
  <path fill="$MARK" d="$(ConvertTo-SvgPath -Path $glyph)"/>
</svg>
"@
[System.IO.File]::WriteAllText((Join-Path $root "favicon.svg"), $svg,
                               (New-Object System.Text.UTF8Encoding($false)))
Write-Host "wrote favicon.svg"

# ---- rasterise ----
function New-RoundedPath([single]$w, [single]$h, [single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc(0, 0, $d, $d, 180, 90)
    $p.AddArc($w - $d, 0, $d, $d, 270, 90)
    $p.AddArc($w - $d, $h - $d, $d, $d, 0, 90)
    $p.AddArc(0, $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

# $Rounded:$false is for apple-touch-icon.png -- iOS applies its own mask, so the
# source must be full-bleed square or the corners get clipped twice.
function New-Master([bool]$Rounded) {
    $bmp = New-Object System.Drawing.Bitmap([int]$S, [int]$S,
               [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $field = New-Object System.Drawing.SolidBrush(
                 [System.Drawing.ColorTranslator]::FromHtml($FIELD))
    if ($Rounded) {
        $rp = New-RoundedPath $S $S $R
        $g.FillPath($field, $rp)
        $rp.Dispose()
    } else {
        $g.FillRectangle($field, 0, 0, $S, $S)
    }

    $mark = New-Object System.Drawing.SolidBrush(
                [System.Drawing.ColorTranslator]::FromHtml($MARK))
    $g.FillPath($mark, $glyph)

    $mark.Dispose(); $field.Dispose(); $g.Dispose()
    return $bmp
}

function Get-Scaled($master, [int]$size, [string]$outPath) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size,
               [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode   = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode     = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality  = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.SmoothingMode       = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($master, (New-Object System.Drawing.Rectangle(0, 0, $size, $size)))
    $g.Dispose()
    if ($outPath) {
        $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "wrote $(Split-Path -Leaf $outPath)"
    }
    return $bmp
}

$masterRounded = New-Master $true
$masterSquare  = New-Master $false

(Get-Scaled $masterRounded 32  (Join-Path $root "favicon-32.png")).Dispose()
(Get-Scaled $masterRounded 192 (Join-Path $root "favicon-192.png")).Dispose()
(Get-Scaled $masterSquare  180 (Join-Path $root "apple-touch-icon.png")).Dispose()

# ---- multi-size .ico with PNG frames (Vista+ format) ----
$frames = @()
foreach ($size in @(16, 32, 48)) {
    $bmp = Get-Scaled $masterRounded $size $null
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $frames += , @{ size = $size; bytes = $ms.ToArray() }
    $ms.Dispose(); $bmp.Dispose()
}

$out = New-Object System.IO.MemoryStream
$bw  = New-Object System.IO.BinaryWriter($out)
$bw.Write([uint16]0)                 # reserved
$bw.Write([uint16]1)                 # type: icon
$bw.Write([uint16]$frames.Count)
$offset = 6 + (16 * $frames.Count)   # past the directory
foreach ($f in $frames) {
    $bw.Write([byte]$(if ($f.size -ge 256) { 0 } else { $f.size }))   # width
    $bw.Write([byte]$(if ($f.size -ge 256) { 0 } else { $f.size }))   # height
    $bw.Write([byte]0)               # palette entries
    $bw.Write([byte]0)               # reserved
    $bw.Write([uint16]1)             # colour planes
    $bw.Write([uint16]32)            # bits per pixel
    $bw.Write([uint32]$f.bytes.Length)
    $bw.Write([uint32]$offset)
    $offset += $f.bytes.Length
}
foreach ($f in $frames) { $bw.Write($f.bytes) }
$bw.Flush()
[System.IO.File]::WriteAllBytes((Join-Path $root "favicon.ico"), $out.ToArray())
$bw.Dispose(); $out.Dispose()
Write-Host "wrote favicon.ico ($($frames.Count) frames)"

$masterRounded.Dispose(); $masterSquare.Dispose(); $glyph.Dispose()
Write-Host "done"
