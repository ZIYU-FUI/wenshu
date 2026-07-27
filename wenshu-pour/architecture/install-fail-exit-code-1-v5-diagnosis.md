# 文枢 Setup 安装未完成 / exit code 1 BUG v5 诊断

> 工单：WO-001AQ（装机 user 8/27 拍板的 v5 路径）
>
> 本次诊断执行器：CC（Claude Code CLI）。
>
> 仓库：`/Volumes/ANAN/Engineering/wenshu`。
>
> 装机 user 私域运行时：`/Users/anbaiqiang/.wenshu-hermes/`。
>
> 诊断日志：`/Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log`。
>
> 机器终端实际日期：2026-07-27；任务文件名按派单要求保留 v5 的日期语义。
>
> 本文只记录真实终端输出、源码核对和边界判断；没有修改 `~/.wenshu-hermes/`，没有修改 `scripts/install.sh`，没有启动或重跑装机用户的安装流程。

## 0. 结论先行

本次“安装未完成 + exit code 1”不是前端窗口启动失败，也不是 bootstrap resolver 下载 `install.sh` 失败。后端已经完成了 manifest 获取，并已经进入第 1 个运行时阶段 `prerequisites`。失败点是该阶段内部的 `install_uv()`：它试图下载并执行 Astral 的 uv 安装器，但网络传输中断。

日志中的失败链是完整且可定位的：

1. Setup 进程解析出 HERMES_HOME 为 `/Users/anbaiqiang/.wenshu-hermes`。
2. bootstrap resolver 成功从 `raw.githubusercontent.com` 下载当前 `main` 的 `scripts/install.sh`，并缓存为 `bootstrap-cache/install-main.sh`。
3. install.sh manifest 成功返回 11 个阶段。
4. 第一个阶段 `prerequisites` 开始运行，并输出“Installing managed uv ...”。
5. uv 安装器下载第一次报告 `curl: (18) Transferred a partial file`。
6. uv 安装器 fallback URL 又报告 `curl: (28) Failed to connect to github.com port 443 after 75016 ms: Couldn't connect to server`。
7. 脚本输出 `Failed to install uv`，随后输出 JSON：`{"ok":false,"stage":"prerequisites","skipped":false,"reason":"exit code 1"}`。
8. Rust bootstrap 层记录 `bootstrap FAILED stage=Some("prerequisites") error=exit code 1`。

因此 v5 的根因拍板为：**候选 1，`scripts/install.sh` 中 `install_uv()` 的外部网络下载失败处理不足；当前白名单内的 `install_script.rs` resolver retry 只覆盖“下载 install.sh 本身”，没有覆盖 install.sh 内部再下载 uv 的请求。**

这也解释了为什么 WO-001AO 的 Rust/UI 侧 v4 修不能消除 v5 的 exit code 1：v4 修改善了入口日志、resolver 下载边界、启动 fast-path 和前端诊断，但实际失败发生在已经下载并执行的 shell 脚本内部。根因修复需要触及脚本本身，或在脚本执行层增加真实的 uv bootstrap fallback；当前派单明确把 `scripts/install.sh` 和 `powershell.rs` 列在 Out，不能在本单越界改动。

## 1. 装机 user BUG 路径与日志真值

### 1.1 用户拍板路径

派单给出的用户路径是：WO-001AP 在 8/27 15:57 重 bundle DMG，并 cp 新 DMG；装机 user 使用 v4 修后的最新 Setup；用户看到“安装未完成”和“exit code 1”，并提供日志路径 `~/.wenshu-hermes/logs/bootstrap-installer.log`。

本次只能核对当前 CC 可读取到的装机 user 私域日志，不把 PM-direct 自家运行当成装机 user 视觉验收，也不把本地 shell 的环境当成 DMG 运行时环境。日志中确实出现了 Setup 的首次运行轨迹和后续失败轨迹，且失败 JSON 的 stage 是 `prerequisites`。

### 1.2 日志末 50 行（实际读取）

以下为本次 `tail -50 /Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log` 的实际关键尾部，保留了时间、stage、网络错误和最终 exit code：

```text
2026-07-27T07:57:05.779155Z  INFO hermes_bootstrap_lib::bootstrap: bootstrap starting pin=Pin { commit: None, branch: Some("main") } kind=Sh include_desktop=true
2026-07-27T07:57:05.781314Z  INFO bootstrap.log: [bootstrap] downloading install.sh for mutable ref main from https://raw.githubusercontent.com/ZIYU-FUI/wenshu/main/scripts/install.sh
2026-07-27T07:57:07.928750Z  INFO bootstrap.log: [bootstrap] cached to /Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh
2026-07-27T07:57:07.928791Z  INFO bootstrap.log: [bootstrap] script /Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh via downloaded
2026-07-27T07:57:07.943799Z  INFO hermes_bootstrap_lib::bootstrap: manifest received stage_count=11 names=["prerequisites", "repository", "venv", "python-deps", "node-deps", "path", "config", "setup", "gateway", "desktop", "complete"]
2026-07-27T07:57:07.943826Z  INFO hermes_bootstrap_lib::bootstrap: stage transition stage=prerequisites state=Running duration_ms=None error=None
2026-07-27T07:57:07.951208Z  INFO bootstrap.log:  stage=prerequisites
2026-07-27T07:57:07.955131Z  INFO bootstrap.log: Detected: macos (macos) stage=prerequisites
2026-07-27T07:57:07.955213Z  INFO bootstrap.log: Installing managed uv into /Users/anbaiqiang/.wenshu-hermes/bin ... stage=prerequisites
2026-07-27T08:20:57.820826Z  INFO bootstrap.log: Failed to install uv stage=prerequisites
2026-07-27T08:20:57.821005Z  INFO bootstrap.log: Installer output: stage=prerequisites
2026-07-27T08:20:57.822524Z  WARN bootstrap.log: stderr:     downloading uv 0.11.32 aarch64-apple-darwin stage=prerequisites
2026-07-27T08:20:57.822690Z  WARN bootstrap.log: stderr:     curl: (18) Transferred a partial file stage=prerequisites
2026-07-27T08:20:57.822710Z  WARN bootstrap.log: stderr:     failed to download https://releases.astral.sh/github/uv/releases/download/0.11.32/uv-aarch64-apple-darwin.tar.gz stage=prerequisites
2026-07-27T08:20:57.822744Z  WARN bootstrap.log: stderr:     trying alternative download URL stage=prerequisites
2026-07-27T08:20:57.822764Z  WARN bootstrap.log: stderr:     curl: (28) Failed to connect to github.com port 443 after 75016 ms: Couldn't connect to server stage=prerequisites
2026-07-27T08:20:57.822774Z  WARN bootstrap.log: stderr:     failed to download https://github.com/astral-sh/uv/releases/download/0.11.32/uv-aarch64-apple-darwin.tar.gz stage=prerequisites
2026-07-27T08:20:57.822792Z  WARN bootstrap.log: stderr:     this may be a standard network error, but it may also indicate
2026-07-27T08:20:57.822831Z  WARN bootstrap.log: stderr:     that uv's release process is not working.
2026-07-27T08:20:57.822876Z  INFO bootstrap.log: Install manually: https://docs.astral.sh/uv/getting-started/installation/ stage=prerequisites
2026-07-27T08:20:57.831793Z  INFO bootstrap.log: {"ok":false,"stage":"prerequisites","skipped":false,"reason":"exit code 1"} stage=prerequisites
2026-07-27T08:20:57.834009Z ERROR hermes_bootstrap_lib::bootstrap: stage transition stage=prerequisites state=Failed duration_ms=Some(1429886) error=Some("exit code 1")
2026-07-27T08:20:57.834523Z ERROR hermes_bootstrap_lib::bootstrap: bootstrap FAILED stage=Some("prerequisites") error=exit code 1
```

日志真值有两个重要含义：

- `raw.githubusercontent.com` 的 install.sh 已经成功下载，所以不能把“resolver 下载脚本失败”当作本次主要根因。
- `manifest received` 后紧接 `stage=prerequisites`，最终失败 stage 仍然是 prerequisites，所以 repository、venv、python-deps、node-deps、path、config、setup、gateway、desktop、complete 都没有进入本次失败运行的后续执行位置。

### 1.3 前一次卡住轨迹与本次 exit 1 的关系

同一日志还保留了早先一次在 prerequisites 卡住的轨迹：先输出 `Installing managed uv into ...`，长时间没有后续输出。v5 这次日志比“无输出卡住”更进一步：网络调用最终退出并把 stderr 写入 bootstrap log，暴露了传输部分文件和 GitHub fallback 连接失败。两者是同一个阶段、同一条 uv 网络链路的两个表现，不是两个独立根因。

第一次日志记录了 `duration_ms=1429886`，约 23 分 49 秒；这不是 Python venv 的耗时，因为 venv 阶段尚未开始。当前安装器将 shell 子进程的阶段结果转成 JSON，因此用户界面最后看到的通用 “exit code 1” 是 prerequisites 对失败脚本的协议化结果，而不是具体网络错误本身。

## 2. 五个候选逐一核查

### 候选 1：scripts/install.sh 的 curl / GitHub release 网络失败

**结果：确认，根因。**

真实日志明确给出了两个底层网络错误：

- `curl: (18) Transferred a partial file`：Astral release 下载发生部分传输；
- `curl: (28) Failed to connect to github.com port 443 after 75016 ms: Couldn't connect to server`：uv 安装器的备用 GitHub 下载也无法建立连接。

仓库 `scripts/install.sh` 的源码核对结果如下。`install_uv()` 在第 542 行附近，managed uv 下载逻辑在第 571 行：

```bash
if ! curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then
    ...
    exit 1
fi
```

这段逻辑把“下载 uv 安装脚本”作为一个会直接退出的步骤。即使该脚本自身随后对 Astral release 和 GitHub release 有内部 fallback，v5 日志已经证明两个下载路径都在当前网络条件下失败。当前调用没有 `--max-time`、`--retry`、`--retry-all-errors` 或 brew/pip fallback，因此失败会表现为长时间等待后统一 exit 1。

本次按派单要求执行了：

```bash
bash -x scripts/install.sh 2>&1 | head -50
```

trace 的实际前 50 行确认了脚本启用 `set -e`、设置 `UV_NO_CONFIG=1`、解析默认参数并进入 `main`/banner；它还暴露了当前 CC shell 继承的 `HERMES_HOME=/Users/anbaiqiang/.hermes/profiles/my-pm`。由于命令按要求用 `head -50` 截断，并且直接运行不是装机 user 的 DMG 运行环境，trace 没有被误当成实际安装路径证据。实际 DMG 路径以 bootstrap log 为准，是 `/Users/anbaiqiang/.wenshu-hermes`。

本机网络 probe 也返回失败：

```text
curl -L https://astral.sh/uv/install.sh --max-time 30
curl: (35) LibreSSL SSL_connect: SSL_ERROR_SYSCALL in connection to astral.sh:443

curl -L https://raw.githubusercontent.com/ZIYU-FUI/wenshu/main/scripts/install.sh --max-time 30
curl: (35) LibreSSL SSL_connect: SSL_ERROR_SYSCALL in connection to raw.githubusercontent.com:443
```

这两个 probe 不是替代装机 user 日志的证据，但与日志中的传输中断/连接失败方向一致。

### 候选 2：Python venv 创建失败

**结果：未到达，排除为本次直接失败点；运行时产物不存在。**

核查命令：

```bash
ls -la /Users/anbaiqiang/.wenshu-hermes/venv
/Users/anbaiqiang/.wenshu-hermes/bin/uv --version
```

实际结果是：`venv` 目录不存在，`~/.wenshu-hermes/bin/uv` 不存在。这个状态不能解释成“venv 创建函数报错”：因为日志显示 prerequisites 在 uv 安装阶段就失败，venv stage 根本没有开始。缺失的 venv 是候选 1 失败后留下的后果/未完成状态，不是候选 2 的正向证据。

源码也与此顺序一致：`install.sh` 的 prerequisites 先调用 `install_uv()`，后续 Python 检查和 `setup_venv()` 才会使用 managed uv；没有 uv，流程不会进入 `uv venv venv --python 3.11`。

### 候选 3：Python dependencies 安装失败

**结果：未到达，排除为本次直接失败点；不存在可供列举的 venv pip。**

核查命令：

```bash
/Users/anbaiqiang/.wenshu-hermes/venv/bin/pip list
```

实际结果是该路径不存在。日志没有 `stage=venv state=Running`，也没有 `stage=python-deps state=Running`；最后失败 stage 是 prerequisites。因此没有任何证据表明 `uv pip install`、`pip install` 或 requirements resolver 已经执行。

### 候选 4：hermes 命令安装失败 / /usr/local/bin 权限

**结果：未到达；没有 `/usr/local/bin/hermes`，但 PATH 中发现的是本机另一个 hermes。**

核查结果：

```text
which hermes
/Users/anbaiqiang/.local/bin/hermes

ls -la /usr/local/bin/hermes
ls: /usr/local/bin/hermes: No such file or directory
```

`which hermes` 命中的 `/Users/anbaiqiang/.local/bin/hermes` 不属于本次文枢私域安装，不能作为文枢安装成功或失败的证据，也不能把它复制或复用到文枢环境。`/usr/local/bin/hermes` 不存在本身也不构成 permission denied；日志在 prerequisites 失败，path stage 没有开始。

### 候选 5：API keys / .env 写入失败

**结果：未到达；`.env` 尚未创建。**

核查命令：

```bash
ls -la /Users/anbaiqiang/.wenshu-hermes/.env
head -5 /Users/anbaiqiang/.wenshu-hermes/.env
```

实际结果是两个路径都报告不存在。日志没有进入 `setup` stage；该 stage 还需要用户输入，且排在 config、gateway 之后。不能把不存在的 `.env` 误写成“权限失败”，真实解释是流程在 prerequisites 失败后没有走到 API key 配置。

## 3. Rust 后端源码核对：当前白名单为什么挡不住根因

### 3.1 `install_script.rs` 的真实职责

`apps/bootstrap-installer/src-tauri/src/install_script.rs` 中存在的是 `resolve()`、`download()`、`cache_plan()` 等 resolver 函数，没有名为 `install_uv()` 的函数。该文件的 `download()` 负责下载 `scripts/install.sh` 或 `scripts/install.ps1`，当前实现有：

- reqwest connect timeout 10 秒；
- overall request timeout 60 秒；
- 3 次尝试；
- 2/4/8 秒退避；
- 临时文件失败清理；
- mutable branch 下载失败时允许 stale cache fallback。

这些机制只包住下面这个 URL：

```text
https://raw.githubusercontent.com/ZIYU-FUI/wenshu/main/scripts/install.sh
```

日志证明这一层成功了：`cached to .../bootstrap-cache/install-main.sh`。随后 Rust 把缓存脚本交给 shell 子进程执行。`install_script.rs` 没有执行 uv 下载，也没有能被调用的 `install_uv()` 入口。因此“修改 `install_script.rs::install_uv()`”与真实源码不一致，不能按这个不存在的符号编写代码。

文件现有注释还明确写着：当前 crate 的下载 timeout/retry 不能修复缓存 `install.sh` 内部的 `curl -LsSf https://astral.sh/uv/install.sh`；`install.sh` 是文枢 fork 的脚本，不在该 resolver 的代码职责内。这是源码层面对边界的直接佐证。

### 3.2 `lib.rs` 的真实职责

`apps/bootstrap-installer/src-tauri/src/lib.rs` 中存在 `run()`、`get_mode()`、`AppState` 和 Tauri command 注册；没有名为 `bootstrap_install()` 的函数。`run()` 做了这些事：

- 初始化 `~/.wenshu-hermes/logs/bootstrap-installer.log`；
- 记录 HERMES_HOME 及父目录写入 probe；
- 处理 macOS 已安装 fast-path；
- 注册 `bootstrap::start_bootstrap`、取消、状态及日志命令。

实际 bootstrap stage orchestration 在 `bootstrap.rs::run_bootstrap()`，脚本进程启动在 `powershell.rs::run_script()`。因此不能在不存在的 `lib.rs::bootstrap_install()` 位置添加 retry/fallback，也不能声称已经修复了 uv 下载。

### 3.3 子进程层的实际行为

`powershell.rs` 在 macOS/Linux 的 `build_command()` 中确实执行：

```rust
let mut cmd = Command::new("bash");
cmd.arg(script_path);
```

`run_script()` 设置 `HERMES_HOME`、捕获 stdout/stderr 并向 bootstrap log tee；它没有把 shell 内部的网络请求改写成带 retry 的 uv 下载。当前日志正是这一 tee 生效后的结果：install.sh 的 stderr 被记录为 `stderr: ...`，最后被 stage 协议包装为 `exit code 1`。

## 4. 系统进程日志与 UI 清理

按派单要求执行 `log show --predicate 'process == "WenShu-Setup"' --last 10m` 时，当前 shell 返回 `log: too many arguments`，说明未加绝对路径的 `log` 解析到了当前 shell 环境中的同名命令/包装，而不是 Apple `/usr/bin/log`。随后使用同一 predicate 调用 `/usr/bin/log show ...`，实际返回了 WenShu-Setup 的 WebKit MemoryPressure/PerformanceLogging 记录，证明 Setup UI 进程曾存在；输出没有改变 bootstrap log 对失败 stage 的结论。

按派单要求执行 `pkill -f WenShu-Setup`，命令返回非零；随后 `ps aux | grep WenShu-Setup` 只看到检查命令自身和当前 CC 命令，没有看到实际 WenShu-Setup 进程。结论是 bootstrap UI 已停止或当时已不存在；没有继续运行的安装进程需要清理。

这里的进程清理不等于重跑验收。没有执行 `open /Applications/文枢.app`，没有删除或覆盖 `/Applications/文枢.app`，没有触碰装机 user 私域目录。

## 5. 根因拍板与候选排除表

| 候选 | 日志/终端事实 | 判断 |
|---|---|---|
| 1. `install.sh` uv/GitHub curl | prerequisites 内出现 curl 18 partial file、curl 28 GitHub 443 connect failure，随后 failed uv / exit 1 | **确认根因** |
| 2. venv 创建 | venv 不存在，但 venv stage 未开始 | 未到达，不是直接根因 |
| 3. Python deps | venv pip 路径不存在，python-deps stage 未开始 | 未到达，不是直接根因 |
| 4. hermes command | `/usr/local/bin/hermes` 不存在；path stage 未开始；PATH 命中另一个本机 hermes | 未到达，不是直接根因 |
| 5. API keys | `~/.wenshu-hermes/.env` 不存在，setup stage 未开始 | 未到达，不是直接根因 |

最终拍板不是“网络可能有问题”这种模糊判断，而是：**安装失败发生在 prerequisites → install_uv → uv release 下载；第一个下载发生 partial transfer，第二个 GitHub fallback 连接超时，shell 以 exit 1 返回，Rust 将该结果原样上报。**

## 6. 修复建议与当前工单边界

真正修复至少要覆盖 uv bootstrap 的外部网络脆弱点：

1. 在 `scripts/install.sh` 的 `install_uv()` 为下载脚本和/或 release 下载增加明确连接/总时限；
2. 对可恢复的网络错误使用有限次数 retry，并清理 partial file；
3. 保留 Astral primary 与 GitHub fallback，但要使 fallback 也有边界；
4. 在 macOS 可用时评估 brew 或其他受支持安装路径作为 fallback；
5. 在脚本返回前把失败 URL、attempt、最终错误完整写入 bootstrap log；
6. 在脚本执行层（`powershell.rs`）为整个 stage 增加可观察的超时/取消语义，避免网络子进程长期占住 UI；
7. 重新 build、替换 DMG 后，必须由装机 user 在其机器/网络环境执行 Setup；CC 不能把自家环境成功当作用户视觉验收。

但本 WO 的 Out 明确禁止修改 `scripts/install.sh`、`powershell.rs`、`paths.rs`，并且白名单只允许修改 `install_script.rs`、`lib.rs` 等指定文件。源码核对又证明白名单中没有派单所写的 `install_uv()` / `bootstrap_install()`。在没有扩展白名单或改派 WO-001AT 前，任何“在 Rust resolver 中已加 fallback”的结论都会是假的：resolver 只能重试 install.sh 下载，不能修复 install.sh 内部的 Astral/GitHub 下载。

所以本诊断完成 AC1；AC2/AC3/AC4 的代码修复、重 build、重装、装机 user 视觉验收和 commit 不能在当前边界内诚实完成。建议按派单已列出的下一单 WO-001AT 扩展白名单后，修 `scripts/install.sh` + `powershell.rs` + `paths.rs`，再重新 bundle DMG。

## 7. 可追溯证据索引

- 用户日志尾部：`/Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log`，本次读取命令：`tail -50 ...`。
- 下载脚本源码：`scripts/install.sh`，`install_uv()` 位于约 542–603 行；失败下载命令约 571 行。
- resolver：`apps/bootstrap-installer/src-tauri/src/install_script.rs`，`resolve()`/`download()` 约 101–439 行；现有 retry 是 raw GitHub 脚本下载 retry。
- bootstrap orchestrator：`apps/bootstrap-installer/src-tauri/src/bootstrap.rs`，`run_bootstrap()` 约 341 行，脚本执行约 680–741 行。
- Unix 子进程入口：`apps/bootstrap-installer/src-tauri/src/powershell.rs`，`run_script()` 约 135 行，`build_command()` 约 293–302 行。
- Setup logging/path：`apps/bootstrap-installer/src-tauri/src/lib.rs` 与 `paths.rs`。
- 关联 v4 诊断：`wenshu-pour/architecture/system-prerequisites-bug-v4-diagnosis.md`，记录了同一 `install_uv()` 链路先前的长时间无输出表现。

## 8. 当前工作树与未完成项

本次 STEP 1 的排查没有改动源码，没有改动装机 user 私域，没有删除或覆盖应用，没有 git commit，也没有 git push。诊断文件是本次新增落档；后续需要 `git status` 验证它是唯一预期变更。

未完成项明确列出：

- 未修改根因代码：因为真实根因在当前 Out 的 `scripts/install.sh` 网络 bootstrap 链路，且指定 Rust 函数不存在；
- 未执行 `cargo tauri build`；
- 未重装 `/Applications/文枢.app`；
- 未执行装机 user DMG 视觉验收；
- 未获得“日志末 50 行 = install complete”；
- 未 commit，避免把未修复、未验收状态伪装成可交付修复。

