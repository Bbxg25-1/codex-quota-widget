---
name: codex-quota-widget
description: "用于查看 Codex 个人资料 Token 使用量、额度窗口，或启动本地 Windows 桌面小窗口。 English: Use when inspecting Codex profile token usage, quota windows, or launching the local Windows companion widget."
---

# Codex 额度查看小窗口

English: Codex Quota Viewer Mini Window

这个 skill 用来检查 Codex 个人资料 Token 统计、额度窗口状态，或启动本地桌面小窗口。

English: This skill inspects Codex profile token stats, quota-window state, or launches the local desktop widget.

## 数据来源 / Data Sources

- 读取本机已有 Codex 登录状态：`~/.codex/auth.json`。
- 调用 Codex 个人资料接口：`https://chatgpt.com/backend-api/wham/profiles/me`。
- 读取字段包括 `lifetime_tokens`、`daily_usage_buckets` 和连续使用天数。
- 强制刷新时通过 Codex app-server 的 `account/rateLimits/read` 获取 5 小时和 7 天额度窗口。
- `~/.codex/sessions/**/*.jsonl` 只作为额度窗口兜底来源。
- 不估算费用，不推断隐藏的绝对额度。

English:

- Reads the existing local Codex login state from `~/.codex/auth.json`.
- Calls the Codex profile endpoint: `https://chatgpt.com/backend-api/wham/profiles/me`.
- Reads fields such as `lifetime_tokens`, `daily_usage_buckets`, and current streak days.
- Uses Codex app-server `account/rateLimits/read` for 5-hour and 7-day quota windows on force refresh.
- Uses `~/.codex/sessions/**/*.jsonl` only as a fallback quota-window source.
- Does not estimate costs or infer hidden absolute quota limits.

## 脚本 / Scripts

读取一次 JSON 快照：

English: Read a one-shot JSON snapshot:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Get-CodexQuotaSnapshot.ps1" -Json
```

启动桌面小窗口：

English: Launch the desktop widget:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Start-CodexQuotaWidget.ps1"
```

创建桌面快捷方式：

English: Create a desktop shortcut:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Install-DesktopShortcut.ps1"
```

## 行为 / Behavior

- Codex 未运行时小窗口隐藏。
- Codex 运行时小窗口显示。
- 不注册开机自启动。
- 单实例运行：重复点击快捷方式只唤醒已有窗口。
- `塔菲模式` 标题旁有刷新按钮，可强制刷新 Token 统计和额度窗口。
- 小窗口运行时每 10 分钟自动强制刷新一次。
- 总 Token、今日 Token 和连续使用天数来自 Codex 个人资料统计。
- 额度条优先来自 Codex app-server，session 日志只兜底。
- 窗口/托盘图标使用 `assets/taffy-headshot.ico`。
- 插件 Logo 使用 `assets/taffy-headshot.png`。

English:

- The widget hides when Codex is not running.
- The widget appears when Codex is running.
- It does not register a startup task.
- It is single-instance; repeated shortcut launches wake the existing window.
- The `塔菲模式` header has a refresh button for token stats and quota windows.
- The widget force-refreshes every 10 minutes while running.
- Lifetime tokens, daily tokens, and current streak days come from Codex profile stats.
- Quota bars prefer Codex app-server, with session logs only as fallback.
- The window/tray icon uses `assets/taffy-headshot.ico`.
- The plugin logo uses `assets/taffy-headshot.png`.
