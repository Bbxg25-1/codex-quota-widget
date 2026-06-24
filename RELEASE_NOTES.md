# v0.2.0 更新说明

> English release notes follow the Chinese section.

## 主要改进

- 在 README 顶部增加安全与隐私说明。
- 明确 access token 只用于请求 `chatgpt.com` 官方域名，不输出、不保存、不记录、不发送到第三方。
- 移除公开仓库中的授权不明确角色素材，改用原创通用图标。
- 支持 `%LOCALAPPDATA%\CodexQuotaWidget\assets` 本机私有自定义素材目录。
- 增加 MIT License、公开预览、三步快速开始和 FAQ。
- 增加 PowerShell `ExecutionPolicy Bypass` 的用途说明和 `RemoteSigned` 替代方案。
- 优化未登录、网络失败、无统计、未找到 Codex 和 app-server 失败时的提示。
- 新增一键创建快捷方式的 `Install-DesktopShortcut.cmd`。
- 保留额度读取、10 分钟自动刷新、手动刷新、单实例和 Codex 状态联动。

## 安装

1. 解压到 `%USERPROFILE%\plugins\codex-quota-widget`。
2. 双击 `scripts\Install-DesktopShortcut.cmd`。
3. 打开并登录 Codex，再双击桌面快捷方式。

## 已知限制

- 本项目不是 OpenAI 官方产品。
- 个人资料后台接口和 Codex app-server 方法可能随官方更新变化。
- 本版本不包含安装器，也不注册开机自启动。

# v0.2.0 Release Notes

## Highlights

- Added a prominent security and privacy notice.
- Removed unverified third-party character artwork from the public package.
- Added original default artwork and local-only custom asset support.
- Added MIT License, preview, three-step quick start, FAQ, and PowerShell policy guidance.
- Improved actionable messages for login, network, profile, Codex executable, and app-server failures.
- Preserved quota retrieval, manual and 10-minute refresh, single-instance behavior, and Codex-aware visibility.

