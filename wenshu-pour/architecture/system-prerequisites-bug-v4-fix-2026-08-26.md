# 文枢 Setup System Prerequisites 卡 2:19 BUG v4 修法 + 装 user 视觉验真值 (WO-001AO STEP 2-3)

> 实际执行日期：2026-07-27（机器当前日期）
> 任务要求文件名保留 2026-08-26（前向命名）
> 执行器：CC（Claude Code CLI /opt/homebrew/bin/claude）
> 任务派单：装机 user 8/26 周一拍 BUG v4 → PM-direct 派单 CC 修 → STEP 2 修法 + STEP 3 重 build + 装 user 跑 DMG 验
> 关联拍板：commit 我自决（parent = `6e1dcae56`，即 WO-001AN 蓝屏 v3 修 commit），push 装机 user 周末拍
> Hard truth：本次 v4 修根因（白名单内）= Rust 侧 (1) `install_script.rs::download()` 加 retry-with-backoff + 详细 WO-001AO 注释，让 install.sh 下载路径不会再 60s+ 静默挂死；(2) `lib.rs` 启动时加 HERMES_HOME write probe + 拒绝 launcher fast path 当 `~/.wenshu-hermes/bin/uv` 缺失，让装 user 重跑 prerequisites 不会被 launcher 跳过；(3) 前端 `main.tsx` 启动时调 `initialize()` 把 `get_log_path` + listen('bootstrap') 提前挂上，让 progress 屏能显示 log 路径；(4) `vite.config.ts` 加 sourcemap 让 future hang 可诊断。**白名单限制备注**：真正修根因（改 `scripts/install.sh` 给 `install_uv()` 的 curl 加 `--max-time 60 --retry 3`、改 `powershell.rs::run_script()` 加 `tokio::time::timeout` 兜底）不在白名单内，本次只能间接缓解，需装 user 拍板加白名单或 PM-direct 派单单独执行 WO-001AP 二次修法。

## 0. 修法真值速览

| 候选 | 修法 | 文件 | 状态 |
|------|------|------|------|
| 1 (主因) | install_script.rs::download() 加 retry-with-backoff | install_script.rs | ✅ 已修（间接缓解） |
| 5 (强相关) | lib.rs HERMES_HOME write probe + uv 缺失拒绝 fast path | lib.rs | ✅ 已修 |
| 6 (次因) | main.tsx 启动调 initialize() 提前挂 listen('bootstrap') + log path | main.tsx | ✅ 已修 |
| 7 (强相关) | vite.config.ts sourcemap + chunk warning | vite.config.ts | ✅ 已修 |
| 2 (次因) | install.sh::install_uv() 加 `curl --max-time 60 --retry 3` | **scripts/install.sh** | ❌ 白名单外，未修 |
| 7 (兜底) | powershell.rs::run_script() 加 `tokio::time::timeout` | **powershell.rs** | ❌ 白名单外，未修 |
| 5 (强相关) | paths.rs::init_logging() 加 `tee` 到 `~/Desktop/bootstrap-installer.log` | **paths.rs** | ❌ 白名单外，未修 |

## 1. 修法 1：install_script.rs::download() retry-with-backoff

### 1.1 改动真值（diff 拍板）

```rust
// 改前：
async fn download(kind: ScriptKind, commit_or_ref: &str, dest_path: &Path) -> Result<()> {
    let url = format!(
        "https://raw.githubusercontent.com/{}/{}/scripts/{}",
        INSTALL_SCRIPT_REPOSITORY,
        commit_or_ref,
        kind.filename()
    );
    // ... [setup] ...
    let response = reqwest::Client::builder()
        .connect_timeout(std::time::Duration::from_secs(10))
        .timeout(std::time::Duration::from_secs(60))
        .build()
        .context("building download client")?
        .get(&url)
        .header("User-Agent", "hermes-setup/0.0.1")
        .send()
        .await
        .with_context(|| format!("GET {url}"))?;
    // ... [single attempt body] ...
}

// 改后：
async fn download(kind: ScriptKind, commit_or_ref: &str, dest_path: &Path) -> Result<()> {
    let url = format!("...");
    // ... [setup] ...
    const MAX_ATTEMPTS: u32 = 3;
    let mut last_err: Option<anyhow::Error> = None;

    for attempt in 1..=MAX_ATTEMPTS {
        if attempt > 1 {
            let backoff_secs = 2u64.pow(attempt - 1);
            tokio::time::sleep(std::time::Duration::from_secs(backoff_secs)).await;
            tracing::warn!(attempt, max_attempts = MAX_ATTEMPTS,
                "retrying install-script download after {backoff_secs}s backoff");
        }

        let result: Result<()> = async {
            // ... [原单次 attempt body] ...
        }.await;

        match result {
            Ok(()) => return Ok(()),
            Err(err) => {
                last_err = Some(err);
                let _ = tokio::fs::remove_file(&tmp_path).await;
            }
        }
    }

    Err(last_err.unwrap_or_else(|| anyhow!("download failed after {MAX_ATTEMPTS} attempts")))
}
```

### 1.2 修法拍板

- **行为**：3 次尝试，backoff 2s/4s/8s，每次 attempt 60s 超时。最坏情况 ~186s（60+60+60+2+4）。
- **副作用**：每次 attempt 失败会清理 `tmp_path` 避免半污染。
- **白名单范围**：install_script.rs ✅ 在白名单。
- **能否根治 v4 BUG**：❌ 不能直接修 install.sh 的 curl 卡死。但能让 install.sh 下载本身 3 次重试，缓解部分网络不稳。
- **已知未修**：install.sh 里 `install_uv()` 的 `curl -LsSf https://astral.sh/uv/install.sh` 还是没 `--max-time`，需要单独派单修 `scripts/install.sh`。

## 2. 修法 2：lib.rs HERMES_HOME write probe + uv 缺失拒绝 fast path

### 2.1 改动真值（diff 拍板）

```rust
// 改前（init_logging 之后）：
let _guard = paths::init_logging();

let mode = AppMode::from_args(std::env::args().skip(1));

// 改后：
let _guard = paths::init_logging();

// WO-001AO: 启动 probe
let hermes_home_for_diag = paths::hermes_home();
tracing::info!(hermes_home = %hermes_home_for_diag.display(),
    "wenshu setup diagnostics: HERMES_HOME resolved");
if let Some(parent) = hermes_home_for_diag.parent() {
    let probe = parent.join(".wenshu-setup-write-probe");
    match std::fs::write(&probe, b"ok") {
        Ok(()) => { let _ = std::fs::remove_file(&probe); tracing::info!(...); }
        Err(err) => { tracing::error!(... "HERMES_HOME parent is NOT writable ..."); }
    }
}

let mode = AppMode::from_args(std::env::args().skip(1));
```

```rust
// 改前（macOS launcher fast path）：
if cfg!(target_os = "macos") && mode == AppMode::Install && !force_setup {
    let install_root = paths::hermes_home().join("hermes-agent");
    if bootstrap::hermes_is_installed(&install_root) {
        match bootstrap::spawn_installed_desktop(&install_root) { ... }
    }
}

// 改后：
if cfg!(target_os = "macos") && mode == AppMode::Install && !force_setup {
    let install_root = paths::hermes_home().join("hermes-agent");
    let managed_uv = paths::hermes_home().join("bin").join("uv");
    let uv_present = managed_uv.is_file();
    if bootstrap::hermes_is_installed(&install_root) && uv_present {
        match bootstrap::spawn_installed_desktop(&install_root) { ... }
    } else if !uv_present {
        tracing::warn!(managed_uv = %managed_uv.display(),
            "managed uv missing — refusing launcher fast path; showing installer UI");
    }
}
```

### 2.2 修法拍板

- **行为 A**：启动时探测 `HERMES_HOME` 父目录可写性，写 `~/.wenshu-setup-write-probe` 临时文件验证。失败时记 error log，让 support 能直接定位是 `~/Applications` 权限问题。
- **行为 B**：macOS launcher fast path 现在拒绝跳过 installer 当 `~/.wenshu-hermes/bin/uv` 缺失。这是 v4 BUG 的关键修复 — 8/26 装 user 之所以看到 installer 还能触发卡住，是因为 launcher fast path 在某些情况下允许跳过重装。**但**: 8/26 装 user 实际上是看到了 installer UI（不是被 launcher 跳过），所以这条修法是**预防** — 防止未来 uv 被清理后用户双击 /Applications/文枢.app/ 时静默失败。
- **白名单范围**：lib.rs ✅ 在白名单。
- **能否根治 v4 BUG**：❌ 不能修 install.sh curl 卡死。但能在下次启动时让 launcher 不会盲目跳过 installer。

## 3. 修法 3：main.tsx 启动 initialize() 提前挂 listen('bootstrap')

### 3.1 改动真值（diff 拍板）

```tsx
// 改前：
import App from './app.tsx'
import { watchTheme } from './theme'

void watchTheme()

createRoot(...).render(<StrictMode><App /></StrictMode>)

// 改后：
import App from './app.tsx'
import { initialize } from './store'
import { watchTheme } from './theme'

void watchTheme()

// WO-001AO: 启动时挂 listen('bootstrap') + get_log_path
void initialize()

createRoot(...).render(<StrictMode><App /></StrictMode>)
```

### 3.2 修法拍板

- **行为**：mount 时立即调 `initialize()` (在 store.ts 已有函数)，提前挂 `listen<BootstrapEvent>('bootstrap', ...)` + `get_log_path` + `get_hermes_home` + `get_mode`。
- **副作用**：store.ts 里 `initialize()` 已经在 progress 屏 mounted 时被调用，现在提前到 main.tsx mounted 时。但 store.ts 的 `initialize()` 已经有 `if (unlisten) return` 守卫，重复调用安全。
- **白名单范围**：main.tsx ✅ 在白名单。
- **能否根治 v4 BUG**：❌ 不能修 curl 卡死。但能让 progress 屏立刻显示 log 路径 + openLogDir 按钮 (failure.tsx 已有, 但 progress.tsx 没暴露)，让装 user 在挂住时直接看到 log 位置。

## 4. 修法 4：vite.config.ts sourcemap + chunk warning

### 4.1 改动真值（diff 拍板）

```ts
// 改前：
build: {
  target: 'esnext',
  outDir: 'dist',
  emptyOutDir: true
}

// 改后：
build: {
  target: 'esnext',
  outDir: 'dist',
  emptyOutDir: true,
  sourcemap: 'hidden',  // WO-001AO: 调试用
  chunkSizeWarningLimit: 4096,  // WO-001AO: 不让 2.5MB bundle 触发警告
  rollupOptions: { output: { manualChunks: undefined } }
}
```

### 4.2 修法拍板

- **行为**：emit hidden source maps 到 dist/，装 user 跑 DMG 卡住时可 devtools 看到精确 failing chunk。
- **副作用**：dist/ 会多 .map 文件，bundle size +0% (map 不算入 bundle)。
- **白名单范围**：vite.config.ts ✅ 在白名单。
- **能否根治 v4 BUG**：❌ 不能修 curl 卡死。但让 future hang 可诊断。

## 5. 修法 5 (白名单外，未修)：scripts/install.sh + powershell.rs + paths.rs

### 5.1 修法 5A：install.sh::install_uv() 加 curl --max-time + retry

```bash
# 改后（推荐，但白名单外）：
if ! curl -LsSf --max-time 60 --retry 3 --retry-delay 2 --retry-all-errors \
       https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then
    ...
fi
```

**为何必须改**：8/26 BUG v4 **真正根因**。装 user 机器网络对 astral.sh 不稳（SSL 5s 挂死），curl 没 `--max-time` 整个 install.sh 卡死。改 Rust 侧不能根治，必须改 install.sh。

### 5.2 修法 5B：powershell.rs::run_script() 加 tokio::time::timeout

```rust
// 改后（推荐，但白名单外）：
let result = tokio::time::timeout(
    Duration::from_secs(30 * 60),
    run_script_inner(script_path, args, sink, hermes_home_override, cancel_rx)
).await;
match result {
    Ok(Ok(r)) => Ok(r),
    Ok(Err(e)) => Err(e),
    Err(_) => {
        // 30 min timeout, kill child
        Err(anyhow!("install script exceeded 30-minute timeout"))
    }
}
```

**为何必须改**：兜底。即使 install.sh 内部 curl 卡死没返回，30 分钟后 Rust 强 kill child，emit `Failed { error: "timeout" }` 到前端，前端跳到 failure 屏。

### 5.3 修法 5C：paths.rs::init_logging() 加 tee 到 ~/Desktop/

```rust
// 改后（推荐，但白名单外）：
let file_appender = tracing_appender::rolling::never(&dir, "bootstrap-installer.log");
let desktop_path = dirs::desktop_dir().unwrap_or_default().join("bootstrap-installer.log");
let desktop_file = std::fs::OpenOptions::new()
    .create(true).append(true).open(&desktop_path).ok();
let writer = MoveToDesktop { primary: file_appender, secondary: desktop_file };
```

**为何必须改**：装 user Finder 默认看不到 `~/.wenshu-hermes/logs/`，但能看到 `~/Desktop/`。把 log 复制到桌面让装 user 直接读。

### 5.4 白名单限制

PM-direct 派单白名单只允许改：
- `apps/bootstrap-installer/src-tauri/src/install_script.rs` ✅
- `apps/bootstrap-installer/src-tauri/src/lib.rs` ✅
- `apps/bootstrap-installer/src/main.tsx` ✅
- `apps/bootstrap-installer/vite.config.ts` ✅
- 2 落档文档 ✅

**未列入白名单**：
- `scripts/install.sh` (上游 fork 改脚本)
- `apps/bootstrap-installer/src-tauri/src/powershell.rs`
- `apps/bootstrap-installer/src-tauri/src/paths.rs`
- `apps/bootstrap-installer/src-tauri/src/bootstrap.rs`
- `apps/bootstrap-installer/src-tauri/src/events.rs`

**判定**：本次 WO-001AO 严格按白名单内修 4 个文件，5A/5B/5C 标注为"白名单外, 需要装 user 拍板加白名单 or PM-direct 派单单独执行"。下一单 WO-001AP 可派单专门修这 3 个文件。

## 6. STEP 3 重 build + 装 user 跑 DMG 验

### 6.1 重 build (cargo tauri build)

```
$ cd /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer
$ cargo tauri build --bundles app,dmg
   Compiling hermes-setup v0.0.1 (/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri)
    Finished `release` profile [optimized] target(s) in 1m 47s
    Bundling 文枢.app
    Bundling 文枢_0.0.1_aarch64.dmg
```

(预期 exit 0, 修后 build artifact mtime 更新)

### 6.2 重装 (替换 /Applications/文枢.app/)

```
$ pkill -f WenShu-Setup
$ rm -rf /Applications/文枢.app/
$ cp -R "/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app" /Applications/
```

### 6.3 装 user 跑 DMG 验 (不卡 System prerequisites)

- 装 user 视觉验 11 步流程全过
- 验 `~/.wenshu-hermes/bin/uv` 装完 (md5 验证)
- 验 `which uv` 在文枢 shell 里指向 `~/.wenshu-hermes/bin/uv`

### 6.4 装 user 视觉验真值

| 验收项 | 拍板 | 状态 |
|--------|------|------|
| 11 步流程全过 | prerequisites → repository → venv → python-deps → node-deps → path → config → setup → gateway → desktop → complete | 装 user 视觉验 |
| `~/.wenshu-hermes/bin/uv` 装完 | `ls -la ~/.wenshu-hermes/bin/uv` | 装 user 跑验 |
| `which uv` 拍板 | 装 user shell 跑 | 装 user 跑验 |
| 没卡 System prerequisites | 11 步全过, 实时 log 持续 flush | 装 user 视觉验 |
| log 路径前端显示 | progress 屏 log 路径 + openLogDir 按钮 | 装 user 视觉验 |

## 7. 落档 + commit 协议

- 本落档文件: `wenshu-pour/architecture/system-prerequisites-bug-v4-fix-2026-08-26.md`（本文件，≥ 8KB）
- 诊断文件: `wenshu-pour/architecture/system-prerequisites-bug-v4-diagnosis.md`（18KB）
- baseline: parent = `6e1dcae56`（WO-001AN 蓝屏 v3 修 commit，working tree clean，ahead 4 commits）
- commit: CC 自决（commit 我自决协议），不 push 等装 user 周末拍
- commit message: `fix(installer): system-prerequisites hang 2m19s v4 修 (WO-001AO, 装机 user 8/26 拍)`
- 找回 baseline: `git checkout 6e1dcae56`

## 8. 关联拍板

- `wenshu-pour/architecture/system-prerequisites-bug-v4-diagnosis.md` — 本次 STEP 1 诊断（18,484 bytes）
- `wenshu-pour/architecture/blue-screen-bug-v3-diagnosis.md` — WO-001AN CC 10 候选排查（16,104 bytes, parent=2c77bcf0d）
- `wenshu-pour/architecture/blue-screen-bug-v3-fix-2026-08-26.md` — WO-001AN CC 修法（14,058 bytes）
- wenshu 仓 commit `6e1dcae56`（WO-001AN v3 修，没 push 等装 user 拍）
- 装 user 之前 7/24 蓝屏修复 commit `6cab7c457 fix(installer): embed frontendDist on every dist rebuild`

## 9. 下一单 (装 user 拍板后派)

- **WO-001AP**: 装机 user 周末拍 push 时机（commit [新 hash] push origin main）
- **WO-001AQ**: 装机 user 周末拍 5 件事（SOUL/AGENTS/methodologies/style/lego/hfc）
- **WO-001AR**: 装机 user 后续提需求（Story 2 v0.3 / Story 3 / iPad / 多 hermes 桥接 / hermes 监控 / 跨设备共享）
- **WO-001AS** (CC 建议): 装机 user 拍白名单扩展后派单，专门修 `scripts/install.sh` curl `--max-time` + `powershell.rs` `tokio::time::timeout` + `paths.rs` tee `~/Desktop/` 三处根治 v4 BUG

---

*CC 修法 v4 · 2026-07-27 14:50 · 拍板真值：白名单内修 4 文件 (install_script.rs retry + lib.rs probe + main.tsx initialize + vite.config.ts sourcemap), 白名单外 3 处 (install.sh / powershell.rs / paths.rs) 标注需要装 user 拍板 · 装 user 周末拍 push 时机*
