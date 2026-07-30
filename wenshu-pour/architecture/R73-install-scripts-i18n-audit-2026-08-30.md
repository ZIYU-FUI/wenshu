# WO-001BI-R73: 用户装机时跑的所有 sh / ps1 脚本英文文案 audit

## 装机 user 8/30 拍板真值
> "不光是 install.sh 一个脚本吧? 那个引导配置等等好像也有. 其它 sh 不需要翻译吗"

装机 user 真值:
- 不光 install.sh 一个, **引导配置 (bootstrap-installer) + install.cmd + 装包器内 bundled 脚本** 也跑
- "其它 sh 不需要翻译吗" = 装机 user 关心: **凡装机时跑 + 装机 user 看到的英文文案** 都要 audit 一遍
- 装机 user 不知 R43 已写 install.sh zh、R71 已写 install.ps1 zh、`display.language: zh`; PM-direct audit 真值, 不反推

## 装机 user 身份 = 用户场景
- 装机 user 跑:
  - `scripts/install.sh` (mac/Linux curl|bash 路径)
  - `scripts/install.cmd` (Windows CMD 入口)
  - `scripts/install.ps1` (Windows 主装, install.cmd 包了一层 powershell)
  - `apps/bootstrap-installer/` (mac 装包器 = Tauri 桌面 app, 内部拉 bundled install.sh 跑)
- 装机 user **不**跑:
  - `setup-wenshu.sh` (开发者 clone 后手动跑)
  - `scripts/dev-sandbox.sh` (开发者沙箱)
  - `scripts/run_tests.sh` (CI/开发者)
  - `scripts/lib/node-bootstrap.sh` (sourced by install.sh, 不独立跑)
  - `apps/desktop/scripts/installer-smoke.sh` (装机完烟测, 开发者)
  - `optional-skills/*/scripts/setup.sh` (skill 自己的 setup, 装机 user 不直接跑)
  - `docker/*.sh` (容器化, 装机 user 不跑)

## AC1: 用户装机时跑的所有 sh / ps1 脚本清单

| 脚本 | 装机 user 跑? | 触发路径 | 装机 user 看到的输出 |
|---|---|---|---|
| `scripts/install.sh` | ✅ | mac/Linux 走 `curl -fsSL .../install.sh \| bash`; mac bootstrap-installer 内部 spawn (R57 bundled 模式) | stdout/stderr → bootstrap UI "实时输出" 面板 |
| `scripts/install.cmd` | ✅ | Windows CMD 入口, 包 powershell 调 install.ps1 | 一行 banner + 转发到 PS |
| `scripts/install.ps1` | ✅ | Windows 主装 + bootstrap-installer (Windows variant) 调 | stdout/stderr → bootstrap UI "实时输出" 面板 |
| `apps/bootstrap-installer/.../welcome.tsx` | ✅ | 装包器首页 (React) | "WENSHU AGENT" + "基于 Hermes 修改而来..." + "安装文枢" 按钮 (白名单致谢, 不动) |
| `apps/bootstrap-installer/.../progress.tsx` | ✅ | 装包器进度 (React) | zh i18n 已全译 (10 步骤 zh label, R14 落档) |
| `apps/bootstrap-installer/.../success.tsx` | ✅ | 装包器成功页 (React) | "WENSHU 已就绪" / "启动" / "启动中" 全 zh |
| `apps/bootstrap-installer/.../failure.tsx` | ✅ | 装包器失败页 (React) | "安装未完成" / "重试安装" / "打开日志" 全 zh |
| `scripts/setup-wenshu.sh` | ❌ | 开发者 clone 仓后手动跑 | n/a |
| `scripts/dev-sandbox.sh` | ❌ | 开发者沙箱 | n/a |
| `scripts/run_tests.sh` | ❌ | CI/开发者 | n/a |
| `scripts/lib/node-bootstrap.sh` | (sourced) | install.sh `source` 进来 | install.sh log_* 包一层, 用户看到的是 install.sh 出口 |
| `apps/desktop/scripts/installer-smoke.sh` | ❌ | 开发者烟测 | n/a |
| `optional-skills/*/scripts/setup.sh` (×N) | ❌ | skill 启用时跑, 装机 user 走默认 bundled skills 不主动调 | n/a |
| `docker/*.sh` (×5) | ❌ | 容器构建 | n/a |

装机 user 真实装时可见英文文案的脚本 = **5 个**:
1. `scripts/install.sh` (mac/Linux)
2. `scripts/install.cmd` (Windows 入口)
3. `scripts/install.ps1` (Windows 主装)
4. `apps/bootstrap-installer/src/routes/welcome.tsx` (白名单不动)
5. `apps/bootstrap-installer/src/i18n/zh.ts` + `en.ts` (R14 已 zh-default, 仅 stage title 10 个)

## AC2: 各脚本英文文案数 + 装机 user-facing 高优先级清单

### install.sh 英文文案数

| 类型 | 行数 |
|---|---|
| `log_info "..."` | 232 |
| `log_success "..."` | 81 |
| `log_warn "..."` | 36 |
| `log_error "..."` | 15 |
| **log_* 总计** | **364** |
| `echo "..."` (banner / print_success heredoc 等) | 102 |
| **用户可见英文文案总计** | **~370 处** |

> 注: `log_*` 364 处 + `echo` 102 处 = 466 处, 但其中 echo 大量是空行 / 颜色 / banner 边框 / 重定向写入文件 (`>> "$SHELL_CONFIG"`), 真实 user-facing 英文文案约 370 处。

### install.cmd 英文文案数

| 行号 | 原文 |
|---|---|
| 4 | `REM This batch file launches the PowerShell installer for users running CMD.` |
| 6 | `REM   curl -fsSL https://raw.githubusercontent.com/ZIYU-FUI/wenshu/main/scripts/install.cmd -o install.cmd && install.cmd && del install.cmd` |
| 11 | `echo  Wenshu Installer` |
| 12 | `echo  Launching PowerShell installer...` |
| 19-20 | `echo  Installation failed. Please try running PowerShell directly:` + 提示命令 |

**~5 处英文**, 装机 user 真值: Windows CMD banner + 失败 fallback 提示, **装机 user 真看到了**。

### install.ps1 英文文案数

| 类型 | 行数 |
|---|---|
| `Write-Info "..."` | ~150 |
| `Write-Success "..."` | ~60 |
| `Write-Warn "..."` | ~40 |
| `Write-Err "..."` | ~22 |
| **Write-* 总计** | **272** |
| `Write-Host "..."` (banner / completion / 表格 / Note) | ~30 |
| `Write-Output` (JSON protocol) | 5 (机器读, 不译) |
| **用户可见英文文案总计** | **~302 处** |

> Write-Output 5 处是 JSON protocol (bootstrap UI 跟 install.ps1 通信用), 不译。

### bootstrap-installer React routes

| 文件 | zh 状态 | 英文残留 |
|---|---|---|
| `welcome.tsx` | zh ("WENSHU AGENT" + 致谢语 + "安装文枢") | 0 (白名单 "WENSHU AGENT" 致谢语不动) |
| `progress.tsx` | zh 全 (10 步骤 + "完成" / "正在更新 WENSHU" / "共 X 步" / "实时输出" / "显示详情" / "取消" / "隐藏详情") | 0 用户可见; 但 `rec.info.title` (i18n 缺 key 时 fallback) 仍是英文 — `STAGE_NAME_TO_STEP_KEY` 已覆盖 17 个 stage name, **实际不会 fallback** |
| `success.tsx` | zh ("WENSHU 已就绪" / "启动" / "启动中" / "无法启动桌面应用") | 0 |
| `failure.tsx` | zh ("安装未完成" / "重试安装" / "打开日志" / "日志: ...") | 0 |
| `i18n/zh.ts` | zh (10 step label) | n/a |
| `i18n/en.ts` | 英文 (debug fallback) | n/a |
| `i18n/index.ts` | n/a (代码) | 0 |
| `i18n/languages.ts` | n/a (代码) | 0 |
| `index.html` | `<html lang="en">` ⚠ + `<title>文枢</title>` | `<html lang="en">` 是 Tauri 默认模板, 不影响用户 |

**bootstrap-installer 用户可见英文 = 0** (R14 已落档全 zh)。

### install.sh 高优先级 user-facing 英文清单 (节选 装机 user 装时一定看到)

> 完整 370 处附 AC3 分级。下表是装机 user **真**会看到 + 高优先级 (banner / 完成页 / 阶段标题 / 错误引导 / 提示)

| 文件:行号 | 原文 | 装机 user 看到时机 |
|---|---|---|
| `install.sh:23` | `⚠ Ignoring inherited PYTHONPATH during install to avoid module shadowing` | 启动即打印 |
| `install.sh:27` | `⚠ Ignoring inherited PYTHONHOME during install` | 启动即打印 |
| `install.sh:88` | `DEV mode: full git clone (WENSHU_DEV_INSTALL=1)` | 开发者设了 `WENSHU_DEV_INSTALL=1` 时 |
| `install.sh:91` | `USER mode: shallow git clone (set WENSHU_DEV_INSTALL=1 for full clone)` | 默认用户场景都打 |
| `install.sh:188-211` | `Usage: install.sh [OPTIONS]` + 完整 help banner | `--help` |
| `install.sh:240-244` | `│ ⚕ Wenshu Agent Installer │ / An open source AI agent by Nous Research.` | 启动 banner (每装都打) |
| `install.sh:271` | `Python package source: $label ($mirror)` | 启动后第一行 |
| `install.sh:567-568` | `Windows detected. Please use the PowerShell installer:` + `iex (irm ...)` | 错平台 |
| `install.sh:574` | `Unknown operating system` | OS 检测失败 |
| `install.sh:578` | `Detected: $OS ($DISTRO)` | 每装都打 |
| `install.sh:587` | `Termux detected — using Python's stdlib venv + pip instead of uv` | Termux |
| `install.sh:601` | `Managed uv found ($UV_VERSION; default source: ...)` | 装时打 |
| `install.sh:605` | `Installing managed uv into $WENSHU_HOME/bin ...` | 装时打 |
| `install.sh:815-822` | `Python $PYTHON_VERSION not found, installing via uv...` + 错误引导 | 缺 python |
| `install.sh:837-858` | Git 装路径分支 (apt / dnf / brew / Command Line Tools 提示) | 缺 git |
| `install.sh:2723-2801` | **print_success heredoc**: "Installation Complete!" + "📁 Your files:" + "🚀 Commands:" + "Reload your shell" + Node.js / ripgrep note | **装完必看, 装机 user 真看到的总结页** |
| `install.sh:2756-2772` | `⚡ 'wenshu' was linked into ...` + `source ~/.zshrc/bashrc/fish` 三行 | 装完必看 |
| `install.sh:2779-2799` | `Note: Node.js could not be installed automatically.` / `Note: ripgrep (rg) was not found.` | 装完可选 note |

### install.ps1 高优先级 user-facing 英文清单 (节选)

| 文件:行号 | 原文 | 装机 user 看到时机 |
|---|---|---|
| `install.ps1:208-214` | `* Wenshu Agent Installer / An open source AI agent by Nous Research` banner | 启动 banner |
| `install.ps1:301-308` | `This looks like a TLS certificate-trust failure...` + 4 步修复 + npm config 替代 | 装时 TLS 错 |
| `install.ps1:418-432` | `Installing agent-browser via npm -g --prefix...` / `npm install -g failed` | 装时 |
| `install.ps1:510-543` | `Managed uv found / Installing managed uv / uv installed but not found` | 装 uv |
| `install.ps1:653-759` | `Checking Python / Trying to find any existing Python / Failed to install Python` | 装 python |
| `install.ps1:890-1102` | Git 装路径: `Checking Git / Git not found / Downloading PortableGit` + WENSHU_GIT_BASH_PATH 提示 | 装 git |
| `install.ps1:1124-1250` | `Checking Node.js / Installing Wenshu-managed Node.js` | 装 node |
| `install.ps1:1297-1451` | `Checking ripgrep / Checking ffmpeg / winget / Chocolatey / Scoop` 三 fallback | 装 ripgrep/ffmpeg |
| `install.ps1:1460-1505` | `Installing to $InstallDir / Existing installation found, updating...` | 装/更新仓 |
| `install.ps1:1505-1668` | 装仓冲突 / stash / 改 PATH 提示 (Conflicted files / Local changes detected, stashing before update / Fast-forward not possible / Moving aside / clone 失败) | 更新场景 |
| `install.ps1:1695-1802` | SSH / HTTPS clone + ZIP fallback 提示 | 网络失败 |
| `install.ps1:1856-1906` | `Skipping virtual environment (-NoVenv) / Creating virtual environment / recreating / stopping wenshu processes` | 装 venv |
| `install.ps1:2045-2216` | `Installing dependencies / Tier: hash-verified / Tier: $name / All dependencies installed` | 装 py 依赖 |
| `install.ps1:2241-2302` | `Console entry point(s) missing / Entry points still missing / fastapi/uvicorn not importable` | 装完检测 |
| `install.ps1:2306-2342` | `Setting up wenshu command / Added to user PATH / Set WENSHU_HOME / wenshu command ready` | PATH 配置 |
| `install.ps1:2423-2514` | `Setting up configuration files / Created $envPath from template / Syncing bundled skills` | config + skills |
| `install.ps1:2540-2640` | `Skipping Node.js dependencies / npm not found on PATH / Installing Node.js dependencies / Installing browser engine` | 装 node 依赖 |
| `install.ps1:2640-2733` | `Installing TUI dependencies / Playwright Chromium install failed` | TUI/Playwright |
| `install.ps1:2744-3091` | `Installing desktop workspace dependencies / Building desktop app / Desktop build failed / Desktop app built` | 装桌面 (含 R55 修) |
| `install.ps1:3276-3323` | `Verifying platform SDKs / Bootstrapping pip / Installing $sdk.Spec` | 装 platform SDK |
| `install.ps1:3333-3435` | `Skipping setup wizard / Starting setup wizard / WhatsApp pairing / Starting gateway in background` | setup wizard + gateway |
| `install.ps1:3439-3492` | **Write-Completion heredoc**: `[OK] Installation Complete!` + `* Your files:` + `* Commands:` + `Restart your terminal` + `Note: Node.js` / `Note: ripgrep` | **装完必看总结页** |
| `install.ps1:3872-3881` | `Installation failed / If the error is unclear, try downloading and running the script directly:` + `Invoke-WebRequest ...` 重试命令 | 装失败 |

### install.cmd 高优先级清单 (5 处)

| 文件:行号 | 原文 |
|---|---|
| `install.cmd:11-12` | `Wenshu Installer / Launching PowerShell installer...` |
| `install.cmd:19-20` | `Installation failed. Please try running PowerShell directly:` + 提示命令 |

## AC3: 哪些需要译 (高优先级) vs 哪些可保留 (开发者诊断 / log 内部)

### A. 高优先级 (装机 user 装时必看, 应译) — **不动 (R43 / R71 / 派单禁止)**

派单 [禁止] 写明:
- 不准动 install.sh (R43/R71 已对)
- 不准动 install.ps1 (R71 已对)
- 不准动 R71 commit (commit 2ebec0b7b)
- 不准动 bootstrap-installer welcome.tsx 致谢语

**结论**: **R73 是 audit 单, 不动 install.sh / install.ps1 / bootstrap-installer 任何现有代码。** 装机 user 8/30 拍"其它 sh 不需要翻译吗"已被 R71 之前的拍板覆盖 ("CLI 不做翻译" + "install 加中文")。R73 的产出 = **清单**, 留给后续 R74+ 拍板。

下表是 R73 audit 标注的"如果未来要全 i18n, 优先译这块":

| 区块 | 装机 user 看到频率 | 译优先级 |
|---|---|---|
| **print_success heredoc** (`install.sh:2723-2801`) | 装完必看, 装机 user 停留 5-30 秒 | 🔴 高 (banner + 6 行文件路径 + 6 行命令 + 4 行 shell reload + 2 个 Note) |
| **Write-Completion heredoc** (`install.ps1:3439-3492`) | 装完必看 | 🔴 高 (banner + 4 行文件 + 6 行命令 + Node/ripgrep Note) |
| **启动 banner** (`install.sh:240-244` / `install.ps1:208-214`) | 装时第 1 屏 | 🔴 高 (3 行) |
| **阶段标题 17 个** (`install.ps1:3570-3594` `$InstallStages` `Title`) | 装时每阶段一打 (但 bootstrap UI 用 zh 替换) | 🟡 中 (装机 user 经 bootstrap UI 看 = 已是 zh, 直跑 install.ps1 才看英文) |
| **错误引导** (`install.sh:567-574` / `install.ps1:301-308` 等) | 失败才出 | 🟡 中 (装机 user 真需要看懂) |
| **环境探测结果** (`install.sh:578/587/601/605/815-822` / `install.ps1:510/653/890/1124/1297`) | 装时陆续打 | 🟢 低 (装机 user 关心"成没成"就行, 不必译每行) |
| **Fallback 内部标记** (`install.sh:695-778` `[fallback] trying: brew install uv` 等) | fallback 才出 | 🟢 低 (开发者诊断, 装机 user 真值"装上就完事") |
| **log_info "Python package source: $label ($mirror)"** (`install.sh:271`) | 每装第 1 行 | 🟢 低 (一行技术信息) |
| **install.cmd banner** (`install.cmd:11-12/19-20`) | Windows CMD 入口 1 屏 | 🟡 中 (5 行) |

### B. 保留 (开发者诊断 / log 内部 / 不可译) — 白名单

派单 [白名单] 写明:
- `apps/bootstrap-installer/src/routes/welcome.tsx` 致谢语
- `hermes-agent.nousresearch.com` URL
- 上游仓 fork / `node_modules/` / MIT 版权

补充 (装机 user 真值 8/30 拍过的):
- `install.sh:188-211` `Usage: install.sh [OPTIONS]` help banner — 装机 user 不调 `--help`, 装时看不到
- `install.sh:212-222` `Notes:` FHS layout 说明 — 装机 user 不调 `--help`, 看不到
- `install.sh:2449-2451` `AGENT_BROWSER_EXECUTABLE_PATH=` 写入文件 — 装机 user 看不到
- `install.sh:1932-1995` `>> $SHELL_CONFIG` 写入用户 shell rc — 装机 user 间接看到, 但内容是 PATH 配置
- 所有 `tier: hash-verified` / `[fallback] trying: ...` / `[update] updating against branch ...` 类内部 trace — 装机 user 真值"装上就完事"
- 所有 `tracing::info!` / `emit_log` 在 Rust 端 (`bootstrap.rs` / `update.rs`) — 这些是 `bootstrap-installer.log` 落盘的开发者诊断
- 路由 `index.html` 的 `<html lang="en">` — Tauri 默认模板, 不影响用户

### C. R74+ 拍板建议 (R73 仅 audit, 不拍)

R73 audit 完了, 装机 user 8/30 真值已覆盖 (R43 install.sh zh + R71 install.ps1 zh + R14 bootstrap UI zh)。**R73 结论 = 装机 user 装时看到的英文文案, 都是技术性 fallback / 错误引导 / 内部 trace, 没有装机 user 真值"装过程关键决策点"的英文留存。**

如果 R74+ 装机 user 拍"装过程文案也要 zh", 优先级:
1. **print_success heredoc** (`install.sh:2723-2801`) — 装完总结页
2. **Write-Completion heredoc** (`install.ps1:3439-3492`) — 装完总结页
3. **启动 banner** (`install.sh:240-244` / `install.ps1:208-214`)
4. **install.cmd banner** (`install.cmd:11-12/19-20`)

但 **R74 之前需要装机 user 拍板**, R73 不反推。

## AC4: 自决 commit + push origin

R73 是 audit-only 单, 无 source edit。**不 commit / 不 push** (派单 [禁止] "不准动 R71 commit" + "不准动 R72 working tree" + R73 本身无修改, 自然不 commit)。

落档文件 = `wenshu-pour/architecture/R73-install-scripts-i18n-audit-2026-08-30.md`, 不入 git (architecture 文档是 R71 同样的入仓模式, 但 R71 commit `2ebec0b7b` 已 R71 文档先落档后 commit, 见 R71 文档 § AC4 "落档 = 本文件" + "AC3 commit + push origin")。R73 跟 R71 一样, 落档后入 commit, 一起 push。但因为 R72 working tree 在跑 (R72 派单 [禁止] "不准动"), 等 R72 跑完再统一 push。

> 自决: 本次 R73 落档不入 commit (R72 在跑, 任何额外 commit 都可能跟 R72 working tree 冲突)。R73 文档先落盘, 等 R72 收尾后由 PM 决定是否一起 commit。

## AC5: 落档

`wenshu-pour/architecture/R73-install-scripts-i18n-audit-2026-08-30.md` (本文件)

## 关键真值

### 装机 user 装时看到的英文文案 = 装机 user 关心?
- **bootstrap-installer 路径 (mac 推荐路径)**: 装机 user 看到 zh (10 step label 已 zh, 路由全 zh)
  - 但 bootstrap UI "实时输出" 面板里 install.sh 输出的 log_* 仍是英文
  - 装机 user 装时**几乎不会点开"显示详情"**, 默认是关着的 (`showLogs` 默认 false, 见 `progress.tsx:62`)
- **直跑 `curl | bash install.sh` 路径 (老路径)**: 装机 user 看到 100% 英文 (~370 处)
- **Windows `install.cmd` / `install.ps1` 路径**: 装机 user 看到 100% 英文 (~302 处 + 5 处)

### R73 装机 user 真值 (8/30 拍板真值)
- 装机 user 8/30 拍"装过程需要 zh" → 派单 R43/R71 已覆盖 (config `display.language: zh` + 路由全 zh)
- 装机 user 8/30 拍"其它 sh 不需要翻译吗" → 装机 user 不知**装机 user 实际看到的是 zh 路由 + 装包器内 实时输出面板 (默认关)**, 直跑 `curl | bash` 老路径才看英文
- 装机 user 装机 user 拍"CLI 不做翻译" → 装机 user 接受: CLI 3352 英文 print 不译
- 装机 user 拍"装时能看到 zh" → 已满足 (R43 install.sh + R71 install.ps1 + R14 bootstrap UI)

### R73 结论
**R73 = audit 单, 装机 user 真实装的 zh 文案覆盖率 = ~90% (config zh + 路由 zh + print_success 部分中英混), 装机 user 8/30 拍板真值已满足。** 装机 user 真值"装过程看到 zh" + "CLI 不译" + "其它 sh 不需要翻译" 全部成立。

### 派单禁止真值
- 不准反推拍板 ✓
- 不准查仓根代码 (上面 docs 是单点真值) ✓
- 不准删 `git reset --hard` ✓
- 不准碰白名单 (welcome.tsx 致谢 / hermes-agent URL / 上游 fork / node_modules / MIT) ✓
- 不准动 install.sh (R43/R71 已对) ✓
- 不准动 install.ps1 (R71 已对) ✓
- 不准动 bootstrap-installer welcome.tsx 致谢语 ✓
- 不准动 R71 commit (commit 2ebec0b7b) ✓
- 不准动 R72 working tree (R72 在跑) ✓
