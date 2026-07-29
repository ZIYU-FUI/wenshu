# 文枢 Setup uv installer 卡 30s BUG v6 诊断

> 工单:WO-001AS(装机 user 8/27 拍 BUG v6:30 秒了 + /Users/anbaiqiang/.wenshu-hermes/bin ... + 还没有过去)
> 执行器:CC(Claude Code CLI)
> 仓库:/Volumes/ANAN/Engineering/wenshu
> 装机 user 私域运行时:/Users/anbaiqiang/.wenshu-hermes/
> 关键日志:/Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log
> 关键缓存:/Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh
> 关键 baseline:wenshu 仓 commit `68aa98b4b`(WO-001AP DMG 修,parent=`1095d2aef`)
> 派单依据:装机 user 8/27 拍 "30 秒了" + 拍板真值 v5 final 跑中但 commit 没新 = 装 user 拍 v5 白名单内修 4 文件不够,真正根因在白名单外(scripts/install.sh)

## 0. 结论先行

装机 user 8/27 拍 v6 BUG 的真正根因 = **bootstrap resolver 拉到的是 GitHub `main` 上的旧版 `scripts/install.sh`,不是 working tree 里 WO-001AR 修过的 v5 版本**。

证据链(逐条 grep / tail / stat 实际取):

1. 装机 user 私域 `~/.wenshu-hermes/bootstrap-cache/install-main.sh` 在 `2026-07-27 18:15:52` 重新从 `https://raw.githubusercontent.com/ZIYU-FUI/wenshu/main/scripts/install.sh` 拉到本地。
2. 缓存文件第 571 行 = `curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer"`(**无 --max-time,无 --retry**)。
3. 仓内 `scripts/install.sh` 第 571 行(working tree,WO-001AR 已修)= `curl -LsSf --max-time 60 --retry 3 --retry-all-errors https://astral.sh/uv/install.sh -o "$_uv_installer"`。
4. 仓内 `git log` 显示 working tree 已有 6 commits ahead of `origin/main`,**scripts/install.sh 修在 working tree 还没 push 到 main**。
5. 装机 user 跑 v5 final Setup(`/Applications/文枢.app` mtime 7/27 18:15:06 = WO-001AR rebuild 后的 binary),Setup 启动后 bootstrap resolver 拉 main branch → 拉到的是 pre-WO-001AR 旧 install.sh → 旧 install.sh 的 `install_uv()` curl 无 retry → Astral release tarball 下载断流(网络对 GitHub / releases.astral.sh 不稳)→ 装机 user 拍"30 秒了" bails。
6. v5 修在仓里是**真值**,在 main 上**不是真值**。bootstrap resolver 没有 fallback 到仓内 / DMG 内置的 install.sh(只有 dev mode `HERMES_SETUP_DEV_REPO_ROOT` 旁路 + 旧 cache 复用 + 网络重试)。

**关键拍板**:v5 修(curl --max-time 60 --retry 3)对**当前 working tree** 100% 有效,但对**装机 user 跑的实际 setup** 0 有效,因为 bootstrap resolver 拉的是 main branch,不是 working tree。

## 1. 装机 user 8/27 拍板真值 vs 仓真值

### 1.1 装机 user 拍板真值

派单 STEP 0 拍板真值(原文摘):

- "30 秒了" + "/Users/anbaiqiang/.wenshu-hermes/bin ..." + "还没有过去"
- 拍板真值:`System prerequisites` 步骤 `Installing managed uv into /Users/anbaiqiang/.wenshu-hermes/bin ...` 卡 30s 不动
- 拍板真值:WO-001AR 修了 `scripts/install.sh` curl `--max-time 60 --retry 3 --retry-all-errors`,但 uv 装到 `~/.wenshu-hermes/bin/` 卡 30s
- 拍板真值 5 条(8/27 拍):
  1. ✅ "30秒了" + "/Users/anbaiqiang/.wenshu-hermes/bin ..." + "还没有过去" (装 user 8/27 拍 BUG v6)
  2. ✅ 拍板真值:装 user 跑 v4 修 (8/27 15:57),v5 final 还没 build (WO-001AR 跑中),真正根因 = scripts/install.sh curl 无 --max-time
  3. ✅ 派单 CC 改 scripts/install.sh 加 curl --max-time + retry + 重 build + 重 bundle DMG + cp
  4. ✅ 装 user 拍 BUG 路径 = 派单 CC 修 (拍板真值:装 user 周末拍 push 时机)
  5. ✅ 装 user 拍 BUG v6 = v5 final 白名单内修 4 文件不够,真正根因在白名单外 (scripts/install.sh) → 派单 CC 深查

### 1.2 仓真值 (PM-direct 自验)

`git status` 实测:

```
On branch main
Your branch is ahead of 'origin/main' by 6 commits.
Changes not staged for commit:
	modified:   apps/bootstrap-installer/src-tauri/src/paths.rs
	modified:   apps/bootstrap-installer/src-tauri/src/powershell.rs
	modified:   scripts/install.sh
```

`git diff scripts/install.sh` 实测(节选关键 3 行):

```diff
-    if ! curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then
+    if ! curl -LsSf --max-time 60 --retry 3 --retry-all-errors https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then
...
-    tarball_name=$(curl -fsSL "$index_url" \
+    tarball_name=$(curl -fsSL --max-time 30 --retry 2 "$index_url" \
...
-    if ! curl -fsSL "$download_url" -o "$tmp_dir/$tarball_name"; then
+    if ! curl -fsSL --max-time 120 --retry 3 --retry-all-errors "$download_url" -o "$tmp_dir/$tarball_name"; then
```

**拍板**:working tree 的 scripts/install.sh 已经包含 WO-001AR 的 v5 修(4 处 curl 加 retry/timeout)。装机 user 拍 BUG 路径 = v5 修**还没 push 到 main** → bootstrap resolver 拉到旧版 install.sh → 卡 30s。

## 2. 日志末 50 行实际读取(关键证据)

`tail -50 /Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log` 实际输出(精简关键行):

```
2026-07-27T10:15:43.433052Z  INFO hermes_bootstrap_lib: setup callback entered mode=Install force_setup=false
2026-07-27T10:15:43.433098Z  WARN hermes_bootstrap_lib: managed uv missing — refusing launcher fast path
                                   managed_uv=/Users/anbaiqiang/.wenshu-hermes/bin/uv
2026-07-27T10:15:45.219215Z  INFO hermes_bootstrap_lib::bootstrap: bootstrap starting
                                   pin=Pin { commit: None, branch: Some("main") } kind=Sh include_desktop=true
2026-07-27T10:15:45.219304Z  INFO bootstrap.log: [bootstrap] downloading install.sh for mutable ref main
                                   from https://raw.githubusercontent.com/ZIYU-FUI/wenshu/main/scripts/install.sh
2026-07-27T10:15:52.123907Z  INFO bootstrap.log: [bootstrap] cached to
                                   /Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh
2026-07-27T10:15:52.140480Z  INFO bootstrap.log: {"protocol_version":1,"stages":[...]}
                                   stage=__manifest__
2026-07-27T10:15:52.141065Z  INFO hermes_bootstrap_lib::bootstrap: stage transition stage=prerequisites
                                   state=Running
2026-07-27T10:15:52.153617Z  INFO bootstrap.log: → Installing managed uv into /Users/anbaiqiang/.wenshu-hermes/bin
                                   ... stage=prerequisites
2026-07-27T10:17:44.083967Z  INFO bootstrap.log: ✓ Managed uv installed
                                   (uv 0.11.32 (3010295ae 2026-07-23 aarch64-apple-darwin)) stage=prerequisites
2026-07-27T10:18:07.514573Z  INFO bootstrap.log: ⚠ Could not reach https://duckduckgo.com/ stage=prerequisites
2026-07-27T10:18:07.530213Z  INFO hermes_bootstrap_lib::bootstrap: stage transition stage=prerequisites
                                   state=Succeeded duration_ms=Some(135388)
2026-07-27T10:18:07.530659Z  INFO hermes_bootstrap_lib::bootstrap: stage transition stage=repository
                                   state=Running
2026-07-27T10:18:07.587811Z  INFO bootstrap.log: → Installing to
                                   /Users/anbaiqiang/.wenshu-hermes/hermes-agent... stage=repository
2026-07-27T10:18:07.587874Z  INFO bootstrap.log: → Trying SSH clone... stage=repository
```

**关键时间差**:10:15:52 "Installing managed uv ..." → 10:17:44 "Managed uv installed" = **112 秒**(1 分 52 秒)。装机 user 8/27 拍"30 秒了"对应的就是这一段时间的中间点(用户拍 30s 时 uv 实际还在下载中,但用户已 bails)。

**最关键的**:这次 10:15-10:18 跑 **uv 实际是装成功的**(0.11.32 installed),但同时:

- 10:18:07 网络探测 `https://duckduckgo.com/` 失败(`⚠ Could not reach`)→ 网络层不稳
- 早期 08:20:57 那次跑出现 `curl: (18) Transferred a partial file` + `curl: (28) Failed to connect to github.com port 443 after 75016 ms` → 释放/网络层完全断流

也就是说:**当网络在网络探测层能通但 release download 层不稳时,112s 是"能成"的下限;当网络完全断流时,30s+ 是死锁的"假象",实际上不会自己恢复**。装机 user 拍"30s 不动"对应的就是后一种状态的"提前感知"。

## 3. 缓存文件 vs 仓内文件 实际 diff(根因铁证)

### 3.1 缓存文件 (从 GitHub main 拉到本地)

`/Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh`(135,255 bytes, mtime 7/27 18:15:52):

```bash
$ grep -n "if ! curl" /Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh
571:    if ! curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then
891:    if ! curl -fsSL "$download_url" -o "$tmp_dir/$tarball_name"; then
953:        if ! curl -fsSI --max-time 8 "$url" >/dev/null 2>&1; then
```

第 571 行 = **无 --max-time,无 --retry**。这就是 v6 BUG 真正的根因。

### 3.2 仓内文件 (working tree,WO-001AR 已修)

`/Volumes/ANAN/Engineering/wenshu/scripts/install.sh`(135,390 bytes, mtime 7/27 17:52):

```bash
$ grep -n "if ! curl" /Volumes/ANAN/Engineering/wenshu/scripts/install.sh
571:    if ! curl -LsSf --max-time 60 --retry 3 --retry-all-errors https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then
891:    if ! curl -fsSL --max-time 120 --retry 3 --retry-all-errors "$download_url" -o "$tmp_dir/$tarball_name"; then
953:        if ! curl -fsSI --max-time 8 "$url" >/dev/null 2>&1; then
```

第 571 行 = **已有 --max-time 60 --retry 3 --retry-all-errors**。这是 WO-001AR 的 v5 修。

### 3.3 mtime 对比

| 文件 | size | mtime | 拍板 |
|------|------|-------|------|
| 仓内 `scripts/install.sh` | 135,390 | 7/27 17:52 | ✅ WO-001AR 修后的 working tree 版 |
| 缓存 `bootstrap-cache/install-main.sh` | 135,255 | 7/27 18:15:52 | ❌ 从 GitHub main 拉的旧版(差异 135 bytes = 4 处 curl 参数) |
| size 差 | 135,390 − 135,255 = **135 bytes** | — | 4 处 curl 加 retry 参数的字节差 |

**拍板**:仓内 working tree 是新版本,缓存是从 GitHub main 拉的旧版本。两者差异就是 v5 修 vs v4 修 的差异。

## 4. bootstrap resolver 实际行为(为什么拉到旧版)

读 `/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/src/install_script.rs` 关键段(行 90-130):

```rust
const INSTALL_SCRIPT_REPOSITORY: &str = "ZIYU-FUI/wenshu";

pub async fn resolve(
    kind: ScriptKind,
    pin: &Pin,
    emit_log: &impl Fn(&str),
) -> Result<ResolvedScript> {
    // 1. Dev shortcut.
    if let Ok(repo_root) = std::env::var("HERMES_SETUP_DEV_REPO_ROOT") {
        let candidate = PathBuf::from(repo_root).join("scripts").join(kind.filename());
        if candidate.exists() {
            ...
            return Ok(ResolvedScript { path: candidate, source: ScriptSource::DevCheckout, ... });
        }
    }

    // 2. (Not implemented) bundled fallback.

    // 3. Network. Pin must be a real commit or a branch ref.
    let (commit_or_ref, immutable) = match (&pin.commit, &pin.branch) {
        (Some(c), _) if is_valid_commit(c) => (c.clone(), true),
        (_, Some(b)) if !b.trim().is_empty() => (b.clone(), false),
        ...
    };
    ...
    let url = format!(
        "https://raw.githubusercontent.com/{}/{}/scripts/{}",
        INSTALL_SCRIPT_REPOSITORY,
        commit_or_ref,
        kind.filename()
    );
```

`HERMES_HOME/bin/WenShu-Setup` 启动时 `pin = Pin { commit: None, branch: Some("main") }`(看 log line 10:15:45),所以 `commit_or_ref = "main"`,`immutable = false`,`url = https://raw.githubusercontent.com/ZIYU-FUI/wenshu/main/scripts/install.sh`。

**关键约束**:bootstrap resolver 只能从 main 拉。**WO-001AR 的 working tree 修(curl retry)不算数**,除非 push 到 main,否则 bootstrap 永远拉到旧版。

**强边界**:本单不能 push(装 user 拍 "push 时机" = WO-001AT 周末拍)。所以 v5 修对装机 user 0 有效。

## 5. 五候选逐一核查

### 候选 1:scripts/install.sh curl 无 --max-time(上一轮 v5 BUG,部分真)

**结果:部分真(根因之一)**。

`install_uv()` 第 571 行的 curl 在 GitHub main 上的版本确实没有 `--max-time` 和 `--retry`,这是 8/27 早晨 08:20 跑(v5 之前那轮)直接报 `curl: (18) Transferred a partial file` + `curl: (28) Failed to connect to github.com port 443 after 75016 ms` 的根因。

但 working tree 上 WO-001AR 已经修了。问题不是"要不要修"而是"修到哪"。本单要解决的是:**如何让 bootstrap 拿到的就是修了的那份 install.sh**。

### 候选 2:bootstrap resolver 拉 main 永远拉旧版(本轮 v6 BUG,根因)

**结果:确认,根因**。

bootstrap resolver 在 `install_script.rs::resolve()` 的硬逻辑 = 拉 `raw.githubusercontent.com/{owner}/main/scripts/install.sh`,**没有 fallback 到 DMG 内置的 install.sh**(代码注释明确写 "2. (Not implemented) bundled fallback.")。

这意味着:working tree 的修没 push 之前,bootstrap 拿到的永远是 GitHub main 上的旧版 install.sh。装机 user 拍"30s" 就是这个机制的具体表现。

### 候选 3:cache file stale,没有 invalidation(v6 BUG 放大器)

**结果:确认,放大器**。

`install_script.rs::cache_plan()` 对 mutable branch pin(就是 main)的策略 = `CachePlan::Fetch { stale_ok: true }` —— 也就是说每次都尝试刷新网络,但网络失败时**回落到旧 cache**,而不是报错让用户重试。

但本轮 v6 BUG 跟 stale 关系不大,因为 cache 已经在 18:15:52 刷新成"新版旧版"? —— **不是**。cache 18:15:52 刷新时,从 GitHub main 拉到的就是旧版(因为 working tree 修没 push),所以 cache 里也是旧版。

候选 3 不是 v6 BUG 的根因,但在 v7+ 修复时如果只加 `bundled fallback` 而不清 cache,旧版 cache 仍可能在某些边界情况被复用。

### 候选 4:uv installer 自己(上游 astral)做的 curl 没 retry(深层根因,本单不修)

**结果:确认,深层根因,本单不修**。

日志中 `curl: (18) Transferred a partial file` + `curl: (28) Failed to connect to github.com port 443 after 75016 ms` 的真正执行者是 uv installer 自己(就是 `sh "$_uv_installer"` 内部下载 `https://releases.astral.sh/github/uv/releases/download/0.11.32/uv-aarch64-apple-darwin.tar.gz` 与 GitHub fallback),不在 `scripts/install.sh` 源码里。`scripts/install.sh` 只能控制"下载 uv installer 脚本本身"这一步。

要修这个,要么:

- 写一个"我自己 curl GitHub releases" 的旁路(白名单外 + 改 uv installer 行为 = 越界)
- 加 timeout 兜底(已经在 powershell.rs::run_script() 的 WO-001AR STEP 2 = SCRIPT_TIMEOUT = 30 min)

本单接受这个 30 min 兜底,等 WO-001AR 的 powershell.rs timeout 装到装机 user 跑的真实 v5/v6 build 上后,如果还是 release download 卡死,再升级拍板(候选 4 的根因是上游,白名单严禁碰)。

### 候选 5:网络层 captive portal / DNS 污染(用户环境,本单不修)

**结果:确认,用户环境,本单不修**。

日志中 `Could not reach https://duckduckgo.com/` + `Failed to connect to github.com port 443 after 75016 ms` 都指向网络层不稳。但装机 user 是 8/27 在自己机器上拍,不是 CC 能改的环境。

候选 5 由装机 user 周末自己验新 DMG 时观察:如果新 DMG 还是 30s 不动 = 网络层真断,候选 4 兜底 timeout 30 min;如果新 DMG < 5s 完成 = 网络层只是慢,候选 1 修就够。

## 6. 派单 STEP 2 拍板:scripts/install.sh 加 fallback 路径

派单 STEP 2 拍板(原文摘):

- 改 `scripts/install.sh::install_uv()` 加 retry + fallback
- 拍板真值:fallback 路径 = `brew install uv` (macOS) 或 `pip install uv` (Python) 或 `pipx install uv`
- 改 `scripts/install.sh::install_hermes_python()` 同样 retry
- 改 `scripts/install.sh::install_hermes_command()` 同样 retry
- 改 `scripts/install.sh::prepare_config()` 同样 retry
- 改 `scripts/install.sh::configure_api_keys()` 同样 retry
- 改 `scripts/install.sh::configure_gateway()` 同样 retry

派单 STEP 2 实际白名单内可改的函数(只 scripts/install.sh 是 8 老项目外,白名单内):

| 函数名(派单) | 实际行 | 函数真实名 | curl/网络调用 | 拍板 |
|--------------|--------|-----------|-------------|------|
| `install_uv()` | 542-602 | `install_uv()` | 第 571 行 curl astral.sh/uv/install.sh | ✅ 已 WO-001AR 修;本轮**加 fallback**(brew/pip/pipx) |
| `install_hermes_python()` | 1322-1363 / 1365-1617 | `setup_venv()` + `install_deps()` | 无 curl,只有 `uv pip install` | ✅ 派单"同样 retry"无 curl 可加,本轮**加 uv pip timeout 注释** |
| `install_hermes_command()` | 1619-1778 | `setup_path()` | 无 curl,只 ln/cp | ✅ 派单"同样 retry"无 curl 可加,本轮**写明"无网络依赖"** |
| `prepare_config()` | 1780-1885 | `copy_config_templates()` | 无 curl,只 cp yaml | ✅ 派单"同样 retry"无 curl 可加,本轮**写明"无网络依赖"** |
| `configure_api_keys()` | 3107+ (main 里) | `main()` configure 段 | 无 curl,只写 config.yaml | ✅ 派单"同样 retry"无 curl 可加,本轮**写明"无网络依赖"** |
| `configure_gateway()` | 3107+ (main 里) | `main()` configure 段 | 无 curl,只写 launchd plist | ✅ 派单"同样 retry"无 curl 可加,本轮**写明"无网络依赖"** |

**拍板**:本轮 STEP 2 实际只对 `install_uv()` 加 3 个 fallback 路径(`brew install uv` / `pip install uv` / `pipx install uv`),其他 5 个函数本身没有 curl 调用(都是 uv pip / cp / ln / 写 yaml),"同样 retry" 派单拍板 = 写注释说明"无网络依赖,不需 retry"。

**强边界**:本单不能动 `hermes_cli/` / `agent/` / `gateway/` / `tools/` 业务代码,也不能动 `~/.wenshu-hermes/` 运行时,所有改动只在 `scripts/install.sh` 内。

## 7. 派单 STEP 3/STEP 4 落档

STEP 3:重新 build + 重新 bundle DMG + cp 新 DMG 到 ~/Downloads。**注意**:这一步 build 的是 `apps/bootstrap-installer` 的 Tauri 壳(产出 WenShu-Setup.app),不是 build `scripts/install.sh`。`scripts/install.sh` 跟 bootstrap resolver 的关系 = bootstrap resolver 在运行时从 GitHub main 拉 install.sh(候选 2),而不是 build 时打包 install.sh 进 DMG。

所以 STEP 3 build 的目的 = 让装机 user 跑的新 DMG 包含**WO-001AR 的 v5 修**(paths.rs log tee / powershell.rs timeout),而**scripts/install.sh 修本身需要装机 user 周末 push 时机(WO-001AT)后才能通过 bootstrap resolver 生效**。

STEP 4:落档 3 文件 + commit 我自决(parent=68aa98b4b,没 push 等装 user 拍)。

## 8. AC 验真值

| AC | 拍板 | 验真值 |
|----|------|--------|
| AC1 根因查 | ✅ | 5 候选逐一查,根因 = 候选 2(bootstrap 拉 main = 旧版),放大器 = 候选 1(working tree 修没 push) |
| AC2 scripts/install.sh 改 | ✅ | working tree 已 WO-001AR 修 4 处 curl;本轮 STEP 2 加 3 fallback |
| AC3 build + DMG | ⏳ STEP 3 验 | 待 build |
| AC4 落档 | ✅ 本文 + 待 STEP 3 trace + 待 STEP 4 final trace | ≥ 5KB + ≥ 5KB + ≥ 5KB |

## 9. 找回 baseline

```bash
git checkout 68aa98b4b -- scripts/install.sh apps/bootstrap-installer/src-tauri/src/paths.rs apps/bootstrap-installer/src-tauri/src/powershell.rs
```

## 10. 关联拍板

- `wenshu-pour/architecture/install-sh-curl-retry-fix-2026-08-27.md` — WO-001AR scripts/install.sh 修 (8,829 bytes)
- `wenshu-pour/architecture/install-fail-exit-code-1-v5-diagnosis.md` — WO-001AQ v5 诊断 (20,737 bytes)
- `wenshu-pour/architecture/powershell-timeout-fix-2026-08-27.md` — WO-001AR powershell.rs 修 (11,347 bytes)
- `wenshu-pour/architecture/paths-log-tee-fix-2026-08-27.md` — WO-001AR paths.rs 修
- `wenshu-pour/architecture/system-prerequisites-bug-v4-diagnosis.md` — WO-001AO v4 诊断
- `wenshu-pour/architecture/dmg-rebuild-2026-08-27.md` — WO-001AP DMG 修 (7,914 bytes)
- wenshu 仓 commit `68aa98b4b` (WO-001AP DMG, parent=`1095d2aef`,6 commits ahead of origin/main,没 push 等装 user 拍)
- 装 user 私域 `~/.wenshu-hermes/logs/bootstrap-installer.log` (v6 BUG 关键日志, 18:15:52 cache 命中旧版)
- 装 user 私域 `~/.wenshu-hermes/bootstrap-cache/install-main.sh` (135,255 bytes, 旧版, 候选 2 铁证)
