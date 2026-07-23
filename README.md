# 文枢 (Wenshu)

> **Hermes Agent v0.19.0 深度改 fork** · Electron + React + TypeScript + Python + 自包含 hermes 内核
> 老板(出资方):安百强 · 状态:**P0 项目基线(2026-07-23 拍板)** · 策略:**完全改源码实现文枢 + 跟上游漂移 + 单任务单一功能 + 打 .app 给老板试用验收**

---

## 1. 是什么

**文枢 = Hermes Agent v0.19.0 深度改 fork**。在 NousResearch/hermes-agent 0.19.0(tag `v2026.7.20`,commit `3ef6bbd20`)基础上**全面改源码**,把 "Hermes" 全部替换成 "文枢",鸣谢 + About 体现 MIT 开源协议 + 致敬 Nous Research,代码层完全独立,跟上游长期漂移。

**核心承诺**(2026-07-23 老板拍板):
- **不复用用户本机 hermes** — 文枢 .app **自包含 hermes 内核**,不读本机 `~/.hermes/hermes-agent/`,用户装一次文枢就有独立完整的 hermes 环境
- **完全改源码** — 不走 "fork + 改 4 个 metadata" 路线,深度改:品牌名 / 产品名 / appId / 文案 / Settings / About / README 鸣谢 / LICENSE 标注 全部替换
- **跟上游漂移** — hermes 上游每月 1-3 次 release(实测 GitHub Releases),文枢每次手动 cherry-pick + 三方 merge(ours/theirs/wenshu-patches),用户用老内核是常态,大版本跳变有滞后
- **文枢项目仓库独立** — `github.com/ZIYU-FUI/wenshu`(取代 `gitee.com/zi-yu1983/novel-platform`),从 `git@github.com:NousResearch/hermes-agent.git` upstream fork,版本号从 `0.0.0` 开始

文枢基于 Hermes Agent v0.19.0 (MIT) 深度改 fork。
原作者 © 2025 Nous Research, 文枢修改 © 2026 安百强。
上游: https://github.com/NousResearch/hermes-agent

## 2. 不是什么

- ❌ **不是 Tauri** — 文枢 = 文枢 Electron 桌面 app(沿用上游 `apps/desktop` Electron + React + TypeScript stack,改的是品牌 + 资源 + 文案)
- ❌ **不是 4 栏布局** — 沿用 hermes app 现有 UI 布局(Updates overlay / Command palette / Right sidebar / Settings),**视觉和交互跟上游一致**,只改产品名和 logo
- ❌ **不是 sparse clone** — 0.0.0 项目基线是 monorepo 完整 fork(`apps/desktop` + `apps/shared` + `apps/bootstrap-installer` + `agent/` + `gateway/` + `hermes_cli/` + `cli.py` + 全 monorepo),**不是 apps/desktop 单子目录 sparse**
- ❌ **不是连本机 hermes** — 上游 4-tier ladder(HERMES_DESKTOP_HERMES_ROOT / SOURCE_REPO_ROOT / bootstrap / PATH / install.sh)**整段砍掉**,文枢只用自己的自包含内核
- ❌ **不是 novel-platform** — `zi-yu1983/novel-platform` Gitee 仓库已 rename 成 `zi-yu1983/wenshu`(同步),ANAN 本机 `/Volumes/ANAN/Engineering/novel-platform/` 是历史包袱(7/16 Tauri + Vue 3 时代已重启),不动也不 push

## 3. 架构

```
文枢 (文枢 monorepo fork, Electron + React + TypeScript + Python)
├── apps/desktop/              (Electron 桌面 app,改 name=文枢 + productName=文枢 + appId=com.wenshu.app)
│   ├── electron/              (主进程,main.cjs / preload.cjs / bootstrap-runner.cjs — 改:4-tier ladder 砍掉 rung 1-4,只留 rung 5 = 自包含内核)
│   ├── src/                   (React + TS 前端,改:About 组件文案 / Settings 标题 / 启动页 logo)
│   └── package.json           (改:name=文枢, productName=文枢, appId=com.wenshu.app, version=0.0.x)
├── apps/shared/               (desktop 共享代码,沿用)
├── apps/bootstrap-installer/  (Python 引导安装器,改:装文枢自有内核,不是 hermes 通用内核)
├── agent/                     (Python agent 核心,改:产品名 + 启动 banner + About 文本)
├── gateway/                   (FastAPI dashboard + WebSocket,改:Web UI 标题 + 启动页)
├── hermes_cli/                (CLI 入口,改:命令输出 "文枢" 替换 "Hermes")
├── cli.py                     (CLI 主入口,改:版本号 + 启动 banner)
├── hermes_bootstrap.py        (Python venv bootstrap,改:默认装文枢版本)
├── hermes_constants.py        (常量,改:HERMES_APP_NAME = "文枢")
├── pyproject.toml             (改:name=wenshu, version=0.0.x, description, author)
├── LICENSE                    (改:在 MIT 块下追加 "文枢 (Wenshu) modifications copyright (c) 2026 安百强")
└── README.md                  (本文件,改:鸣谢 NousResearch/hermes-agent)
```

**文枢 = 完整 monorepo fork,不是单个 app**。所有 Python 包、CLI、gateway、agent 核心、bootstrap-installer、desktop app,**全部要改 "Hermes" → "文枢"**(不只是 desktop app)。

## 4. 阶段目标

| 阶段 | 目标 | 状态 |
|------|------|------|
| **0.0.0** | 项目基线 = 0.0.0.0 文档交付(README/AGENTS/CLAUDE 落档,本地 commit 0.0.0) | 🔄 当前 |
| **0.0.1** | LICENSE 合规(0.0.0.1 工单:改 productName + appId + About 鸣谢 + README 鸣谢 + LICENSE copyright 追加 + commit "chore(wenshu): 0.0.0.1 LICENSE 合规" + push origin main) | ⏸ 待派 PM |
| **0.0.2** | 品牌重塑(全 monorepo 字符串替换 文枢 → 文枢,Settings / About / 启动页 / logo / 启动 banner / 命令输出 / CLI 文案 全部到位) | ⏸ |
| **0.0.3** | 砍 4-tier ladder rung 1-4(只剩 rung 5 = 自包含内核,启动时不再检测本机 hermes) | ⏸ |
| **0.0.4** | 跑通 build(pnpm install + pnpm build + electron-builder --mac,出 文枢.app + 文枢.dmg) | ⏸ |
| **0.0.5** | 装到 /Applications/文枢.app + 启动验证(自包含内核起来,About 显示 "文枢 v0.0.x · 基于 Hermes Agent v0.19.0 (MIT) 修改") | ⏸ |
| **0.1.0** | PM↔CC 单 loop 跑加功能(每个任务 = 单一功能 + 打 .app 给老板试用验收) | ⏸ |
| **0.2.0+** | 跟上游漂移(hermes 0.20.0 release 时,cherry-pick + 三方 merge) | ⏸ |

## 5. 范围

**包含**:
- ✅ 完整 monorepo fork(所有 Python + Electron + React 代码)
- ✅ LICENSE 合规(改 productName + appId + About + README 鸣谢 + LICENSE copyright 追加)
- ✅ 品牌重塑(全 monorepo "Hermes" → "文枢" 字符串替换)
- ✅ 砍 4-tier ladder rung 1-4(只留 rung 5 = 自包含内核)
- ✅ 跑通 build + 出 .app
- ✅ PM↔CC 单 loop 跑加功能
- ✅ 跟上游漂移(hermes 上游新 release → PM 三方 merge)

**不包含**(避免范围漂移):
- ❌ 不连用户本机 hermes(`~/.hermes/hermes-agent/`)
- ❌ 不复用 hermes 上游 4-tier ladder rung 1-4(本机检测)
- ❌ 不改 hermes Python venv 的核心逻辑(我们改品牌 + 资源,不改业务)
- ❌ 不带 novel-platform Tauri / Rust / SQLite / Vue 3 痕迹
- ❌ 不复用 novel-craft / 旧 Slate-Desk 旧 V0.5.1/V0.5.4 协议
- ❌ 不动 `/Users/anbaiqiang/.hermes/`(hermes 端是出资方 7/9 §11 边界外)
- ❌ 不用 hermes 上游 `apps/desktop` 的 0.17.0 子版本号(我们从 0.0.0 重新起)

## 6. 关键决策(已拍)

| 决策点 | 拍板 | 时间 | 备注 |
|--------|------|------|------|
| **完全改 hermes 源码**(方案二) | 老板 | 2026-07-23 15:25 | 不走方案一(整体内核化 + 双层更新),直接深入改 |
| **不复用用户本机 hermes** | 老板 | 2026-07-23 15:25 | 文枢 .app 自包含内核,无论用户本机有没有 hermes |
| **锁 0.19.0 tag 起步** | 老板 | 2026-07-23 16:48 | `v2026.7.20` tag = 文枢 0.19.0(commit 3ef6bbd20),先稳再升 |
| **项目仓库 = github.com/ZIYU-FUI/wenshu** | 老板 | 2026-07-23 18:55 | 取代 Gitee `zi-yu1983/novel-platform`(已 rename) |
| **upstream = github.com/NousResearch/hermes-agent** | 老板 | 2026-07-23 16:34 | fork 关系,跟上游漂移 |
| **版本号从 0.0.0 开始** | 老板 | 2026-07-23 15:25 | 不用上游 `apps/desktop` 的 0.17.0 子版本,文枢独立版本 |
| **LICENSE 合规 = 0.0.0.1 第一工单** | 老板 | 2026-07-23 16:22 | 改 4 文件,改完才 push origin main |
| **3 文档策略 = 完全改源码重写** | 老板 | 2026-07-23 16:22 | 不再沿用 sparse clone 假设,以 monorepo 真实结构重写 |
| **跟上游漂移工作流** | 老板 | 2026-07-23 15:25 | 每月 1-3 次 hermes release,PM 三方 merge(ours/theirs/wenshu-patches) |
| **PM↔CC 单 loop 拍单原则** | 老板 | 2026-07-23 | 沿用 v0.6.0(详见 AGENTS.md §4) |
| **单任务单一功能 + 打 .app 给老板验收** | 老板 | 2026-07-23 15:25 | 沿用 novel-platform 7/10 18:14 拍板 |

## 7. 系统总览

```
┌──────────────────────────────────────────────────────────────┐
│  文枢 (Electron 主进程 + Python 内核)                          │
│  ┌──────────────────────┬───────────────────────────────┐   │
│  │  Renderer (React)    │  Preload (preload.ts)          │   │
│  │  - 文枢 Updates UI   │  - hermesDesktop.updates.*     │   │
│  │  - 文枢 Settings     │  - hermesDesktop.gateway.*     │   │
│  │  - 文枢 About        │  - hermesDesktop.process.*     │   │
│  │  (视觉跟 hermes 同)   │  (改 productName 显示)         │   │
│  └──────────┬───────────┴────────────┬──────────────────┘   │
│             │  IPC                     │                     │
│  ┌──────────▼─────────────────────────▼──────────────────┐   │
│  │  main.cjs 改:rung 1-4 砍,只留 rung 5 = 自包含内核     │   │
│  │  apps/bootstrap-installer/runBootstrap(改:文枢版本)    │   │
│  └────────────────────────────────────────────────────────┘   │
└─────────────────────────┬────────────────────────────────────┘
                          │ spawn 文枢自有 Python venv
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  文枢自有 ~/.wenshu/hermes-agent/ (Python venv,自包含)        │
│  - hermes_cli / cli.py / hermes_bootstrap / agent / gateway  │
│  - 文枢独立配置(不读本机 ~/.hermes/hermes-agent/)             │
│  - memory / skills / kanban DB(归文枢,本机 hermes 不动)        │
└──────────────────────────────────────────────────────────────┘
                          ↓
              (跟上游 hermes-agent 0.19.0 fork,跟版本漂移)
                          ↓
┌──────────────────────────────────────────────────────────────┐
│  upstream github.com/NousResearch/hermes-agent (0.19.0)      │
│  - 月度 1-3 次 release(实测 v0.18.1→0.18.2=1 天,v0.18.0→0.19.0=19 天)│
│  - PM↔CC 三方 merge(ours / theirs / wenshu-patches)          │
│  - 滞后 1-3 周(小版本) / 1-2 月(大版本)                       │
└──────────────────────────────────────────────────────────────┘
```

## 8. 部署架构

- **开发环境**:本地 macOS + pnpm 11 + Node 20 + Electron + Python 3.11-3.14
- **测试环境**:本地 `pnpm build` + `electron-builder --mac` → `apps/desktop/release/mac-arm64/文枢.app`
- **生产环境**:
  - 桌面:`文枢.app` 装到 `/Applications/文枢.app`
  - 分发:`文枢_<version>_aarch64.dmg` 推到 `github.com/ZIYU-FUI/wenshu/releases`
  - 内核自包含:`~/.wenshu/hermes-agent/`(用户主目录,文枢私有,**不污染 `~/.hermes/`**)

## 9. 协作规则(出资方 7/9-7/23 拍)

- **PM ↔ CC**:单 loop 跑实现(≤ 4 在跑卡,出资方 v0.5.25 拍板放宽)。老板不在 loop 内,PM 自驱。详见 `AGENTS.md §4`
- **跟上游漂移**:维护性任务,每月触发(hermes upstream release),不阻塞 P0/P1 阶段门控,但 PM 每周同步一次进度。详见 `AGENTS.md §10`
- **AIF**:出 3 类项目文档 + 落档 + 派 PM → 退场。**AIF 派完不进 PM↔CC loop**
- **老板(出资方 安百强)**:在阶段门控节点(0.0.0 / 0.0.1 / 0.1.0 / ...)出现,看产品反馈,飞书会纠偏(均 loop 外)
- 派单原则 / 拍单边界 / 评论 SLA / 升级路径 = 真理源 `AGENTS.md`

## 10. 跟上游漂移工作流(出资方 7/23 拍)

文枢 = hermes-agent fork,跟上游漂移是必然(每月 1-3 次 release,实测数据见 AGENTS §10 风险表)。

**漂移流程**:
1. PM 监测 `upstream/main` 新 commit / 新 release tag(GitHub watch + RSS + cron)
2. PM 拉新 release → 跟当前文枢 fork diff
3. PM 评估:哪些改动影响文枢的 "文枢 → 文枢" 字符串替换 / appId / brand?
4. PM 拆工单,CC 跑三方 merge(ours / theirs / wenshu-patches)
5. PM 验证 .app 起来 + 主流程 + About 显示版本正确
6. PM 同步老板(每周/每月一次)

**滞后周期**(实测估算):
- 小版本(0.18.x → 0.18.x+1):**1-3 周**(PM-direct 投入 4-8h,CC 0-8h)
- 大版本(0.x → 0.x+1):**1-2 月**(PM-direct 1-3 天,CC 1-3 天)

**用户用老内核是常态**,关键缓解:
- About 显示文枢版本 + 标注 "基于 Hermes Agent v0.19.0 (MIT)"
- 用户用 .app 时会知道当前是 0.0.x + 内核 0.19.0,内核升级滞后是产品设计的一部分

## 11. 关键路径速查

```
/Volumes/ANAN/Engineering/wenshu/                  ← ACTIVE(文枢项目根,0.0.0 项目基线)
├── README.md                                      ← 本文件(项目门面)
├── AGENTS.md                                      ← 协作规则真理源(v0.1)
├── CLAUDE.md                                      ← CC 项目记忆(v0.1)
├── pyproject.toml                                 ← Python monorepo(name=wenshu 改完)
├── LICENSE                                        ← MIT(0.0.1 追加文枢 copyright)
├── package.json                                   ← monorepo root
├── apps/
│   ├── desktop/                                   ← Electron 桌面 app(改 productName/appId)
│   ├── shared/                                    ← desktop 共享代码
│   └── bootstrap-installer/                       ← Python 引导安装器(改装文枢版本)
├── agent/                                         ← Python agent 核心(改 brand)
├── gateway/                                       ← FastAPI dashboard(改 Web UI 标题)
├── hermes_cli/                                    ← CLI 入口(改输出文案)
├── cli.py                                         ← CLI 主入口
└── ...                                            ← (完整 monorepo,所有 Python 包)
```

---

*文枢 v0.0 · 2026-07-23 18:55 出资方拍板"项目基线 · 改自 NousResearch/hermes-agent v0.19.0 (tag v2026.7.20)" · 仓库 = `github.com/ZIYU-FUI/wenshu`*
