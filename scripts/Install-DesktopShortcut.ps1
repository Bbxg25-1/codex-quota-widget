param(
  [string]$ShortcutName = "Codex额度查看小窗口.lnk"
)

$scriptPath = Join-Path $PSScriptRoot "Start-CodexQuotaWidget.ps1"
$pluginRoot = Split-Path -Parent $PSScriptRoot
$assetsRoot = Join-Path $pluginRoot "assets"
. (Join-Path $PSScriptRoot "WidgetAssets.ps1")
$iconPath = Get-CodexQuotaAssetPath `
  -BundledAssetsRoot $assetsRoot `
  -PrivateFileNames @("icon.ico") `
  -BundledFileNames @("codex-quota-widget.ico")
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop $ShortcutName
$legacyShortcutPath = Join-Path $desktop "Codex Quota Widget.lnk"

if ($legacyShortcutPath -ne $shortcutPath -and (Test-Path -LiteralPath $legacyShortcutPath)) {
  Remove-Item -LiteralPath $legacyShortcutPath -Force
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.WindowStyle = 7
$shortcut.Description = "查看 Codex Token 使用量和额度窗口"
if (Test-Path -LiteralPath $iconPath) {
  $shortcut.IconLocation = $iconPath
}
$shortcut.Save()

Write-Output "Created shortcut: $shortcutPath"
