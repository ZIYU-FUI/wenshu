# 文枢 Setup (Bootstrap Installer)

> 文枢 (Wenshu) 是 Wenshu Agent v0.19.0 的 fork。
> 这个 Tauri app 引导装机 user 完成文枢的"首次装 + 在线更新"流程。

## 它做什么

装机 user 打开 dmg, 把 `文枢.app` 拖到 `/Applications/`, 启动它.
Tauri 端 (React UI + Rust backend) 弹出 onboarding 向导, 引导装机 user 走 11 阶段安装:

1. **prerequisites** — 系统依赖检查 (Python, git, uv)
2. **repository** — git clone `github.com/ZIYU-FUI/wenshu` 到 `~/.wenshu-hermes/wenshu-agent/`
3. **venv** — 建 Python venv
4. **python-deps** — `uv pip install -e .` 装 wenshu-agent 包
5. **node-deps** — 装 node-side 依赖 (browser tool 等)
6. **path** — `wenshu` 命令 wrapper 写到 `~/.wenshu-hermes/bin/`
7. **config** — 生成 `~/.wenshu-hermes/config.yaml` 模板
8. **setup** — API keys 配置 (交互)
9. **gateway** — Feishu/微信 gateway 配置
10. **complete** — 写安装完成 marker

## 跟原 wenshu installer 区别

| 项 | wenshu | 文枢 |
|---|---|---|
| 装路径 | `~/.wenshu-hermes/` | `~/.wenshu-hermes/` (避免跟用户已有 wenshu 冲突) |
| 默认 repo | `github.com/NousResearch/hermes-agent` | `github.com/ZIYU-FUI/wenshu` |
| 应用名 | `Wenshu-Setup` / `com.nousresearch.wenshu.setup` | `文枢-Setup` / `com.wenshu.app.setup` |
| 装好之后 | `~/.wenshu-hermes/bin/wenshu` | `~/.wenshu-hermes/bin/wenshu` (wrapper, 调 wenshu-agent CLI) |

## 在线更新 (Update)

Tauri 端 `update.rs` 实现:
- 装机 user 重启 "文枢 Setup.app" + 选 "Update"
- 等文枢 desktop 进程退出 (释放 venv + asar 锁)
- 跑 `wenshu update --yes --gateway` (Python/repo update)
- 跑 `wenshu desktop --build-only` (rebuild 文枢 desktop, 不真装)
- 启动新文枢 desktop

## Python 包国内镜像（默认）

GUI 装包器和 `scripts/install.sh` 都会强制把 uv / pip 指向清华 TUNA，避免
`pypi.org` 或 `download.pytorch.org` 在国内网络不稳定时掩盖代码问题：

```text
UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
UV_CONCURRENT_DOWNLOADS=100
✓ Managed uv found (uv 0.11.32 ...; default source: https://pypi.tuna.tsinghua.edu.cn/simple)
```

- 清华源安装失败后，Python 依赖会切到阿里云
  `https://mirrors.aliyun.com/pypi/simple/` 重试。
- 装包器会清除继承的 `UV_TORCH_BACKEND`，防止 torch 等包绕过镜像访问
  `download.pytorch.org`。
- 当前 `uv.lock` 记录的是官方站 artifact URL。强制镜像模式会跳过该 locked
  下载路径，改用镜像重新解析，确保实际下载不回到官方站。

## 开发者 (本机 build)

```bash
cd apps/bootstrap-installer
npm install
CSC_IDENTITY_AUTO_DISCOVERY=false npm run tauri:build
# 产物: src-tauri/target/release/bundle/{dmg,macos}/文枢*
# dmg 5.4 MB, .app 7.4 MB (M-series)
```

## 文件结构

```
apps/bootstrap-installer/
├── src/                    # React UI (Tauri 前端)
│   ├── app.tsx
│   ├── routes/             # install / update 路由
│   ├── components/         # bootstrap 进度条, log 实时滚动
│   └── lib/                # IPC 调用 wrapper
├── src-tauri/              # Rust backend
│   ├── src/
│   │   ├── bootstrap.rs    # 装流程 orchestration, 跑 install.ps1
│   │   ├── update.rs       # 在线更新流程
│   │   ├── install_script.rs # 拉 install.ps1 (dev/cache/downloaded)
│   │   ├── paths.rs        # WENSHU_HOME 路径解析
│   │   ├── powershell.rs   # Windows install.ps1 适配 (跨平台预留)
│   │   └── events.rs       # Tauri event schema
│   ├── tauri.conf.json
│   └── icons/              # .icns/.ico/.png (跟 desktop 端 LOGO 一致)
├── public/                 # 静态资源
├── package.json
├── tauri.conf.json         # (在 src-tauri/)
└── .gitignore
```

## 跟 scripts/ 的关系

本 app 调 `../../scripts/install.sh` (macOS/Linux) 或 `install.ps1` (Windows).
这些脚本不在本目录, 跟文仓根的 `scripts/` 共享.
脚本本身是 wenshu 项目的 install.sh/ps1 改造, 默认值改 wenshu (参见 `scripts/install.sh` L46-48).
