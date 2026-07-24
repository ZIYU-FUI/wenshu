# PROJECT-NOTES.md · 文枢 (Wenshu)

> 留给下一位 PM / CC session 接手的现场笔记.
> 不是文档真理 (真理在 AGENTS.md / CLAUDE.md / README.md).
> v1.98 GS 协议(7/24) 落档: PM-direct 自己写 NOTES, 装机 user 拍板边界.

---

## TL;DR 状态 (cutoff 2026-07-24 11:08 +0800)

- **wenshu tag**: `v0.0.1` 已打 + push (远端 `9ec6fead` 指向 commit `3ab58a14f`, **拉后已被 HEAD `6d20d518c` 超越**, 见 L4)
- **HEAD = origin/main**: `6d20d518c` (本地 = 远端 sync)
- **commit 数**: 18 (从 baseline `388b4bb91` 起)
- **installer dmg**: `~/Downloads/文枢_0.0.1_aarch64.dmg` (5.0 MB, mtime 10:28, CC 落档)
- **desktop .app**: `/Applications/文枢.app` **未装** (装机 user 11:50 删, 老项目同名干扰), 实际装机 user 走 installer + online update
- **隔离路径**: `~/.wenshu-hermes/` (installer 装), `~/.hermes/` 装机 user 已有 hermes 不动
- **CI**: `.github/workflows/ci.yml` 7 jobs (lint / typecheck / test / rust-check / installer-build / desktop-build / install-sh-manifest)

---

## v1.98 GS 装机 user 7/24 拍板真意 (PM-direct 必须遵守)

### GS-1: 验收双层 (反馈即拍 + PM-direct 8 项 AC 验)

| 阶段 | 角色 | 动作 |
|---|---|---|
| 反馈需求/BUG | 装机 user | 直接发, PM-direct 不反问 |
| 派单 | PM-direct | fire CC / 写 prompt, GS-4 模板 |
| CC 跑 | CC | `claude --bare -p` + sentinel `CC DONE: HH:MM:SS` |
| **PM-direct 8 项 AC 验** | **PM-direct** | **不**让装机 user 去跑 npm/cargo/build/install. 自己 grep/cat/plutil/ls 跑, 验真真机能不能跑 |
| 装机 user 真机验收 | 装机 user | PM-direct 确认"可以验" → 装机 user 接手 (UI 视觉 / 启动) |

**反模式**: ❌ PM-direct 验过就告诉装机 user "完事了" + 装机 user 真机跑. ✅ PM-direct 自己跑 8 项 AC 真机.

### GS-2: CC 卡死修复 (0-byte 误判修正)

| 现象 | v1.94 GP 旧 | **GS-2 新 (7/24)** |
|---|---|---|
| CC alive PID, .out 0 byte | "5min 后 0 = 死, 接手" | **claude -p default quiet, 5-15min 无 stdout 是 default** |
| CC PID 没了 | "死" | **真死** ✓ |

**判断流程 (GS-2)**:
```
PM-direct 派单后, 巡检 .out + 看 PID:
  ├─ .out 含 "CC DONE:"  →  ✓ done, 走 8 项 AC 验
  ├─ .out 0 byte + PID alive + 5min 后 0 byte  →  ⏳ 静默跑, 再 wait 5min
  ├─ PID 没了 + 无 sentinel  →  ✗ 真死, kill 重 fire (1 次), 仍死 → 暂停告装机 user
  └─ PID alive + .out 有 stderr build error  →  ⚠ 卡 build, 拍板是否 kill
```

### GS-3: 圣杯派单姿势 (`wenshu-fire-cc` helper, 7/24 落档)

用法:
```bash
wenshu-fire-cc <wo-id> <prompt-path> [--allowedTools "..."] [--add-dir ...]
```

自动注入:
- prompt 末尾 **CC DONE: HH:MM:SS** sentinel (GS-2 协议)
- python 双 fork + os.setsid() (Mac 没 setsid 二进制)
- 显式 `PATH` (hermes sandbox 隔离)
- ssh-agent + ssh-add ~/.ssh/id_ed25519 (CC git push 需)
- `--bare` flag (避开 hermes gateway 冲突)
- 默认 `--add-dir /Volumes/ANAN/Engineering/wenshu` + whitelist `--allowedTools`

### GS-4: 派单 prompt 模板 (GS-3)

```
# WO-YYYYMMDD-NNN: 一句话核心

## 上轮
[之前 CC commit hash / scratchpad / 改了什么 file]

## Scope
**In**: [...明确 3-7 项...]
**Out**: [...明确 0-3 项, 不在 scope...]

## Hard rules (装机 user 拍板相关)
1. 所有研发走 CC (7/24 11:13 拍)
2. 不改 src-tauri 没授权
3. ...

## AC (pm-direct 8 项验收)
- [ ] ...
- [ ] ...

## Failure handling
- ...

## Output format (强制 sentinel)
每 step 完 echo "=== STEP N done ==="
最后 echo "=== ALL DONE ==="
最后 echo "CC DONE: $(date +%H:%M:%S)"
```

### GS-5: CC 沉淀 (v2.1.201, 7/24 mac)

- `claude --bare -p` + `--add-dir` + `--allowedTools` 是 base 圣杯姿势
- claude -p 默认 quiet → 派单必含 sentinel 协议
- 国内网络不通 claude.ai, `claude install --force stable` 失败 → 2.1.201 是 manual 最后能装的 stable
- CC 跑 build/install/commit 5-15min 静默是 default, 不能 0-byte 直接 kill

---

## v1.97 GR (7/24 wenshu fork 战略 + installer-only + AIF 边界)

### GR-1: wenshu fork = 复用 hermes 全套 + 只改

**装机 user 真意**: wenshu 是 Hermes Agent v0.19.0 fork, 复用 hermes 全套现有能力 (installer / self-update / monorepo / CLI / gateway / skills / MCP / Feishu / 排程). PM-direct 只做品牌 + 隔离路径 + LOGO + LICENSE 鸣谢 + 参数化.

### GR-2: installer-only 安装策略 (不再手包 desktop dmg)

- 装机 user 11:13 拍板: "以后不用 [手包 desktop dmg] 手动安装了, 只用安装器 + 在线更新"
- 装机 user 端只走 `install.sh` + `hermes update --yes --gateway` + `hermes desktop --build-only` 自更新
- PM-direct **不**再 `hdiutil create` 包 desktop .app dmg, **不**再 `cp` /Applications/文枢.app
- ✅ 装机 user 升 wenshu = 自己跑 installer / 自动 online update

### GR-3: AIF 只聊项目方向, LOOP 不归 AIF

- 装机 user 11:14 拍板: "C, 不对, 你给 AIF 派活没有意义, 项目开发全是你的事, AIF 只是和我聊项目方向的. LOOP 缓解他完全退出了"
- AIF 不跑 LOOP / 不接 WO / 不写代码
- PM-direct 不派 kanban_create(assignee='aif') 跑活 (装机 user 7/24 13:35 取消这种用法)

---

## 装机 user 跑过的真实流程 (PM-direct 现场笔记)

1. **装机 user 7/24 11:13**: 反馈"LOGO 颜色没用对, 安装包用白底黑色就可以" + crash log (PID 29801 EXC_BAD_ACCESS SIGSEGV `+[NSBundle bundleWithIdentifier:]`)
2. **装机 user 7/24 11:18**: "我反馈需求和 BUG 你就直接动手, 不用问我" + "CC 干完了告诉我可以验, 我去实操之前你要先验, 别有阻断性的让我去当测试"
3. **装机 user 7/24 11:34**: "不要接手, 去解决 CC 卡死的问题, 你要维护 CC 让他顺畅, 避免 CC 卡死"
4. **装机 user 7/24 11:50**: 删了 `/Applications/文枢.app` (老项目同名干扰), 走 installer 重装

---

## 踩过的坑 (Pitfalls) — 历史 v1.85 / v1.94 GP era

### Pitfall (v1.85 GB): CC fire 100% 0-byte 死 (已修正 by GS-3 helper)

旧 `terminal(background=true)` fire CC, grandchild session-detach 杀. **GS-3 helper + GS-2 sentinel 协议修**.

### Pitfall (v1.94 GP-3): Tauri dmg 内容物是拖拽 .app (不是 Tauri UI installer)

`npm run tauri:build` 出 `.dmg` 内部只有 .app + Applications 软链 (macOS 拖拽格式). **不是** Tauri React installer (那个要单独配置).

### Pitfall (v1.94 GP-4): Rust edition misconfig

`[lib]` 段缺 `edition = "2021"` → 8 个 `async fn` 报 "not permitted in Rust 2015". `[lib]` 加 `edition = "2021"`. (CC WO-014 era 修)

### Pitfall (v1.94 GP-5): Tauri icons 跟 desktop icons 不同步

Tauri build 用 `apps/bootstrap-installer/src-tauri/icons/icon.icns`, 独立于 `apps/desktop/assets/icon.icns`. 改 desktop LOGO 必须**同时改 6 个文件** (desktop 4 + installer 6 PNG). **MD5 同步验真**: desktop icon.png MD5 = installer icon.png MD5.

### Pitfall (v1.94 GP-6): dist:mac kill 后 "Lock file is already being held" 错

electron-builder kill 时留 stale lockfile. 等 5s 重 fire, 或 purge `~/.cache/electron-builder/`.

---

## Next Session TODO (装机 user 装机 + 我接 LOOP 后)

| ID | 事项 | 状态 |
|---|---|---|
| WO-020 | installer crash 调研 (CC alive, 等 sentinel) | 🏃 running |
| WO-021 | crash fix 派 CC (等 WO-020 完, 改 src-tauri) | 📋 pending |
| WO-022 | cua-driver Screen Recording TCC 装机 user 手动勾 | low |
| WO-023 | desktop vitest 420 failed (pre-existing, 不阻塞) | med |
| WO-024 | desktop lint 9 warnings (不阻塞但噪音) | low |

---

## 不**改**的 (项目级硬约束)

| 项 | 改的 = 越界 |
|---|---|
| LICENSE 文本 (CC 严禁, 改 = 升级老板) | 改 |
| hermes 业务逻辑 (改 brand, 不重写) | 改 |
| v0.19.0 tag `3ef6bbd20` 内容 | 改 |
| `pyproject.toml [project].name = "hermes-agent"` (v0.0.x 不改, v0.1.x 改 `"wenshu-agent"`) | 改 |
| `apps/desktop/release/` 130 MB | commit 进 git (在 .gitignore) |
| `~/.hermes/` 内容 (装机 user 已有 hermes) | 改 |
| 不动 PM-direct 拍板边界 (派 CC, 不接手大活) | 破 |
| 不动 installer-only (GR-2 拍板) | 手包 desktop .app dmg |
| 不动 AIF 边界 (GR-3 拍板) | 派 kanban 给 AIF 跑 LOOP |

---

## 装机 user → CC → PM-direct → 装机 user 真机 验证 SOP

```
[装机 user] 反馈需求/BUG
    ↓
[PM-direct] fire CC (wenshu-fire-cc <wo-id> <prompt-path>)
    ↓
[CC (claude --bare -p)] 跑 (含 sentinel CC DONE)
    ↓
[PM-direct] 8 项 AC 验 (grep/cat/plutil/ls/md5/git, 不让装机 user 跑 build)
    ↓ 验过没阻断
[装机 user] 真机 UI 启动 / click-through 验 (cua-driver 已授权)
    ↓
[PM-direct] kanban_complete + 更新 NOTES
```
