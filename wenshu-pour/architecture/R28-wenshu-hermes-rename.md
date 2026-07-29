# WO-001BI-R28：仓内 Hermes 全面更名为 Wenshu-Hermes

> 工单：WO-001BI-R28  
> 日期：2026-07-29  
> 拍板真值：装机 user 8/28——“深度改代码，让 wenshu 项目的 hermes，全面更名为 wenshu-hermes。完全和本级 hermes 区别出来。”  
> 本档记录本轮实际改动、隔离边界、验证证据和未收尾事项。它不是上游 Hermes Agent 的历史改写，也不改 LICENSE。

---

## 1. 为什么 R26 不够

R26 解决的是桌面壳启动路径：将文枢运行根固定到 `~/.wenshu-hermes/`，并要求桌面进程优先使用隔离 venv。但仓内安装出来的 Python distribution、import path、console command、环境变量和 Electron IPC 仍沿用 Hermes 名称，例如：

- distribution 仍为 `hermes-agent`；
- Python package 仍为 `hermes_cli`；
- 根模块仍为 `hermes_bootstrap.py`、`hermes_constants.py`、`hermes_logging.py`、`hermes_state.py`、`hermes_time.py`；
- Electron renderer bridge 仍暴露 `window.hermesDesktop`，IPC channel 仍是 `hermes:*`；
- 启动脚本和服务名仍出现 `hermes-gateway`、`HERMES_HOME`、`HERMES_DESKTOP_*`；
- `wenshu` 桌面端虽然指向隔离目录，但探针仍执行 `python -m hermes_cli.main`，容易与本机已有 Hermes Python 环境混淆；
- dashboard 默认端口仍为上游固定的 9119，文枢与本机 Hermes 同时启动时存在端口碰撞。

因此 R28 不是 UI 文案替换，而是运行命名空间切换：distribution、Python import、console entry point、环境变量、数据根、IPC、服务文件、安装脚本和测试引用必须形成同一个 Wenshu 命名闭环。

## 2. 本轮命名决策

| 层 | R28 前 | R28 后 |
|---|---|---|
| Python distribution | `hermes-agent` | `wenshu-agent` |
| Python package | `hermes_cli` | `wenshu_cli` |
| console entry | `hermes` | `wenshu` |
| agent entry | `hermes-agent` | `wenshu-agent` |
| ACP entry | `hermes-acp` | `wenshu-acp` |
| bootstrap module | `hermes_bootstrap` | `wenshu_bootstrap` |
| constants module | `hermes_constants` | `wenshu_constants` |
| logging module | `hermes_logging` | `wenshu_logging` |
| state module | `hermes_state` | `wenshu_state` |
| time module | `hermes_time` | `wenshu_time` |
| runtime env prefix | `HERMES_*` | `WENSHU_*` |
| runtime data root | 上游 `~/.hermes` / 中间态 `~/.wenshu` | `~/.wenshu-hermes` |
| renderer bridge | `window.hermesDesktop` | `window.wenshuDesktop` |
| Electron channels | `hermes:*` | `wenshu:*` |
| gateway helper | `scripts/hermes-gateway` | `scripts/wenshu-gateway` |
| Homebrew formula | `hermes-agent.rb` | `wenshu-agent.rb` |
| dashboard default port | 固定 `9119` | `0`，由 OS 自动分配可用端口 |

`~/.wenshu-hermes` 是装机 user 在 R26 已拍的隔离根，名称中保留 `hermes` 是有意的产品运行根命名，不是遗留的 `hermes_cli` 模块或本机 `~/.hermes`。本轮批量改名过程中专门防止它被误替换为 `~/.wenshu-wenshu`。

## 3. Python 包与入口改动

### 3.1 package 和根模块

仓根 Python package 已从 `hermes_cli/` 移为 `wenshu_cli/`，包内所有绝对 import、延迟 import、字符串模块路径、monkeypatch 路径和 `python -m` 调用同步指向 `wenshu_cli`。根模块同步改为：

- `wenshu_bootstrap.py`
- `wenshu_constants.py`
- `wenshu_logging.py`
- `wenshu_state.py`
- `wenshu_time.py`

`pyproject.toml` 的关键真值变为：

```toml
[project]
name = "wenshu-agent"

[project.scripts]
wenshu = "wenshu_cli.main:main"
wenshu-agent = "run_agent:main"
wenshu-acp = "acp_adapter.entry:main"

[tool.setuptools]
py-modules = [
  "run_agent", "model_tools", "toolsets", "batch_runner",
  "trajectory_compressor", "toolset_distributions", "cli",
  "wenshu_bootstrap", "wenshu_constants", "wenshu_state",
  "wenshu_time", "wenshu_logging", "utils", "mcp_serve"
]
```

setuptools package discovery和 package-data 也改为 `wenshu_cli`。extras 内部自引用从 `hermes-agent[...]` 改为 `wenshu-agent[...]`，避免安装 extras 时重新解析上游 distribution。

### 3.2 测试目录

测试 package 同步迁移：

- `tests/hermes_cli/` → `tests/wenshu_cli/`
- `tests/hermes_state/` → `tests/wenshu_state/`
- `test_hermes_bootstrap.py` → `test_wenshu_bootstrap.py`
- `test_hermes_constants.py` → `test_wenshu_constants.py`
- `test_hermes_logging.py` → `test_wenshu_logging.py`
- `test_hermes_state*.py` → `test_wenshu_state*.py`

测试中的 import、monkeypatch target 和临时环境变量同步改为 Wenshu 命名。`test_nous_hermes_non_agentic.py` 的 Hermes 是外部模型/服务语义，文件名按保留边界不强改。

## 4. 桌面端和 IPC 改动

Electron preload 现在使用：

```ts
contextBridge.exposeInMainWorld('wenshuDesktop', {
  getConnection: profile => ipcRenderer.invoke('wenshu:connection', profile),
  // ...
})
```

renderer 下所有 `window.hermesDesktop.*` 调用、`global.d.ts` bridge 类型和测试 mock 已同步切到 `window.wenshuDesktop.*`。主进程 handler、event、invoke/send/on channel 从 `hermes:*` 成套切到 `wenshu:*`，避免仅改 renderer 名称却仍共用旧 channel。

桌面端源码入口也从 `apps/desktop/src/hermes.ts` 等改为 `wenshu.ts`、`types/wenshu.ts`，相关测试文件和 import path 一并迁移。Windows 路径辅助模块从 `windows-hermes-path.ts` 改为 `windows-wenshu-path.ts`。桌面共享 workspace package 从 `@hermes/shared` 改为 `@wenshu/shared`，对应 package.json 和 pnpm lock 引用一致。

环境变量统一使用 `WENSHU_HOME`、`WENSHU_DESKTOP_*` 等前缀；桌面 `LSEnvironment` 现在注入：

```json
{ "WENSHU_HOME": "$HOME/.wenshu-hermes" }
```

桌面探针和 spawn argv 已实际指向 `python -m wenshu_cli.main`，不再以旧 module 名解析本机 Hermes package。

## 5. 安装、服务、打包与资产

安装和服务侧完成以下迁移：

- `scripts/install.sh` 的 `install_hermes*()` 系列标识迁到 `install_wenshu*()`；
- PowerShell、shell、Docker 和 Nix 内部运行命名改用 Wenshu；
- `scripts/hermes-gateway` → `scripts/wenshu-gateway`；
- `setup-hermes.sh` → `setup-wenshu.sh`；
- `packaging/homebrew/hermes-agent.rb` → `packaging/homebrew/wenshu-agent.rb`；
- `nix/hermes-agent.nix` → `nix/wenshu-agent.nix`；
- Docker shim / s6 service 的内部服务路径改为 Wenshu；
- 软件开发 skill `hermes-agent-skill-authoring/` 改为 `wenshu-agent-skill-authoring/`；
- 文枢内置 skill、plugin、website guide 和桌面动画资产的内部 Hermes 文件名同步迁移，避免代码已引用 `wenshu-*` 但磁盘仍只有 `hermes-*`。

外部 npm 包 `hermes-parser`、`hermes-estree` 保留原名；`github.com/NousResearch/hermes-agent` 和 `github:NousResearch/hermes-agent` 作为上游地址保留；LICENSE 未修改；仓根 `AGENTS.md`、`README.md`、`.gitignore`、`.github/` 和 `wenshu-pour/` 的上游/历史真值不做批量改写。

## 6. 数据、配置、数据库与端口隔离

所有运行时默认 home 归一到 `~/.wenshu-hermes`，配置、日志、SQLite state、sessions、skills、plugins 和 gateway 状态都从该根派生。这样文枢不会读取本机 Hermes 的 `~/.hermes`，也不会落入批量替换产生的中间态 `~/.wenshu`。

端口不通过拍一个新的固定数字来“错开”，而是将 `wenshu dashboard` / `wenshu serve` parser 默认值和 `start_server()` 默认值设为 `0`。`0` 交给 OS 自动分配可用端口，启动后沿用现有 actual-port / ready-file 查询链返回真实端口。这满足“不要和本机 Hermes 固定 9119 重名”，同时符合桌面端必须动态查询当前端口的既有安全约束。

`wenshu dashboard --help` 的实际输出是：

```text
--port PORT   Port (default 0: auto-assign an available OS port)
```

顶层 help 也改为 “Start web UI dashboard (auto-assigned port)”。API-server 插件的显式用户配置端口没有擅自改写；本轮处理的是文枢主 dashboard/serve 启动默认值及桌面动态端口链。

## 7. 验证证据

### 7.1 AC1：旧核心标识扫描

对仓内代码范围执行扫描，排除工单明确保留的仓根真值文档、`.github/`、`docs/`、`.plans/` 和 `wenshu-pour/`：

```text
hermes_cli          0
hermes_bootstrap    0
hermes_constants    0
hermesDesktop       0
```

运行时代码范围另查 `HERMES_[A-Z_]+`，无输出。构建后的 `apps/desktop/dist` 中查 `hermesDesktop|hermes_cli|hermes_bootstrap|hermes_constants`，无文本命中。

### 7.2 AC2：新 CLI 真在

在临时 `WENSHU_HOME=/tmp/r28-wenshu-home` 下执行，不访问装机 user 私域：

```text
$ uv run --python 3.11 wenshu --help
... dashboard ... serve ... update ...

$ uv run --python 3.11 python -m wenshu_cli.main --help
... dashboard ... serve ... update ...

$ importlib.metadata.distribution('wenshu-agent')
wenshu-agent 0.19.0 wenshu_cli.main
```

同时以 Python 3.11 编译并 import `wenshu_cli`、`wenshu_cli.main`、`wenshu_constants` 成功；`get_wenshu_home()` 返回 `/Users/anbaiqiang/.wenshu-hermes`，该步只计算路径，没有读写禁止目录。

### 7.3 Python 测试

核心改名测试结果：

```text
664 passed, 5 skipped, 2 deselected in 14.55s
45 passed in 1.15s
```

第一组覆盖 bootstrap/constants/state/logging 以及 `tests/wenshu_state/`。两项 deselect 是仓库基线中测试与实现本来不一致的 GUI logging 断言：测试要求 `COMPONENT_PREFIXES["gui"]` 含 `gateway`，但 HEAD 原实现的 gui tuple 只有 `hermes_cli.web_server`、`hermes_cli.pty_bridge`、`uvicorn`；R28 对应替换后仍是同一业务结构，不在品牌改名工单内改变日志路由。第二组覆盖 argparse flag propagation、subparser routing 和 package metadata，45 项全过。

### 7.4 macOS 构建

在 `apps/desktop` 执行两次 `pnpm run dist:mac`，最终一次包含动态端口改动，exit 0。关键输出：

```text
✓ 14925 modules transformed
✓ assert-dist-built: dist/index.html + assets present
packaging platform=darwin arch=arm64 electron=40.10.2
building target=macOS zip
building target=DMG
```

产物：

- `apps/desktop/release/mac-arm64/文枢.app`：约 305 MB；
- `apps/desktop/release/文枢-0.0.1-arm64.dmg`：约 129 MB；
- `apps/desktop/release/文枢-0.0.1-arm64.zip`：约 129 MB。

机器没有有效 Developer ID Application identity，因此 electron-builder 明确跳过签名；未配置 Apple notarization 三元组，因此跳过 notarization。这两个是构建环境事实，不影响本次 `dist:mac` exit 0 和 `.app`/DMG 生成。

### 7.5 其他门禁

`git diff --check` exit 0。桌面单独 `pnpm run typecheck` 遇到现有 root/app 双份 `@assistant-ui/core` / `assistant-stream` 类型实例不兼容，报错集中在 `src/lib/incremental-external-store-runtime.ts`；本轮实际 `pnpm run dist:mac` 的 prebuild、Vite、Electron bundle 和 builder 均成功。该依赖树问题未在 R28 内越界修改。

## 8. 边界和未收尾

1. 没有访问或修改 `/Users/anbaiqiang/Documents/`、`/Volumes/ANAN/Engineering/novel-platform/`、`~/.wenshu-hermes/`；CLI 验证使用 `/tmp/r28-wenshu-home`。
2. 没有改 LICENSE，没有 commit，没有 push，符合工单“装机 user 验收通过后由 PM-direct 自决 commit + push”。
3. 没有改 `node_modules` 中 `hermes-parser` / `hermes-estree` 外部 npm 包名。
4. 保留 `contributors/emails/hermesagent424@gmail.com`、`docs/hermes-kanban-v1-spec.pdf`、`hermes-already-has-routines.md`、Nous Hermes 模型语义测试和 `wenshu-pour` 历史索引。
5. 当前会话没有飞书 DM 工具，且禁止借运行时私域自行调用用户配置；因此 AC5 尚未执行。PM-direct 可在验收时发送本档路径、`.app`/DMG 路径和构建结论。
6. working tree 在开工前已有 R14–R27 的修改和未跟踪文件；R28 没有清理、覆盖或提交这些既有工作。

## 9. 验收对照

| AC | 状态 | 证据 |
|---|---|---|
| AC1 旧核心标识 0 命中 | 通过 | 代码范围四项均为 0；保留区仅存上游/历史真值 |
| AC2 `wenshu_cli` / module / command 真在 | 通过 | console entry、`python -m wenshu_cli.main`、distribution metadata 均实跑 |
| AC3 `pnpm run dist:mac` exit 0 | 通过 | `.app`、DMG、ZIP 已生成 |
| AC4 R28 落档 ≥5KB | 通过 | 本文件记录决策、范围、验证和遗留 |
| AC5 飞书 DM | 未执行 | 当前工具集无飞书发送能力，留 PM-direct 收尾 |

---

**复盘结论**：R26 只把桌面路径指向隔离根，不足以证明运行的 package 真是文枢。R28 将可执行命令、Python import、distribution、IPC、环境变量、服务名、安装脚本、测试与动态端口统一到 Wenshu 命名空间；本机 Hermes 的上游名、外部 npm 包和私域目录仍按边界保留。后续验收应以新 `.app` 启动日志中的 `WENSHU_HOME=~/.wenshu-hermes`、`python -m wenshu_cli.main` 和动态 ready port 为三项运行时证据。
