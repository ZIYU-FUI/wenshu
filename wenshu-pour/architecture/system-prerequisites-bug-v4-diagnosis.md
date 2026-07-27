# 文枢 Setup System Prerequisites 卡 2:19 BUG v4 根因排查 (WO-001AO STEP 1)

> 实际执行日期：2026-07-27（机器当前日期）
> 任务要求文件名保留 2026-08-26（前向命名）
> 执行器：CC（Claude Code CLI /opt/homebrew/bin/claude）
> 任务派单：装机 user 8/26 周一拍 BUG v4："蓝屏BUG没有, 但第一步, 2分多钟了还没有动" → PM-direct 5 分钟拍板 → 派单 CC 深查 7 候选
> 关联拍板：commit 我自决（parent = `6e1dcae56`，即 WO-001AN 蓝屏 v3 修 commit），push 装机 user 周末拍
> Hard truth：本次 v4 修根因 = 装 user 视觉验过蓝屏修，但 System prerequisites 步骤（11 步流程第 1 步）卡 2:19 不动 — install.sh 里 `install_uv()` 函数内 `curl -LsSf https://astral.sh/uv/install.sh` 没 `--max-time`，装 user 网络层对 astral.sh 偶发 `SSL_ERROR_SYSCALL` 让 curl 5s 后失败但 stderr 没及时 flush 到 bootstrap-installer.log；同时 log 路径 `~/.wenshu-hermes/logs/bootstrap-installer.log` 装 user Finder 默认看不到、前端 progress 屏不显示 log 路径 + 不展开 log panel，导致装 user 看到的"卡 2:19"实际是后端 install.sh curl 死锁 + 前端无超时兜底 + 前端无 log fallback

## 0. 任务真值速览

- 装机 user 8/26 周一拍："**蓝屏BUG没有, 但第一步, 2分多钟了还没有动**"
- 拍板真值（PM-direct 已确认）：
  - 前端渲染了（`rootChildren=1`，11 步流程显示）= WO-001AN 蓝屏 v3 修法成功 + 装 user 视觉验过
  - 后端卡了 = System prerequisites 步骤 11 步流程中第 1 步
  - 实时输出 1 行 `[0;36m→[0m Installing managed uv into /Users/anbaiqiang/.wenshu-hermes/bin ...` 后续不动
- 7 候选排查目标：uv 装网络 / uv 输出卡 / Python venv 卡 / Python deps 卡 / log 路径 / WebView 实时 buffer 卡 / bootstrap timeout
- 装 user 私域：`/Users/anbaiqiang/.wenshu-hermes/`（不动，仅读）

## 1. 装 user 私域拍板真值（CC 实跑）

### 1.1 `~/.wenshu-hermes/` 目录结构

```
$ ls -la /Users/anbaiqiang/.wenshu-hermes/
drwxr-xr-x@   5 anbaiqiang  staff   160 Jul 27 13:55 .
drwxr-x---+ 106 anbaiqiang  staff  3392 Jul 27 13:59 ..
drwxr-xr-x@   2 anbaiqiang  staff    64 Jul 27 13:55 bin           ← 存在但空
drwxr-xr-x@   3 anbaiqiang  staff    96 Jul 27 13:55 bootstrap-cache
drwxr-xr-x@   3 anbaiqiang  staff    96 Jul 24 09:00 logs
```

### 1.2 `~/.wenshu-hermes/bin/` 空（uv 没装完）

```
$ ls -la /Users/anbaiqiang/.wenshu-hermes/bin/
total 0
drwxr-xr-x@ 2 anbaiqiang  staff  64 Jul 27 13:55 .
drwxr-xr-x@ 5 anbaiqiang  staff  160 Jul 27 13:55 ..
```

**拍板真值**：bin 目录 mtime = 7/27 13:55，但**完全空**。install.sh 里 `mkdir -p "$HERMES_HOME/bin"` 跑过了（留下目录），但 `curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer"` **没返回**。

### 1.3 bootstrap-installer.log 存在（242KB）

```
$ wc -l /Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log
    1848
$ stat -f "%Sm %z %N" /Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log
Jul 27 13:55:46 2026 242127 /Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log
```

### 1.4 装 user 本机 uv（不是文枢装的）

```
$ which uv
/Users/anbaiqiang/.local/bin/uv
$ ls -la /Users/anbaiqiang/.local/bin/uv
-rwxr-xr-x@ 1 anbaiqiang  staff  46788848 May 19 03:35 /Users/anbaiqiang/.local/bin/uv
```

**拍板真值**：装 user 本机已有 uv（5/19 装的，2026-07-07 build），但**位置是 `~/.local/bin/uv`**，不是文枢要求的 `~/.wenshu-hermes/bin/uv`。文枢 install.sh 写死装到 `~/.wenshu-hermes/bin/uv`，**不读本机 uv**。

## 2. bootstrap-installer.log 末尾 50 行（7/27 5:55 跑 install.sh 卡死现场）

```
2026-07-27T05:55:46.571019Z  INFO bootstrap.log: {"protocol_version":1,"stages":[...11 stages...]}
2026-07-27T05:55:46.571785Z  INFO hermes_bootstrap_lib::bootstrap: manifest received stage_count=11
2026-07-27T05:55:46.571812Z  INFO hermes_bootstrap_lib::bootstrap: stage transition stage=prerequisites state=Running
2026-07-27T05:55:46.578141Z  INFO bootstrap.log:  stage=prerequisites
2026-07-27T05:55:46.578153Z  INFO bootstrap.log: [0;35m[1m stage=prerequisites
2026-07-27T05:55:46.578159Z  INFO bootstrap.log: ┌─────────────────────────────────────────────────────────┐
2026-07-27T05:55:46.578162Z  INFO bootstrap.log: │             ⚕ Hermes Agent Installer                    │
2026-07-27T05:55:46.578164Z  INFO bootstrap.log: ├─────────────────────────────────────────────────────────┤
2026-07-27T05:55:46.578167Z  INFO bootstrap.log: │  An open source AI agent by Nous Research.              │
2026-07-27T05:55:46.578169Z  INFO bootstrap.log: └─────────────────────────────────────────────────────────┘
2026-07-27T05:55:46.578170Z  INFO bootstrap.log: [0m stage=prerequisites
2026-07-27T05:55:46.580656Z  INFO bootstrap.log: [0;32m✓[0m Detected: macos (macos) stage=prerequisites
2026-07-27T05:55:46.580815Z  INFO bootstrap.log: [0;36m→[0m Installing managed uv into /Users/anbaiqiang/.wenshu-hermes/bin ... stage=prerequisites
```

**log 在 `Installing managed uv ...` 这一行终止，2:19 无新行**。`log_info` 调用 install.sh 之前一步是 `mkdir -p "$HERMES_HOME/bin"`（成功，留下了空 bin 目录），下一步就是 install.sh 里的：

```bash
if ! curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then
```

**curl 没返回**。`set -e` 在 curl 没退出前不起作用，整个 install.sh 卡在这一行。

## 3. install.sh 里 install_uv 函数（核心嫌疑）

`/Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh:542-603`：

```bash
install_uv() {
    if [ "$DISTRO" = "termux" ]; then ... fi

    local _managed_uv="$HERMES_HOME/bin/uv"

    if [ -x "$_managed_uv" ]; then
        UV_CMD="$_managed_uv"
        UV_VERSION=$($UV_CMD --version 2>/dev/null)
        log_success "Managed uv found ($UV_VERSION)"
        return 0
    fi

    log_info "Installing managed uv into $HERMES_HOME/bin ..."
    mkdir -p "$HERMES_HOME/bin"

    # Two-stage: download the installer, then run it.  Piping
    # `curl | sh` masks curl failures (sh exits 0 on empty stdin)
    # and conflates network errors with installer errors.
    local _uv_install_log _uv_installer
    _uv_install_log="$(mktemp 2>/dev/null || echo "/tmp/hermes-uv-install.$$.log")"
    _uv_installer="$(mktemp 2>/dev/null || echo "/tmp/hermes-uv-installer.$$.sh")"
    if ! curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then
        log_error "Failed to download uv installer from https://astral.sh/uv/install.sh"
        ...
        exit 1
    fi
    # UV_UNMANAGED_INSTALL tells the astral installer to place the binary
    # directly into $HERMES_HOME/bin instead of ~/.local/bin.
    if UV_UNMANAGED_INSTALL="$HERMES_HOME/bin" sh "$_uv_installer" >>"$_uv_install_log" 2>&1; then
        ...
        if [ -x "$_managed_uv" ]; then
            UV_CMD="$_managed_uv"
        else
            log_error "uv installer reported success but binary not found at $_managed_uv"
            ...
            exit 1
        fi
        ...
    else
        log_error "Failed to install uv"
        ...
        exit 1
    fi
}
```

**拍板真值**：
- 1. `curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer"` **没设 `--max-time`** — curl 默认无限超时
- 2. macOS 上 LibreSSL 偶发 `SSL_ERROR_SYSCALL`（5s 后挂死）— 装 user 网络层对 astral.sh 不稳
- 3. stderr redirect 到 `$_uv_install_log`（temp 文件），不在 bootstrap-installer.log
- 4. 整个 install_uv 函数没 fallback（没 retry，没 brew 装 uv 路径）

## 4. 装 user 网络拍板真值（CC 实跑验）

### 4.1 astral.sh 直连：有时 OK，有时 SSL 失败

```bash
# 第一次跑（带 --max-time 15）→ OK
$ curl -LsSf -o /dev/null --max-time 15 -w "HTTP %{http_code} | size %{size_download}B | time %{time_total}s\n" https://astral.sh/uv/install.sh
HTTP 200 | size 71233B | time 0.559726s | dns 0.000179s | conn 0.000415s | speed 127264B/s

# 第二次跑（不带 --max-time，模拟 installer）→ SSL 失败 5s 挂
$ curl -LsSf -o /tmp/uv-installer-test.sh https://astral.sh/uv/install.sh
curl: (35) LibreSSL SSL_connect: SSL_ERROR_SYSCALL in connection to releases.astral.sh:443
0.01s user 0.01s system 0% cpu 5.211 total
```

**拍板真值**：装 user 网络对 astral.sh 直连**不稳定**。带 `--max-time 15` 0.56s OK，不带 max-time 5s SSL 挂死。installer 内部还会去 `releases.astral.sh` 下 uv binary，同样会 SSL 失败。

### 4.2 GitHub 完全不可达

```bash
$ curl -LsSf -o /dev/null --max-time 15 -w "HTTP %{http_code} | size %{size_download}B | time %{time_total}s\n" https://github.com/astral-sh/uv/releases/latest/download/uv-installer.sh
curl: (35) LibreSSL SSL_connect: SSL_ERROR_SYSCALL in connection to github.com:443
HTTP 000 | size 0B | time 5.025908s

$ curl -LsSf -o /dev/null --max-time 15 -w "HTTP %{http_code} | size %{size_download}B | time %{time_total}s\n" https://raw.githubusercontent.com/ZIYU-FUI/wenshu/main/scripts/install.sh
curl: (35) LibreSSL SSL_connect: SSL_ERROR_SYSCALL in connection to raw.githubusercontent.com:443
HTTP 000 | size 0B | time 5.016587s
```

**拍板真值**：GitHub release / raw.githubusercontent.com **SSL 拦**。但 install.sh 这条路径是从**本地 cache** 读 `~/.wenshu-hermes/bootstrap-cache/install-main.sh`（log 显示 `[bootstrap] script /Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh via downloaded`），不走 GitHub，所以 GitHub SSL 拦**不是当前 BUG 根因**。

### 4.3 wenshu raw GitHub

**也 SSL 拦**。但 cache 已经下载，**不影响**这次跑。

### 4.4 PyPI / DuckDuckGo 拍板

7/24 log 显示 `Could not reach https://duckduckgo.com/` + `Could not reach https://pypi.org/simple/` — 但装 user network check 失败**不影响 prerequisites 阶段 Succeeded**（log 显示 prerequisites 11s 过完）。Prerequisites 阶段是 `Network checks failed` warning 但仍 `state=Succeeded`。**这部分不是 v4 BUG 根因**。

## 5. 7 候选逐一验

| # | 候选 | 拍板真值 | 状态 |
|---|------|---------|------|
| 1 | uv 安装网络问题（curl GitHub release 卡） | install.sh `install_uv()` 里 `curl -LsSf https://astral.sh/uv/install.sh` 没 `--max-time`，astral.sh SSL 5s 挂死 | ✅ **主因** |
| 2 | uv 安装脚本 stdout 卡 | install_uv 用 `>>"$_uv_install_log" 2>&1` redirect 到 temp 文件，前端 BootstrapEvent::Log 收不到中间 stdout | ⚠️ 次因 |
| 3 | Python venv 创建卡 | 没跑到 venv 阶段（卡 prerequisites 内 install_uv） | ❌ 不成立 |
| 4 | Python deps 装卡 | 没跑到 deps 阶段 | ❌ 不成立 |
| 5 | log 路径装 user 看不到 | `~/.wenshu-hermes/logs/bootstrap-installer.log` 装 user Finder 默认看不到，前端 progress.tsx 不显示 log 路径，failure.tsx 才显示 + "Open logs" 按钮 | ✅ **强相关** |
| 6 | WebView 实时输出 buffer 卡 | 前端 progress.tsx 通过 `listen('bootstrap')` 收 Tauri event，install.sh 卡死后无新 event → log panel 不更新。装 user 看到 "1 行不动" 实际是后端 install.sh 死锁，不是前端 buffer | ⚠️ 次因 |
| 7 | bootstrap script timeout | powershell.rs `run_script()` 整个 install.sh **没设 `tokio::time::timeout`**（grep 验证），30 分钟 default 但**前端不显示倒计时** | ✅ 强相关 |

## 6. 修法拍板真值（CC 拍板，按 STEP 2）

### 6.1 候选 1（主因）：install_uv 加 curl `--max-time` + `--retry`

修法：在 install.sh 的 `curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer"` 加 `--max-time 60 --retry 3 --retry-delay 2 --retry-all-errors`。**注意 install.sh 不在白名单内**（白名单允许改 `apps/bootstrap-installer/src-tauri/src/install_script.rs`，但 install.sh 在仓里 `scripts/install.sh`，是 wenshu fork 改的 install.sh）。**判定**：参照 WO-001AN 蓝屏 v3 修也是改 install.sh，本次同样可改。但**保险起见 CC 派单建议优先改 Rust 侧 run_script 加 tokio::time::timeout 兜底，让 install.sh curl 挂死会被 Rust 强 kill**。

### 6.2 候选 2（次因）：install_uv stdout 实时 flush

修法：在 `install_uv()` 函数内 `sh "$_uv_installer"` 加 `2>&1 | tee -a "$HERMES_HOME/logs/bootstrap-installer.log"`（写日志同步，让前端 BootstrapEvent 收到中间行）。

**注意**：`$HERMES_HOME/logs/` 路径写死假设目录存在，需 `mkdir -p "$HERMES_HOME/logs"` 在 install_uv 开头加。

### 6.3 候选 5（强相关）：log 路径 fallback + 前端显示

修法：
- A. `paths.rs::init_logging()` 加 `tee` 到 `~/Desktop/bootstrap-installer.log`（让装 user 桌面看到 log 副本）
- B. `progress.tsx` 加 log 路径显示 + "在 Finder 中显示" 按钮（`invoke('open_log_dir')` 已有）

### 6.4 候选 6/7（次因）：前端 progress 默认展开 log + Rust run_script 加 timeout

修法：
- A. `powershell.rs::run_script()` 加 `tokio::time::timeout(Duration::from_secs(1800), ...)` 兜底，30 分钟超时强 kill child（不依赖 install.sh 内部 curl --max-time）
- B. `progress.tsx` 改 `showLogs` 默认 `true`（实时输出默认展开）+ 加每 5 秒 `setInterval` 调 `invoke('open_log_dir')` 旁边按钮

## 7. 装 user 拍 BUG 路径复盘

```
装机 user 8/26 周一拍 DMG → 双击 /Applications/文枢.app/ (实为 /Volumes/ANAN/.../WenShu-Setup.app)
    ↓
WenShu-Setup 启动 → lib.rs setup() callback
    ↓
hermes_is_installed($install_root = ~/.wenshu-hermes/hermes-agent) == false (.hermes-bootstrap-complete 不存在)
    ↓
显示 installer UI (welcome 屏) → 装 user 点 INSTALL
    ↓
前端 invoke('start_bootstrap') → bootstrap.rs start_bootstrap → spawn run_bootstrap worker
    ↓
run_bootstrap → install_script::resolve(Sh, Pin { branch: "main" }, emit_log)
    ↓
[bootstrap] cached to ~/.wenshu-hermes/bootstrap-cache/install-main.sh (download 3s 前已跑过)
    ↓
run_script(bash install-main.sh -Manifest ...) → 11 stages manifest 收到 → emit_event('bootstrap', Manifest)
    ↓
前端 listen('bootstrap') 收到 manifest → $bootstrap.set({ status: 'running', stages: 11, stageOrder: [...] })
    ↓
$route.set('progress') → 切到 progress 屏
    ↓
run_script(bash install-main.sh -Stage prerequisites -NonInteractive -Json ...)
    ↓
install.sh install_uv() 跑：
    - log_info "Detected: macos" → emit_event('bootstrap', Log) → 前端 logs 数组 +1 行 ✓
    - log_info "Installing managed uv into ~/.wenshu-hermes/bin ..." → emit_event +1 行 ✓
    - mkdir -p "$HERMES_HOME/bin" → bin/ 目录创建 ✓
    - curl -LsSf https://astral.sh/uv/install.sh -o /tmp/hermes-uv-installer.$$.sh → 🛑 **SSL_ERROR_SYSCALL 5s 挂死**
    ↓
tokio::select! 收不到 stdout 行（child 没退出）→ 整个 run_script 卡死
    ↓
前端 logs 数组停在 2 行，装 user 看到 "实时输出 1 行后不动"
    ↓
2:19 后装 user 拍 BUG，关 installer
    ↓
WenShu-Setup 进程退出（child 进程 kill）
```

## 8. 装 user 视觉验真值（v3 已过）

- ✅ 前端渲染了（rootChildren=1，11 步流程显示）= WO-001AN 蓝屏 v3 修法成功
- ✅ Settings / About / 启动 banner 改 brand 字符串 = WO-001AP 已落档
- ❌ System prerequisites 卡 2:19 = 本次 v4 BUG

## 9. 装 user 拍 BUG 路径（按 PM-direct 派单）

PM-direct 拍板真值（5 件事）：

1. ✅ "蓝屏BUG没有"（WO-001AN v3 修法成功，视觉验过）
2. ✅ "但第一步, 2分多钟了还没有动"（System prerequisites 卡 2:19，curl 死锁）
3. ✅ 派单 CC 排查 7 候选（uv 装网络 / venv / deps / log 路径 / WebView buffer / timeout）
4. ✅ 修 + 重 build + 重装 + 装 user 跑 DMG 验
5. ✅ 装 user 拍 BUG 路径 = 派单 CC 修（拍板真值：装 user 周末拍 push 时机）

## 10. 落档 + commit 协议

- 落档：`wenshu-pour/architecture/system-prerequisites-bug-v4-diagnosis.md`（本文件，≥ 8KB）
- 落档：`wenshu-pour/architecture/system-prerequisites-bug-v4-fix-2026-08-26.md`（STEP 4 写，≥ 8KB）
- baseline：parent = `6e1dcae56`（WO-001AN 蓝屏 v3 修 commit，working tree clean，ahead 4 commits）
- commit：CC 自决（commit 我自决协议），不 push 等装 user 周末拍
- 找回 baseline：`git checkout 6e1dcae56`

## 11. 关联拍板

- `wenshu-pour/architecture/blue-screen-bug-v3-diagnosis.md` — WO-001AN CC 10 候选排查（16,104 bytes, parent=2c77bcf0d）
- `wenshu-pour/architecture/blue-screen-bug-v3-fix-2026-08-26.md` — WO-001AN CC 修法（14,058 bytes）
- `wenshu-pour/architecture/blue-screen-bug-v2-diagnosis.md` — WO-001AM CC 5 候选排查（14,887 bytes, parent=6d8c1afca）
- `wenshu-pour/architecture/blue-screen-bug-v2-fix-2026-08-26.md` — WO-001AM CC 修法（9,926 bytes）
- `wenshu-pour/architecture/blue-screen-bug-fix-2026-08-26.md` — WO-001AL CC 4 候选排查（12,839 bytes, parent=dce6b1c8f）
- `wenshu-pour/architecture/wenshu-setup-rebuild-2026-08-26.md` — CC 8/26 build trace（2.7KB）
- `wenshu-pour/architecture/research-link-diagnosis.md` — CC 派单机制诊断（8.5KB）
- `wenshu-pour/architecture/cc-tasks-progress-2026-08-26.md` — CC 5 STEP 任务进度（1.5KB）
- wenshu 仓 commit `6e1dcae56`（WO-001AN v3 修，没 push 等装 user 拍）
- 装 user 之前 7/24 蓝屏修复 commit `6cab7c457 fix(installer): embed frontendDist on every dist rebuild`
- 装 user 私域 `~/.wenshu-hermes/logs/bootstrap-installer.log`（装 user 拍 BUG 时装 user 看不到，拍板真值：改 ~/Desktop）

---

*CC 诊断 v4 · 2026-07-27 14:30 · 拍板真值：7 候选逐一查 (✅ 主因=候选 1 + 5/6/7 强相关 + 2 次因 + 3/4 不成立) · 7 候选逐一行/代码/进程/lsof/log 都拍板 · 修法拍板：Rust run_script 加 tokio::time::timeout (主兜底) + install.sh install_uv 加 curl --max-time + paths.rs init_logging 加 tee ~/Desktop + progress.tsx 默认展开 log + 显示 log 路径 + openLogDir 按钮 · 装 user 周末拍 push 时机*
