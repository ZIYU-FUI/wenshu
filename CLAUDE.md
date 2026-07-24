# CLAUDE.md · 文枢 (Wenshu)

> CC(Claude Code CLI)启动时自动读取的项目上下文
> 真理源指针:@AGENTS.md(角色边界/派单/客户侧硬约束/评论 SLA/升级/跟上游漂移)
> 项目基线 0.0.0(2026-07-23 18:55 出资方拍板),基线 = NousResearch/hermes-agent v0.19.0 (tag v2026.7.20)

---

## 1. Project Overview

> **文枢 = WenShu Agent v0.19.0 深度改 fork**(完整 monorepo,不是 sparse clone)
> 完整愿景见 `README.md §1`

**项目基线**(老板 2026-07-23 18:55 拍板):
- 老板拍板"用当前的 0.19.0,完全改 hermes 源码,不改 metadata fork"
- **架构 = NousResearch/hermes-agent v0.19.0 完整 monorepo fork + 全 monorepo 字符串替换 "Hermes" → "文枢" + 砍 4-tier ladder rung 1-4(自包含内核)**
- **不复用**:novel-platform(Tauri 2 + Rust + SQLite + Vue 3)/ novel-craft / Hermes-Slate-Desk / v0.5.1 / v0.5.4 协议 / sparse clone 假设
- **新策略**:每个任务 = 单一功能 + 打 .app 给老板试用验收(沿用 novel-platform 7/10 18:14 拍板)
- **跟上游漂移** = 维护性任务,出资方 2026-07-23 拍

**基线信息**:
- upstream = `git@github.com:NousResearch/hermes-agent.git`
- 仓库 = `github.com/ZIYU-FUI/wenshu`(私有)
- 起点 tag = `v2026.7.20` (Hermes 0.19.0, commit `3ef6bbd20`)
- LICENSE = MIT, Copyright (c) 2025 Nous Research
- 文枢修改 = Copyright (c) 2026 安百强(0.0.1 工单追加)

## 2. Tech Stack

| 层 | 技术 | 版本 | 选型理由 |
|----|------|------|---------|
| monorepo root | pnpm workspace | pnpm 11 | 沿用 hermes-agent(完整 monorepo) |
| 桌面壳 | Electron | 30.x | 沿用 hermes `apps/desktop`(改 productName=文枢,appId=com.wenshu.app) |
| 前端 | React 18 + TypeScript + Vite | React 18.x / Vite 5.x | 沿用 hermes `apps/desktop/src` |
| 后端 | Node.js + Electron main.cjs | Node 20.19+ / 22.12+ | 沿用 hermes `apps/desktop/electron` |
| 文枢自有内核 | Python 3.11-3.14 + wenshu 改版 hermes-cli | 0.0.x | 自包含,装到 `~/.wenshu/hermes-agent/venv/`(**不归文枢 app 装,文枢只是 spawn**),**不读本机 `~/.hermes/hermes-agent/`** |
| monorepo 包 | `agent/` / `gateway/` / `hermes_cli/` / `acp_adapter/` / `acp_registry/` / `cron/` | 沿用上游 | 改 brand,不改业务 |
| Bootstrap | `apps/bootstrap-installer/` | 沿用上游 | 改:装文枢版本,不是通用 hermes 内核 |
| 包管理 | pnpm 11 | pnpm 11 | monorepo 跟上游一致 |
| Build | electron-builder | 26.8.1 | 跟上游一致 |

**用**(已落地):
- ✅ hermes-agent 完整 monorepo fork(所有 Python + Electron + React + monorepo 包)
- ✅ LICENSE = MIT,文枢修改追加 copyright(0.0.1 工单)
- ✅ 改 productName / appId / About / Settings / 启动 banner / CLI 文案(0.0.1 + 0.0.2 工单)

**不用**(P0 / 0.0.x 阶段):
- ❌ 复用 hermes 上游 4-tier ladder rung 1-4(本机检测)— 0.0.3 砍,只留 rung 5 = 自包含内核
- ❌ 连用户本机 `~/.hermes/hermes-agent/` — 文枢不读本机 hermes
- ❌ 自己写 desktop shell(用 hermes `apps/desktop` 现成的)
- ❌ 改 hermes 业务逻辑(我们改 brand,不重写)
- ❌ 自己改 Python hermes-cli 业务代码(改 brand,业务代码沿用)
- ❌ 任何 novel-platform Tauri / Rust / SQLite 痕迹
- ❌ 改 LICENSE 文本(CC 严禁,改 = 升级老板)
- ❌ 改 4-tier ladder rung 数量在 0.0.3 工单外(其他工单内改 = 越界)

## 3. Directory Structure

```
wenshu/                                            ← 项目根(0.0.0 基线)
├── README.md                                      ← 项目门面(已重写为文枢)
├── AGENTS.md                                      ← 协作规则真理源(已重写)
├── CLAUDE.md                                      ← 本文件(已重写)
├── LICENSE                                        ← MIT,0.0.1 追加文枢 copyright
├── pyproject.toml                                 ← Python monorepo(name=wenshu 0.0.1 改)
├── package.json                                   ← monorepo root
├── .github/                                       ← GitHub workflows
├── .gitignore
├── docs/                                          ← 上游 docs,改 brand
├── locales/                                       ← i18n,改 brand
├── docker/                                        ← Docker 镜像(可选,改 brand)
├── nix/
├── docker-compose.yml
├── Dockerfile
├── CONTRIBUTING.md                                ← 上游贡献指南(改 brand)
├── SECURITY.md
│
├── apps/                                          ← monorepo apps
│   ├── desktop/                                   ← ⭐ Electron 桌面 app
│   │   ├── AGENTS.md                              ←   (上游原版,改 brand)
│   │   ├── README.md
│   │   ├── DESIGN.md
│   │   ├── components.json
│   │   ├── eslint.config.mjs
│   │   ├── index.html
│   │   ├── package.json                           ←   ⭐ 0.0.1 改 name=wenshu + productName=文枢 + appId=com.wenshu.app + version=0.0.1
│   │   ├── tsconfig.json
│   │   ├── tsconfig.electron.json
│   │   ├── vite.config.ts
│   │   ├── vitest.config.ts
│   │   ├── vitest.setup.ts
│   │   ├── public/                                ←   icon / favicon(0.0.2 换文枢 logo)
│   │   ├── pr-assets/                              ←   preview assets
│   │   ├── assets/                                ←   应用资源
│   │   ├── scripts/                               ←   build scripts(沿用)
│   │   ├── electron/                              ←   主进程(.ts,0.0.3 砍 rung 1-4)
│   │   │   ├── main.ts                            ←   改:启动 banner "文枢" + window title "文枢"
│   │   │   ├── preload.ts                         ←   改:IPC channel 名称带 "wenshu" prefix
│   │   │   ├── bootstrap-runner.ts                ←   改:rung 5 装文枢版本
│   │   │   ├── backend-probes.ts                  ←   (沿用,验 venv 能 import)
│   │   │   └── ...                                ←   ~30+ 文件,所有 "Hermes" → "文枢" 字符串
│   │   ├── src/                                   ←   React + TS 前端
│   │   │   ├── app/
│   │   │   │   ├── updates-overlay.tsx            ←   (沿用,改:标题 "文枢更新")
│   │   │   │   ├── p0-1-frame/
│   │   │   │   │   └── BottomBar.tsx              ←   改:右下角显示 "文枢 v0.0.x"
│   │   │   │   ├── settings/                      ←   改:Settings 标题 + 标签 "文枢"
│   │   │   │   ├── chat/
│   │   │   │   ├── session/
│   │   │   │   └── about/                         ←   0.0.1 改:About 显示 "文枢 v0.0.1 · 基于 WenShu Agent v0.19.0 (MIT) 修改"
│   │   │   ├── components/                        ←   ~几十文件,所有 "Hermes" → "文枢"
│   │   │   ├── store/
│   │   │   ├── lib/
│   │   │   └── ...
│   │   └── release/                               ←   build 产物
│   │
│   ├── shared/                                    ← desktop 共享代码(改 brand)
│   └── bootstrap-installer/                       ← Python 引导安装器(改:装文枢版本)
│
├── agent/                                         ← Python agent 核心
│   ├── __init__.py                                ←   改:版本号 "wenshu 0.0.x"
│   ├── __main__.py                                ←   改:启动 banner "文枢"
│   ├── ...                                        ←   所有 "Hermes" → "文枢"
│
├── gateway/                                       ← FastAPI dashboard + WebSocket
│   ├── server.py                                  ←   改:Web UI 标题 "文枢"
│   ├── ...                                        ←   所有 "Hermes" → "文枢"
│
├── hermes_cli/                                    ← CLI 入口
│   ├── __init__.py                                ←   改:__version__ = "0.0.x"
│   ├── main.py                                    ←   改:命令输出 "文枢" 替换 "Hermes"
│   ├── ...                                        ←   所有 "Hermes" → "文枢"
│
├── acp_adapter/                                   ← ACP 协议适配器
├── acp_registry/                                  ← ACP 注册表
├── cron/                                          ← 定时任务
├── hermes_bootstrap.py                            ← Python venv bootstrap,改:默认装文枢版本
├── hermes_constants.py                            ← 改:HERMES_APP_NAME = "文枢"
├── hermes_logging.py                              ← 改:logger name = "wenshu"
├── hermes_state.py
├── hermes_time.py
├── cli.py                                         ← CLI 主入口,改:版本号 + 启动 banner
├── cli-config.yaml.example                        ← 改:注释 "文枢"
├── mcp_serve.py
├── model_tools.py
├── mini_swe_runner.py
├── batch_runner.py
├── infogrophic/
├── optional-mcps/                                 ← (可选 MCP)
├── optional-skills/                               ← (可选 skills)
├── contributors/
├── datagen-config-examples/
├── plans/
├── flake.lock / flake.nix
└── ...                                            ← 完整 monorepo,所有 Python 包
```

## 4. Modules(文枢视角)

文枢**自带**所有模块(沿用 hermes-agent monorepo),改的是 brand 字符串,不改业务逻辑:

| Module | 路径 | 职责 | 改/不改 |
|--------|------|------|---------|
| Backend Discovery | `apps/desktop/electron/main.ts` 改:rung 1-4 砍 | 自包含 venv 启动 | 0.0.3 砍 rung 1-4,只留 rung 5 = 装文枢自有 venv |
| Backend Spawn | `apps/desktop/electron/main.ts:createPythonBackend` | spawn 文枢自有 Python venv | 改:启动参数 `~/.wenshu/hermes-agent/venv/bin/python` |
| Bootstrap (Install) | `apps/bootstrap-installer/runBootstrap` | 装文枢自有 hermes-agent | 改:装文枢版本(0.0.x),不是通用 hermes |
| Backend Probe | `apps/desktop/electron/backend-probes.ts` | 验 venv 能 import yaml/dotenv/wenshu_cli | 改:探针测 `wenshu_cli` import,不是 `hermes_cli` |
| Updates Overlay | `apps/desktop/src/app/updates-overlay.tsx` | 文枢自我更新 UI | 改:标题 "文枢更新" |
| Statusbar | `apps/desktop/src/app/p0-1-frame/BottomBar.tsx` | 右下角版本号 | 改:"文枢 v0.0.x · 内核 Hermes 0.19.0" |
| Window Title | `apps/desktop/src/app/.../App.tsx` | 窗口标题 "文枢" | 0.0.1 改 |
| About | `apps/desktop/src/app/about/...` | About 页面 | 0.0.1 改:"文枢 v0.0.1 · 基于 WenShu Agent v0.19.0 (MIT) 修改" |
| Settings | `apps/desktop/src/app/settings/...` | Settings 页面 | 0.0.2 改:标题 + 标签 |
| CLI 主入口 | `cli.py` + `hermes_cli/main.py` | CLI 命令 | 改:启动 banner + 版本号 + 输出文案 |
| Gateway Web UI | `gateway/server.py` | FastAPI dashboard | 改:Web UI 标题 "文枢" |
| Agent 核心 | `agent/` | Python agent | 改:brand 字符串 |
| 跟上游漂移 | `wenshu-patches/`(PM 维护) | patch series | PM 维护,CC 跑三方 merge |

## 5. Web/IPC 接口(文枢特有 + 沿用)

文枢**改** IPC + bridge channel 名称(加 "wenshu" prefix),业务逻辑沿用 hermes:

| 接口 | 路径 | 用途 |
|------|------|------|
| `window.wenshuDesktop.updates.*` | `apps/desktop/src/preload.ts` 改 | 文枢自我更新(0.0.2 改) |
| `window.wenshuDesktop.updates.check()` | 同上 | 查更新 |
| `window.wenshuDesktop.updates.apply()` | 同上 | 装更新 |
| `window.wenshuDesktop.getVersion()` | 同上 | 读版本(返回 "wenshu 0.0.x") |
| `window.wenshuGateway.*` | 同上 改 | 接文枢自有 gateway(0.0.2 改) |

详细 IPC schema: `apps/desktop/src/global.ts` + `apps/desktop/src/preload.ts`(0.0.2 工单改 brand)

## 6. Project Conventions

- **代码风格**:沿用 hermes-agent 现有 ESLint + TypeScript config(**不动**)
- **测试**:沿用 hermes-agent 现有 vitest/jest 框架(**不动**)
- **Git**:沿用 novel-platform/h Hermes-Slate-Desk 现有 husky + commitlint(如果已配,**不动**)
- **不要新增** ESLint / vitest / 测试配置 — 沿用现有

## 7. Security(CC 必读,源自 AGENTS.md §7)

- **不复用即错**:任何项目侧(文枢)不准硬塞 hermes gateway 端口 / base_url / provider / API key / MoA / UI 预设
- **配置只在** `~/.wenshu/hermes-agent/config.yaml`(文枢独立配置,**不读 `~/.hermes/profiles/default/config.yaml`**)
- **客户侧只读不写**
- **端口动态查询**:启动时查文枢自有 venv 暴露的查询接口,不写死
- 文枢 APP 启动时**必须**查自己 venv 当前端口(端口每次重启会变)
- **跟本机 hermes 切割**:文枢不读 `~/.hermes/hermes-agent/`,不复用本机 hermes 任何数据

## 8. Verification(CC 写完代码必跑)

```bash
# monorepo 根
cd /Volumes/ANAN/Engineering/wenshu

# Python 部分(pyproject.toml 改了之后)
pip install -e .
python -m pytest

# Electron desktop 部分
cd apps/desktop
pnpm install
pnpm type-check                            # TypeScript
pnpm lint                                 # ESLint
pnpm build                                # Vite build
pnpm test                                 # vitest 跑测试
pnpm electron-builder --mac --config electron-builder.json  # 出 .dmg

# 验证品牌重塑(0.0.2 完成后)
grep -r "Hermes" --include="*.py" --include="*.ts" --include="*.tsx" --include="*.json" --include="*.cjs" --include="*.md" . 2>&1 | head -20
# 期望:0 命中(代码区)/ 只在 LICENSE / 上游引用 / commit hash 处出现
```

## 9. Project Baseline Context(CC 必读)

> **本节最重要,CC 接到任务必先读**

文枢 = Hermes monorepo 深度改 fork + 改名。**禁止**:
- ❌ 带 novel-platform Tauri / Rust / SQLite / Vue 3 痕迹
- ❌ 改 hermes-agent 业务逻辑(改 brand 字符串 ≠ 改业务)
- ❌ 复用 hermes 上游 4-tier ladder rung 1-4(本机检测)— 0.0.3 砍,只留 rung 5
- ❌ 连用户本机 `~/.hermes/hermes-agent/` — 文枢不读本机 hermes
- ❌ 自己写 desktop shell / 改 hermes-agent 业务代码 / 改 Python hermes-cli 业务
- ❌ 改 LICENSE 文本(CC 严禁,改 = 升级老板)
- ❌ 改 4-tier ladder rung 数量在 0.0.3 工单外(其他工单内改 = 越界)
- ❌ 动 `/Users/anbaiqiang/.hermes/` 或 `/Volumes/ANAN/.hermes/`(hermes 端边界外)
- ❌ 改 monorepo 跟上游同步节奏(改 = 升级老板)
- ❌ 重生成签名密钥(沿用现有)

**CC 改的 4 个 metadata 字段(0.0.1 工单)**:
- `apps/desktop/package.json` → `name=wenshu`, `productName=文枢`, `version=0.0.1`, `build.appId=com.wenshu.app`
- `apps/desktop/src/app/.../App.tsx` 或 window 配置文件 → `title="文枢"`
- `apps/desktop/src/app/about/...` → About 显示 "文枢 v0.0.1 · 基于 WenShu Agent v0.19.0 (MIT) 修改"
- `LICENSE` → 在原 MIT 块下追加 "文枢 (Wenshu) modifications copyright (c) 2026 安百强"

**CC 改的全 monorepo 字符串(0.0.2 工单)**:
- 所有 `Hermes` / `hermes-agent` / `hermes_agent` / `HERMES` 字符串 → `文枢` / `wenshu` / `wenshu` / `WENSHU`
- **保留不动的**:
  - upstream URL `github.com/NousResearch/hermes-agent`
  - commit hash 引用(在 CHANGELOG / 注释里)
  - LICENSE 文件里的 "Copyright (c) 2025 Nous Research" 原文
  - 任何"基于 WenShu Agent v0.19.0" 的鸣谢文案

**CC 改的 4-tier ladder(0.0.3 工单)**:
- `apps/desktop/electron/main.ts:resolveHermesBackend()` 砍 rung 1-4
- 只留 rung 5 = `apps/bootstrap-installer/runBootstrap` 装文枢自有 venv
- 启动时不再检测本机 `~/.hermes/hermes-agent/`,文枢只用自包含内核

## 10. References

- 真理源:`AGENTS.md`(角色边界/派单/客户侧硬约束/评论 SLA/升级/跟上游漂移)
- 项目门面:`README.md`
- PM 硬约束:`LOOP-CONSTRAINTS.md`(待 PM 创建)
- 跟上游漂移工作流:`AGENTS.md §10`
- 上游基线:`/Volumes/ANAN/.hermes/hermes-agent/`(本机已装的 hermes-agent 备份,仅参考,不动)
- Hermes-agent 上游:`https://github.com/NousResearch/hermes-agent`
- Hermes-agent 0.19.0 tag:`v2026.7.20` (commit `3ef6bbd20`)
- 文枢仓库:`https://github.com/ZIYU-FUI/wenshu`
- 本机文枢:`/Volumes/ANAN/Engineering/wenshu/`
- 文枢自有 venv:`~/.wenshu/hermes-agent/`(用户机器上,**不归文枢 app 装,文枢 spawn 起来**)
- 本机 hermes:`~/.hermes/hermes-agent/`(**文枢不读,不污染**)

---

*CLAUDE.md v0.1 · 2026-07-23 18:55 项目基线 0.0.0 · 改自 NousResearch/hermes-agent v0.19.0 (tag v2026.7.20) · 仓库 = `github.com/ZIYU-FUI/wenshu`*
