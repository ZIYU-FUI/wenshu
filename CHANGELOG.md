# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-07-24 (装 / 验证可用)

文枢首版 (v0.0.x rebrand 收尾 + LOGO 替换 + installer 隔离化 + 装机文档).

### Added

- **桌面端 LOGO 替换** — 毛笔"文枢"两字, 圆形深色背景 (#0a0a0a), macOS ic12 + Windows ICO + apple-touch 全套
- **`apps/desktop/assets/icon.{png,icns,ico}`** — 1024×1024 PNG + 564 KB ic12 (含 16/32/64/128/256/512/1024 多尺寸) + 6 尺寸 ICO
- **`apps/desktop/public/apple-touch-icon.png`** — 180×180
- **`apps/bootstrap-installer/src-tauri/icons/`** — installer 同步 LOGO 覆盖
- **installer dmg** — `~/Downloads/文枢_0.0.1_aarch64.dmg` (5.4 MB), 装机 user 拖到 Applications 即装
- **`docs/setup/wenshu-installer-quickstart.md`** — 装机 user 端到端指南 (TL;DR 3 步 + 11 阶段 + 升级 + 卸载 + 故障排查)

### Changed

- **`hermes_constants.py:52`** — 默认 `HERMES_HOME` 从 `~/.hermes` 改 `~/.wenshu-hermes` (避免污染装机 user 已有 hermes)
- **`apps/desktop/electron/main.ts:412`** — 启动时强制 `process.env.HERMES_HOME ||= ~/.wenshu-hermes` (5 spawn 场景保证 100% 隔离)
- **`apps/desktop/package.json mac.extendInfo.LSEnvironment`** — macOS .app 启动自动注入 `HERMES_HOME=$HOME/.wenshu-hermes` 给所有子进程
- **`scripts/install.sh:48`** — `HERMES_HOME` 默认 `~/.wenshu-hermes`
- **`scripts/install.sh:46-47`** — repo URL 改 `git@github.com:ZIYU-FUI/wenshu.git` (不再是 hermes 上游)
- **`scripts/install.sh:9/530/1789`** — URL 改 `raw.githubusercontent.com/ZIYU-FUI/wenshu/main/scripts/install.sh`
- **`scripts/install.sh:1552`** — pyproject extras regex 加 fallback 分支, 兼容 wenshu pyproject 格式
- **`scripts/install.ps1:26-27/139-140/1666-1676/2088`** — Windows 端同样改造 (HermesHome 默认 + repo URL + zip URL + filename + regex)
- **`scripts/install.cmd:8`** — Windows cmd 端 URL 改
- **`setup-hermes.sh`** — 注释引用 wenshu
- **`apps/bootstrap-installer/src-tauri/src/paths.rs`** — 默认 `home.join(".wenshu-hermes")` + 注释更新
- **`apps/bootstrap-installer/src-tauri/src/update.rs`** — 注释 `Hermes-Setup.exe` → `文枢-Setup.exe`
- **`apps/bootstrap-installer/src-tauri/Cargo.toml`** — `name="wenshu-setup"`, `authors="文枢 Project"`, `bin="文枢-Setup"`, 修 pre-existing `[lib]` 缺 `edition="2021"` 导致 `async fn` Rust 2015 报错
- **`apps/bootstrap-installer/src-tauri/tauri.conf.json`** — 修双逗号 typo + publisher/copyright 改 `文枢 Project`
- **`apps/desktop/electron/main.ts:500`** — `.hermes-bootstrap-complete` marker 文件名注释 (历史继承, ACTIVE_HERMES_ROOT 隔离)

### Removed

- **`apps/bootstrap-installer/src-tauri/src/paths.rs:likely_bootstrap_marker()`** — dead code, 0 caller, 删 9 行
- **`apps/bootstrap-installer/src-tauri/src/install_script.rs:ScriptSource::Bundled`** — dead code 警告 (实际还用作 match arm, **保留**, 不真 dead)

### Verified

- ✅ `npm run typecheck` exit 0 (TS + Electron tsconfig)
- ✅ `cargo check` exit 0 (Tauri build)
- ✅ `npm run tauri:build` exit 0 (cold build 1m 21s)
- ✅ `git push origin main` 11 commit 同步
- ✅ install.sh -Manifest 跑通 (11 stages 输出正确 JSON)
- ✅ `~/.wenshu-hermes/` 隔离, `~/.hermes/` 不动
- ✅ `/Applications/文枢.app` CFBundleDisplayName=文枢, Identifier=com.wenshu.app, Version 0.0.1
- ✅ ls-remote 11 关键 commit 全部在远端 main

### Known limitations

- ⚠️ installer dmg 仅 macOS (Win/Linux 后续)
- ⚠️ macOS installer 不写 `.hermes-bootstrap-complete` marker (Windows install.ps1 写; macOS 端 desktop 找不到这个 marker 走 fallback 路径)
- ⚠️ ad-hoc signing (无 Apple Developer ID, 装机 user 端需 Gatekeeper "Open Anyway" 一次)
- ⚠️ pyproject `[project].name` 仍是 `"hermes-agent"` (v0.0.1 不改, 后续 v0.1.x 改 `"wenshu-agent"` 避免 pip 装包冲突)

## [0.0.0] - 2026-07-23 (项目基线)

- 拉 NousResearch/hermes-agent v0.19.0 完整 monorepo fork 到 wenshu 仓
- AIF 落档 3 类项目文档: README / AGENTS / CLAUDE.md
- 拍板"完全改 fork + 跟上游漂移 + 单任务单一功能 + 打 .app 验收"

[Unreleased]: https://github.com/ZIYU-FUI/wenshu/compare/388b4bb91...HEAD
[0.0.1]: https://github.com/ZIYU-FUI/wenshu/compare/388b4bb91...HEAD (merged through c60fac887)
