# powershell.rs::run_script() hard timeout 修法 (WO-001AR STEP 2)

> 工单:WO-001AR(装机 user 8/27 LOOP 拍板,白名单扩展 v5 根治 STEP 2)
> 执行器:CC(Claude Code CLI)
> 仓库:/Volumes/ANAN/Engineering/wenshu
> 真实根因出处:wenshu-pour/architecture/install-fail-exit-code-1-v5-diagnosis.md §1.2(v5 日志卡 23:49)

## 0. 拍板真值

派单 STEP 2 拍板:Tauri spawn shell 子进程加 30 分 timeout 兜底,解决 v4 BUG "卡 2:19 不超时"。

本次实际执行:
- 在 `apps/bootstrap-installer/src-tauri/src/powershell.rs` 加 `const SCRIPT_TIMEOUT: Duration = Duration::from_secs(1800);`
- `run_script()` 改成 outer wrapper,内层 body 抽到 `run_script_inner()`
- 用 `tokio::time::timeout(SCRIPT_TIMEOUT, run_script_inner(...))` 包整段执行
- 通过 `Arc<std::sync::Mutex<Option<Child>>>` 把 child handle 暴露给 outer,timeout 触发时 `child.start_kill()` best-effort
- 超时返回 `anyhow::bail!` 带清晰错误信息:"install script timed out after 1800 seconds — likely stuck on Astral/GitHub release download"

## 1. 为什么需要 30 分钟兜底

v5 诊断 §1.2 已经记录:`stage transition stage=prerequisites state=Failed duration_ms=Some(1429886)` = 23 分 49 秒。这就是 v4 修法(WO-001AO)漏掉的根因——v4 改的是 Rust resolver 层(下载 install.sh 本身 + UI 启动 fast-path),但失败发生在已经下载并执行的 shell 脚本内部,卡在 `install_uv()` 的 `sh "$_uv_installer"` 阶段——uv installer 自己内部 curl 没有 timeout,会一直挂着等 Astral release 或 GitHub fallback。

v5 日志显示两个 curl 错误:
- `curl: (18) Transferred a partial file` —— Astral release 部分传输
- `curl: (28) Failed to connect to github.com port 443 after 75016 ms` —— GitHub fallback 75 秒超时(uv installer 自己的)

理论上 uv installer 应该在第二个错误后立即退出,但实测它"exit 1"前的总耗时达到 23:49——可能是 uv installer 在内部 retry、clean up、log 输出等环节累计的耗时。**只要 Rust 层没有 outer timeout,UI 就会一直"卡 23+ 分钟无进展"**。

30 分钟 = 1800s 是拍板边界:
- 比 v5 实际耗时(23:49 = 1429s)高 26%,留余量给网络抖动
- 比装机 user 可接受的"卡 UI"上限(30 分钟)略低,符合"不要让用户等超过 30 分"的产品边界
- 对合法慢 stage 也够用:Python deps(600s)+ Node.js(可能 5-10 分)+ electron-builder(900s)+ 杂项 = 总共合理上限 ~25 分钟

## 2. 改前 / 改后

### 2.1 imports 块

```diff
 use anyhow::{Context, Result};
 use std::path::Path;
 use std::process::Stdio;
+use std::sync::{Arc, Mutex as StdMutex};
+use std::time::Duration;
 use tokio::io::{AsyncBufReadExt, BufReader};
 use tokio::process::{Child, Command};
 use tokio::sync::mpsc;
+
+/// WO-001AR STEP 2: hard 30-min timeout for install.sh / install.ps1.
+/// Without this, the install script can hang for 23+ minutes on a stalled
+/// Astral/GitHub release download before v5 "exit code 1" surfaces, and the
+/// UI freezes with no visible progress. 30 minutes is generous enough for
+/// every legitimately slow stage (Python deps, Node.js, electron-builder)
+/// but cuts off any single network-bound stage that overruns its budget.
+const SCRIPT_TIMEOUT: Duration = Duration::from_secs(1800);
```

### 2.2 run_script() 改为 outer wrapper

```diff
-pub async fn run_script(
-    script_path: &Path,
-    args: &[String],
-    sink: StreamSink,
-    hermes_home_override: Option<&str>,
-    mut cancel_rx: Option<CancelRx>,
-) -> Result<ScriptResult> {
+/// Spawns install.ps1 / install.sh with the given args and streams output.
+///
+/// `hermes_home_override` propagates to the child as $HERMES_HOME so the
+/// install script writes to the same directory the installer is reading from.
+///
+/// WO-001AR STEP 2: the entire call is wrapped in [`SCRIPT_TIMEOUT`] so a
+/// stuck uv-installer download (v5 BUG, 23+ min hang) cannot freeze the UI
+/// indefinitely. On timeout we kill the child best-effort and return an
+/// error so the bootstrap stage reports "exit code 1" with a clear message
+/// instead of a silent 23-minute wait.
+pub async fn run_script(
+    script_path: &Path,
+    args: &[String],
+    sink: StreamSink,
+    hermes_home_override: Option<&str>,
+    cancel_rx: Option<CancelRx>,
+) -> Result<ScriptResult> {
+    // Shared child handle so the outer timeout can kill the inner process
+    // even after tokio::time::timeout drops the inner future.
+    let child_holder: Arc<StdMutex<Option<Child>>> = Arc::new(StdMutex::new(None));
+
+    let inner = run_script_inner(
+        script_path,
+        args,
+        sink,
+        hermes_home_override,
+        cancel_rx,
+        child_holder.clone(),
+    );
+
+    match tokio::time::timeout(SCRIPT_TIMEOUT, inner).await {
+        Ok(result) => result,
+        Err(_elapsed) => {
+            tracing::error!(
+                timeout_secs = SCRIPT_TIMEOUT.as_secs(),
+                "install script hard timeout — killing child (WO-001AR v5 兜底)"
+            );
+            if let Ok(mut guard) = child_holder.lock() {
+                if let Some(child) = guard.as_mut() {
+                    let _ = child.start_kill();
+                }
+            }
+            anyhow::bail!(
+                "install script timed out after {} seconds — likely stuck on Astral/GitHub release download",
+                SCRIPT_TIMEOUT.as_secs()
+            )
+        }
+    }
+}
+
+async fn run_script_inner(
+    script_path: &Path,
+    args: &[String],
+    sink: StreamSink,
+    hermes_home_override: Option<&str>,
+    mut cancel_rx: Option<CancelRx>,
+    child_holder: Arc<StdMutex<Option<Child>>>,
+) -> Result<ScriptResult> {
     let mut cmd = build_command(script_path, args);
     ...
     let mut child: Child = cmd.spawn()?;
     let stdout = child.stdout.take().expect("stdout was piped");
     let stderr = child.stderr.take().expect("stderr was piped");
+
+    // Register child for outer hard-timeout kill before entering the
+    // select loop. The holder is a std::sync::Mutex (not tokio) so the
+    // lock is held only briefly; the child lives inside the holder for
+    // the rest of this function and is taken back at the bottom for
+    // wait(). Cancels inside the loop also reach into the holder.
+    if let Ok(mut guard) = child_holder.lock() {
+        *guard = Some(child);
+    }
     ...
     loop {
         tokio::select! {
             ...
             _ = recv_cancel(&mut cancel_rx) => {
                 tracing::warn!("cancellation received — killing child");
                 killed = true;
-                let _ = child.start_kill();
+                // best-effort kill via shared holder; don't propagate errors
+                if let Ok(mut guard) = child_holder.lock() {
+                    if let Some(child) = guard.as_mut() {
+                        let _ = child.start_kill();
+                    }
+                }
                 break;
             }
         }
     }
     ...
-    let status = child.wait().await?;
+    // Take child back from the shared holder so we can wait() on it.
+    let mut child = child_holder
+        .lock()
+        .ok()
+        .and_then(|mut g| g.take())
+        .ok_or_else(|| anyhow::anyhow!("child handle missing from holder"))?;
+
+    let status = child.wait().await?;
     ...
 }
```

## 3. 设计要点解释

### 3.1 为什么用 `std::sync::Mutex` 而不是 `tokio::sync::Mutex`

`tokio::sync::Mutex` 的 `lock()` 是 `async` 的,在 hot path(`tokio::select!` loop)里调用会破坏 cancel 响应性。`std::sync::Mutex` 是 sync lock,只在 brief critical section(几行 assignment)里持有,不跨 await point,不会让 select loop 卡住。Child handle 的"读/写"都是几行的 assignment,完全适合 std::sync::Mutex。

### 3.2 为什么 child 不能简单 Clone

`tokio::process::Child` 没有 Clone 实现(底层是 process handle / fd,没法 dup)。所以 child 必须 move 进 holder,所有访问通过 `guard.as_mut()` 或 `g.take()` 间接做。

### 3.3 timeout 触发时 child 状态

当 `tokio::time::timeout` 返回 `Err(_elapsed)` 时,inner future 被 drop,`run_script_inner` 内部的 select loop 也停了。但 child 进程**还在 OS 里跑**(tokio drop Child 不会自动 kill,只会 leak)。所以 outer 必须显式 `child.start_kill()`。这是兜底的核心动作。

### 3.4 取消路径

原本 cancel 通过 `_ = recv_cancel(&mut cancel_rx)` 触发,直接 `child.start_kill()`。改完后 child 在 holder 里,所以 cancel 分支改成 `if let Ok(mut guard) = child_holder.lock() { if let Some(child) = guard.as_mut() { let _ = child.start_kill(); } }`。语义不变。

### 3.5 为什么 `mut sink` 被移除

第一次 commit 留下 `mut sink: StreamSink` warning(`sink.on_stdout_line(&l)` 是 Box<dyn Fn> 调用,不需要 mut sink)。rustc 提醒了,我去掉了。剩下唯一 warning 是 `install_script.rs:37:5 variant Bundled is never constructed`,这是原有 warning,不是 STEP 2 引入的。

## 4. 编译验证(派单 STEP 2 验)

```bash
cd apps/bootstrap-installer/src-tauri
cargo check --message-format=short
```

实际输出:

```text
warning: wenshu-setup@0.0.1: hermes-bootstrap: following branch main HEAD (no commit pin; set HERMES_BUILD_PIN_COMMIT for an immutable pin)
    Checking wenshu-setup v0.0.1 (/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri)
src/install_script.rs:37:5: warning: variant `Bundled` is never constructed
warning: `wenshu-setup` (lib) generated 1 warning
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 39.02s
```

退出码 0,耗时 39.02s(增量编译,首次编译 52.73s,见首次验证)。

唯一 warning 在 `install_script.rs:37`(`Bundled` variant never constructed)—— 这是上游 hermes-agent v0.19.0 仓库里就有的 warning,不属于本次 STEP 2 引入。STEP 2 自带的 `mut sink` warning 已经在重编译前修掉。

## 5. 没改的部分(派单边界外)

1. **`apps/bootstrap-installer/src-tauri/src/bootstrap.rs`** 没动 —— 派单白名单只列 `scripts/install.sh` / `powershell.rs` / `paths.rs` 三个文件。bootstrap.rs 是 stage orchestrator,不直接调 `tokio::time::timeout`。
2. **`apps/bootstrap-installer/src-tauri/src/install_script.rs`** 没动 —— resolver retry 已经覆盖 `scripts/install.sh` 下载(v4 修法),不需要再加 timeout。
3. **Windows 镜像 `scripts/install.ps1`** 没动 —— 派单白名单外。Windows 装机 user 验时如果有相同 BUG,WO-001AS 之后扩白名单再加 Invoke-WebRequest timeout。
4. **uv installer 自身的 release 下载逻辑** 没动 —— 这不是本仓代码,改不到。

## 6. AC2 验收

- ✅ CC 改 `apps/bootstrap-installer/src-tauri/src/powershell.rs` 加 `tokio::time::timeout(1800s)`
- ✅ 加 `SCRIPT_TIMEOUT = Duration::from_secs(1800)` 常量(有完整注释解释为什么 30 分钟)
- ✅ child 通过 `Arc<StdMutex<Option<Child>>>` 共享,timeout 触发时 `child.start_kill()` best-effort
- ✅ 原有 cancel 路径同步改造,语义不变
- ✅ `cargo check` exit 0,1 个原有 warning,0 个 STEP 2 新增 warning
- ✅ `run_script` 签名对外兼容(`mut cancel_rx` → `cancel_rx`,Rust 调用方不受影响—— receiver 本来就只需要可变借用做 `recv()`)

AC2 PASS。
