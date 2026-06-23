# Codex 额度查看小窗口

English: Codex Quota Viewer Mini Window

一个 Windows 桌面小窗口，用来查看 Codex 的 Token 使用量、5 小时额度窗口、7 天额度窗口和连续使用天数。它会在 Codex 运行时显示，Codex 关闭时自动隐藏。

English: A small Windows desktop companion window for viewing Codex token usage, the 5-hour quota window, the 7-day quota window, and current streak days. It appears while Codex is running and hides when Codex is closed.

## 功能 / Features

- 查看 Codex 个人资料里的总 Token 使用量。
- 查看今天的 Token 使用量。
- 查看 5 小时额度窗口和重置时间。
- 查看 7 天额度窗口和重置时间。
- 显示连续使用天数。
- 支持手动刷新。
- 每 10 分钟自动强制刷新一次。
- 单实例运行：重复点击桌面图标不会打开多个窗口，只会唤醒已有窗口。
- 不估算费用，也不推断隐藏的绝对额度。

English:

- Shows lifetime token usage from the Codex profile.
- Shows today's token usage.
- Shows the 5-hour quota window and reset time.
- Shows the 7-day quota window and reset time.
- Shows current streak days.
- Supports manual refresh.
- Force-refreshes every 10 minutes.
- Runs as a single instance: repeated desktop shortcut launches wake the existing window instead of opening duplicates.
- Does not estimate costs or infer hidden absolute quota limits.

## 数据来源 / Data Sources

Token 总量和今日使用量来自 Codex 个人资料接口。脚本会读取本机已有的 Codex 登录状态：

English: Lifetime and daily token usage come from the Codex profile endpoint. The script reads the existing local Codex login state:

```text
%USERPROFILE%\.codex\auth.json
```

请求的个人资料统计接口：

English: Profile stats endpoint:

```text
https://chatgpt.com/backend-api/wham/profiles/me
```

额度窗口优先来自 Codex app-server：

English: Quota windows are read primarily from Codex app-server:

```text
account/rateLimits/read
```

本地 session 文件只作为兜底：

English: Local session files are used only as a fallback:

```text
%USERPROFILE%\.codex\sessions\**\*.jsonl
```

## 运行 / Run

启动小窗口：

English: Launch the widget:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Start-CodexQuotaWidget.ps1"
```

查看一次 JSON 快照：

English: Read a one-shot JSON snapshot:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Get-CodexQuotaSnapshot.ps1" -Json
```

创建桌面快捷方式：

English: Create a desktop shortcut:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\codex-quota-widget\scripts\Install-DesktopShortcut.ps1"
```

这个脚本只创建桌面快捷方式，不会创建开机自启动任务。

English: This script only creates a desktop shortcut. It does not create a startup task.

## 行为说明 / Behavior

- Codex 没有运行时，小窗口会隐藏。
- Codex 运行时，小窗口会显示。
- 点击关闭按钮只会隐藏窗口，不会设置开机自启动。
- 桌面图标连续点击多次，只保留一个窗口实例。
- `塔菲模式` 旁边的刷新按钮会强制刷新 Token 统计和额度窗口。
- 打开窗口、唤醒已有窗口、点击刷新按钮、每 10 分钟定时刷新，都会触发强制刷新。

English:

- The widget hides when Codex is not running.
- The widget appears when Codex is running.
- The close button hides the window and does not install any startup task.
- Repeated desktop shortcut launches keep only one widget instance.
- The refresh button beside `塔菲模式` force-refreshes token stats and quota windows.
- Startup, wake-up, manual refresh, and the 10-minute timer all trigger force refresh.

## 素材 / Assets

小窗口支持自定义塔菲风格素材：

English: The widget supports custom Taffy-style assets:

```text
%USERPROFILE%\plugins\codex-quota-widget\assets\taffy-character.png
%USERPROFILE%\plugins\codex-quota-widget\assets\taffy-character-card.png
%USERPROFILE%\plugins\codex-quota-widget\assets\taffy-logo.png
%USERPROFILE%\plugins\codex-quota-widget\assets\taffy-headshot.png
%USERPROFILE%\plugins\codex-quota-widget\assets\taffy-headshot.ico
```

公开发布前，请确认你有权再分发 `assets/` 目录里的角色图、Bilibili 头像、Logo 或同人图。如果没有，请替换为你自己拥有版权或授权的图片。

English: Before publishing this repository publicly, make sure you have permission to redistribute the character artwork, Bilibili avatar images, logos, or fan art under `assets/`. If not, replace them with images you own or are licensed to use.

## 目录结构 / Project Structure

```text
.codex-plugin/plugin.json
scripts/Get-CodexQuotaSnapshot.ps1
scripts/Start-CodexQuotaWidget.ps1
scripts/Install-DesktopShortcut.ps1
assets/
skills/codex-quota-widget/SKILL.md
```

English: The project is a local Codex plugin with PowerShell scripts, assets, and one skill description.
