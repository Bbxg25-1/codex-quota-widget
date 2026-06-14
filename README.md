# Codex Quota Widget

A local Windows companion widget for Codex quota visibility.

## What It Shows

- Codex running state.
- Codex profile lifetime token usage.
- Today's Codex profile token usage.
- Primary Codex rate-limit window, usually 300 minutes.
- Secondary Codex rate-limit window, usually 10080 minutes.
- Current streak days.

The widget uses the Codex profile usage endpoint for total and daily token counts.
On force refresh, it uses Codex app-server `account/rateLimits/read` for the quota bars.
Local `token_count` quota values are kept only as a fallback.
It does not estimate costs and does not infer hidden absolute quotas.

## Data Source

Profile token totals are read with the existing Codex login token in:

```text
%USERPROFILE%\.codex\auth.json
```

The widget requests only the profile stats payload from:

```text
https://chatgpt.com/backend-api/wham/profiles/me
```

Quota-window percentages come from Codex app-server on force refresh. Local session files are used only as a fallback:

```text
%USERPROFILE%\.codex\sessions\**\*.jsonl
```

The scripts look for:

```text
event_msg -> payload.type == token_count
```

Profile API and app-server rate-limit responses are cached between force-refreshes.
Profile stats and app-server quota windows are force-refreshed on startup, when the window is shown, when an existing instance is woken, when the refresh button is clicked, and every 10 minutes while the widget is running.

## Run

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Start-CodexQuotaWidget.ps1"
```

The window hides when Codex is not running and appears when a `Codex` or `codex` process is detected.
Launching the desktop shortcut repeatedly keeps a single widget instance; later launches only wake the existing window.
Use the refresh button beside `塔菲模式` to force-refresh profile token usage and quota windows.
Profile token usage and quota windows are also force-refreshed every 10 minutes while the widget is running.

## Taffy Assets

The widget supports a character-hugging-window layout. Put image assets here:

```text
%USERPROFILE%\plugins\codex-quota-widget\assets\taffy-character.png
%USERPROFILE%\plugins\codex-quota-widget\assets\taffy-character-card.png
%USERPROFILE%\plugins\codex-quota-widget\assets\taffy-logo.png
%USERPROFILE%\plugins\codex-quota-widget\assets\taffy-headshot.png
%USERPROFILE%\plugins\codex-quota-widget\assets\taffy-headshot.ico
```

Use a transparent PNG for `taffy-character.png` if you want the character to wrap around the panel cleanly.
For square art, use `taffy-character-card.png`; the widget loads it before the raw character file.
The window and tray icon use `taffy-headshot.ico`; the plugin listing uses `taffy-headshot.png`.
When these files are missing, the widget uses a small original pink/lavender placeholder.

Before publishing this repository publicly, verify that you have permission to redistribute any
character artwork, Bilibili avatar images, logos, or fan art included under `assets/`.

## Snapshot

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Get-CodexQuotaSnapshot.ps1" -Json
```

## Desktop Shortcut

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Install-DesktopShortcut.ps1"
```

This creates a shortcut on the desktop. It does not create a startup task.
