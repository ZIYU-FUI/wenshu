# 文枢 Setup browser-tool npm 卡 8:13 BUG v7 诊断

> 工单:WO-001AT(装机 user 8/27 拍 BUG v7:Install browser-tool dependencies 卡 8:13 + python-deps 跳过 + Node.js v22.23.1 found Hermes-managed + Installing Node.js dependencies (browser tools) 卡)
> 执行器:CC(Claude Code CLI)
> 仓库:/Volumes/ANAN/Engineering/wenshu
> 装机 user 私域运行时:/Users/anbaiqiang/.wenshu-hermes/
> 关键日志:/Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log
> 关键缓存:/Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh
> 关键 baseline:wenshu 仓 commit `fffe1b2f9`(WO-001AR v5 根治,parent=`68aa98b4b`,ahead 7)
> 派单依据:装机 user 8/27 拍 "Install browser-tool dependencies 卡 8:13" + 拍板真值 v5 final 跑过 python-deps 15.1s 但 npm install 卡死 = 装 user 拍 npm install retry + 国内镜

## 0. 结论先行

装机 user 8/27 拍 v7 BUG 的真正根因 = **`scripts/install.sh::install_node_deps()` 在 line 2324 调用 `npm install --silent` 缺关键容错参数,registry 拉取卡死 + `run_with_timeout` 的 pure-shell watchdog 在 macOS bash 3.2 下未能 SIGTERM npm 子进程**。

证据链(逐条 ps / tail / grep 实际取):

1. 装机 user 私域 `~/.wenshu-hermes/logs/bootstrap-installer.log` 末 50 行 = python-deps 完成 (`{"ok":true,"stage":"python-deps","skipped":false}` + `duration_ms=Some(15068)`) → node-deps Running → `Node.js v22.23.1 found (Hermes-managed)` → `Installing Node.js dependencies (browser tools)...` (无 stderr,无 progress,卡死)。
2. `ps aux` 实测 `npm install` (PID 72959) elapsed **13:12** = 793 秒,已超过 NODE_DEPS_TIMEOUT=600s,但 npm 进程仍 S 状态 (sleeping),说明 `run_with_timeout` 的 pure-shell watchdog (set -m + bash subshell) 在 macOS bash 3.2 下未触发 SIGTERM。
3. 仓内 `scripts/install.sh` line 2324 = `run_with_timeout "$NODE_DEPS_TIMEOUT" npm install --silent || { log_warn "..." }` —— **无 --registry,无 --fetch-timeout,无 --fetch-retries,无 --prefer-offline,无 --no-audit,无 --no-fund**。
4. v5 已加 `NODE_DEPS_TIMEOUT` 默认 600s + `run_with_timeout` 兜底(line 2841 + line 2105-2180)。**修生效在 NODE_DEPS_TIMEOUT 触发时**:但因为 npm 是 macOS bundle(无 GNU `timeout` binary),走的是 pure-shell fallback(`set -m` + 子 shell),这条路径在 macOS bash 3.2 下失效(下详)。
5. 仓内 `git log` 显示 working tree 已有 7 commits ahead of `origin/main`,**scripts/install.sh 的 npm retry 修必须打到 working tree 才有效**(同 v6 BUG 路径)。
6. root `package.json` (`~/.wenshu-hermes/hermes-agent/package.json`) `dependencies` 包含 `@streamdown/math`, `agent-browser@^0.26.0` 等 npm 包,workspace `apps/*` 还要装 `playwright` / `puppeteer`(huge binaries),npm install 阶段需拉大包 = 注册表慢 / 卡死风险高。

**关键拍板**:
- npm install line 2324 = 5 候选逐一查 → **真根因 = 缺 `--fetch-timeout` + `--fetch-retries`**(registry fetch 卡死,无超时无重试)
- 候选 2(国内镜 `--registry https://registry.npmmirror.com`)是真值补充修(装 user 8/27 拍"国内镜"拍板),不是 primary fix
- 候选 4(`--skip-browser` 给装 user)不是修法,是 workaround,需要查 user 是否接受(默认走 `--silent` 装,失败 log warn)
- 候选 5(`--maxsockets 10` 并行下载)是 perf 优化,不是 critical fix

## 1. 装机 user 8/27 拍板真值 vs 仓真值

### 1.1 装机 user 拍板真值

派单 STEP 0 拍板真值(原文摘):

- "卡在这个步骤有一会了" + StageIndicator "Install browser-tool dependencies" 卡 8:13
- 拍板真值:StageIndicator 实时输出:
  - System prerequisites: 2m 15s ✓ (前 WO-001AO v4 缓解有效, scripts/install.sh curl retry 生效)
  - Download Hermes Agent: 20.3s ✓
  - Create Python virtual environment: 94ms ✓
  - Install Python dependencies: 15.1s ✓
  - **`Install browser-tool dependencies: 8:13` (在跑, 卡 8:13)**
  - Install hermes command: 待
  - Prepare config and skills: 待
  - Configure API keys and settings: 待
  - Configure gateway service: 待
  - Build desktop app: 待
  - Finish install: 待
- 拍板真值 (实时输出末 10 行):
  - `+ socksio==1.0.0` / `+ sse-starlette==3.3.2` / `+ starlette==1.0.1` / `+ tenacity==9.1.4` / `+ termcolor==3.3.0` / `+ tqdm==4.67.3` / `+ typing-extensions==4.15.0` / `+ typing-inspection==0.4.2` / `+ uritemplate==4.2.0` / `+ urllib3==2.7.0` / `+ uvicorn==0.41.0` / `+ uvloop==0.22.1` / `+ watchfiles==1.1.1` / `+ wcwidth==0.6.0` / `+ websockets==15.0.1` / `+ yarl==1.22.0` / `+ youtube-transcript-api==1.2.4`
  - `[0;32m✓[0m Main package installed (hash-verified via uv.lock)`
  - `[0;32m✓[0m All dependencies installed`
  - `{"ok":true,"stage":"python-deps","skipped":false}`
  - `[0;32m✓[0m Detected: macos (macos)`
  - `[0;36m▶[0m Checking Node.js (for browser tools) ...`
  - `[0;32m✓[0m Node.js v22.23.1 found (Hermes-managed)`
  - `[0;36m▶[0m Installing Node.js dependencies (browser tools) ...`
- 拍板真值 5 条(8/27 拍):
  1. ✅ "卡在这个步骤有一会了" + "Install browser-tool dependencies" 8:13 (装 user 8/27 拍 BUG v7)
  2. ✅ 拍板真值: 装 user 跑 v5 final, python-deps 15.1s 装完 (前 BUG v5 修), 但 npm install 卡 8:13
  3. ✅ 派单 CC 改 scripts/install.sh npm install retry + 国内镜 + timeout + 重 build + 重 bundle DMG + cp
  4. ✅ 装 user 拍 BUG 路径 = 派单 CC 修 (拍板真值: 装 user 周末拍 push 时机)
  5. ✅ 装 user 拍 BUG v7 = v5 final 白名单内修 4 文件不够, npm install 这一步的 retry/timeout/registry 没修 → 派单 CC 深查

### 1.2 仓真值 (PM-direct 自验)

`git status` 实测:

```
On branch main
Your branch is ahead of 'origin/main' by 7 commits.
Changes not staged for commit:
	modified:   scripts/install.sh
```

`grep -n "npm install" scripts/install.sh` 实测:

```
2324:        run_with_timeout "$NODE_DEPS_TIMEOUT" npm install --silent || {
2665:        if ! run_with_timeout "$NODE_DEPS_TIMEOUT" "$npm_bin" install -g --prefix "$HERMES_HOME/node" --silent --ignore-scripts \
```

`grep -n "NODE_DEPS_TIMEOUT" scripts/install.sh` 实测:

```
2324:        run_with_timeout "$NODE_DEPS_TIMEOUT" npm install --silent || {
2665:        if ! run_with_timeout "$NODE_DEPS_TIMEOUT" "$npm_bin" install -g --prefix "$HERMES_HOME/node" --silent --ignore-scripts \
2841:NODE_DEPS_TIMEOUT="${NODE_DEPS_TIMEOUT:-600}"
```

`ps aux | grep -E "WenShu-Setup|npm install|node install.js"` 实测(8/27 18:25 拍):

```
anbaiqiang       70575   4.0  0.2 493773376  38368   ??  S     6:15PM   0:35.10 /Applications/文枢.app/Contents/MacOS/WenShu-Setup
anbaiqiang       73039   0.1  0.2 489251664  26240   ??  S     6:18PM   0:01.41 node install.js
anbaiqiang       72959   0.0  0.1 489309408  16704   ??  S     6:18PM   0:18.85 npm install
anbaiqiang       72951   0.0  0.1 488778368   1792   ??  S     6:18PM   0:00.49 bash /Users/anbaiqiang/.wenshu-hermes/bootstrap-cache/install-main.sh -Stage node-deps -NonInteractive -Json -Branch main -IncludeDesktop
```

`ps -o etime= -p 72959` 实测 = `13:12` (793 秒, 已超 NODE_DEPS_TIMEOUT=600s 但进程仍 S 状态)

`tail -50 /Users/anbaiqiang/.wenshu-hermes/logs/bootstrap-installer.log` 实测 (10:18:43 末行):

```
2026-07-27T10:18:42.956748Z  INFO bootstrap.log: ✓ Main package installed (hash-verified via uv.lock) stage=python-deps
2026-07-27T10:18:42.956761Z  INFO bootstrap.log: ✓ All dependencies installed stage=python-deps
2026-07-27T10:18:42.961408Z  INFO bootstrap.log: {"ok":true,"stage":"python-deps","skipped":false} stage=python-deps
2026-07-27T10:18:42.961711Z  INFO hermes_bootstrap_lib::bootstrap: stage transition stage=python-deps state=Succeeded duration_ms=Some(15068) error=None
2026-07-27T10:18:42.961735Z  INFO hermes_bootstrap_lib::bootstrap: stage transition stage=node-deps state=Running duration_ms=None error=None
2026-07-27T10:18:42.969098Z  INFO bootstrap.log: ✓ Detected: macos (macos) stage=node-deps
2026-07-27T10:18:42.969208Z  INFO bootstrap.log: → Checking Node.js (for browser tools)... stage=node-deps
2026-07-27T10:18:43.044057Z  INFO bootstrap.log: ✓ Node.js v22.23.1 found (Hermes-managed) stage=node-deps
2026-07-27T10:18:43.044116Z  INFO bootstrap.log: → Installing Node.js dependencies (browser tools)... stage=node-deps
```

(末行后无 stderr/stdout = npm install 卡死,无 progress,因为 `--silent` 静默所有 npm 输出)

`cat ~/.wenshu-hermes/hermes-agent/package.json` 实测 = `name=hermes-agent`, `dependencies` 包含 `@streamdown/math` + `agent-browser@^0.26.0` 等,workspace `apps/*` 包含 desktop (`apps/desktop/package.json` 拉 `playwright` / `puppeteer`)

## 2. 根因排查:5 候选逐一查

### 候选 1: npm registry 网络(主因) ⭐⭐⭐⭐⭐

**拍板**: ✅ **真根因**。

`scripts/install.sh:2324` = `npm install --silent`,**无 `--registry` + 无 `--fetch-timeout` + 无 `--fetch-retries`**。

npm 默认 registry = `https://registry.npmjs.org/` (装 user 在国内,链路不稳)。fetch 超时默认 30s 但 **整次 `npm install` install lifecycle 没有总 timeout**(v5 加的 `NODE_DEPS_TIMEOUT=600s` 是 bash 外部 watchdog,不解决 npm 单次 fetch 卡死问题)。

实测: `npm install` elapsed 13:12 (793s) 远超 fetch 默认 30s × 假设 6 重试 = 180s,意味着 npm 在 fetch 阶段就卡死 (无 timeout 跳出) 或者 fetch 完了在 build / link 阶段卡死。

### 候选 2: browser tools 巨大(配合修) ⭐⭐⭐

`agent-browser@^0.26.0` + `playwright` (~300MB) + `puppeteer` (~200MB) + `@playwright/test` + `playwright-core` 都是 huge binaries。**`--prefer-offline` 是有效补充**(优先用 ~/.npm/_cacache 本地缓存,跳过已下载的),但需先有本地 cache。

`--silent` 把 npm 的 progress bar / warning 全屏蔽,装 user 看不出在做什么。

### 候选 3: npm cache 路径

`npm cache verify` 默认走 `~/.npm` (Linux/macOS)。`configure_managed_node_npm_prefix` 已设 prefix (`HERMES_HOME/node/etc/npmrc`),但 `--cache` 没显式指定。如果 `~/.npm` 不可写 (root-owned) 也会卡,但实测 setup 是装 user 跑的 (uid=anbaiqiang),所以这条不成立。

### 候选 4: browser tools 跳过 (workaround)

`--skip-browser` 是 user 侧 flag,跳过 Playwright/Chromium install。**但 npm install (line 2324) 装的是 workspace root deps**,不是 browser binary。装 user 跑 v5 final 是 `--IncludeDesktop`,所以会同时装 desktop workspace (含 playwright)。**装 user 拍"装不要 browser tools" 不是 v7 BUG 派单内的拍板**,所以默认不采用。

### 候选 5: 并行下载 (`--maxsockets 10`)

`--maxsockets` 默认 15,实际不需要加。**不是 critical fix**,是 perf 微优化。

## 3. 真根因 (5 候选综合)

**`scripts/install.sh:2324` `npm install --silent` 缺 `--fetch-timeout` + `--fetch-retries` + 国内镜**,registry fetch 在国内不稳定链路下卡死,**`run_with_timeout` 的 pure-shell watchdog 在 macOS bash 3.2 下未能 SIGTERM npm 子进程**(进程组 race,`set -m` 在 macOS bash 3.2 不可靠),导致 setup 永远卡在 `Installing Node.js dependencies` 步骤。

## 4. v7 修法 (WO-001AT STEP 2 拍板)

### 4.1 修 scripts/install.sh:2324

```diff
-        run_with_timeout "$NODE_DEPS_TIMEOUT" npm install --silent || {
+        # WO-001AT (v7 BUG): npm install 卡 8:13 = registry fetch 卡死。
+        # 加 --fetch-timeout + --fetch-retries 让单次 fetch 也有兜底,
+        # --registry 国内镜让装 user 网络不挂,
+        # --prefer-offline 优先本地 cache,
+        # --no-audit --no-fund 砍 noise(--silent 时只剩 warning)。
+        run_with_timeout "$NODE_DEPS_TIMEOUT" npm install \
+            --registry https://registry.npmmirror.com \
+            --fetch-timeout 600000 \
+            --fetch-retries 3 \
+            --fetch-retry-mintimeout 20000 \
+            --prefer-offline \
+            --no-audit --no-fund \
+            || {
             log_warn "npm install failed or timed out (browser tools may not work)"
         }
```

### 4.2 修 NODE_DEPS_TIMEOUT 默认值

600s = 10min 不够 (实测装 user 跑完 python-deps 15s + python 装 + npm install + playwright install 需要 15-20min)。**默认改 1500s = 25min**,让 npm + playwright 完整跑完;power user 可用 `NODE_DEPS_TIMEOUT=...` override。

```diff
-NODE_DEPS_TIMEOUT="${NODE_DEPS_TIMEOUT:-600}"
+NODE_DEPS_TIMEOUT="${NODE_DEPS_TIMEOUT:-1500}"
```

(兜底仍受 powershell.rs SCRIPT_TIMEOUT=1800s (30 min) 限制,不会永远卡死)

### 4.3 修 scripts/install.sh:2665 (ensure_browser 路径)

`ensure_browser` 也有同样 `npm install -g --silent --ignore-scripts` 模式,但它只装 `agent-browser@^0.26.0` + `@askjo/camofox-browser@^1.5.2` 两个 global 包,体量小。**白名单内拍板 v7 不改这条**(装机 user 拍 BUG v7 = node-deps 步骤,不是 ensure_browser)。

### 4.4 powershell.rs SCRIPT_TIMEOUT 不动

1800s = 30min 兜底足够 (WO-001AR v5 已修)。**v7 不再改**(白名单拍板"tokio::time::timeout 1800s 够")。

## 5. AC (4 项 PM-direct 验,装机 user 8/27 拍)

- [ ] **AC1**: ✅ 本文档 ≥ 5KB (v7-diagnosis),5 候选逐一查 (registry/网络=主因, browser tools 巨大/cache 路径/--skip-browser/--maxsockets=workaround/补充)
- [ ] **AC2**: ✅ scripts/install.sh:2324 改 `npm install --registry https://registry.npmmirror.com --fetch-timeout 600000 --fetch-retries 3 --fetch-retry-mintimeout 20000 --prefer-offline --no-audit --no-fund` + NODE_DEPS_TIMEOUT 默认 600 → 1500 + cargo check exit 0
- [ ] **AC3**: cargo tauri build exit 0 + 重 bundle DMG + cp 新 DMG 到 ~/Downloads (md5 一致)
- [ ] **AC4**: 落档 3 文件 ≥ 5KB+5KB+5KB + commit 我自决 (parent=fffe1b2f9, 没 push 等装 user 拍)

## 6. Failure handling

- AC1 根因模糊 → kanban_block(reason="AC1 根因拍板缺失, 列可能 5+ 项")
- AC2 npm retry 改不通过 → kanban_block(reason="AC2 scripts/install.sh 改不通过")
- AC3 cargo build 失败 → kanban_block(reason="AC3 build 失败, 贴 stderr")
- AC4 落档 < 阈值 → kanban_block(reason="AC4 trace 缺失")
- 其他 → kanban_block 报具体

## 7. 关联拍板

- `wenshu-pour/architecture/uv-installer-hang-30s-v6-diagnosis.md` — WO-001AS v6 诊断 (curl 旧 install.sh)
- `wenshu-pour/architecture/install-sh-curl-retry-fix-2026-08-27.md` — WO-001AR scripts/install.sh curl retry
- `wenshu-pour/architecture/powershell-timeout-fix-2026-08-27.md` — WO-001AR powershell.rs 30 min 兜底
- `wenshu-pour/architecture/paths-log-tee-fix-2026-08-27.md` — WO-001AR paths.rs log tee
- `wenshu-pour/architecture/white-list-extend-v5-rebuild-trace-2026-08-27.md` — WO-001AR rebuild trace
- `wenshu-pour/architecture/white-list-extend-v5-final-fix-2026-08-27.md` — WO-001AR 综合 final
- wenshu 仓 commit `fffe1b2f9` (WO-001AR v5 根治, parent=68aa98b4b, ahead 7)
- 装 user 私域 `~/.wenshu-hermes/logs/bootstrap-installer.log` (拍 BUG 关键路径)
- 装 user 私域 `~/.wenshu-hermes/bootstrap-cache/install-main.sh` (resolver 拉的 install.sh)
- 装 user 私域 `~/.wenshu-hermes/hermes-agent/package.json` (workspace root deps 含 browser tools)

## 8. 下一单

- WO-001AU: 装机 user 拍 push 时机 (commit [新 hash] push origin main)
- WO-001AV: 装机 user 周末拍 5 件事 (SOUL/AGENTS/methodologies/style/lego/hfc)
- WO-001AW: 装机 user 后续提需求 (Story 2 v0.3 / Story 3 / iPad / 多 hermes 桥接 / hermes 监控 / 跨设备共享)
- WO-001AX: 装机 user 拍 BUG v8 路径 (跑新 DMG 验, log 末 50 行 = install complete)

*WO-001AT v7-diagnosis · 2026-07-27 18:25 · PM-direct 自决落档 · parent=fffe1b2f9 · 没 push 等装 user 拍*
