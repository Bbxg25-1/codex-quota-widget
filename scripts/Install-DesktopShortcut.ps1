param(
  [string]$ShortcutName = "Codex Quota Widget.lnk"
)

$scriptPath = Join-Path $PSScriptRoot "Start-CodexQuotaWidget.ps1"
$pluginRoot = Split-Path -Parent $PSScriptRoot
$iconPath = Join-Path $pluginRoot "assets\taffy-headshot.ico"
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop $ShortcutName

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.WindowStyle = 7
$shortcut.Description = "Show Codex quota remaining while Codex is running"
if (Test-Path -LiteralPath $iconPath) {
  $shortcut.IconLocation = $iconPath
}
$shortcut.Save()

Write-Output "Created shortcut: $shortcutPath"
