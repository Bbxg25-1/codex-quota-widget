param(
  [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) "assets")
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class CodexQuotaNativeMethods {
  [DllImport("user32.dll", CharSet = CharSet.Auto)]
  public static extern bool DestroyIcon(IntPtr handle);
}
'@

function New-RoundedPath {
  param(
    [System.Drawing.RectangleF]$Bounds,
    [float]$Radius
  )

  $diameter = $Radius * 2
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc($Bounds.X, $Bounds.Y, $diameter, $diameter, 180, 90)
  $path.AddArc($Bounds.Right - $diameter, $Bounds.Y, $diameter, $diameter, 270, 90)
  $path.AddArc($Bounds.Right - $diameter, $Bounds.Bottom - $diameter, $diameter, $diameter, 0, 90)
  $path.AddArc($Bounds.X, $Bounds.Bottom - $diameter, $diameter, $diameter, 90, 90)
  $path.CloseFigure()
  return $path
}

function New-QuotaArtwork {
  param([int]$Size)

  $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

  $bounds = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
  $background = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $bounds,
    [System.Drawing.Color]::FromArgb(255, 255, 227, 241),
    [System.Drawing.Color]::FromArgb(255, 228, 220, 255),
    38
  )
  $graphics.FillRectangle($background, $bounds)

  $panelBounds = New-Object System.Drawing.RectangleF(($Size * 0.15), ($Size * 0.18), ($Size * 0.70), ($Size * 0.64))
  $panelPath = New-RoundedPath $panelBounds ($Size * 0.09)
  $panelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(248, 255, 253, 255))
  $panelPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 237, 181, 212), ($Size * 0.018))
  $graphics.FillPath($panelBrush, $panelPath)
  $graphics.DrawPath($panelPen, $panelPath)

  $green = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 47, 93, 80))
  $pink = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 247, 168, 200))
  $lavender = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 176, 166, 245))
  $track = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 236, 229, 235))

  $graphics.FillEllipse($pink, ($Size * 0.22), ($Size * 0.25), ($Size * 0.11), ($Size * 0.11))
  $graphics.FillEllipse($lavender, ($Size * 0.68), ($Size * 0.25), ($Size * 0.07), ($Size * 0.07))

  foreach ($row in @(
    @{ Y = 0.43; Fill = 0.50; Brush = $green },
    @{ Y = 0.56; Fill = 0.34; Brush = $pink },
    @{ Y = 0.69; Fill = 0.43; Brush = $lavender }
  )) {
    $trackRect = New-Object System.Drawing.RectangleF(($Size * 0.25), ($Size * $row.Y), ($Size * 0.50), ($Size * 0.055))
    $trackPath = New-RoundedPath $trackRect ($Size * 0.0275)
    $graphics.FillPath($track, $trackPath)
    $fillRect = New-Object System.Drawing.RectangleF($trackRect.X, $trackRect.Y, ($Size * $row.Fill), $trackRect.Height)
    $fillPath = New-RoundedPath $fillRect ($Size * 0.0275)
    $graphics.FillPath($row.Brush, $fillPath)
    $fillPath.Dispose()
    $trackPath.Dispose()
  }

  $background.Dispose()
  $panelBrush.Dispose()
  $panelPen.Dispose()
  $green.Dispose()
  $pink.Dispose()
  $lavender.Dispose()
  $track.Dispose()
  $panelPath.Dispose()
  $graphics.Dispose()
  return $bitmap
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$pngPath = Join-Path $OutputDirectory "codex-quota-widget.png"
$icoPath = Join-Path $OutputDirectory "codex-quota-widget.ico"

$pngBitmap = New-QuotaArtwork 1024
$pngBitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBitmap.Dispose()

$iconBitmap = New-QuotaArtwork 256
$iconHandle = $iconBitmap.GetHicon()
try {
  $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
  $stream = [System.IO.File]::Create($icoPath)
  try {
    $icon.Save($stream)
  } finally {
    $stream.Dispose()
    $icon.Dispose()
  }
} finally {
  [void][CodexQuotaNativeMethods]::DestroyIcon($iconHandle)
  $iconBitmap.Dispose()
}

Write-Output "Created: $pngPath"
Write-Output "Created: $icoPath"

