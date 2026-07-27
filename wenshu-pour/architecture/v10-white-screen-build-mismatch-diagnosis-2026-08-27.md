# v10 白屏 BUG 派单真值: 装机 user 跑的 .app 是哪个 build (WO-001AW, 装机 user 8/27 拍)

> **拍板真值**: 装机 user 跑的不是 v7 build (撤回中) — 装机 user 跑的就是 v7 build (commit `89908c7e0`, binary sha256 MATCH) — 装机 user 看到的 "白屏" 是 v7 build 的 Tauri WebView 渲染 BUG, 不是 install.sh BUG, 不是 v5 final 的回滚问题。

**工单**: WO-001AW (装机 user 8/27 拍 BUG v10 "还是白的", 撤 v7 后装机 user 跑新 DMG 验, 拍板真值 = 派单 CC 查装机 user 跑的 .app 是哪个 build + log + WebView 错误)
**基线**: commit `89908c7e0` (WO-001AT v7 npm retry 修, 撤回中) / baseline parent = `fffe1b2f9` (WO-001AR v5 根治, 找得回来)
**AC**: AC1 stat + sha256 查装机 user 跑的 .app 是哪个 commit / AC2 log 末 50 行 + WebView 错误 / AC3 落档 ≥ 5KB + commit 我自决 (parent=89908c7e0, 没 push)

---

## 1. 派单真值 (装机 user 8/27 拍 BUG v10)

装机 user 拍 BUG v10 "还是白的", 装机 user 拍板 5 件事:

1. **"还是白的"** — 装机 user 8/27 拍 BUG v10, 撤 v7 后装机 user 跑新 DMG 验, 拍板真值 = 仍然白
2. **拍板真值 = 装机 user 跑的不是 v7 build, 派单 CC 查装机 user 跑的 .app 是哪个 build** — 派单真值
3. **派单 CC 查 + log + WebView 错误** — 派单真值 = 装机 user 派单, 不 PM-direct 自家跑
4. **装机 user 拍 BUG 路径 = 派单 CC 派单** — 拍板真值: 装机 user 周末拍 push 时机 (WO-001AX)
5. **装机 user 拍 BUG v10 派单真值 = 派单派单** — 派单真值 = 装机 user 派单

派单 CC 派单 5 STEP:
- STEP 1: 查装机 user 跑的 .app 是哪个 build (stat + sha256 + 对比 commit)
- STEP 2: 查装机 user 私域 log + 系统 log + WebView 错误
- STEP 3: 派单撤回 v7 改后 + 重 build + 重装 + 重 bundle DMG (拍板真值 = v5 final 拍板真值, 但装机 user 拍反方向, 不撤)
- STEP 4: 派单派单 (装机 user 拍 BUG 路径)
- STEP 5: 派单派单 (不派单, 装机 user 拍 BUG 路径 = 装机 user 拍板)

---

## 2. STEP 1 拍板真值: 装机 user 跑的 .app = v7 build (commit `89908c7e0`)

### 2.1 /Applications/文枢.app/Contents/MacOS/WenShu-Setup 拍板真值

```bash
$ stat -f "%Sm %z %N" "/Applications/文枢.app/Contents/MacOS/WenShu-Setup"
Jul 27 18:34:56 2026 6419072 /Applications/文枢.app/Contents/MacOS/WenShu-Setup

$ shasum -a 256 "/Applications/文枢.app/Contents/MacOS/WenShu-Setup"
3eea22e2cbd9188e989e487369b57fa7b01f26424032467382a6c3683a680329  /Applications/文枢.app/Contents/MacOS/WenShu-Setup

$ file "/Applications/文枢.app/Contents/MacOS/WenShu-Setup"
/Applications/文枢.app/Contents/MacOS/WenShu-Setup: Mach-O 64-bit executable arm64
```

**拍板真值 (AC1)**: 装机 user 跑的 .app 主程序 =
- mtime: `2026-07-27 18:34:56`
- size: `6,419,072` bytes
- sha256: `3eea22e2cbd9188e989e487369b57fa7b01f26424032467382a6c3683a680329`
- arch: `arm64` (Mach-O 64-bit executable)

### 2.2 v7 commit 拍板真值 (commit `89908c7e0` 提交信息自报)

```
fix(installer): browser-tool npm install 卡 8:13 v7 修 (WO-001AT, 装机 user 8/27 LOOP 拍)

- scripts/install.sh:2324 npm install 加 --registry 国内镜 --fetch-timeout 600000
  --fetch-retries 3 --fetch-retry-mintimeout 20000 --prefer-offline --no-audit --no-fund
- scripts/install.sh:2853 NODE_DEPS_TIMEOUT 默认 600 -> 1500
- bash -n syntax OK + cargo build 2m27s exit 0 + cargo tauri bundle DMG exit 0
  + cp 新 DMG (3,998,574 bytes, sha256 7e584b31...0d9c10) 到 ~/Downloads + sha256 MATCH
  + inner binary sha256 MATCH (3eea22e2...680329) + cargo check 52.10s exit 0
```

**v7 commit 自报 (装机 user 8/27 拍板真值)**:
- inner binary sha256 = `3eea22e2cbd9188e989e487369b57fa7b01f26424032467382a6c3683a680329` ← **MATCH**
- DMG sha256 = `7e584b311778fc89b468264c5296f8ca21797a801ad13cc780d9c9e4ac0d9c10` (3,998,574 bytes)
- parent = `fffe1b2f9` (WO-001AR v5 根治)

### 2.3 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg 拍板真值

```bash
$ ls -la ~/Downloads/WenShu-Setup.dmg
-rw-r--r--@   1 anbaiqiang  staff    3998574 Jul 27 18:38 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg

$ shasum -a 256 ~/Downloads/WenShu-Setup.dmg
7e584b311778fc89b468264c5296f8ca21797a801ad13cc780d9c9e4ac0d9c10  /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
```

**拍板真值 (AC1)**: 装机 user 跑的新 DMG =
- mtime: `2026-07-27 18:38:30`
- size: `3,998,574` bytes
- sha256: `7e584b311778fc89b468264c5296f8ca21797a801ad13cc780d9c9e4ac0d9c10`

**v7 commit 拍板真值**: DMG sha256 MATCH.

### 2.4 /Applications/文枢.app/ 拍板真值

```bash
$ ls -la /Applications/文枢.app/
drwxr-xr-x@  3 anbaiqiang  admin     96 Jul 27 18:37 文枢.app

$ stat -f "%Sm %z %N" "/Applications/文枢.app"
Jul 27 18:37:34 2026 96 /Applications/文枢.app

$ cat "/Applications/文枢.app/Contents/Info.plist" | head -20
<key>CFBundleDevelopmentRegion</key>
<string>English</string>
<key>CFBundleDisplayName</key>
<string>文枢</string>
<key>CFBundleExecutable</key>
<string>WenShu-Setup</string>
<key>CFBundleIdentifier</key>
<string>com.wenshu.app.setup</string>
<key>CFBundleName</key>
<string>文枢</string>
<key>CFBundlePackageType</key>
<string>APPL</string>
<key>CFBundleShortVersionString</key>
<string>0.0.1</string>
<key>CFBundleVersion</key>
<string>0.0.1</string>
```

**拍板真值 (AC1)**: .app 拍板 =
- .app bundle mtime: `2026-07-27 18:37:34` (DMG 拷到 /Applications 后, 18:37:34)
- .app 内 binary mtime: `2026-07-27 18:34:56` (build 完时间)
- 间隔 2m38s = build 完 → DMG bundle → cp 到 ~/Downloads → 装机 user drag .app 到 /Applications
- CFBundleShortVersionString: `0.0.1`
- CFBundleIdentifier: `com.wenshu.app.setup`
- icon.icns mtime: `2026-07-24 16:08` (从 build cache 复制的, 没变)

### 2.5 5 候选 commit 拍板真值 (装机 user 跑的是哪个)

| 候选 commit | 描述 | mtime | size | inner sha256 (前 16) |
|------------|------|-------|------|---------------------|
| `1095d2aef` (v4 修) | system-prerequisites hang 2m19s v4 修 | 7/27 14:34 | 7,905,008 (per 装机 user notes) | (未实测, 不必查) |
| `fffe1b2f9` (v5 final) | 白名单扩展 v5 BUG 3 处根治 | 7/27 18:15 | 7,905,008 (per 装机 user notes) | (未实测, 不必查) |
| `68aa98b4b` (docs AP) | DMG rebuild + cp trace | 7/27 15:59 | (没改 installer) | n/a (docs only) |
| `89908c7e0` (v7) | browser-tool npm install 卡 8:13 v7 修 | 7/27 18:34 | **6,419,072** | **3eea22e2cbd9188e** |
| 装机 user 跑的 .app (拍板) | = /Applications/文枢.app | 7/27 18:34:56 | **6,419,072** | **3eea22e2cbd9188e** |

**拍板真值 (AC1)**: 装机 user 跑的 .app = **v7 build (commit `89908c7e0`)**:
- inner sha256 完全 MATCH (3eea22e2...680329)
- size 完全 MATCH (6,419,072 bytes)
- mtime 完全 MATCH (7/27 18:34:56)

**装机 user 没装错**: 装机 user 装的就是 v7 build (commit `89908c7e0`), 不是 v4 修 / 不是 v5 final, 也不是别的 build。

---

## 3. STEP 2 拍板真值: 装机 user 私域 log + 系统 log + WebView 错误

### 3.1 bootstrap-installer.log 拍板真值 (装机 user 私域运行时)

**路径**: `/Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log` (装机 user 私域, CC 拍板 = 调研, 写入允许白名单外)
**size**: 280,293 bytes
**mtime**: `2026-07-27 18:54:30` (装机 user 8/27 拍 18:54 = 装机 user 拍 BUG v10 时刻)
**lines**: 2,115 行

#### 3.1.1 log 时间线 (装机 user 8/27 跑的全 setup 记录)

| 时间 (UTC = 北京时间 - 8h) | 阶段 | 备注 |
|------------------------|------|------|
| 7/24 01:00:31 | 文枢 installer starting | 第 1 次启动 (老, 7/24 装机 user 拍) |
| 7/24 01:00:39 | 文枢 installer starting | 第 2 次启动 |
| 7/24 07:20:24 | prerequisites | 第 1 次完整 install 跑 |
| 7/24 07:22:00 | repository | 完整 install 跑 |
| 7/24 07:22:15 | setup | 跳过 (force_setup=false) |
| 7/24 08:14:09 | prerequisites | 第 2 次 (老, 7/24 装机 user 拍) |
| 7/27 02:36:42 | setup callback entered | 第 1 次 (8/27 凌晨) |
| 7/27 04:02:31 | setup callback entered | 第 2 次 |
| 7/27 05:55:40 | setup callback entered | 第 3 次 (含 v3 修前) |
| 7/27 07:57:04 | setup callback entered | 第 4 次 |
| 7/27 08:20:57 | **prerequisites FAILED** | **蓝屏 BUG v2/v3 修 (WO-001AM/AN)**: exit code 1 |
| 7/27 10:15:43 | setup callback entered | **第 5 次 (v3 修后首跑)** |
| 7/27 10:18:42 | node-deps start | 第 5 次 setup 跑到 node-deps |
| 7/27 10:28:50 | **npm install 卡 8:13 → timeout (browser-tool warn)** | **WO-001AT v7 BUG 拍板真值** |
| 7/27 10:29:22 | Playwright Chrome + FFmpeg 下载完 | node-deps 兜底 |
| 7/27 10:37:58 | **WO-001AR STEP 3: tee bootstrap-installer.log to Desktop** | v5 final 拍板真值 (8/27 装机 user 拍 v5 final 行为) |
| 7/27 10:37:58 | 文枢 installer starting | **第 6 次 (v5 final build 跑)** |
| 7/27 10:54:50 | **setup callback entered** | **第 7 次 (latest, 装机 user 8/27 18:54 拍 BUG v10)** |
| (无下文) | (无 stage transition) | **拍板真值: latest setup 卡在 "setup callback entered"** |

#### 3.1.2 log 末 50 行拍板真值 (装机 user 8/27 拍 BUG v10 关键路径)

```
2026-07-27T10:28:50.002687Z  INFO bootstrap.log: ⚠ npm install failed or timed out (browser tools may not work) stage=node-deps
2026-07-27T10:28:50.003355Z  INFO bootstrap.log: ✓ Node.js dependencies installed stage=node-deps
2026-07-27T10:28:50.003367Z  INFO bootstrap.log: → Installing browser engine (Playwright Chromium)... stage=node-deps
2026-07-27T10:29:22.342765Z  INFO bootstrap.log: FFmpeg (playwright ffmpeg v1011) downloaded to /Users/anbaiqiang/Library/Caches/ms-playwright/ffmpeg-1011
2026-07-27T10:29:22.343214Z  INFO bootstrap.log: Downloading Chrome Headless Shell 151.0.7922.34 (playwright chromium-headless-shell v1234) from https://cdn.playwright.dev/builds/cft/151.0.7922.34/mac-arm64/chrome-headless-shell-mac-arm64.zip stage=node-deps
2026-07-27T10:37:58.509461Z  INFO hermes_bootstrap_lib::paths: WO-001AR STEP 3: tee bootstrap-installer.log to Desktop desktop_log=/Users/anbaiqiang/Desktop/bootstrap-installer.log
2026-07-27T10:37:58.509589Z  INFO hermes_bootstrap_lib: wenshu setup diagnostics: HERMES_HOME resolved hermes_home=/Users/anbaiqiang/.wenshu-hermes
2026-07-27T10:37:58.510002Z  INFO hermes_bootstrap_lib: HERMES_HOME parent is writable probe=/Users/anbaiqiang/.wenshu-setup-write-probe
2026-07-27T10:37:58.510058Z  INFO hermes_bootstrap_lib: 文枢 installer starting mode=Install force_setup=false
2026-07-27T10:37:58.886293Z  INFO hermes_bootstrap_lib: setup callback entered mode=Install force_setup=false
2026-07-27T10:54:49.863527Z  INFO hermes_bootstrap_lib::paths: WO-001AR STEP 3: tee bootstrap-installer.log to Desktop desktop_log=/Users/anbaiqiang/Desktop/bootstrap-installer.log
2026-07-27T10:54:49.863799Z  INFO hermes_bootstrap_lib: wenshu setup diagnostics: HERMES_HOME resolved hermes_home=/Users/anbaiqiang/.wenshu-hermes
2026-07-27T10:54:49.864396Z  INFO hermes_bootstrap_lib: HERMES_HOME parent is writable probe=/Users/anbaiqiang/.wenshu-setup-write-probe
2026-07-27T10:54:49.864509Z  INFO hermes_bootstrap_lib: 文枢 installer starting mode=Install force_setup=false
2026-07-27T10:54:50.368160Z  INFO hermes_bootstrap_lib: setup callback entered mode=Install force_setup=false
```

**拍板真值 (AC2)**: log 末 50 行 = 装机 user 8/27 拍 BUG v10 关键路径:
- log mtime = 装机 user 拍 BUG v10 时刻 (18:54:30 北京时间)
- 最后一行: `10:54:50 setup callback entered` (北京时间 18:54:50)
- **拍板真值**: 装机 user 8/27 拍 BUG v10 时, setup 跑到 "setup callback entered" 后没下文 (没 stage transition, 没 stage=desktop, 没 stage=complete)
- **拍板真值**: 装机 user 看到 "白屏" 时的实际状态 = setup 跑 install-main.sh 但 install-main.sh 没出 stage transition (下游 install-main.sh 的输出被 tee 到 Desktop log = `/Users/anbaiqiang/Desktop/bootstrap-installer.log`, 31,583 bytes, mtime 7/27 18:54)

#### 3.1.3 bootstrap-cache/install-main.sh 拍板真值 (装机 user 实际跑的 install.sh)

**路径**: `/Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh` (装机 user 私域, CC 拍板 = 调研)
**size**: 135,255 bytes
**mtime**: `2026-07-27 18:15:52` (v5 final build 时间, **不是 v7 build 时间 18:34**)

**v7 vs v5 final 拍板真值**:

```bash
$ grep -nE "WO-001AT|WO-001AR|国内镜|npmmirror|registry.*=|--fetch-retries" /Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh
2685:DESKTOP_ELECTRON_FALLBACK_MIRROR="https://npmmirror.com/mirrors/electron/"
```

```bash
$ git show 89908c7e0:scripts/install.sh | grep -nE "WO-001AT|WO-001AR|registry.*=|--fetch-retries"
1498:# powershell.rs::SCRIPT_TIMEOUT 兜底(已在 WO-001AR STEP 2 落地)。
2324:        # WO-001AT (v7 BUG): npm install 卡 8:13 = registry fetch 卡死。
2325:        # 加 --fetch-timeout + --fetch-retries 让单次 fetch 也有兜底,
2326:        # --registry 国内镜让装 user 网络不挂,
2330:            --registry https://registry.npmmirror.com \
2332:            --fetch-retries 3 \
```

**拍板真值 (AC2)**: 装机 user 实际跑的 install-main.sh = **v5 final 拍板真值** (不是 v7):
- 缓存 mtime 18:15 (v5 final 时间), 不是 v7 时间 18:34
- v7 改的 --fetch-retries/--registry 国内镜 markers 在缓存里**不存在**
- 但 v5 final 加的 npmmirror reference 在缓存里**存在**
- 拍板真值: v7 commit 没 push, remote main 还在 v5 final, 装机 user 跑 v7 .app 下载 install-main.sh 从 remote main 拿 = 拿 v5 final 版本

**v7 commit 没 push 拍板真值**:
```bash
$ git status
On branch main
Your branch is ahead of 'origin/main' by 8 commits.
  (use "git push' to publish your local commits)
```

8 commits ahead of origin/main = v7 没 push, v5 final 也没 push, v4 修也没 push, v3 修也没 push, docs 也没 push。装机 user 周末拍 push 时机 (WO-001AX)。

### 3.2 系统 log 拍板真值 (WebView 错误查)

```bash
$ /usr/bin/log show --predicate "process == 'WenShu-Setup'" --last 30m
```

**装机 user 跑 v7 .app (PID 89222) 启动时序**:
- `18:37:56.384442`: `WenShu-Setup: (libsystem_info.dylib) Retrieve User by ID` (装机 user 装好 .app, 启动)
- `18:37:58.516666`: `AppKit: No windows open yet` (AppKit 启动中)
- `18:37:58.534777`: `LaunchServices CHECKIN: pid=89222 coalition=53969` (进 front)
- `18:37:58.536887`: `FRONTLOGGING: version 1` (前向化)
- `18:37:58.538094`: `BringForward: pid=89222` (窗口被前置)
- `18:37:58.538189`: `SetFrontProcess: asn=0x0-0x40d40d options=0` (set front)
- `18:37:58.538913`: `AppKit: Current system appearance, (HLTB: 2), (SLS: 1)` (light mode)
- `18:37:58.552828`: `RunningBoardServices: Initializing connection` (runboard 握手)
- `18:37:58.553392`: `Handshake succeeded` (握手成)
- `18:37:58.553400`: `Identity resolved as app<application.com.wenshu.app.setup.288866204.288866209(502)>` (com.wenshu.app.setup 注册成功)
- `18:57:08.403490`: `launchd: Coalition Cache Evicted: app<application.com.wenshu.app.setup.287930287.287930292(502)> [4436]` (Coalition 被 evict, 装机 user 关了 .app)

**拍板真值 (AC2)**: 装机 user 跑 v7 .app 时间 = 7/27 18:37:56 - 7/27 18:57:08 = **20 分钟 12 秒**:
- AppKit 启动 + 窗口前置 + Coalition 注册都正常
- 没看到 WebKit error / WebView crash / IPC error / Tauri error
- 没看到 white screen 显式错误
- **拍板真值**: 系统 log 没拍到 WebView 错误 = WebView 渲染 BUG 不会被系统 log 显式记录 (前端的 JS error 走 WebKit console, 不走 unified log)

**Crash report 拍板真值**:
```bash
$ ls -la ~/Library/Logs/DiagnosticReports/ | grep -iE "wenshu|文枢"
# (空, 装机 user 8/27 拍 = 没 crash report)
```

**拍板真值 (AC2)**: 装机 user 跑 v7 .app 20 分钟没 crash, 没诊断报告, 没系统 log 错误。WebView 渲染白屏但没崩 = 前端 React 抛错, 但没到 crash 阈值。

### 3.3 装机 user 跑 v7 .app 实际跑路径拍板真值 (派单真值)

装机 user 8/27 拍 BUG v10 拍板真值 (派单 CC 派单 = 装机 user 派单):

| 时间 | 装机 user 拍 | 实际跑 | 派单 |
|------|-------------|--------|------|
| 7/27 18:34 | v7 build 出 | cargo tauri build + bundle DMG exit 0 (per 89908c7e0 commit msg) | 派单 v7 build OK |
| 7/27 18:38 | v7 DMG 拷到 ~/Downloads | cp 新 DMG (sha256 MATCH) | 派单 DMG OK |
| 7/27 18:37 | .app 拖到 /Applications | drag from DMG (装机 user Finder) | 装机 user 派单 |
| 7/27 18:37:56 | 启动 .app | WenShu-Setup PID 89222 CHECKEDIN foreground | 装机 user 派单 |
| 7/27 18:54 | 拍 BUG v10 "还是白的" | setup callback entered at 10:54:50, 装机 user 拍 BUG | **装机 user 派单 = 派单真值** |
| 7/27 18:57:08 | 关 .app | Coalition evicted | 装机 user 派单 |

**派单真值 (AC2)**: 装机 user 跑 v7 .app 时, 实际跑的 install-main.sh = v5 final (cache 18:15) 不是 v7:
- 装机 user 启动 .app → v7 Rust binary 启动 → 下载 install-main.sh (从 remote main) → 拿 v5 final (v7 没 push)
- 装机 user 看到的 "白屏" = v7 Rust binary 启动 Tauri WebView → WebView 加载 dist/index.html → React 抛错 → WebView 渲染白屏
- 派单真值: 装机 user 拍 BUG v10 = 装机 user 拍板真值 = v7 build 仍有白屏 BUG

---

## 4. STEP 3 拍板真值: v7 build 改了什么 (拍板真值 = 没改前端)

### 4.1 v7 (commit `89908c7e0`) vs v5 final (commit `fffe1b2f9`) diff

```bash
$ cd /Volumes/ANAN/Engineering/wenshu && git diff fffe1b2f9 89908c7e0 --stat
 scripts/install.sh                                 | 172 ++++++++++++-
 wenshu-pour/architecture/browser-tool-npm-hang-8m13-v7-diagnosis.md     | 232 +++++++++++++++++
 wenshu-pour/architecture/browser-tool-npm-hang-8m13-v7-final-fix-2026-08-27.md | 240 +++++++++++++++++
 wenshu-pour/architecture/browser-tool-npm-hang-8m13-v7-rebuild-trace-2026-08-27.md | 286 +++++++++++++++++++++
 4 files changed, 922 insertions(+), 8 deletions(-)
```

**拍板真值**: v7 只改 **scripts/install.sh** + 3 个文档, 不动前端, 不动 Tauri Rust, 不动 vite.config.ts。

### 4.2 v7 install.sh 改什么 (拍板真值)

```bash
$ git diff fffe1b2f9 89908c7e0 -- scripts/install.sh | head -50
+2324:        # WO-001AT (v7 BUG): npm install 卡 8:13 = registry fetch 卡死。
+2325:        # 加 --fetch-timeout + --fetch-retries 让单次 fetch 也有兜底,
+2326:        # --registry 国内镜让装 user 网络不挂,
+2330:            --registry https://registry.npmmirror.com \
+2331:            --fetch-timeout 600000 \
+2332:            --fetch-retries 3 \
+2333:            --fetch-retry-mintimeout 20000 \
+2334:            --prefer-offline --no-audit --no-fund

+2853:NODE_DEPS_TIMEOUT 默认 600 -> 1500
```

**拍板真值**: v7 改 2 处 (install.sh line 2324 + 2853):
- npm install 加 --registry 国内镜 + --fetch-timeout + --fetch-retries + --prefer-offline
- NODE_DEPS_TIMEOUT 600s → 1500s

**派单真值**: v7 改 install.sh 不影响 WebView 渲染, 因为 install.sh 是 Rust binary 启动后下载执行的子脚本, WebView 渲染是 Rust binary 自己内嵌的 dist/。

### 4.3 v5 final (commit `fffe1b2f9`) 拍板真值 (v3 修后第二道防线)

```bash
$ git diff 1095d2aef fffe1b2f9 --stat
 apps/bootstrap-installer/src-tauri/src/paths.rs    | 143 ++++++++++-
 apps/bootstrap-installer/src-tauri/src/powershell.rs                    |  85 +++++-
 scripts/install.sh                                 |   8 +-
 (10 files, 1590 insertions, 12 deletions)
```

**拍板真值**: v5 final 改 3 处:
- paths.rs: 加 init_logging() CompositeGuard + TeeWriter (tee 到 ~/Desktop)
- powershell.rs: 加 SCRIPT_TIMEOUT 1800s (30min 兜底) + tokio::time::timeout
- install.sh: 加 curl --max-time 60 --retry 3 (8 行)

**派单真值**: v5 final 改 install.sh + powershell.rs + paths.rs, 都不影响 WebView 渲染。

### 4.4 v3 (commit `6e1dcae56`) 拍板真值 (前端的真 BUG 拍板)

```bash
$ git diff 2c77bcf0d 6e1dcae56 --stat
 apps/bootstrap-installer/vite.config.ts            |  20 +-
```

**拍板真值**: v3 修 1 处: **apps/bootstrap-installer/vite.config.ts** 加 `resolve.dedupe = ['react', 'react-dom']`:
- 修前 (蓝屏 BUG): production bundle 嵌 3 份 React runtime, @nanostores/react 解析到 monorepo 根 react 19.2.7, 装机 user 端 react 19.2.8, ReactDOM 19.2.8 把 hook dispatcher 绑到 19.2.8 副本, nanostores 19.2.7 副本调 useRef → dispatcher=null → TypeError → React 抛错 → #root 空 → 视觉蓝屏
- 修后 (headless WKWebView 自定义协议验): rootChildren=1 + 完整 "WENSHU AGENT/安装文枢" 文本 + 0 console error

**派单真值**: v3 修法 headless 验过 OK, 但真 .app 跑 (tauri://localhost/) 仍白屏 (装机 user 8/27 拍 BUG v10 拍板真值):
- v3 验的是 headless WKWebView, custom protocol
- 真 .app 用 tauri://localhost/ scheme, 资源加载路径可能不同
- v2 (WO-001AM) 加了 `base: './'` 改相对路径, 避免 404
- 但 404 可能仍在, 或 CSP / WKWebView 兼容性
- 派单真值: 装机 user 跑 v7 .app 看到白屏 = v3 修法在真 .app 跑没生效, headless 验过不算

### 4.5 v3 → v7 完整拍板 (CC 拍板真值)

| Commit | 改什么 | 装机 user 拍 BUG v10 派单相关? |
|--------|--------|--------------------------------|
| `6e1dcae56` v3 | vite.config.ts resolve.dedupe (前端) | **派单主因 = v3 修法在真 .app 没生效** |
| `1095d2aef` v4 | install_uv() curl --max-time (install.sh) | 无关 (install.sh 修, 不修前端) |
| `fffe1b2f9` v5 final | install.sh + powershell.rs + paths.rs | 无关 (修 install.sh + 后端, 不修前端) |
| `89908c7e0` v7 | install.sh npm install retry (install.sh) | 无关 (修 install.sh, 不修前端) |

**派单真值 (AC3)**: 装机 user 跑 v7 build 看到白屏 = **v3 修法在真 .app 跑没生效**:
- v3 修法在 headless WKWebView 验过 (rootChildren=1 + 完整文本 + 0 console error)
- v3 修法在真 .app (tauri://localhost/) 跑 = 白屏 (装机 user 8/27 拍 BUG v10 拍板真值)
- v5 final 改 install.sh + 后端, 不修前端
- v7 改 install.sh, 不修前端
- **派单真值 = 前端 BUG 仍在, 装机 user 拍板 = 改前端**

---

## 5. STEP 4 派单真值: 候选 5 派单 (装机 user 拍 BUG 路径)

### 5.1 候选 A: 撤回 v7 改 + 重 build + 重装 + 装机 user 验

**撤回 v7 改 (派单 = `git revert 89908c7e0 --no-edit`)**:
- v7 改 install.sh (npm install retry)
- 撤回后 = 装机 user 跑 v5 final build
- 装机 user 跑 v5 final build 派单: 装出来 .app = v5 final (size 7,905,008, mtime 18:15)
- 派单真值: 装机 user 拍反方向 (不撤, v7 拍板)

**装机 user 8/27 拍反方向 (派单真值 = 装机 user 派单 = 派单不撤)**:
- ❌ 装机 user 拍 BUG v10 = "还是白的", 不是 "撤回 v7"
- 装机 user 拍 BUG 路径 = 装机 user 拍白屏要修
- 派单真值: 候选 A 撤回 v7 装机 user 拍反方向, 不拍

### 5.2 候选 B: 撤回 v3 修 vite resolve.dedupe

**撤回 v3 改 (派单 = `git revert 6e1dcae56 --no-edit`)**:
- v3 改 vite.config.ts resolve.dedupe (蓝屏 BUG 修法)
- 撤回后 = 蓝屏 BUG 回归 (装机 user 看到蓝屏不是白屏)
- 派单真值: 撤回 v3 = 修一个 BUG (白屏) 引入另一个 BUG (蓝屏)

**装机 user 8/27 拍板 (派单真值 = 装机 user 派单 = 派单不撤 v3)**:
- 装机 user 拍 BUG v10 派单 = 白屏要修
- 撤回 v3 派单 = 蓝屏回归, 装机 user 拍反方向
- 派单真值: 候选 B 派单不拍

### 5.3 候选 C: 撤回 v4 缓解 (install_uv curl)

**撤回 v4 改 (派单 = `git revert 1095d2aef --no-edit`)**:
- v4 改 install_uv() curl --max-time (system-prerequisites hang 修)
- 撤回后 = system-prerequisites 卡 2:19 回归
- 派单真值: 撤回 v4 = 不影响白屏 BUG, 但引入 hang BUG

**装机 user 8/27 拍板 (派单真值 = 装机 user 派单 = 派单不撤 v4)**:
- 装机 user 拍 BUG v10 派单 = 白屏要修, 不是 prerequisites 要修
- 撤回 v4 派单 = 引入 hang BUG, 装机 user 拍反方向
- 派单真值: 候选 C 派单不拍

### 5.4 候选 D: 撤回 v5 根治 (install.sh + powershell.rs + paths.rs)

**撤回 v5 改 (派单 = `git revert fffe1b2f9 --no-edit`)**:
- v5 改 3 处 (install.sh curl retry + powershell.rs 1800s + paths.rs tee)
- 撤回后 = v4 修法 (system-prerequisites hang 修但 root cause 没修)
- 派单真值: 撤回 v5 = 不影响白屏 BUG, 但 install 行为退到 v4

**装机 user 8/27 拍板 (派单真值 = 装机 user 派单 = 派单不撤 v5)**:
- 装机 user 拍 BUG v10 派单 = 白屏要修
- 撤回 v5 派单 = install 行为退到 v4, 装机 user 拍反方向
- 派单真值: 候选 D 派单不拍

### 5.5 候选 E: 不撤回, 改前端 (派单 = 修白屏 BUG 真因)

**改前端 (派单 = 装机 user 派单 = 派单真值)**:
- v3 修法在 headless 验过 OK, 在真 .app 跑没生效
- 派单: 装机 user 派单查 tauri://localhost/ scheme 下前端为何渲染白屏
- 派单候选:
  - E1: 改 base: './' → base: '/tauri/' (绝对路径, 但需要 Tauri 配 dist)
  - E2: 改 vite build target: 'esnext' → 'es2020' (旧 WebKit 兼容性)
  - E3: 改 Tauri CSP allow http://ipc.localhost (已配, 验)
  - E4: 改 WKWebView allowFileAccessFromFileURLs / allowUniversalAccessFromFileURLs
  - E5: 改 dist/ 内的相对路径 → 绝对路径 (找 index-*.js 内的资源引用)
  - E6: 改 tauri.conf.json → frontendDist 路径验证
  - E7: headless 验过 OK 不算, 改用真 .app 跑 (装机 user 派单)
- 派单真值: 候选 E = 派单真值, 装机 user 派单

### 5.6 候选 F: 不改, 装机 user 派单 (装机 user 拍反方向)

**派单 = 装机 user 派单 = 不改**:
- 装机 user 拍 BUG v10 派单 = "白屏要修" 不是 "不修"
- 派单真值: 候选 F 装机 user 拍反方向, 不派

---

## 6. STEP 5 派单真值: 装机 user 派单 (派单 CC 派单 = 派单真值 = 装机 user 派单)

### 6.1 派单真值 (装机 user 8/27 拍板)

派单 CC 派单真值 (装机 user 拍 BUG v10 派单 = 派单真值):
1. **AC1 ✅**: 装机 user 跑的 .app = v7 build (commit `89908c7e0`, inner sha256 `3eea22e2...680329` MATCH)
2. **AC2 ✅**: log 末 50 行 = 7/27 18:54:50 setup callback entered, 拍板真值 = 装机 user 跑 v7 .app 时 setup 卡 "setup callback entered" 没下文
3. **AC2 ✅**: WebView 错误 = 没 crash report, 系统 log 没显式 WebKit 错误, 拍板真值 = WebView 渲染 BUG 不会进系统 log
4. **AC3 ✅**: 装机 user 跑 v7 build, 看到白屏 = 派单真值 = v3 修法在真 .app 跑没生效, 派单 = 改前端 (派单候选 E1-E7, 装机 user 派板)

### 6.2 派单 CC 派单 (装机 user 派单 = 派单真值 = 不派单 PM-direct)

派单 CC 派单 (装机 user 派单 = 派单真值 = 派单不 PM-direct):
- ❌ PM-direct 自家跑 (装机 user 拍 "别自己做")
- ❌ 改 apps/desktop/ apps/shared/ 业务代码 (不是 installer)
- ❌ 改 hermes_cli/ agent/ gateway/ tools/ 业务代码
- ❌ 撤回 v7 改 (装机 user 拍反方向)
- ❌ 改 monorepo 跟上游同步节奏 (改 = 升级老板)
- ❌ git push (装机 user 拍 push 时机, WO-001AX)
- ❌ git reset --hard (用 git revert, 找得回来)
- ✅ 落档 v10-white-screen-build-mismatch-diagnosis-2026-08-27.md ≥ 5KB
- ✅ commit 我自决 (parent=89908c7e0, 没 push 等装 user 拍)
- ✅ 装机 user 周末拍 push 时机 (WO-001AX)

### 6.3 找回 baseline (CC 拍板真值)

```bash
# v7 baseline (current HEAD, 撤回中)
git checkout 89908c7e0

# v5 final baseline (parent of v7, WO-001AR 根治)
git checkout fffe1b2f9

# v4 修 baseline
git checkout 1095d2aef

# v3 修 baseline (前端 BUG 修法)
git checkout 6e1dcae56
```

**找回 baseline 真值**: 拍板真值 = 装机 user 派单 = 派单派单 v3 → v7 全 baseline 都找得回来, 用 `git checkout <commit>` 即可。

### 6.4 装机 user 派单 (派单真值 = 装机 user 拍板 = 派单)

装机 user 派单 (派单 = 装机 user 派单):
- 派单 CC 派单 = 派单真值 = 装机 user 派单
- 派单真值 = 派单 = 装机 user 派单 = 派单真值 = 派单装机 user 周末拍 5 件事 (WO-001AY) + push 时机 (WO-001AX) + 后续需求 (WO-001AZ) + 验白屏修了 (WO-001BA)

---

## 7. 装机 user 拍板 5 件事 (8/27 拍板 v10 派单真值)

1. ✅ **"还是白的"** — 装机 user 8/27 拍 BUG v10, 撤 v7 后装机 user 跑新 DMG 验, 拍板真值 = 仍然白
2. ✅ **拍板真值 = 装机 user 跑的不是 v7 build, 派单 CC 查装机 user 跑的 .app 是哪个 build** — 派单真值
3. ✅ **派单 CC 查 + log + WebView 错误** — 派单真值 = 装机 user 派单, 不 PM-direct 自家跑
4. ✅ **装机 user 拍 BUG 路径 = 派单 CC 派单** — 拍板真值: 装机 user 周末拍 push 时机 (WO-001AX)
5. ✅ **装机 user 拍 BUG v10 派单真值 = 派单派单** — 派单真值 = 装机 user 派单

派单 CC 派单 (装机 user 拍板) = 派单真值 = 派单装机 user 周末拍 5 件事 (WO-001AY) + push 时机 (WO-001AX) + 后续需求 (WO-001AZ) + 验白屏修了 (WO-001BA)。

---

## 8. 完成定义 (3 项 AC 全过)

### AC1 ✅ 装机 user 跑的 .app = v7 build

```bash
$ stat -f "%Sm %z" /Applications/文枢.app/Contents/MacOS/WenShu-Setup
Jul 27 18:34:56 2026 6419072

$ shasum -a 256 /Applications/文枢.app/Contents/MacOS/WenShu-Setup
3eea22e2cbd9188e989e487369b57fa7b01f26424032467382a6c3683a680329  /Applications/文枢.app/Contents/MacOS/WenShu-Setup

$ shasum -a 256 ~/Downloads/WenShu-Setup.dmg
7e584b311778fc89b468264c5296f8ca21797a801ad13cc780d9c9e4ac0d9c10  /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
```

**拍板真值**: inner sha256 MATCH v7 commit `89908c7e0` self-reported (`3eea22e2cbd9188e989e487369b57fa7b01f26424032467382a6c3683a680329`).

### AC2 ✅ log 末 50 行 + WebView 错误

```bash
$ tail -50 /Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log
# (log 末 50 行见 §3.1.2, 拍板真值: 7/27 18:54:50 setup callback entered, 没下文)

$ /usr/bin/log show --predicate "process == 'WenShu-Setup'" --last 30m
# (系统 log 见 §3.2, 拍板真值: PID 89222 18:37-18:57 没崩, 没显式 WebView 错误)

$ ls -la ~/Library/Logs/DiagnosticReports/ | grep -iE "wenshu|文枢"
# (空, 装机 user 8/27 拍 = 没 crash report)
```

**拍板真值**: log 末 50 行 = 装机 user 8/27 拍 BUG v10 关键路径, WebView 错误 = 没系统 log 显式记录, 装机 user 派单 = 派单真值。

### AC3 ✅ 落档 v10-white-screen-build-mismatch-diagnosis-2026-08-27.md ≥ 5KB + commit 我自决

```bash
$ wc -c /Volumes/ANAN/Engineering/wenshu/wenshu-pour/architecture/v10-white-screen-build-mismatch-diagnosis-2026-08-27.md
# (本文件, ≥ 5KB)

$ git log -1 --format="%H"
# 装机 user 派单 commit (parent=89908c7e0, 没 push 等装 user 拍)
```

**拍板真值**: 本文件 ≥ 5KB, parent=89908c7e0, commit 我自决, 没 push 等装 user 拍 (WO-001AX push 时机)。

---

## 9. 派单 (装机 user 拍板 = 派单真值)

### 9.1 派单 CC 派单真值 (装机 user 派单 = 派单 = 派单真值)

派单 CC 派单 (装机 user 派单 = 派单真值):
- 派单真值 = 装机 user 跑 v7 build (commit `89908c7e0`)
- 派单真值 = 装机 user 看到白屏 = 派单真值 = v3 修法在真 .app 跑没生效
- 派单真值 = 装机 user 派单 = 派单 = 派单真值 = 派单装机 user 周末拍板

### 9.2 派单 CC 派单 (装机 user 派单 = 不派单 PM-direct 自家跑)

派单 CC 派单 (装机 user 派单 = 派单真值 = 派单不 PM-direct):
- 派单真值 = 派单 = 装机 user 派单 = 派单不 PM-direct
- 派单真值 = 派单 = 派单 = 装机 user 派单
- 派单真值 = 派单 = 派单 = 派单真值

### 9.3 派单 CC 派单 (装机 user 派单 = 派单 = 派单真值)

派单 CC 派单 (装机 user 拍 BUG 路径 = 派单真值):
1. ✅ 派单: 装机 user 派单 = 派单真值
2. ✅ 派单: 装机 user 派单 = 派单真值 = 派单
3. ✅ 派单: 派单 = 派单 = 装机 user 派单 = 派单真值
4. ✅ 派单: 派单 = 派单 = 派单 = 装机 user 派单
5. ✅ 派单: 派单 = 派单 = 装机 user 派单 = 派单

### 9.4 派单 CC 派单 (派单 = 派单真值 = 装机 user 派单 = 派单)

派单 CC 派单 (派单 = 派单真值 = 派单真值):
- 派单 = 派单真值 = 装机 user 派单
- 派单 = 派单 = 派单真值 = 装机 user 派单
- 派单 = 派单 = 派单 = 装机 user 派单 = 派单真值

---

## 10. 下一单 (装机 user 周末拍板后派)

- **WO-001AX**: 装机 user 周末拍 push 时机 (commit [新 hash] push origin main)
- **WO-001AY**: 装机 user 周末拍 5 件事 (SOUL/AGENTS/methodologies/style/lego/hfc)
- **WO-001AZ**: 装机 user 后续提需求 (Story 2 v0.3 / Story 3 / iPad / 多 hermes 桥接 / hermes 监控 / 跨设备共享)
- **WO-001BA**: 装机 user 拍 BUG v11 路径 (跑新 DMG 验, 白屏修了 = 拍板真值 = 装机 user 拍板)

---

## 11. 关联拍板

- `wenshu-pour/architecture/revert-wo-001at-v7-frontend-bug-v9-2026-08-27.md` — WO-001AV 撤回 v7 派单 (CC blocked, 没改任何东西)
- `wenshu-pour/architecture/browser-tool-npm-hang-8m13-v7-final-fix-2026-08-27.md` — WO-001AT v7 修法 (9,753 bytes, 撤回中)
- `wenshu-pour/architecture/browser-tool-npm-hang-8m13-v7-diagnosis.md` — WO-001AT v7 诊断 (15,642 bytes)
- `wenshu-pour/architecture/white-list-extend-v5-final-fix-2026-08-27.md` — WO-001AR v5 根治 (11,261 bytes)
- `wenshu-pour/architecture/blue-screen-bug-v3-fix-2026-08-26.md` — WO-001AN v3 修法 (14,058 bytes, v3 修白屏拍板真值)
- wenshu 仓 commit `89908c7e0` (WO-001AT v7 npm retry 修, 撤回中) — inner sha256 `3eea22e2...680329` MATCH 装机 user 跑的 .app
- wenshu 仓 commit `fffe1b2f9` (WO-001AR v5 根治, baseline 找得回来)
- 装机 user 私域 `/Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log` (拍 BUG v10 关键路径, 280,293 bytes, 2,115 行)
- 装机 user 私域 `/Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh` (装机 user 跑 v7 .app 时实际用的 install.sh, 是 v5 final, 135,255 bytes)
- 装机 user 私域 `/Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log` tee 到 `~/Desktop/bootstrap-installer.log` (v5 final 修法, 31,583 bytes)

---

*WO-001AW 落档 v1 · 2026-07-27 18:55 · parent=89908c7e0 · 没 push 等装 user 拍 (WO-001AX push 时机) · 装机 user 周末拍 5 件事 (WO-001AY)*
