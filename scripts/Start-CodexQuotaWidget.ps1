param(
  [string]$CodexHome = (Join-Path $env:USERPROFILE ".codex"),
  [int]$RefreshSeconds = 5
)

$snapshotScript = Join-Path $PSScriptRoot "Get-CodexQuotaSnapshot.ps1"
. $snapshotScript

$script:SingleInstanceMutexName = "Local\CodexQuotaWidget.SingleInstance"
$script:ShowEventName = "Local\CodexQuotaWidget.ShowWindow"
$script:SingleInstanceMutex = $null
$script:ShowEvent = $null
$script:IsSingleInstanceOwner = $false

$createdNew = $false
$script:SingleInstanceMutex = New-Object System.Threading.Mutex($true, $script:SingleInstanceMutexName, [ref]$createdNew)
if (-not $createdNew) {
  try {
    $existingEvent = [System.Threading.EventWaitHandle]::OpenExisting($script:ShowEventName)
    [void]$existingEvent.Set()
    $existingEvent.Dispose()
  } catch {
  }
  return
}

$script:IsSingleInstanceOwner = $true
$script:ShowEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, $script:ShowEventName)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace CodexQuotaWidget {
  public class RoundedPanel : Panel {
    public int Radius { get; set; } = 16;
    public Color FillColor { get; set; } = Color.White;
    public Color StrokeColor { get; set; } = Color.FromArgb(230, 224, 216);
    public int StrokeWidth { get; set; } = 1;

    public RoundedPanel() {
      this.SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.SupportsTransparentBackColor, true);
      this.DoubleBuffered = true;
      this.BackColor = Color.Transparent;
      this.UpdateStyles();
    }

    protected override void OnPaint(PaintEventArgs e) {
      base.OnPaint(e);
      e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
      Rectangle rect = new Rectangle(0, 0, this.Width - 1, this.Height - 1);
      using (GraphicsPath path = RoundRect(rect, this.Radius))
      using (SolidBrush fill = new SolidBrush(this.FillColor))
      using (Pen stroke = new Pen(this.StrokeColor, this.StrokeWidth)) {
        e.Graphics.FillPath(fill, path);
        e.Graphics.DrawPath(stroke, path);
      }
    }

    private static GraphicsPath RoundRect(Rectangle bounds, int radius) {
      int diameter = radius * 2;
      GraphicsPath path = new GraphicsPath();
      path.AddArc(bounds.X, bounds.Y, diameter, diameter, 180, 90);
      path.AddArc(bounds.Right - diameter, bounds.Y, diameter, diameter, 270, 90);
      path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
      path.AddArc(bounds.X, bounds.Bottom - diameter, diameter, diameter, 90, 90);
      path.CloseFigure();
      return path;
    }
  }

  public class PercentBar : Control {
    private double percent = 0;
    public double Percent {
      get { return percent; }
      set {
        percent = Math.Max(0, Math.Min(100, value));
        this.Invalidate();
      }
    }

    public Color TrackColor { get; set; } = Color.FromArgb(235, 230, 224);
    public Color FillColor { get; set; } = Color.FromArgb(47, 93, 80);
    public Color GlowColor { get; set; } = Color.FromArgb(247, 168, 200);
    public int Radius { get; set; } = 7;

    public PercentBar() {
      this.SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.SupportsTransparentBackColor, true);
      this.DoubleBuffered = true;
      this.Height = 14;
      this.UpdateStyles();
    }

    protected override void OnPaint(PaintEventArgs e) {
      base.OnPaint(e);
      e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
      Rectangle track = new Rectangle(0, 0, this.Width - 1, this.Height - 1);
      using (GraphicsPath trackPath = RoundRect(track, this.Radius))
      using (SolidBrush trackBrush = new SolidBrush(this.TrackColor)) {
        e.Graphics.FillPath(trackBrush, trackPath);
      }

      int fillWidth = (int)Math.Round((this.Width - 1) * (this.Percent / 100.0));
      if (fillWidth > 0) {
        Rectangle fill = new Rectangle(0, 0, Math.Max(fillWidth, this.Height), this.Height - 1);
        using (GraphicsPath fillPath = RoundRect(fill, this.Radius))
        using (LinearGradientBrush brush = new LinearGradientBrush(fill, this.FillColor, this.GlowColor, LinearGradientMode.Horizontal)) {
          e.Graphics.FillPath(brush, fillPath);
        }
      }
    }

    private static GraphicsPath RoundRect(Rectangle bounds, int radius) {
      int diameter = radius * 2;
      GraphicsPath path = new GraphicsPath();
      path.AddArc(bounds.X, bounds.Y, diameter, diameter, 180, 90);
      path.AddArc(bounds.Right - diameter, bounds.Y, diameter, diameter, 270, 90);
      path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
      path.AddArc(bounds.X, bounds.Bottom - diameter, diameter, diameter, 90, 90);
      path.CloseFigure();
      return path;
    }
  }
}
'@

$colors = @{
  Shell = [System.Drawing.Color]::FromArgb(255, 246, 250)
  Card = [System.Drawing.Color]::FromArgb(255, 253, 250)
  CardSoft = [System.Drawing.Color]::FromArgb(255, 248, 252)
  Border = [System.Drawing.Color]::FromArgb(239, 213, 226)
  Ink = [System.Drawing.Color]::FromArgb(31, 35, 33)
  Muted = [System.Drawing.Color]::FromArgb(105, 112, 108)
  SoftMuted = [System.Drawing.Color]::FromArgb(139, 128, 133)
  CodexGreen = [System.Drawing.Color]::FromArgb(47, 93, 80)
  TaffyPink = [System.Drawing.Color]::FromArgb(247, 168, 200)
  TaffyLavender = [System.Drawing.Color]::FromArgb(176, 166, 245)
  Warm = [System.Drawing.Color]::FromArgb(244, 176, 112)
  Alert = [System.Drawing.Color]::FromArgb(219, 95, 104)
  Track = [System.Drawing.Color]::FromArgb(236, 230, 224)
}

$script:CodexQuotaFontName = "Microsoft YaHei UI"
try {
  [void](New-Object System.Drawing.FontFamily($script:CodexQuotaFontName))
} catch {
  $script:CodexQuotaFontName = "Segoe UI"
}

$pluginRoot = Split-Path -Parent $PSScriptRoot
$assetsRoot = Join-Path $pluginRoot "assets"
$characterCardPath = Join-Path $assetsRoot "taffy-character-card.png"
$characterRawPath = Join-Path $assetsRoot "taffy-character.png"
$characterPath = if (Test-Path -LiteralPath $characterCardPath) { $characterCardPath } else { $characterRawPath }
$logoPath = Join-Path $assetsRoot "taffy-logo.png"
$headshotIconPath = Join-Path $assetsRoot "taffy-headshot.ico"
$layoutOffsetX = 132
$script:PrimaryRemaining = 0.0
$script:SecondaryRemaining = 0.0
$script:PrimaryBarColor = $colors.CodexGreen
$script:SecondaryBarColor = $colors.CodexGreen
$script:backdropBox = $null
$script:ManualHidden = $false
$script:WidgetIconIsCustom = $false
$script:Refreshing = $false

function Format-Number {
  param([object]$Value)
  if ($null -eq $Value) { return "-" }
  try { return "{0:N0}" -f [double]$Value } catch { return "$Value" }
}

function Percent-Or-Zero {
  param([object]$Value)
  if ($null -eq $Value) { return 0.0 }
  try { return [double]$Value } catch { return 0.0 }
}

function Set-BarPalette {
  param(
    [CodexQuotaWidget.PercentBar]$Bar,
    [object]$Remaining
  )

  $remainingValue = Percent-Or-Zero $Remaining
  if ($remainingValue -lt 15) {
    $Bar.FillColor = $colors.Alert
    $Bar.GlowColor = $colors.TaffyPink
  } elseif ($remainingValue -lt 40) {
    $Bar.FillColor = $colors.Warm
    $Bar.GlowColor = $colors.TaffyPink
  } else {
    $Bar.FillColor = $colors.CodexGreen
    $Bar.GlowColor = $colors.TaffyLavender
  }
}

function New-Label {
  param(
    [string]$Text,
    [int]$X,
    [int]$Y,
    [int]$Width,
    [int]$Height = 20,
    [int]$Size = 9,
    [string]$Weight = "Regular",
    [System.Drawing.Color]$Color = $colors.Ink
  )

  $label = New-Object System.Windows.Forms.Label
  $label.Text = $Text
  $label.Location = New-Object System.Drawing.Point($X, $Y)
  $label.Size = New-Object System.Drawing.Size($Width, $Height)
  $label.Font = New-Object System.Drawing.Font($script:CodexQuotaFontName, $Size, $Weight)
  $label.ForeColor = $Color
  $label.BackColor = [System.Drawing.Color]::Transparent
  return $label
}

function New-RoundedPanel {
  param(
    [int]$X,
    [int]$Y,
    [int]$Width,
    [int]$Height,
    [System.Drawing.Color]$Fill,
    [int]$Radius = 14
  )

  $panel = New-Object CodexQuotaWidget.RoundedPanel
  $panel.Location = New-Object System.Drawing.Point($X, $Y)
  $panel.Size = New-Object System.Drawing.Size($Width, $Height)
  $panel.FillColor = $Fill
  $panel.BackColor = $Fill
  $panel.StrokeColor = $colors.Border
  $panel.Radius = $Radius
  return $panel
}

function Get-ImageOrNull {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }

  try {
    return [System.Drawing.Image]::FromFile($Path)
  } catch {
    return $null
  }
}

function Get-WidgetIcon {
  param([string]$Path)

  if (Test-Path -LiteralPath $Path) {
    try {
      $script:WidgetIconIsCustom = $true
      return New-Object System.Drawing.Icon($Path)
    } catch {
      $script:WidgetIconIsCustom = $false
    }
  }

  return [System.Drawing.SystemIcons]::Information
}

function New-PictureBox {
  param(
    [System.Drawing.Image]$Image,
    [int]$X,
    [int]$Y,
    [int]$Width,
    [int]$Height
  )

  $box = New-Object System.Windows.Forms.PictureBox
  $box.Image = $Image
  $box.Location = New-Object System.Drawing.Point($X, $Y)
  $box.Size = New-Object System.Drawing.Size($Width, $Height)
  $box.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
  $box.BackColor = [System.Drawing.Color]::Transparent
  return $box
}

function New-RoundRectPath {
  param(
    [int]$X,
    [int]$Y,
    [int]$Width,
    [int]$Height,
    [int]$Radius
  )

  $diameter = $Radius * 2
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
  $path.AddArc(($X + $Width - $diameter), $Y, $diameter, $diameter, 270, 90)
  $path.AddArc(($X + $Width - $diameter), ($Y + $Height - $diameter), $diameter, $diameter, 0, 90)
  $path.AddArc($X, ($Y + $Height - $diameter), $diameter, $diameter, 90, 90)
  $path.CloseFigure()
  return $path
}

function Draw-RoundRect {
  param(
    [System.Drawing.Graphics]$Graphics,
    [int]$X,
    [int]$Y,
    [int]$Width,
    [int]$Height,
    [int]$Radius,
    [System.Drawing.Color]$Fill,
    [System.Drawing.Color]$Stroke
  )

  $path = New-RoundRectPath $X $Y $Width $Height $Radius
  $brush = New-Object System.Drawing.SolidBrush($Fill)
  $pen = New-Object System.Drawing.Pen($Stroke, 1)
  $Graphics.FillPath($brush, $path)
  $Graphics.DrawPath($pen, $path)
  $pen.Dispose()
  $brush.Dispose()
  $path.Dispose()
}

function Draw-QuotaBar {
  param(
    [System.Drawing.Graphics]$Graphics,
    [int]$X,
    [int]$Y,
    [int]$Width,
    [int]$Height,
    [double]$Percent,
    [System.Drawing.Color]$Fill
  )

  Draw-RoundRect $Graphics $X $Y $Width $Height 6 $colors.Track ([System.Drawing.Color]::FromArgb(226, 218, 222))
  $fillWidth = [Math]::Round($Width * ([Math]::Max(0, [Math]::Min(100, $Percent)) / 100.0))
  if ($fillWidth -lt 3) {
    return
  }

  $path = New-RoundRectPath $X $Y ([int]$fillWidth) $Height 6
  $rect = New-Object System.Drawing.Rectangle($X, $Y, [int]$fillWidth, $Height)
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    $Fill,
    $colors.TaffyPink,
    [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
  )
  $Graphics.FillPath($brush, $path)
  $brush.Dispose()
  $path.Dispose()
}

function New-BackdropImage {
  $bitmap = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

  $bounds = New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $bounds,
    [System.Drawing.Color]::FromArgb(255, 250, 244, 249),
    [System.Drawing.Color]::FromArgb(255, 246, 228, 255),
    28
  )
  $rose = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(86, 255, 197, 224))
  $lav = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(66, 204, 202, 255))
  $spark = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(140, $colors.TaffyPink), 2)

  $graphics.FillRectangle($bg, $bounds)
  $graphics.FillEllipse($rose, -48, 28, 166, 166)
  $graphics.FillEllipse($lav, 52, 262, 136, 136)
  $graphics.FillEllipse($rose, 414, -42, 166, 166)
  $graphics.DrawLine($spark, 482, 46, 501, 65)
  $graphics.DrawLine($spark, 501, 46, 482, 65)

  Draw-RoundRect $graphics ($layoutOffsetX + 8) 18 400 322 20 $colors.Card $colors.Border
  Draw-RoundRect $graphics ($layoutOffsetX + 22) 200 356 48 12 $colors.CardSoft $colors.Border
  Draw-RoundRect $graphics ($layoutOffsetX + 22) 254 356 48 12 $colors.CardSoft $colors.Border

  Draw-QuotaBar $graphics ($layoutOffsetX + 34) 232 322 10 $script:PrimaryRemaining $script:PrimaryBarColor
  Draw-QuotaBar $graphics ($layoutOffsetX + 34) 286 322 10 $script:SecondaryRemaining $script:SecondaryBarColor

  $spark.Dispose()
  $rose.Dispose()
  $lav.Dispose()
  $bg.Dispose()
  $graphics.Dispose()
  return $bitmap
}

function Refresh-Backdrop {
  if ($null -eq $script:backdropBox) {
    return
  }

  $oldImage = $script:backdropBox.Image
  $script:backdropBox.Image = New-BackdropImage
  if ($null -ne $oldImage) {
    $oldImage.Dispose()
  }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Codex 额度小窗"
$form.Size = New-Object System.Drawing.Size(552, 360)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.BackColor = $colors.Shell
$widgetIcon = Get-WidgetIcon $headshotIconPath
$form.Icon = $widgetIcon
$form.Paint.Add({
  param($sender, $event)
  $g = $event.Graphics
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width, $sender.Height)
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(255, 250, 244, 249),
    [System.Drawing.Color]::FromArgb(255, 247, 230, 255),
    28
  )
  $rose = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(74, 255, 198, 224))
  $lav = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(58, 208, 204, 255))

  $g.FillRectangle($bg, $rect)
  $g.FillEllipse($rose, -46, 30, 164, 164)
  $g.FillEllipse($lav, 64, 260, 128, 128)
  $g.FillEllipse($rose, 418, -38, 156, 156)

  $bg.Dispose()
  $rose.Dispose()
  $lav.Dispose()
})

$workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location = New-Object System.Drawing.Point(($workingArea.Right - $form.Width - 18), ($workingArea.Top + 28))

$script:backdropBox = New-Object System.Windows.Forms.PictureBox
$script:backdropBox.Location = New-Object System.Drawing.Point(0, 0)
$script:backdropBox.Size = New-Object System.Drawing.Size($form.Width, $form.Height)
$script:backdropBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Normal
$script:backdropBox.BackColor = $colors.Shell
$form.Controls.Add($script:backdropBox)
Refresh-Backdrop
$script:backdropBox.SendToBack()

$card = New-RoundedPanel 8 8 400 322 $colors.Card 20
$card.Left = $card.Left + $layoutOffsetX
$card.Top = $card.Top + 10
$card.Paint.Add({
  param($sender, $event)
  $g = $event.Graphics
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

  $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width, $sender.Height)
  $wash = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(78, 255, 226, 240),
    [System.Drawing.Color]::FromArgb(44, 236, 229, 255),
    35
  )

  $pinkBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(42, $colors.TaffyPink))
  $lavBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(36, $colors.TaffyLavender))
  $linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, $colors.TaffyPink), 2)

  $g.FillRectangle($wash, $rect)
  $g.FillEllipse($pinkBrush, 314, -34, 116, 116)
  $g.FillEllipse($lavBrush, 334, 68, 48, 48)
  $g.FillEllipse($pinkBrush, -34, 246, 102, 102)
  $g.DrawLine($linePen, 336, 26, 356, 46)
  $g.DrawLine($linePen, 356, 26, 336, 46)

  $wash.Dispose()
  $pinkBrush.Dispose()
  $lavBrush.Dispose()
  $linePen.Dispose()
})

$form.Controls.Add($card)

$characterImage = Get-ImageOrNull $characterPath
$logoImage = Get-ImageOrNull $logoPath
$characterBox = $null
$characterFallback = $null

if ($null -ne $characterImage) {
  $characterBox = New-PictureBox $characterImage 16 224 122 122
  $form.Controls.Add($characterBox)
} else {
  $characterFallback = New-RoundedPanel 16 218 122 128 ([System.Drawing.Color]::FromArgb(255, 239, 247)) 28
  $characterFallback.StrokeColor = [System.Drawing.Color]::FromArgb(235, 188, 211)
  $characterFallback.Paint.Add({
    param($sender, $event)
    $g = $event.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $hair = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(246, 154, 198))
    $skin = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 225, 213))
    $lav = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(184, 174, 248))
    $inkPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(90, 69, 78), 2)
    $softPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 172, 207), 3)

    $g.FillEllipse($hair, 20, 24, 76, 92)
    $g.FillEllipse($skin, 28, 42, 60, 62)
    $g.FillPolygon($lav, @(
      [System.Drawing.Point]::new(16, 18),
      [System.Drawing.Point]::new(42, 30),
      [System.Drawing.Point]::new(22, 46)
    ))
    $g.FillPolygon($lav, @(
      [System.Drawing.Point]::new(74, 30),
      [System.Drawing.Point]::new(101, 18),
      [System.Drawing.Point]::new(96, 48)
    ))
    $g.DrawArc($inkPen, 42, 65, 12, 10, 0, 180)
    $g.DrawArc($inkPen, 66, 65, 12, 10, 0, 180)
    $g.DrawArc($inkPen, 48, 78, 22, 12, 10, 160)
    $g.DrawCurve($softPen, @(
      [System.Drawing.Point]::new(15, 125),
      [System.Drawing.Point]::new(42, 144),
      [System.Drawing.Point]::new(88, 142),
      [System.Drawing.Point]::new(105, 126)
    ))
    $g.DrawString("塔菲", [System.Drawing.Font]::new("Microsoft YaHei UI", 10, [System.Drawing.FontStyle]::Bold), $lav, 34, 92)

    $hair.Dispose()
    $skin.Dispose()
    $lav.Dispose()
    $inkPen.Dispose()
    $softPen.Dispose()
  })
  $form.Controls.Add($characterFallback)
}

$upperArm = $null
$lowerArm = $null

$close = New-Object System.Windows.Forms.Button
$close.Text = "关"
$close.Location = New-Object System.Drawing.Point(360, 18)
$close.Size = New-Object System.Drawing.Size(28, 24)
$close.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$close.FlatAppearance.BorderSize = 0
$close.BackColor = $colors.Card
$close.ForeColor = $colors.Muted
$close.Font = New-Object System.Drawing.Font($script:CodexQuotaFontName, 8, "Regular")
$close.Add_Click({
  $script:ManualHidden = $true
  $form.Hide()
})

$kicker = New-Label "CODEX 额度" 22 20 120 18 8 "Bold" $colors.CodexGreen
$taffyChip = New-RoundedPanel 238 19 78 24 ([System.Drawing.Color]::FromArgb(255, 244, 248)) 12
$taffyChip.StrokeColor = [System.Drawing.Color]::FromArgb(238, 191, 212)
$taffyText = New-Label "塔菲模式" 251 24 60 14 7 "Bold" $colors.SoftMuted

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "刷新"
$refreshButton.Location = New-Object System.Drawing.Point(318, 18)
$refreshButton.Size = New-Object System.Drawing.Size(38, 24)
$refreshButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$refreshButton.FlatAppearance.BorderSize = 0
$refreshButton.BackColor = [System.Drawing.Color]::FromArgb(255, 244, 248)
$refreshButton.ForeColor = $colors.CodexGreen
$refreshButton.Font = New-Object System.Drawing.Font($script:CodexQuotaFontName, 7, "Bold")
$refreshButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$refreshButton.Add_Click({
  if ($script:Refreshing) {
    return
  }

  $script:Refreshing = $true
  $refreshButton.Enabled = $false
  $refreshButton.Text = "刷新中"
  try {
    Update-Widget -ForceProfileRefresh
  } finally {
    $refreshButton.Text = "刷新"
    $refreshButton.Enabled = $true
    $script:Refreshing = $false
  }
})

$title = New-Label "" 22 42 240 28 13 "Bold" $colors.Ink
$title.Visible = $false
$status = New-Label "等待 Codex 运行..." 22 66 356 18 8 "Regular" $colors.Muted

$totalCaption = New-Label "总 Token 使用量" 22 92 180 16 8 "Bold" $colors.SoftMuted
$totalValue = New-Label "-" 22 110 356 32 21 "Bold" $colors.Ink
$totalMeta = New-Label "今日使用 Token" 22 146 180 16 8 "Bold" $colors.SoftMuted
$todayValue = New-Label "-" 22 160 356 24 13 "Bold" $colors.Ink

$primaryPanel = New-RoundedPanel 22 190 356 48 $colors.CardSoft 12
$secondaryPanel = New-RoundedPanel 22 244 356 48 $colors.CardSoft 12

$primaryName = New-Label "5小时额度" 34 199 88 18 8 "Bold" $colors.Ink
$primaryPercent = New-Label "剩余 --" 120 199 72 18 8 "Bold" $colors.CodexGreen
$primaryBar = New-Object CodexQuotaWidget.PercentBar
$primaryBar.Location = New-Object System.Drawing.Point(34, 222)
$primaryBar.Size = New-Object System.Drawing.Size(322, 12)
$primaryBar.TrackColor = $colors.Track
$primaryBar.BackColor = $colors.Track
$primaryBar.Visible = $false
$primaryReset = New-Label "重置时间 -" 174 199 200 18 7 "Regular" $colors.Muted

$secondaryName = New-Label "7天额度" 34 253 88 18 8 "Bold" $colors.Ink
$secondaryPercent = New-Label "剩余 --" 120 253 72 18 8 "Bold" $colors.CodexGreen
$secondaryBar = New-Object CodexQuotaWidget.PercentBar
$secondaryBar.Location = New-Object System.Drawing.Point(34, 276)
$secondaryBar.Size = New-Object System.Drawing.Size(322, 12)
$secondaryBar.TrackColor = $colors.Track
$secondaryBar.BackColor = $colors.Track
$secondaryBar.Visible = $false
$secondaryReset = New-Label "重置时间 -" 174 253 200 18 7 "Regular" $colors.Muted

$threadLabel = New-Label "上次请求 -" 22 300 356 18 8 "Regular" $colors.Muted
$sourceLabel = New-Label "" 22 318 356 16 7 "Regular" $colors.SoftMuted
$sourceLabel.Visible = $false

$shiftedControls = @(
  $close,
  $kicker,
  $taffyChip,
  $taffyText,
  $refreshButton,
  $title,
  $status,
  $totalCaption,
  $totalValue,
  $totalMeta,
  $todayValue,
  $primaryPanel,
  $secondaryPanel,
  $primaryName,
  $primaryPercent,
  $primaryBar,
  $primaryReset,
  $secondaryName,
  $secondaryPercent,
  $secondaryBar,
  $secondaryReset,
  $threadLabel,
  $sourceLabel
)

foreach ($control in $shiftedControls) {
  $control.Left = $control.Left + $layoutOffsetX
  $control.Top = $control.Top + 10
}

$card.Visible = $false
$taffyChip.Visible = $false
$primaryPanel.Visible = $false
$secondaryPanel.Visible = $false

foreach ($control in @($kicker, $title, $status, $totalCaption, $totalValue, $totalMeta, $todayValue, $threadLabel, $sourceLabel)) {
  $control.BackColor = $colors.Card
}

foreach ($control in @($primaryName, $primaryPercent, $primaryReset, $secondaryName, $secondaryPercent, $secondaryReset)) {
  $control.BackColor = $colors.CardSoft
}

$taffyText.BackColor = [System.Drawing.Color]::FromArgb(255, 244, 248)

$logoBox = $null
if ($null -ne $logoImage) {
  $logoBox = New-PictureBox $logoImage ($layoutOffsetX + 20) 18 136 34
  $kicker.Visible = $false
}

$form.Controls.AddRange(@(
  $close,
  $kicker,
  $taffyChip,
  $taffyText,
  $refreshButton,
  $title,
  $status,
  $totalCaption,
  $totalValue,
  $totalMeta,
  $todayValue,
  $primaryPanel,
  $secondaryPanel,
  $primaryName,
  $primaryPercent,
  $primaryBar,
  $primaryReset,
  $secondaryName,
  $secondaryPercent,
  $secondaryBar,
  $secondaryReset,
  $threadLabel,
  $sourceLabel
))

if ($null -ne $logoBox) {
  $form.Controls.Add($logoBox)
}

foreach ($control in @($kicker, $taffyText, $refreshButton, $title, $status, $totalCaption, $totalValue, $totalMeta, $todayValue, $primaryName, $primaryPercent, $primaryReset, $secondaryName, $secondaryPercent, $secondaryReset, $threadLabel, $sourceLabel, $logoBox, $upperArm, $lowerArm)) {
  if ($null -eq $control) {
    continue
  }
  $control.BringToFront()
}
if ($null -ne $characterBox) { $characterBox.BringToFront() }
if ($null -ne $characterFallback) { $characterFallback.BringToFront() }
$close.BringToFront()
$refreshButton.BringToFront()

$script:dragging = $false
$script:dragPoint = New-Object System.Drawing.Point(0, 0)
$dragStart = {
  param($sender, $event)
  if ($event.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
    $script:dragging = $true
    $script:dragPoint = $event.Location
  }
}
$dragMove = {
  param($sender, $event)
  if ($script:dragging) {
    $form.Left = $form.Left + $event.X - $script:dragPoint.X
    $form.Top = $form.Top + $event.Y - $script:dragPoint.Y
  }
}
$dragEnd = { $script:dragging = $false }

foreach ($control in @(
  $form,
  $script:backdropBox,
  $characterBox,
  $characterFallback,
  $kicker,
  $taffyText,
  $status,
  $totalCaption,
  $totalValue,
  $totalMeta,
  $todayValue,
  $primaryName,
  $primaryPercent,
  $primaryReset,
  $secondaryName,
  $secondaryPercent,
  $secondaryReset,
  $threadLabel,
  $sourceLabel,
  $logoBox
)) {
  if ($null -eq $control) {
    continue
  }
  $control.Cursor = [System.Windows.Forms.Cursors]::SizeAll
  $control.Add_MouseDown($dragStart)
  $control.Add_MouseMove($dragMove)
  $control.Add_MouseUp($dragEnd)
}

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = $widgetIcon
$notify.Text = "Codex 额度小窗"
$notify.Visible = $true
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$showItem = $menu.Items.Add("显示")
$exitItem = $menu.Items.Add("退出")
$showItem.Add_Click({
  $script:ManualHidden = $false
  $form.Show()
  $form.Activate()
  Update-Widget -ForceProfileRefresh
})
$exitItem.Add_Click({ $form.Close() })
$notify.ContextMenuStrip = $menu
$notify.Add_DoubleClick({
  $script:ManualHidden = $false
  $form.Show()
  $form.Activate()
  Update-Widget -ForceProfileRefresh
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = [Math]::Max(1, $RefreshSeconds) * 1000

function Update-Widget {
  param([switch]$ForceProfileRefresh)

  $shouldForceRefresh = $ForceProfileRefresh -or ((-not $form.Visible) -and (-not $script:ManualHidden) -and (Test-CodexProcess))
  $snapshot = Get-CodexQuotaSnapshot -CodexHome $CodexHome -ForceProfileRefresh:$shouldForceRefresh

  if (-not $snapshot.codexRunning) {
    $script:ManualHidden = $false
    if ($notify.Visible) {
      $notify.Visible = $false
    }
    if ($form.Visible) {
      $form.Hide()
    }
    return
  }

  if (-not $notify.Visible) {
    $notify.Visible = $true
  }

  if (-not $form.Visible -and -not $script:ManualHidden) {
    $form.Show()
    $form.Activate()
  }

  if ($snapshot.status -ne "ok") {
    $status.Text = "Codex 正在运行，等待令牌数据"
    $totalValue.Text = "-"
    $todayValue.Text = "-"
    $primaryBar.Percent = 0
    $secondaryBar.Percent = 0
    $primaryPercent.Text = "剩余 --"
    $secondaryPercent.Text = "剩余 --"
    $primaryReset.Text = "重置时间 -"
    $secondaryReset.Text = "重置时间 -"
    $threadLabel.Text = "上次请求 -"
    $sourceLabel.Text = ""
    $script:PrimaryRemaining = 0.0
    $script:SecondaryRemaining = 0.0
    Refresh-Backdrop
    return
  }

  $primary = $snapshot.rateLimits.primary
  $secondary = $snapshot.rateLimits.secondary
  $profileUsage = $snapshot.profileUsage
  $hasProfileUsage = $null -ne $profileUsage -and $profileUsage.status -eq "ok"
  $status.Text = "个人资料更新：$($snapshot.timestamp)"

  if ($hasProfileUsage) {
    $totalValue.Text = Format-Number $profileUsage.lifetimeTokens
    $todayValue.Text = Format-Number $profileUsage.todayTokens
  } else {
    $totalValue.Text = "-"
    $todayValue.Text = Format-Number $snapshot.todayUsage.totalTokens
    if ($null -ne $profileUsage -and -not [string]::IsNullOrWhiteSpace($profileUsage.message)) {
      $status.Text = "个人资料读取失败"
    }
  }
  $script:PrimaryRemaining = 0.0
  $script:SecondaryRemaining = 0.0
  $script:PrimaryBarColor = $colors.CodexGreen
  $script:SecondaryBarColor = $colors.CodexGreen

  if ($null -ne $primary) {
    Set-BarPalette $primaryBar $primary.remainingPercent
    $primaryBar.Percent = Percent-Or-Zero $primary.remainingPercent
    $script:PrimaryRemaining = Percent-Or-Zero $primary.remainingPercent
    $script:PrimaryBarColor = $primaryBar.FillColor
    $primaryPercent.Text = "剩余 $($primary.remainingPercent)%"
    $primaryReset.Text = "重置 $($primary.resetsAtLocal)"
  }

  if ($null -ne $secondary) {
    Set-BarPalette $secondaryBar $secondary.remainingPercent
    $secondaryBar.Percent = Percent-Or-Zero $secondary.remainingPercent
    $script:SecondaryRemaining = Percent-Or-Zero $secondary.remainingPercent
    $script:SecondaryBarColor = $secondaryBar.FillColor
    $secondaryPercent.Text = "剩余 $($secondary.remainingPercent)%"
    $secondaryReset.Text = "重置 $($secondary.resetsAtLocal)"
  }

  if ($hasProfileUsage) {
    $threadLabel.Text = "连续使用 $($profileUsage.currentStreakDays) 天"
    $sourceLabel.Text = ""
  } else {
    $threadLabel.Text = "等待 Codex 个人资料统计"
    $sourceLabel.Text = ""
  }
  Refresh-Backdrop
}

$timer.Add_Tick({ Update-Widget })

$profileRefreshTimer = New-Object System.Windows.Forms.Timer
$profileRefreshTimer.Interval = 10 * 60 * 1000
$profileRefreshTimer.Add_Tick({
  Update-Widget -ForceProfileRefresh
})

$showSignalTimer = New-Object System.Windows.Forms.Timer
$showSignalTimer.Interval = 500
$showSignalTimer.Add_Tick({
  if ($null -eq $script:ShowEvent -or -not $script:ShowEvent.WaitOne(0)) {
    return
  }

  $script:ManualHidden = $false
  if (Test-CodexProcess) {
    if (-not $form.Visible) {
      $form.Show()
    }
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.Activate()
    Update-Widget -ForceProfileRefresh
  }
})

$form.Add_Shown({
  Update-Widget -ForceProfileRefresh
})

$form.Add_FormClosed({
  $timer.Stop()
  $timer.Dispose()
  $profileRefreshTimer.Stop()
  $profileRefreshTimer.Dispose()
  $showSignalTimer.Stop()
  $showSignalTimer.Dispose()
  $notify.Visible = $false
  $notify.Dispose()
  if ($null -ne $characterImage) { $characterImage.Dispose() }
  if ($null -ne $logoImage) { $logoImage.Dispose() }
  if ($script:WidgetIconIsCustom -and $null -ne $widgetIcon) { $widgetIcon.Dispose() }
  if ($null -ne $script:backdropBox -and $null -ne $script:backdropBox.Image) { $script:backdropBox.Image.Dispose() }
  if ($null -ne $script:ShowEvent) { $script:ShowEvent.Dispose() }
  if ($script:IsSingleInstanceOwner -and $null -ne $script:SingleInstanceMutex) {
    try { $script:SingleInstanceMutex.ReleaseMutex() } catch {}
    $script:SingleInstanceMutex.Dispose()
  }
})

$timer.Start()
$profileRefreshTimer.Start()
$showSignalTimer.Start()
[void](Update-Widget -ForceProfileRefresh)
[void][System.Windows.Forms.Application]::Run($form)
