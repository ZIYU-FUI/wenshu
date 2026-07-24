# 文枢装机指南 (Wenshu Quickstart)

> 文枢 (Wenshu) 是 WenShu Agent v0.19.0 的 fork.
> 本指南是"装机 user 走通"流程 — 不是开发者.

## TL;DR (3 步)

```bash
# 1. 拖 dmg
open ~/Downloads/文枢_0.0.1_aarch64.dmg
# 弹窗 → 拖 文枢.app → Applications/

# 2. 跑 installer
open /Applications/文枢.app
# 跟着 React UI 走 11 阶段 onboarding (~ 5-10 分钟)
# 默认装到 ~/.wenshu-hermes/

# 3. 跑 desktop
open /Applications/文枢.app
# (跟 installer 同一个 app 入口; 装好之后, 双击 = 直接进 wenshu desktop)
```

## 详细流程

### Step 1: 验证 dmg

`~/Downloads/文枢_0.0.1_aarch64.dmg` 应该存在 (5.4 MB).
如果不在, 让 PM-direct 重 build (或跑 `cd apps/bootstrap-installer && CSC_IDENTITY_AUTO_DISCOVERY=false npm run tauri:build`).

### Step 2: 挂载 dmg + 拖 .app

```bash
# GUI 方式:
#   双击 dmg → Finder 弹窗 → 拖 文枢.app → Applications/

# CLI 方式:
hdiutil attach ~/Downloads/文枢_0.0.1_aarch64.dmg
cp -R /Volumes/文枢/文枢.app /Applications/
hdiutil detach /Volumes/文枢
```

> 注意: dmg 里的 `文枢.app` = Tauri 编译的 installer app, 跟文枢 desktop .app (`/Applications/文枢.app`) 是**两个不同的 app**.
> 装好 installer 后, 文枢 desktop .app 也会被自动装上 (在 installer 内部 desktop 阶段).

### Step 3: 启动 installer

```bash
open /Applications/文枢.app
```

弹出 React UI (文枢 Setup), 引导走 11 阶段:

| # | 阶段 | 做什么 | 装机 user 需做什么 |
|---|---|---|---|
| 1 | prerequisites | 检查 Python / git / uv / 必要时装 | 等 |
| 2 | repository | `git clone git@github.com:ZIYU-FUI/wenshu.git ~/.wenshu-hermes/hermes-agent/` | (SSH key 没设的话可能要输 PAT) |
| 3 | venv | `uv venv ~/.wenshu-hermes/hermes-agent/.venv` | 等 |
| 4 | python-deps | `uv pip install -e .[all]` | 等 1-3 分钟 |
| 5 | node-deps | npm install 装 browser tool | 等 1-2 分钟 |
| 6 | path | venv bin 写到 PATH | 自动 |
| 7 | config | 生成 `~/.wenshu-hermes/config.yaml` 模板 | 自动 |
| 8 | setup | API keys (Anthropic / OpenAI / MiniMax-M3 等) | **输入** (核心交互) |
| 9 | gateway | Feishu/微信 机器人 (可选) | **输入** (可选) |
| 10 | desktop | `cd ~/.wenshu-hermes/hermes-agent && npm run build` | 等 5-10 分钟 (首次) |
| 11 | complete | 写 `.install_method` marker | 自动 |

### Step 4: 验证

```bash
# Python 内核
~/.wenshu-hermes/hermes-agent/.venv/bin/hermes --version
# 应该输出 hermes-agent 0.19.0

# Desktop
open /Applications/文枢.app
# 启动后应该看到 "文枢 v0.0.1" splash + About 页

# 隔离验证
ls -la ~/.hermes
# mtime 应该是老的 (没动); wenshu 装没碰你已有 hermes
```

## 升级流程 (后续)

不需要重装 .app. 通过 installer 的 update 模式:

```bash
open /Applications/文枢.app
# 选 "Update" 模式
# 跑 `hermes update --yes --gateway` (拉 wenshu repo main 最新 commit)
# 跑 `hermes desktop --build-only` (rebuild 文枢 desktop)
# 自动重启
```

或者 CLI:

```bash
~/.wenshu-hermes/hermes-agent/.venv/bin/hermes update --yes --gateway
```

## 卸载

```bash
# 卸文枢 desktop
rm -rf /Applications/文枢.app

# 卸文枢 venv + 装数据
rm -rf ~/.wenshu-hermes

# 卸 hermes-agent 装 (PyPI 装的)
~/.wenshu-hermes/hermes-agent/.venv/bin/pip uninstall hermes-agent
# 或
rm -rf ~/.wenshu-hermes/hermes-agent
```

**不会污染 `~/.hermes`** — 文枢装在独立目录 `~/.wenshu-hermes`.

## 故障排查

### "Python not found"
macOS 默认有 Python 3 (系统装). 如果没有, 装 Xcode CLT: `xcode-select --install`.

### "git clone 失败" (Permission denied)
装 SSH key: `ssh-add ~/.ssh/id_ed25519`
或用 HTTPS: 装时改 URL.

### "uv not found"
installer 会自动装 (curl 装 uv 二进制). 看 log `~/.wenshu-hermes/logs/bootstrap-<timestamp>.log`.

### 装到一半卡住
重启文枢 Setup.app, 选 "Update" 模式 (会自动续装).

## 文件位置总结

| 类别 | 路径 |
|---|---|
| 文枢 desktop .app | `/Applications/文枢.app` |
| 文枢 installer .app | `/Applications/文枢.app` (双击 = installer 模式) |
| 文枢 venv (Python + hermes-agent 包) | `~/.wenshu-hermes/hermes-agent/.venv/` |
| 文枢 git checkout (wenshu fork) | `~/.wenshu-hermes/hermes-agent/` |
| 文枢 hermes CLI | `~/.wenshu-hermes/hermes-agent/.venv/bin/hermes` |
| 文枢 config | `~/.wenshu-hermes/config.yaml` |
| 文枢 data / sessions / logs | `~/.wenshu-hermes/` |
| 文枢 installer 装日志 | `~/.wenshu-hermes/logs/bootstrap-<timestamp>.log` |
| 文枢 marker (装完 marker) | `~/.wenshu-hermes/hermes-agent/.install_method` (写) + `~/.wenshu-hermes/hermes-agent/.hermes-bootstrap-complete` (Windows 端, macOS 没写) |
| 文枢 .dmg | `~/Downloads/文枢_0.0.1_aarch64.dmg` |

> 你的 `~/.hermes` 目录 (已有 hermes 装)**完全不动** — 文枢装在独立 `~/.wenshu-hermes` 隔离.
