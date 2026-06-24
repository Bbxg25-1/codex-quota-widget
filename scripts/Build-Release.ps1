param(
  [string]$Version = "0.2.0",
  [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) "dist")
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-quota-widget-release-" + [Guid]::NewGuid().ToString("N"))
$packageRoot = Join-Path $stagingRoot "codex-quota-widget"
$zipPath = Join-Path $OutputDirectory "codex-quota-widget-v$Version.zip"

$items = @(
  ".codex-plugin",
  "assets",
  "scripts",
  "skills",
  "README.md",
  "LICENSE",
  "RELEASE_NOTES.md"
)

try {
  New-Item -ItemType Directory -Path $packageRoot, $OutputDirectory -Force | Out-Null
  foreach ($item in $items) {
    Copy-Item -LiteralPath (Join-Path $repoRoot $item) -Destination $packageRoot -Recurse -Force
  }

  Get-ChildItem -LiteralPath $packageRoot -Recurse -File |
    Where-Object { $_.Name -match "(?i)taffy|bilibili" } |
    ForEach-Object { throw "Release package contains a blocked third-party asset name: $($_.FullName)" }

  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }
  Compress-Archive -LiteralPath $packageRoot -DestinationPath $zipPath -CompressionLevel Optimal
  Write-Output "Created: $zipPath"
} finally {
  Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
}
