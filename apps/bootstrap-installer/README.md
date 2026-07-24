# 文枢 Setup (Bootstrap Installer)

> 文枢 (Wenshu) 是 WenShu Agent v0.19.0 的 fork。
> 这个 Tauri app 引导装机 user 完成文枢的"首次装 + 在线更新"流程。

## 它做什么

装机 user 打开 dmg, 把 `文枢.app` 拖到 `/Applications/`, 启动它.
Tauri 端 (React UI + Rust backend) 弹出 onboarding 向导, 引导装机 user 走 11 阶段安装:

1. **prerequisites** — 系统依赖检查 (Python, git, uv)
2. **repository** — git clone `github.com/ZIYU-FUI/wenshu` 到 `~/.wenshu-hermes/hermes-agent/`
3. **venv** — 建 Python venv
4. **python-deps** — `uv pip install -e .` 装 hermes-agent 包
5. **node-deps** — 装 node-side 依赖 (browser tool 等)
6. **path** — `hermes` 命令 wrapper 写到 `~/.wenshu-hermes/bin/`
7. **config** — 生成 `~/.wenshu-hermes/config.yaml` 模板
8. **setup** — API keys 配置 (交互)
9. **gateway** — Feishu/微信 gateway 配置
10. **complete** — 写安装完成 marker

## 跟原 hermes installer 区别

| 项 | hermes | 文枢 |
|---|---|---|
| 装路径 | `~/.hermes/` | `~/.wenshu-hermes/` (避免跟用户已有 hermes 冲突) |
| 默认 repo | `github.com/NousResearch/hermes-agent` | `github.com/ZIYU-FUI/wenshu` |
| 应用名 | `Hermes-Setup` / `com.nousresearch.hermes.setup` | `文枢-Setup` / `com.wenshu.app.setup` |
| 装好之后 | `~/.hermes/bin/hermes` | `~/.wenshu-hermes/bin/hermes` (wrapper, 调 hermes-agent CLI) |

## 在线更新 (Update)

Tauri 端 `update.rs` 实现:
- 装机 user 重启 "文枢 Setup.app" + 选 "Update"
- 等文枢 desktop 进程退出 (释放 venv + asar 锁)
- 跑 `hermes update --yes --gateway` (Python/repo update)
- 跑 `hermes desktop --build-only` (rebuild 文枢 desktop, 不真装)
- 启动新文枢 desktop

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
│   │   ├── paths.rs        # HERMES_HOME 路径解析
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
脚本本身是 hermes 项目的 install.sh/ps1 改造, 默认值改 wenshu (参见 `scripts/install.sh` L46-48).
