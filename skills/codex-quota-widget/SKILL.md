---
name: codex-quota-widget
description: "Use when the user wants to inspect Codex profile token usage, Codex quota/rate-limit remaining, or launch the local Windows Codex Quota Widget companion."
---

# Codex Quota Widget

Use this skill to inspect Codex profile token stats and local quota-window state.

## Data Source

- Reads the existing Codex login token from `~/.codex/auth.json`.
- Calls `https://chatgpt.com/backend-api/wham/profiles/me` for profile stats such as `lifetime_tokens`, `daily_usage_buckets`, and current streak days.
- Caches profile stats and app-server rate-limit responses between force-refreshes.
- Uses Codex app-server `account/rateLimits/read` for quota-window percentages and reset timestamps on force refresh.
- Reads `~/.codex/sessions/**/*.jsonl` only as a fallback for quota-window percentages and reset timestamps.
- Looks for `event_msg` entries whose payload type is `token_count`.
- Uses `payload.rate_limits.primary` and `payload.rate_limits.secondary` for quota remaining.
- Does not estimate daily costs and does not infer hidden absolute quotas.

## Scripts

Run a one-shot JSON snapshot:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Get-CodexQuotaSnapshot.ps1" -Json
```

Launch the companion window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Start-CodexQuotaWidget.ps1"
```

Optional desktop shortcut:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Install-DesktopShortcut.ps1"
```

## Behavior

- The widget hides when no `Codex` or `codex` process is running.
- The widget appears when a Codex process is detected.
- It is not installed as a startup app.
- The widget is single-instance; repeated shortcut launches signal the existing window instead of opening another one.
- The `塔菲模式` header has a refresh button for force-refreshing profile token usage and quota windows.
- Profile token usage and quota windows are force-refreshed every 10 minutes while the widget is running.
- Optional assets are loaded from `assets/taffy-character.png` and `assets/taffy-logo.png`.
- Total and daily token counts are based on the Codex profile stats endpoint.
- Current streak days are based on the Codex profile stats endpoint.
- The quota display is based on Codex's own locally recorded `used_percent` and reset timestamps, so it can show remaining percent and reset time but not an undisclosed absolute token allowance.
- The window/tray icon is loaded from `assets/taffy-headshot.ico`; the plugin logo is `assets/taffy-headshot.png`.
