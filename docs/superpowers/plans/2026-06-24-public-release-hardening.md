# Public Release Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the Codex quota widget for public distribution without breaking its existing local behavior.

**Architecture:** Keep the existing PowerShell WinForms application and quota data flow. Add two focused helper scripts for asset resolution and user-facing status messages, move copyrighted local artwork outside the repository, and package only redistributable files.

**Tech Stack:** Windows PowerShell 5.1, WinForms, System.Drawing, Codex app-server, GitHub repository files

---

### Task 1: Protect local artwork and define asset lookup

**Files:**
- Create: `scripts/WidgetAssets.ps1`
- Create: `tests/Run-Tests.ps1`
- Modify: `scripts/Start-CodexQuotaWidget.ps1`
- Modify: `scripts/Install-DesktopShortcut.ps1`

- [ ] Write tests proving that the private local asset directory wins over bundled assets and that bundled assets remain a fallback.
- [ ] Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1` and confirm the asset tests fail because `WidgetAssets.ps1` does not exist.
- [ ] Implement `Get-CodexQuotaAssetPath` and integrate it into widget and shortcut startup.
- [ ] Copy the existing local artwork to `%LOCALAPPDATA%\CodexQuotaWidget\assets`.
- [ ] Re-run the tests and confirm the asset tests pass.

### Task 2: Make errors actionable

**Files:**
- Create: `scripts/WidgetMessages.ps1`
- Modify: `scripts/Start-CodexQuotaWidget.ps1`
- Modify: `scripts/Get-CodexQuotaSnapshot.ps1`
- Test: `tests/Run-Tests.ps1`

- [ ] Add tests for `no-auth`, `request-failed`, `no-stats`, missing Codex executable, and app-server failure messages.
- [ ] Run the test script and confirm the message tests fail because the helper is missing.
- [ ] Implement the smallest status-to-message mapping and expose app-server status without exposing exception or token data.
- [ ] Re-run the tests and confirm all message tests pass.

### Task 3: Public documentation and licensing

**Files:**
- Modify: `README.md`
- Modify: `assets/README.md`
- Modify: `skills/codex-quota-widget/SKILL.md`
- Modify: `.codex-plugin/plugin.json`
- Create: `LICENSE`
- Create: `RELEASE_NOTES.md`

- [ ] Add a bilingual security and privacy notice at the top of README.
- [ ] Add preview, three-step quick start, ExecutionPolicy explanation, FAQ, data-source details, custom-asset instructions, and license notes.
- [ ] Add the MIT License and explain that user-supplied artwork is separately licensed.
- [ ] Update plugin and skill metadata to match public behavior and version `0.2.0`.

### Task 4: Replace tracked artwork and prepare release artifacts

**Files:**
- Delete: `assets/taffy-bilibili-face.jpg`
- Delete: `assets/taffy-character-card.png`
- Delete: `assets/taffy-character.png`
- Delete: `assets/taffy-headshot.ico`
- Delete: `assets/taffy-headshot.png`
- Create: `assets/codex-quota-widget.png`
- Create: `assets/codex-quota-widget.ico`
- Create: `assets/preview-running.png`
- Create: `dist/codex-quota-widget-v0.2.0.zip`

- [ ] Create an original pink quota-window icon with no third-party character or brand artwork.
- [ ] Capture a public-safe screenshot using bundled assets.
- [ ] Build a ZIP containing the plugin manifest, scripts, skill, README, License, release notes, and redistributable assets.

### Task 5: Verification and publication

**Files:**
- Verify all modified files.

- [ ] Run the repository test script.
- [ ] Run a forced JSON snapshot and verify profile and app-server data paths still work.
- [ ] Validate the plugin with `validate_plugin.py`.
- [ ] Scan tracked files for access-token output, third-party asset names, and release-package omissions.
- [ ] Test repeated launches keep one widget process.
- [ ] Commit the reviewed changes and push `main` to GitHub.

