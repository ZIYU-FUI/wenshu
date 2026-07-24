# PROJECT-NOTES.md · 文枢 (Wenshu)

> 留给下一位 PM / CC session 接手的现场笔记.
> 不是文档真理 (真理在 AGENTS.md / CLAUDE.md / README.md).
> 是"现在正在发生什么"+"踩过的坑"+"装机 user 期望".

---

## TL;DR 状态 (cutoff 2026-07-24 09:13 +0800)

- **wenshu tag**: `v0.0.1` 已打 + push (commit `3ab58a14f` HEAD)
- **commit 数**: 16 (从 baseline `388b4bb91` 起)
- **installer dmg**: `~/Downloads/文枢_0.0.1_aarch64.dmg` (5.4 MB)
- **desktop .app**: `/Applications/文枢.app` 在跑 (PID 54280 → 后来 kill 重开)
- **隔离路径**: `~/.wenshu-hermes/` (installer 装), `~/.hermes/` 装机 user 已有 hermes 不动
- **CI**: `.github/workflows/ci.yml` 7 jobs (lint / typecheck / test / rust-check / installer-build / desktop-build / install-sh-manifest)

---

## 踩过的坑 (Pitfalls)

### 1. CC fire 100% 0-byte 死 (Pitfall GB v1.85)

`terminal(background=true)` 派 CC 会** grandchild session-detach 杀** (CC 输出 0 bytes, exit code None).
**修法**: 必须 `terminal(background=true)` **加** `notify_on_complete=true` + PM-direct 自己用 `os.fork() os.setsid()` fire, 这样 grandchild 真正脱离 hermes session 树. PM-direct 自己跑更靠谱.
**真实案例**: 7/23 PM-direct 派 3 张 CC 都 0-byte 死 (WO-001 era), 之后所有大活 (WO-006/008/016/018/020) 都是 PM-direct 用 shell script fire + setsid disown.

### 2. macOS 装安装 .dmg 实践

`installer dmg 内容物 = 1 个 .app (文枢 Setup.app) + 软链 Applications`. 装机 user 操作: 拖 .app 到 Applications → 启动 → Tauri React UI 弹 → 11 阶段 onboarding → 装完.

`installer 装 `.app` ≠ 文枢 desktop .app` (`.app` 同名不同物).
- installer .app (`文枢 Setup.app`) = Tauri 编译, 启动 UI, 11 stages (prereqs / repo clone / venv / deps / path / config / setup / gateway / desktop / complete)
- desktop .app (`文枢.app`) = Electron 编译, 真实文枢体验

两个都装: 拖 installer .app 装 → installer 自己跑 desktop stage (`npm run build`) → 自动 build .app

### 3. electron-builder macOS typo bug

`tauri.conf.json` L38 末尾有双逗号 `,,` (pre-existing bug) + publisher="Nous Research". cargo check 报告 "JSON Tauri config parse fail at line 38 col 134".
**修法** (WO-014 fix): 删 `,`, publisher/copyright 改 `文枢 Project`.

### 4. Rust edition misconfig

`[lib]` 段缺 `edition = "2021"`, Cargo 默认给 lib 2015 edition → 8 个 `async fn` 报 "not permitted in Rust 2015".
**修法** (WO-014 era): `[lib]` 加 `edition = "2021"`.

### 5. Tauri icons 跟 desktop 不同步

Tauri build 用 `apps/bootstrap-installer/src-tauri/icons/icon.icns`, 独立于 `apps/desktop/assets/icon.icns`. 改 desktop LOGO 必须**同时改 6 个文件** (desktop 4 + installer 6 个 PNG).
**漏改 installer icons**: Tauri build 出 .app 仍用 Hermes 旧 icon. 用 MD5 验 `apps/desktop/assets/icon.icns` 跟 `src-tauri/icons/icon.icns` 同 hash 才算同步.

### 6. desktop dist 是 37 MB, 在 .gitignore L70

不是 bug, 装机 user 装完会 git clone 重 build, dist 是 build artifact, 必须 ignore.

---

## 装机 user 端到端 路径

1. `pm-direct` (或 `hermes computer-use`) build `apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg`
2. **cp 到 `~/Downloads/`** (装机 user 模拟"从网上下")
3. **装机 user 双击 dmg** → 弹出 Finder
4. **拖 `文枢.app` 到 `Applications/`** 软链 (Tauri installer .app)
5. **打开 `Applications/文枢.app`** → React UI
6. UI 走 11 阶段 onboarding
7. 默认装到 `~/.wenshu-hermes/`
8. 装完再开 `Applications/文枢.app` = 启动文枢 desktop (Electron .app 在 installer desktop stage built)
9. About 页应显示 "文枢 v0.0.1 · 基于 Hermes Agent v0.19.0 (MIT) 修改"

---

## 还**没做**的工单 (Next Session TODO)

| WO | 描述 | 优先级 |
|---|---|---|
| L1 | install.sh macOS 不写 `.hermes-bootstrap-complete` marker (Windows 写), desktop 找不到走 fallback | low (功能走 fallback) |
| L2 | `pyproject.toml [project].name` 仍是 `"hermes-agent"`, v0.1.x 改 `"wenshu-agent"` | low (pip 装 OK, 仅命名) |
| L3 | desktop vitest 420 failed (React 19 + useRef null 错), pre-existing, 不阻塞 | med (test infra) |
| L4 | desktop lint 9 warnings (React Hook deps + document globals), 不阻塞但噪音 | low |
| L5 | cua-driver Screen Recording TCC 缺 grant, 装机 user 手动勾 System Settings → Privacy → Security → Screen Recording → 加 CuaDriver.app | low (非代码) |
| L6 | cua-driver daemon 默认不启, PM-direct 启 `open -n -g -a CuaDriver --args serve` 才截屏 | low |

---

## CC 死循环 (0-byte)

PM-direct 派 CC 跑 ≥10 张, **0-byte 死率 ~30%**. 大活 (build / 复杂多步骤) 永远 PM-direct 自己跑. 小活 (< 5 步) 才派 CC.

修法: PM-direct shell script + setsid disown + monitor log 起步 (8-30s) 确认 alive.

---

## 装机 user 测试 manual 检验 (装机 user 收到 dmg 后)

1. **双击 dmg** → 看到 Finder 窗口里 `文枢.app`
2. **拖到 Applications 软链** → Progress bar 几秒
3. **从 Applications 启动 文枢 Setup.app** → React UI 弹
4. React UI 默认所有 stage 自动, **只需要输入** Stage 8 (API keys) + Stage 9 (gateway 可选)
5. 看 stage 进度条
6. Stage 10 (desktop) 5-10 分钟 npm run build
7. Stage 11 (complete) 写 `.install_method=git` marker
8. **重启 Applications/文枢.app** = 进文枢 desktop (Electron .app)
9. About 页: CFBundleDisplayName=文枢, Identifier=com.wenshu.app, Version 0.0.1 ✓
10. 关掉 / 验不污染: `ls -la ~/.hermes` mtime 没动 ✓

---

## 不**改**的 (项目级硬约束)

- 改 LICENSE 文本 (CC 严禁, 改 = 升级老板)
- 改 hermes 业务逻辑 (我们改 brand, 不重写)
- 改 v0.19.0 tag commit `3ef6bbd20` 内容 (跟上游漂移策略)
- 改 `pyproject.toml [project].name` (v0.0.1 不改)
- 改 `apps/desktop/release/` 路径或 gitignore (130 MB 必须 ignore)
- 改 `~/.hermes/` 内容 (装机 user 已有 hermes, 不动)
