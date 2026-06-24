param(
  [switch]$Json,
  [switch]$ForceProfileRefresh,
  [string]$CodexHome = (Join-Path $env:USERPROFILE ".codex"),
  [int]$MaxFiles = 24,
  [int]$TailLines = 1200
)

$script:CodexQuotaDisplayTimeZone = $null
try {
  $script:CodexQuotaDisplayTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("China Standard Time")
} catch {
  $script:CodexQuotaDisplayTimeZone = [System.TimeZoneInfo]::Local
}
$script:CodexProfileUsageCache = $null
$script:CodexProfileUsageCacheAt = [DateTimeOffset]::MinValue
$script:CodexRateLimitsCache = $null
$script:CodexRateLimitsCacheAt = [DateTimeOffset]::MinValue
$script:CodexRateLimitsLastStatus = "not-requested"

function Test-CodexProcess {
  $process = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -ieq "Codex" -or $_.ProcessName -ieq "codex" } |
    Select-Object -First 1

  return [bool]$process
}

function ConvertFrom-UnixSeconds {
  param([object]$Value)

  if ($null -eq $Value) {
    return $null
  }

  try {
    $offset = [DateTimeOffset]::FromUnixTimeSeconds([int64]$Value)
    return [System.TimeZoneInfo]::ConvertTime($offset, $script:CodexQuotaDisplayTimeZone).DateTime
  } catch {
    return $null
  }
}

function ConvertTo-CodexQuotaDisplayTime {
  param([object]$Value)

  if ($null -eq $Value) {
    return $null
  }

  try {
    $offset = [DateTimeOffset]::Parse([string]$Value)
    return [System.TimeZoneInfo]::ConvertTime($offset, $script:CodexQuotaDisplayTimeZone).DateTime
  } catch {
    return $null
  }
}

function ConvertTo-CodexQuotaDisplayText {
  param([object]$Value)

  $displayTime = ConvertTo-CodexQuotaDisplayTime $Value
  if ($null -ne $displayTime) {
    return $displayTime.ToString("yyyy年MM月dd日 HH:mm:ss")
  }

  if ($null -ne $Value) {
    return [string]$Value
  }

  return $null
}

function Get-PercentValue {
  param([object]$Value)

  if ($null -eq $Value) {
    return $null
  }

  try {
    $number = [double]$Value
    if ($number -lt 0) { return 0.0 }
    if ($number -gt 100) { return 100.0 }
    return [Math]::Round($number, 1)
  } catch {
    return $null
  }
}

function Get-LongValue {
  param([object]$Value)

  if ($null -eq $Value) {
    return 0
  }

  try {
    return [int64]$Value
  } catch {
    return 0
  }
}

function Get-CodexAuthAccessToken {
  param([string]$CodexHome)

  $authPath = Join-Path $CodexHome "auth.json"
  if (-not (Test-Path -LiteralPath $authPath)) {
    return $null
  }

  try {
    $auth = Get-Content -Raw -LiteralPath $authPath | ConvertFrom-Json -ErrorAction Stop
    $token = $auth.tokens.access_token
    if ([string]::IsNullOrWhiteSpace([string]$token)) {
      return $null
    }

    return [string]$token
  } catch {
    return $null
  }
}

function New-ProfileUsageResult {
  param(
    [string]$Status,
    [string]$Message = $null
  )

  return [pscustomobject]@{
    status = $Status
    source = "codex-profile"
    message = $Message
    lifetimeTokens = $null
    todayTokens = $null
    todayDate = $null
    peakDailyTokens = $null
    currentStreakDays = $null
    longestStreakDays = $null
    totalThreads = $null
    statsAsOf = $null
    generatedAt = $null
    generatedAtLocal = $null
    dailyUsageBuckets = @()
  }
}

function Get-CodexCliPath {
  if (-not [string]::IsNullOrWhiteSpace($env:CODEX_CLI_PATH) -and
      (Test-Path -LiteralPath $env:CODEX_CLI_PATH)) {
    return $env:CODEX_CLI_PATH
  }

  $localBin = Join-Path $env:LOCALAPPDATA "OpenAI\Codex\bin"
  if (Test-Path -LiteralPath $localBin) {
    $candidate = Get-ChildItem -LiteralPath $localBin -Recurse -Filter "codex.exe" -File -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($null -ne $candidate) {
      return $candidate.FullName
    }
  }

  $programApps = Join-Path $env:ProgramFiles "WindowsApps"
  if (Test-Path -LiteralPath $programApps) {
    $candidate = Get-ChildItem -LiteralPath $programApps -Recurse -Filter "codex.exe" -File -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -like "*OpenAI.Codex*" } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($null -ne $candidate) {
      return $candidate.FullName
    }
  }

  return $null
}

function Send-WebSocketJson {
  param(
    [System.Net.WebSockets.ClientWebSocket]$Socket,
    [object]$Payload,
    [System.Threading.CancellationToken]$CancellationToken
  )

  $json = $Payload | ConvertTo-Json -Depth 12 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $segment = [System.ArraySegment[byte]]::new($bytes)
  [void]$Socket.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $CancellationToken).GetAwaiter().GetResult()
}

function Receive-WebSocketJson {
  param(
    [System.Net.WebSockets.ClientWebSocket]$Socket,
    [System.Threading.CancellationToken]$CancellationToken
  )

  $buffer = New-Object byte[] 8192
  $stream = New-Object System.IO.MemoryStream
  try {
    do {
      $segment = [System.ArraySegment[byte]]::new($buffer)
      $result = $Socket.ReceiveAsync($segment, $CancellationToken).GetAwaiter().GetResult()
      if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
        return $null
      }
      if ($result.Count -gt 0) {
        $stream.Write($buffer, 0, $result.Count)
      }
    } while (-not $result.EndOfMessage)

    $text = [System.Text.Encoding]::UTF8.GetString($stream.ToArray())
    if ([string]::IsNullOrWhiteSpace($text)) {
      return $null
    }

    return $text | ConvertFrom-Json -ErrorAction Stop
  } finally {
    $stream.Dispose()
  }
}

function New-AppServerRateLimitWindow {
  param([object]$Window)

  if ($null -eq $Window) {
    return $null
  }

  return [pscustomobject]@{
    used_percent = $Window.usedPercent
    window_minutes = $Window.windowDurationMins
    resets_at = $Window.resetsAt
  }
}

function Get-CodexAppServerRateLimits {
  param(
    [int]$CacheSeconds = 600,
    [switch]$ForceRefresh
  )

  $now = [DateTimeOffset]::Now
  if (-not $ForceRefresh -and
      $null -ne $script:CodexRateLimitsCache -and
      ($now - $script:CodexRateLimitsCacheAt).TotalSeconds -lt $CacheSeconds) {
    $script:CodexRateLimitsLastStatus = "ok"
    return $script:CodexRateLimitsCache
  }

  if ($null -eq $script:CodexRateLimitsCache -and -not $ForceRefresh) {
    $script:CodexRateLimitsLastStatus = "not-requested"
    return $null
  }

  $codexCli = Get-CodexCliPath
  if ([string]::IsNullOrWhiteSpace($codexCli)) {
    $script:CodexRateLimitsLastStatus = "codex-not-found"
    return $script:CodexRateLimitsCache
  }

  $port = Get-Random -Minimum 52000 -Maximum 59000
  $listenUri = "ws://127.0.0.1:$port"
  $process = $null
  $socket = $null
  $cts = $null

  try {
    $process = Start-Process -FilePath $codexCli -ArgumentList @("app-server", "--listen", $listenUri) -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 1800

    $socket = New-Object System.Net.WebSockets.ClientWebSocket
    $cts = New-Object System.Threading.CancellationTokenSource
    $cts.CancelAfter(15000)
    $socket.ConnectAsync([Uri]$listenUri, $cts.Token).GetAwaiter().GetResult()

    Send-WebSocketJson -Socket $socket -CancellationToken $cts.Token -Payload @{
      id = 1
      method = "initialize"
      params = @{
        clientInfo = @{
          name = "codex-quota-widget"
          version = "0.2.0"
        }
        capabilities = $null
      }
    }
    Send-WebSocketJson -Socket $socket -CancellationToken $cts.Token -Payload @{
      id = 2
      method = "account/rateLimits/read"
    }

    $rateLimitPayload = $null
    while ($null -eq $rateLimitPayload) {
      $message = Receive-WebSocketJson -Socket $socket -CancellationToken $cts.Token
      if ($null -eq $message) {
        break
      }

      if ($message.id -eq 2) {
        $rateLimitPayload = $message.result.rateLimits
      }
    }

    if ($null -eq $rateLimitPayload) {
      return $script:CodexRateLimitsCache
    }

    $result = [pscustomobject]@{
      status = "ok"
      source = "codex-app-server"
      planType = $rateLimitPayload.planType
      rateLimits = [pscustomobject]@{
        limitId = $rateLimitPayload.limitId
        primary = New-RateLimitSnapshot (New-AppServerRateLimitWindow $rateLimitPayload.primary)
        secondary = New-RateLimitSnapshot (New-AppServerRateLimitWindow $rateLimitPayload.secondary)
        credits = $rateLimitPayload.credits
      }
    }

    $script:CodexRateLimitsCache = $result
    $script:CodexRateLimitsCacheAt = $now
    $script:CodexRateLimitsLastStatus = "ok"
    return $result
  } catch {
    $script:CodexRateLimitsLastStatus = "request-failed"
    return $script:CodexRateLimitsCache
  } finally {
    if ($null -ne $socket) {
      try {
        if ($socket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
          $closeCts = New-Object System.Threading.CancellationTokenSource
          $closeCts.CancelAfter(1000)
          [void]$socket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "done", $closeCts.Token).GetAwaiter().GetResult()
          $closeCts.Dispose()
        }
      } catch {
      }
      $socket.Dispose()
    }
    if ($null -ne $cts) {
      $cts.Dispose()
    }
    if ($null -ne $process -and -not $process.HasExited) {
      Stop-Process -Id $process.Id -Force
    }
  }
}

function Get-CodexProfileUsage {
  param(
    [string]$CodexHome,
    [int]$CacheSeconds = 600,
    [switch]$ForceRefresh
  )

  $now = [DateTimeOffset]::Now
  if (-not $ForceRefresh -and
      $null -ne $script:CodexProfileUsageCache -and
      ($now - $script:CodexProfileUsageCacheAt).TotalSeconds -lt $CacheSeconds) {
    return $script:CodexProfileUsageCache
  }

  $token = Get-CodexAuthAccessToken -CodexHome $CodexHome
  if ($null -eq $token) {
    $result = New-ProfileUsageResult -Status "no-auth" -Message "未找到 Codex 登录令牌"
    $script:CodexProfileUsageCache = $result
    $script:CodexProfileUsageCacheAt = $now
    return $result
  }

  try {
    $headers = @{
      Authorization = "Bearer $token"
      Accept = "application/json"
      "User-Agent" = "CodexQuotaWidget/0.2"
    }

    $response = Invoke-RestMethod `
      -Uri "https://chatgpt.com/backend-api/wham/profiles/me" `
      -Headers $headers `
      -Method Get `
      -TimeoutSec 20

    $stats = $response.stats
    if ($null -eq $stats) {
      $result = New-ProfileUsageResult -Status "no-stats" -Message "个人资料未返回统计字段"
      $script:CodexProfileUsageCache = $result
      $script:CodexProfileUsageCacheAt = $now
      return $result
    }

    $todayDate = [System.TimeZoneInfo]::ConvertTime([DateTimeOffset]::Now, $script:CodexQuotaDisplayTimeZone).ToString("yyyy-MM-dd")
    $todayTokens = [int64]0
    $dailyBuckets = @()

    foreach ($bucket in @($stats.daily_usage_buckets)) {
      if ($null -eq $bucket) {
        continue
      }

      $bucketDate = [string]$bucket.start_date
      $bucketTokens = Get-LongValue $bucket.tokens
      $dailyBuckets += [pscustomobject]@{
        startDate = $bucketDate
        tokens = $bucketTokens
      }

      if ($bucketDate -eq $todayDate) {
        $todayTokens = $bucketTokens
      }
    }

    $generatedAtLocal = ConvertTo-CodexQuotaDisplayText $response.metadata.generated_at
    $result = [pscustomobject]@{
      status = "ok"
      source = "codex-profile"
      message = $null
      lifetimeTokens = Get-LongValue $stats.lifetime_tokens
      todayTokens = $todayTokens
      todayDate = $todayDate
      peakDailyTokens = Get-LongValue $stats.peak_daily_tokens
      currentStreakDays = Get-LongValue $stats.current_streak_days
      longestStreakDays = Get-LongValue $stats.longest_streak_days
      totalThreads = Get-LongValue $stats.total_threads
      statsAsOf = $response.metadata.stats_as_of
      generatedAt = $response.metadata.generated_at
      generatedAtLocal = $generatedAtLocal
      dailyUsageBuckets = $dailyBuckets
    }

    $script:CodexProfileUsageCache = $result
    $script:CodexProfileUsageCacheAt = $now
    return $result
  } catch {
    $result = New-ProfileUsageResult -Status "request-failed" -Message "Codex profile request failed"
    $script:CodexProfileUsageCache = $result
    $script:CodexProfileUsageCacheAt = $now
    return $result
  }
}

function New-RateLimitSnapshot {
  param([object]$Limit)

  if ($null -eq $Limit) {
    return $null
  }

  $used = Get-PercentValue $Limit.used_percent
  $remaining = $null
  if ($null -ne $used) {
    $remaining = [Math]::Round((100.0 - $used), 1)
  }

  $resetLocal = ConvertFrom-UnixSeconds $Limit.resets_at
  $resetText = $null
  $isStale = $false
  if ($null -ne $resetLocal) {
    $nowLocal = [System.TimeZoneInfo]::ConvertTime([DateTimeOffset]::Now, $script:CodexQuotaDisplayTimeZone).DateTime
    if ($resetLocal -lt $nowLocal) {
      $isStale = $true
      $resetText = "等待新记录"
    } else {
      $resetText = $resetLocal.ToString("yyyy年MM月dd日 HH:mm")
    }
  }

  return [pscustomobject]@{
    usedPercent = $used
    remainingPercent = $remaining
    windowMinutes = $Limit.window_minutes
    resetsAtUnix = $Limit.resets_at
    resetsAtLocal = $resetText
    isStale = $isStale
  }
}

function Get-LastTokenCountEventInFile {
  param(
    [string]$FilePath,
    [int]$TailLines
  )

  try {
    $stream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  } catch {
    return $null
  }

  try {
    $targetBytes = [Math]::Max(65536, $TailLines * 4096)
    $bytesToRead = [int][Math]::Min($stream.Length, $targetBytes)
    if ($bytesToRead -le 0) {
      return $null
    }

    $buffer = New-Object byte[] $bytesToRead
    [void]$stream.Seek(-1 * $bytesToRead, [System.IO.SeekOrigin]::End)
    [void]$stream.Read($buffer, 0, $bytesToRead)
    $text = [System.Text.Encoding]::UTF8.GetString($buffer)
  } finally {
    $stream.Dispose()
  }

  $lines = @($text -split "`r?`n")

  for ($index = $lines.Count - 1; $index -ge 0; $index--) {
    $line = $lines[$index]
    if (-not $line -or $line.IndexOf('"token_count"') -lt 0) {
      continue
    }

    try {
      $event = $line | ConvertFrom-Json -ErrorAction Stop
    } catch {
      continue
    }

    if ($event.type -eq "event_msg" -and $event.payload.type -eq "token_count") {
      return $event
    }
  }

  return $null
}

function Get-LatestTokenCountEvent {
  param(
    [string]$SessionsRoot,
    [int]$MaxFiles,
    [int]$TailLines
  )

  if (-not (Test-Path -LiteralPath $SessionsRoot)) {
    return $null
  }

  $files = Get-ChildItem -LiteralPath $SessionsRoot -Recurse -Filter "*.jsonl" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First $MaxFiles

  foreach ($file in $files) {
    $event = Get-LastTokenCountEventInFile -FilePath $file.FullName -TailLines $TailLines
    if ($null -ne $event) {
      return [pscustomobject]@{
        file = $file.FullName
        event = $event
      }
    }
  }

  return $null
}

function Get-LocalTokenTotals {
  param(
    [string]$SessionsRoot,
    [int]$TailLines
  )

  if (-not (Test-Path -LiteralPath $SessionsRoot)) {
    return [pscustomobject]@{
      sessionCount = 0
      inputTokens = 0
      cachedInputTokens = 0
      outputTokens = 0
      reasoningOutputTokens = 0
      totalTokens = 0
    }
  }

  $sessionCount = 0
  $inputTokens = [int64]0
  $cachedInputTokens = [int64]0
  $outputTokens = [int64]0
  $reasoningOutputTokens = [int64]0
  $totalTokens = [int64]0

  $files = Get-ChildItem -LiteralPath $SessionsRoot -Recurse -Filter "*.jsonl" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending
  foreach ($file in $files) {
    $event = Get-LastTokenCountEventInFile -FilePath $file.FullName -TailLines $TailLines
    if ($null -eq $event) {
      continue
    }

    $usage = $event.payload.info.total_token_usage
    if ($null -eq $usage) {
      continue
    }

    $sessionCount += 1
    $inputTokens += Get-LongValue $usage.input_tokens
    $cachedInputTokens += Get-LongValue $usage.cached_input_tokens
    $outputTokens += Get-LongValue $usage.output_tokens
    $reasoningOutputTokens += Get-LongValue $usage.reasoning_output_tokens
    $totalTokens += Get-LongValue $usage.total_tokens
  }

  return [pscustomobject]@{
    sessionCount = $sessionCount
    inputTokens = $inputTokens
    cachedInputTokens = $cachedInputTokens
    outputTokens = $outputTokens
    reasoningOutputTokens = $reasoningOutputTokens
    totalTokens = $totalTokens
  }
}

function Get-TodayTokenTotals {
  param([string]$SessionsRoot)

  if (-not (Test-Path -LiteralPath $SessionsRoot)) {
    return [pscustomobject]@{
      eventCount = 0
      totalTokens = 0
      inputTokens = 0
      cachedInputTokens = 0
      outputTokens = 0
      reasoningOutputTokens = 0
    }
  }

  $today = [System.TimeZoneInfo]::ConvertTime([DateTimeOffset]::Now, $script:CodexQuotaDisplayTimeZone).Date
  $eventCount = 0
  $inputTokens = [int64]0
  $cachedInputTokens = [int64]0
  $outputTokens = [int64]0
  $reasoningOutputTokens = [int64]0
  $totalTokens = [int64]0

  $files = Get-ChildItem -LiteralPath $SessionsRoot -Recurse -Filter "*.jsonl" -File -ErrorAction SilentlyContinue
  foreach ($file in $files) {
    try {
      $stream = [System.IO.File]::Open($file.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
    } catch {
      continue
    }

    try {
      while (($line = $reader.ReadLine()) -ne $null) {
        if (-not $line -or $line.IndexOf('"token_count"') -lt 0) {
          continue
        }

        try {
          $event = $line | ConvertFrom-Json -ErrorAction Stop
        } catch {
          continue
        }

        if ($event.type -ne "event_msg" -or $event.payload.type -ne "token_count") {
          continue
        }

        $eventTime = ConvertTo-CodexQuotaDisplayTime $event.timestamp
        if ($null -eq $eventTime -or $eventTime.Date -ne $today) {
          continue
        }

        $usage = $event.payload.info.last_token_usage
        if ($null -eq $usage) {
          continue
        }

        $eventCount += 1
        $inputTokens += Get-LongValue $usage.input_tokens
        $cachedInputTokens += Get-LongValue $usage.cached_input_tokens
        $outputTokens += Get-LongValue $usage.output_tokens
        $reasoningOutputTokens += Get-LongValue $usage.reasoning_output_tokens
        $totalTokens += Get-LongValue $usage.total_tokens
      }
    } finally {
      $reader.Dispose()
      $stream.Dispose()
    }
  }

  return [pscustomobject]@{
    eventCount = $eventCount
    totalTokens = $totalTokens
    inputTokens = $inputTokens
    cachedInputTokens = $cachedInputTokens
    outputTokens = $outputTokens
    reasoningOutputTokens = $reasoningOutputTokens
  }
}

function Get-CodexQuotaSnapshot {
  param(
    [string]$CodexHome = (Join-Path $env:USERPROFILE ".codex"),
    [int]$MaxFiles = 24,
    [int]$TailLines = 1200,
    [int]$TotalTailLines = 200,
    [switch]$ForceProfileRefresh
  )

  $sessionsRoot = Join-Path $CodexHome "sessions"
  $latest = Get-LatestTokenCountEvent -SessionsRoot $sessionsRoot -MaxFiles $MaxFiles -TailLines $TailLines
  $profileUsage = Get-CodexProfileUsage -CodexHome $CodexHome -ForceRefresh:$ForceProfileRefresh
  $appServerRateLimits = Get-CodexAppServerRateLimits -ForceRefresh:$ForceProfileRefresh
  $hasProfileUsage = $profileUsage.status -eq "ok"
  $localTotals = $null
  $todayTotals = $null
  if ($hasProfileUsage) {
    $todayTotals = [pscustomobject]@{
      eventCount = $null
      totalTokens = $profileUsage.todayTokens
      inputTokens = $null
      cachedInputTokens = $null
      outputTokens = $null
      reasoningOutputTokens = $null
      source = "codex-profile"
    }
  } else {
    $localTotals = Get-LocalTokenTotals -SessionsRoot $sessionsRoot -TailLines $TotalTailLines
    $todayTotals = Get-TodayTokenTotals -SessionsRoot $sessionsRoot
  }
  $running = Test-CodexProcess

  if ($null -eq $latest) {
    return [pscustomobject]@{
      codexRunning = $running
      status = if ($hasProfileUsage) { "ok" } else { "no-token-count-found" }
      sourceFile = $null
      timestamp = $profileUsage.generatedAtLocal
      appServerStatus = $script:CodexRateLimitsLastStatus
      rateLimitSource = if ($null -ne $appServerRateLimits) { $appServerRateLimits.source } else { $null }
      rateLimits = if ($null -ne $appServerRateLimits) { $appServerRateLimits.rateLimits } else { $null }
      tokenUsage = $null
      profileUsage = $profileUsage
      localTotals = $localTotals
      todayUsage = $todayTotals
    }
  }

  $event = $latest.event
  $timestampLocal = $null
  try {
    $timestampLocal = ConvertTo-CodexQuotaDisplayText $event.timestamp
    if ($null -eq $timestampLocal) {
      throw "Cannot parse timestamp"
    }
  } catch {
    $timestampLocal = $event.timestamp
  }

  if ($hasProfileUsage -and $null -ne $profileUsage.generatedAtLocal) {
    $timestampLocal = $profileUsage.generatedAtLocal
  }

  $rateLimitSource = "local-token-count"
  $rateLimits = [pscustomobject]@{
    limitId = $event.payload.rate_limits.limit_id
    primary = New-RateLimitSnapshot $event.payload.rate_limits.primary
    secondary = New-RateLimitSnapshot $event.payload.rate_limits.secondary
    credits = $event.payload.rate_limits.credits
  }
  if ($null -ne $appServerRateLimits -and $appServerRateLimits.status -eq "ok") {
    $rateLimitSource = $appServerRateLimits.source
    $rateLimits = $appServerRateLimits.rateLimits
  }

  return [pscustomobject]@{
    codexRunning = $running
    status = "ok"
    sourceFile = $latest.file
    timestamp = $timestampLocal
    appServerStatus = $script:CodexRateLimitsLastStatus
    rateLimitReachedType = $event.payload.rate_limits.rate_limit_reached_type
    rateLimitSource = $rateLimitSource
    rateLimits = $rateLimits
    tokenUsage = [pscustomobject]@{
      total = $event.payload.info.total_token_usage
      last = $event.payload.info.last_token_usage
      modelContextWindow = $event.payload.info.model_context_window
    }
    profileUsage = $profileUsage
    localTotals = $localTotals
    todayUsage = $todayTotals
  }
}

if ($MyInvocation.InvocationName -ne ".") {
  $snapshot = Get-CodexQuotaSnapshot -CodexHome $CodexHome -MaxFiles $MaxFiles -TailLines $TailLines -ForceProfileRefresh:$ForceProfileRefresh

  if ($Json) {
    $snapshot | ConvertTo-Json -Depth 12
  } else {
    $primary = $snapshot.rateLimits.primary
    $secondary = $snapshot.rateLimits.secondary

    "Codex 是否运行：$($snapshot.codexRunning)"
    "状态：$($snapshot.status)"
    "个人资料更新时间：$($snapshot.timestamp)"
    if ($null -ne $snapshot.profileUsage -and $snapshot.profileUsage.status -eq "ok") {
      "总 Token 使用量：$($snapshot.profileUsage.lifetimeTokens)"
    }
    "今日使用 Token：$($snapshot.todayUsage.totalTokens)"
    if ($null -ne $primary) {
      "5小时额度窗口：剩余 $($primary.remainingPercent)%，重置时间 $($primary.resetsAtLocal)"
    }
    if ($null -ne $secondary) {
      "7天额度窗口：剩余 $($secondary.remainingPercent)%，重置时间 $($secondary.resetsAtLocal)"
    }
  }
}
