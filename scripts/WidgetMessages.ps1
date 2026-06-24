function Get-CodexQuotaProfileMessage {
  param([string]$Status)

  switch ($Status) {
    "no-auth" {
      return "未检测到 Codex 登录状态，请先打开 Codex 并登录。"
    }
    "request-failed" {
      return "读取个人资料失败，可能是网络异常或登录已过期。"
    }
    "no-stats" {
      return "Codex 个人资料暂未返回使用统计，请稍后刷新。"
    }
    default {
      return "暂时无法读取 Codex 个人资料，请稍后刷新。"
    }
  }
}

function Get-CodexQuotaSnapshotMessage {
  param([string]$Status)

  switch ($Status) {
    "no-token-count-found" {
      return "尚未检测到 Codex 请求记录，使用一次 Codex 后再刷新。"
    }
    default {
      return "Codex 正在运行，正在等待可用统计。"
    }
  }
}

function Get-CodexQuotaAppServerMessage {
  param([string]$Status)

  switch ($Status) {
    "codex-not-found" {
      return "未找到 Codex 程序，请确认 Codex 已安装。"
    }
    "request-failed" {
      return "无法读取额度窗口，可能是 Codex 版本不支持或 app-server 启动失败。"
    }
    default {
      return "额度窗口暂不可用，请稍后刷新。"
    }
  }
}

