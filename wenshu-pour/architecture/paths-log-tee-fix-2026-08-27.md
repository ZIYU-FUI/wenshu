# paths.rs::init_logging() Desktop log tee 修法 (WO-001AR STEP 3)

> 工单:WO-001AR(装机 user 8/27 LOOP 拍板,白名单扩展 v5 根治 STEP 3)
> 执行器:CC(Claude Code CLI)
> 仓库:/Volumes/ANAN/Engineering/wenshu
> 装机 user 拍板真值:log 在 `~/.wenshu-hermes/logs/bootstrap-installer.log` = 装 user 看不到,
> 改 tee 到 `~/Desktop/` 装 user 看到

## 0. 拍板真值

派单 STEP 3 拍板:修 `apps/bootstrap-installer/src-tauri/src/paths.rs::init_logging()`,
在保留原 v5 路径(`~/.wenshu-hermes/logs/bootstrap-installer.log`)的基础上,
加一个 tee 到 `~/Desktop/bootstrap-installer.log`,让装机 user 在 Finder 里直接看到日志。

本次实际执行:
- `init_logging()` 返回类型从 `Option<WorkerGuard>` 改成 `Option<CompositeGuard>`
- 新增 `CompositeGuard { desktop: Option<WorkerGuard>, primary: WorkerGuard }` — drop 顺序 desktop → primary(保证 Desktop 文件先 flush)
- 新增 `TeeWriter` (实现 `io::Write` + `tracing_subscriber::fmt::MakeWriter<'a>`)
- 新增 `desktop_log_path()` helper — 当 `~/Desktop/` 不存在(headless macOS / 删了 Desktop 文件夹)时返回 None
- Desktop 文件 tee 是 best-effort:开文件失败时 fallback 到 v5 单 sink 行为,不破坏主流程

## 1. 为什么需要 Desktop tee

v5 诊断 §1.2 显示失败日志写在 `~/.wenshu-hermes/logs/bootstrap-installer.log`,装机 user 8/27 拍 "log 在 ~/.wenshu-hermes/logs/bootstrap-installer.log = 装 user 看不到"。原因:

1. `~/.wenshu-hermes/` 是隐藏目录(macOS Finder 默认不显示 `.*` 文件夹);
2. 装机 user 在 BUG 反馈时需要快速访问日志,但要靠终端 `ls -la` 才能看到;
3. macOS Finder 默认 `~/Desktop/` 是用户最熟悉的位置,Finder "前往 → 桌面" 直接可达;
4. v5 BUG 的 exit code 1 信息无法告诉装机 user "去哪个文件看细节",把日志放到 Desktop 让装机 user 直接双击 `bootstrap-installer.log` 就能用 Console.app / TextEdit 打开。

## 2. 改前 / 改后

### 2.1 imports 块

```diff
+use std::io;
 use std::path::{Path, PathBuf};
 #[cfg(target_os = "macos")]
 use std::process::Command;
-use tracing_appender::non_blocking::WorkerGuard;
+use tracing_appender::non_blocking::{NonBlocking, WorkerGuard};
```

### 2.2 init_logging() 主体

```diff
-pub fn init_logging() -> Option<WorkerGuard> {
+pub fn init_logging() -> Option<CompositeGuard> {
     let dir = log_dir();
     if let Err(err) = std::fs::create_dir_all(&dir) {
         eprintln!("[hermes-setup] could not create log dir {dir:?}: {err}");
         return None;
     }

+    // Primary sink: ~/.wenshu-hermes/logs/bootstrap-installer.log (v5 path).
     let log_appender = tracing_appender::rolling::never(&dir, "bootstrap-installer.log");
-    let (non_blocking, guard) = tracing_appender::non_blocking(file_appender);
+    let (primary_nb, primary_guard) = tracing_appender::non_blocking(log_appender);

     let env_filter = tracing_subscriber::EnvFilter::try_from_env("HERMES_BOOTSTRAP_LOG")
         .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info"));

-    tracing_subscriber::fmt()
-        .with_env_filter(env_filter)
-        .with_writer(non_blocking)
-        .with_ansi(false)
-        .with_target(true)
-        .init();
+    // Desktop mirror: best-effort. If Desktop is missing, fall through to
+    // single-sink (preserves v5 behaviour when macOS Finder default location
+    // is unavailable).
+    if let Some(desktop_path) = desktop_log_path() {
+        match std::fs::OpenOptions::new().create(true).append(true).open(&desktop_path) {
+            Ok(desktop_file) => {
+                let (desktop_nb, desktop_guard) = tracing_appender::non_blocking(desktop_file);
+                tracing_subscriber::fmt()
+                    .with_env_filter(env_filter)
+                    .with_writer(TeeWriter::tee(primary_nb.clone(), desktop_nb))
+                    .with_ansi(false)
+                    .with_target(true)
+                    .init();
+                tracing::info!(
+                    desktop_log = %desktop_path.display(),
+                    "WO-001AR STEP 3: tee bootstrap-installer.log to Desktop"
+                );
+                return Some(CompositeGuard {
+                    desktop: Some(desktop_guard),  // drop first
+                    primary: primary_guard,         // drop second
+                });
+            }
+            Err(err) => {
+                eprintln!("[hermes-setup] could not open Desktop log {desktop_path:?}: {err} (falling back to single-sink)");
+            }
+        }
+    }
 
-    Some(guard)
+    // Single-sink fallback (v5 behaviour).
+    tracing_subscriber::fmt()
+        .with_env_filter(env_filter)
+        .with_writer(primary_nb)
+        .with_ansi(false)
+        .with_target(true)
+        .init();
+
+    Some(CompositeGuard {
+        desktop: None,
+        primary: primary_guard,
+    })
 }
```

### 2.3 新增 helpers

```rust
fn desktop_log_path() -> Option<PathBuf> {
    let home = dirs::home_dir()?;
    let desktop_dir = home.join("Desktop");
    if !desktop_dir.is_dir() {
        return None;
    }
    Some(desktop_dir.join("bootstrap-installer.log"))
}

#[allow(dead_code)] // fields owned + dropped via Drop, never explicitly read
pub struct CompositeGuard {
    desktop: Option<WorkerGuard>,
    primary: WorkerGuard,
}

struct TeeWriter {
    primary: NonBlocking,
    desktop: Option<NonBlocking>,
}

impl TeeWriter {
    fn tee(primary: NonBlocking, desktop: NonBlocking) -> Self {
        Self { primary, desktop: Some(desktop) }
    }
}

impl<'a> tracing_subscriber::fmt::MakeWriter<'a> for TeeWriter {
    type Writer = TeeWriter;
    fn make_writer(&'a self) -> TeeWriter {
        TeeWriter {
            primary: self.primary.clone(),
            desktop: self.desktop.clone(),
        }
    }
}

impl io::Write for TeeWriter {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        let _ = self.primary.write(buf);
        if let Some(d) = self.desktop.as_mut() {
            let _ = d.write(buf);
        }
        Ok(buf.len())
    }
    fn flush(&mut self) -> io::Result<()> {
        let _ = self.primary.flush();
        if let Some(d) = self.desktop.as_mut() {
            let _ = d.flush();
        }
        Ok(())
    }
}
```

## 3. 设计要点

### 3.1 为什么返回 `CompositeGuard` 而不是 `WorkerGuard`

`WorkerGuard` 只 flush 单个 NonBlocking 的 background thread。如果原签名返回 `WorkerGuard`,我只能 leak 第二个 guard 或者用 unsafe trick。返回 `CompositeGuard` 是干净的 RAII 做法——两个 guard 都在同一个 struct 里,Drop 顺序由 field 声明顺序决定(逆序)。

### 3.2 Drop 顺序:desktop 先,primary 后

字段声明是 `desktop: Option<WorkerGuard>, primary: WorkerGuard`。Rust struct drop 是逆序——先 drop `primary`?

让我再查 Rust drop order 规则——实际上 Rust struct drop 是 field declaration order:**first-declared first dropped**。

所以 `CompositeGuard { desktop: ..., primary: ... }` 是:
1. 整个 CompositeGuard scope 结束
2. drop call CompositeGuard::drop() (默认 no-op)
3. 然后 drop 每个 field in **declaration order**: first `desktop`, then `primary`

不对,我错了——Rust struct field drop 是按 declaration order(first-declared first),不是 reverse。让我重读:

> When a struct is dropped, its fields are dropped in declaration order.

确认: declaration order = first dropped first。

所以 `CompositeGuard { desktop: ..., primary: ... }`:
1. drop desktop WorkerGuard (flushes desktop background thread, joins)
2. drop primary WorkerGuard (flushes primary background thread, joins)

这就是我要的顺序——Desktop 先 flush,primary 后 flush。如果 primary 先 flush,desktop log 可能没写完(因为 desktop 的 background thread 还在跑)。

### 3.3 `TeeWriter` 用 `io::Write` + `MakeWriter` impl

`tracing_appender::non_blocking::NonBlocking` 本身实现 MakeWriter。我没有重新实现 writer,而是写一个 TeeWriter 把每个 log line write 两次(到 primary 和 desktop 的 NonBlocking channel)。

`NonBlocking` 是 Clone(从源码确认 `#[derive(Clone, Debug)]`),所以 `make_writer()` clone 出新 TeeWriter 实例,每个 log line 独立 enqueue 到两个 channel。

### 3.4 best-effort: Desktop 不可用时不破坏主流程

`desktop_log_path()` 在 `~/Desktop` 不存在时返回 None,`init_logging()` 直接走 single-sink 分支。`OpenOptions::open()` 失败时也走 single-sink 分支 + stderr warning。

### 3.5 caller 兼容性

`apps/bootstrap-installer/src-tauri/src/lib.rs:99` 是:
```rust
let _guard = paths::init_logging();
```

这是 `let _guard`,Rust 类型推断会自动用 `Option<CompositeGuard>`,不需要 caller 改任何东西。`_guard` 的下划线前缀意味着"不在乎类型细节"。当 lib.rs::run() 退出时,_guard drop 触发 CompositeGuard::drop() → desktop WorkerGuard drop(flush+join) → primary WorkerGuard drop(flush+join)。

## 4. 编译验证(派单 STEP 3 验)

```bash
cd apps/bootstrap-installer/src-tauri
cargo check --message-format=short
```

实际输出(清理 dedup + private fields 之后):

```text
warning: wenshu-setup@0.0.1: hermes-bootstrap: following branch main HEAD (no commit pin; set HERMES_BUILD_PIN_COMMIT for an immutable pin)
    Checking wenshu-setup v0.0.1 (/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri)
src/install_script.rs:37:5: warning: variant `Bundled` is never constructed
warning: `wenshu-setup` (lib) generated 1 warning
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 40.48s
```

退出码 0,耗时 40.48s(增量编译)。只剩 1 个 warning(`install_script.rs:37` Bundled variant),是上游 hermes-agent v0.19.0 仓库里就有的,与 STEP 3 无关。

第一次 `cargo check` 失败的原因与修复:
- 第一次 fail: `TeeWriter` 没实现 `MakeWriter` → 加 impl
- 第二次 fail: `fields desktop/primary never read` warning → 改 private + `#[allow(dead_code)]`
- 第三次 fail(无关): 我重复加了一份 CompositeGuard doc comment,清理后 0 warning

## 5. 没改的部分(派单边界外)

1. **`apps/bootstrap-installer/src-tauri/src/lib.rs`** 没动 —— caller 只用 `let _guard`,类型推断自动适配新签名。
2. **`log_path()` / `log_dir()` / `get_log_path()` Tauri command** 没动 —— 仍然返回 `~/.wenshu-hermes/logs/bootstrap-installer.log`,这是 contract。如果将来想暴露 Desktop 路径,可以加 `get_desktop_log_path()` command,但派单 STEP 3 不要求。
3. **`open_log_dir()` Tauri command** 没动 —— 仍然打开 `~/.wenshu-hermes/logs/`,不会自动跳到 Desktop。

## 6. AC3 验收

- ✅ CC 改 `apps/bootstrap-installer/src-tauri/src/paths.rs::init_logging()` 加 tee 到 `~/Desktop/bootstrap-installer.log`
- ✅ 保留 v5 路径 `~/.wenshu-hermes/logs/bootstrap-installer.log`(primary sink)
- ✅ Desktop 不可用时 fallback 到 single-sink(best-effort,不破坏主流程)
- ✅ `CompositeGuard` drop 顺序:desktop 先 flush,primary 后 flush
- ✅ `cargo check` exit 0,1 个原有 warning,0 个 STEP 3 新 warning
- ✅ caller `lib.rs:99` 无需改动(类型推断自动适配)

AC3 PASS。
