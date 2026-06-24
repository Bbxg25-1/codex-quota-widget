$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$assetScript = Join-Path $repoRoot "scripts\WidgetAssets.ps1"
$messageScript = Join-Path $repoRoot "scripts\WidgetMessages.ps1"

function Assert-Equal {
  param(
    [object]$Actual,
    [object]$Expected,
    [string]$Name
  )

  if ($Actual -ne $Expected) {
    throw "$Name failed. Expected '$Expected', got '$Actual'."
  }

  Write-Output "PASS: $Name"
}

function Assert-Contains {
  param(
    [string]$Actual,
    [string]$ExpectedFragment,
    [string]$Name
  )

  if ([string]::IsNullOrWhiteSpace($Actual) -or -not $Actual.Contains($ExpectedFragment)) {
    throw "$Name failed. Expected '$ExpectedFragment' in '$Actual'."
  }

  Write-Output "PASS: $Name"
}

. $assetScript
. $messageScript

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-quota-widget-tests-" + [Guid]::NewGuid().ToString("N"))
$privateRoot = Join-Path $tempRoot "private"
$bundledRoot = Join-Path $tempRoot "bundled"

try {
  New-Item -ItemType Directory -Path $privateRoot, $bundledRoot -Force | Out-Null
  $privateIcon = Join-Path $privateRoot "headshot.ico"
  $bundledIcon = Join-Path $bundledRoot "codex-quota-widget.ico"
  Set-Content -LiteralPath $privateIcon -Value "private" -Encoding Ascii
  Set-Content -LiteralPath $bundledIcon -Value "bundled" -Encoding Ascii

  $resolvedPrivate = Get-CodexQuotaAssetPath `
    -PrivateAssetsRoot $privateRoot `
    -BundledAssetsRoot $bundledRoot `
    -PrivateFileNames @("headshot.ico") `
    -BundledFileNames @("codex-quota-widget.ico")
  Assert-Equal $resolvedPrivate $privateIcon "private assets take priority"

  Remove-Item -LiteralPath $privateIcon -Force
  $resolvedBundled = Get-CodexQuotaAssetPath `
    -PrivateAssetsRoot $privateRoot `
    -BundledAssetsRoot $bundledRoot `
    -PrivateFileNames @("headshot.ico") `
    -BundledFileNames @("codex-quota-widget.ico")
  Assert-Equal $resolvedBundled $bundledIcon "bundled asset is fallback"

  $missing = Get-CodexQuotaAssetPath `
    -PrivateAssetsRoot $privateRoot `
    -BundledAssetsRoot $bundledRoot `
    -PrivateFileNames @("missing.png") `
    -BundledFileNames @("missing.png")
  Assert-Equal $missing $null "missing asset returns null"
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Assert-Contains (Get-CodexQuotaProfileMessage -Status "no-auth") "打开 Codex 并登录" "no-auth guidance"
Assert-Contains (Get-CodexQuotaProfileMessage -Status "request-failed") "网络异常或登录已过期" "request failure guidance"
Assert-Contains (Get-CodexQuotaProfileMessage -Status "no-stats") "暂未返回使用统计" "missing stats guidance"
Assert-Contains (Get-CodexQuotaSnapshotMessage -Status "no-token-count-found") "使用一次 Codex 后再刷新" "missing token record guidance"
Assert-Contains (Get-CodexQuotaAppServerMessage -Status "codex-not-found") "确认 Codex 已安装" "missing Codex guidance"
Assert-Contains (Get-CodexQuotaAppServerMessage -Status "request-failed") "无法读取额度窗口" "app-server failure guidance"

$requiredFiles = @(
  "README.md",
  "LICENSE",
  "RELEASE_NOTES.md",
  "assets\codex-quota-widget.png",
  "assets\codex-quota-widget.ico",
  "assets\preview-running.png",
  "scripts\Install-DesktopShortcut.cmd"
)
foreach ($relativePath in $requiredFiles) {
  $fullPath = Join-Path $repoRoot $relativePath
  Assert-Equal (Test-Path -LiteralPath $fullPath -PathType Leaf) $true "required file $relativePath"
}

$blockedAssets = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "assets") -File |
  Where-Object { $_.Name -match "(?i)taffy|bilibili" })
Assert-Equal $blockedAssets.Count 0 "public assets exclude third-party character files"

$readme = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot "README.md")
Assert-Contains $readme "安全与隐私说明" "README security section"
Assert-Contains $readme "三步快速开始" "README quick start"
Assert-Contains $readme "为什么使用 ExecutionPolicy Bypass" "README execution policy explanation"
Assert-Contains $readme "常见问题" "README FAQ"
Assert-Contains $readme "MIT License" "README license"

$manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot ".codex-plugin\plugin.json") | ConvertFrom-Json
Assert-Equal $manifest.interface.logo "./assets/codex-quota-widget.png" "manifest uses public logo"

$widgetSource = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot "scripts\Start-CodexQuotaWidget.ps1")
Assert-Equal $widgetSource.Contains('$logoBox') $false "widget has no top logo control"
Assert-Equal $widgetSource.Contains('柔粉模式') $false "widget has no mode badge"

foreach ($scriptFile in Get-ChildItem -LiteralPath (Join-Path $repoRoot "scripts") -Filter "*.ps1" -File) {
  $bytes = [System.IO.File]::ReadAllBytes($scriptFile.FullName)
  $utf8Text = [System.Text.Encoding]::UTF8.GetString($bytes)
  $containsNonAscii = $utf8Text.ToCharArray() | Where-Object { [int]$_ -gt 127 } | Select-Object -First 1
  if ($null -ne $containsNonAscii) {
    $hasUtf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    Assert-Equal $hasUtf8Bom $true "Windows PowerShell UTF-8 BOM $($scriptFile.Name)"
  }

  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    $scriptFile.FullName,
    [ref]$tokens,
    [ref]$parseErrors
  )
  Assert-Equal $parseErrors.Count 0 "PowerShell parse $($scriptFile.Name)"
}

Write-Output "All tests passed."
