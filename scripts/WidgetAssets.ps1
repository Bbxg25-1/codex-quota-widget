function Get-CodexQuotaPrivateAssetsRoot {
  if (-not [string]::IsNullOrWhiteSpace($env:CODEX_QUOTA_ASSET_DIR)) {
    return $env:CODEX_QUOTA_ASSET_DIR
  }

  return Join-Path $env:LOCALAPPDATA "CodexQuotaWidget\assets"
}

function Get-CodexQuotaAssetPath {
  param(
    [string]$PrivateAssetsRoot = (Get-CodexQuotaPrivateAssetsRoot),
    [Parameter(Mandatory = $true)]
    [string]$BundledAssetsRoot,
    [string[]]$PrivateFileNames = @(),
    [string[]]$BundledFileNames = @()
  )

  if ($env:CODEX_QUOTA_USE_BUNDLED_ASSETS -ne "1" -and
      -not [string]::IsNullOrWhiteSpace($PrivateAssetsRoot)) {
    foreach ($fileName in $PrivateFileNames) {
      $candidate = Join-Path $PrivateAssetsRoot $fileName
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return $candidate
      }
    }
  }

  foreach ($fileName in $BundledFileNames) {
    $candidate = Join-Path $BundledAssetsRoot $fileName
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }

  return $null
}

