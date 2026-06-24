---
name: codex-quota-widget
description: "用于查看 Codex 个人资料 Token 使用量、额度窗口，或启动本地 Windows 桌面小窗口。 English: Inspect Codex profile token usage and quota windows, or launch the local Windows companion widget."
---

# Codex 额度查看小窗口

English: Codex Quota Viewer Mini Window

## 适用场景 / Use Cases

- 查看总 Token 和今日 Token 使用量。
- 查看 5 小时、7 天额度窗口和重置时间。
- 查看连续使用天数。
- 启动或刷新 Windows 桌面小窗口。

English: Use this skill to inspect profile token statistics, quota-window state, streak days, or launch the Windows widget.

## 安全边界 / Security Boundary

- 只从 `~/.codex/auth.json` 在内存中读取现有 Codex 登录 token。
- token 只发送到 `https://chatgpt.com/backend-api/wham/profiles/me`。
- token 不打印、不保存、不写日志、不发送到第三方。
- Codex app-server 只通过本机 `127.0.0.1` 临时连接。
- 本地 session 文件只作为额度备用数据，不会上传。

English: The access token remains in memory and is sent only to the official ChatGPT HTTPS host. Local session data is fallback-only and is never uploaded.

## 命令 / Commands

读取 JSON 快照：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Get-CodexQuotaSnapshot.ps1" -Json -ForceProfileRefresh
```

启动窗口：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Start-CodexQuotaWidget.ps1"
```

创建桌面快捷方式：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Install-DesktopShortcut.ps1"
```

## 行为 / Behavior

- Codex 未运行时窗口隐藏，运行时窗口显示。
- 不注册开机自启动。
- 单实例运行，重复点击只唤醒现有窗口。
- 支持手动刷新和每 10 分钟自动强制刷新。
- 总 Token、今日 Token 和连续使用天数来自个人资料统计。
- 额度窗口优先来自 Codex app-server，session 日志只作备用。
- 公开默认图标使用 `assets/codex-quota-widget.png` 和 `.ico`。
- 本机私有自定义素材从 `%LOCALAPPDATA%\CodexQuotaWidget\assets` 读取。

English: The widget is single-instance, Codex-aware, refreshes every 10 minutes, uses profile statistics plus local app-server quota data, and supports local-only custom assets.
