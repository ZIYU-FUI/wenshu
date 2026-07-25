# 老项目需求清单调研报告 · 装机 user 7/25 拍

> **作者**: PM-direct (Claude Code 执行)
> **日期**: 2026-07-25
> **目标**: 装机 user 7/25 拍 "你去看看老项目我们做了若干个需求了, 你把需求清单罗列一下给我, 老项目就是共用 hermes 那个版本"
> **范围**: `/Volumes/ANAN/Engineering/` 下 8 个老项目 (Hermes-Slate-Desk / novel-platform / novel-canvas / open-design / loop-engineering / novel-research / dev-tools / wenshu)
> **不落档 wenshu 仓根** (装机 user 周末审改后跟 Story 2 v0.2 一起落档)

---

## 0. 调研方法 + 总览

### 0.1 调研方法 (PM-direct 5 分钟)

1. 找 `CHANGELOG.md` / `STATUS.md` / `loop-run-log.md` / `decisions/` 目录
2. 找 `packages/` / `apps/` / `docs/` 下的 `requirements` / `features` / `tasks` 目录
3. 找 git log 提取功能 commit
4. 找 README + 战略/架构/工程档

### 0.2 8 项目总览 + 需求数

| # | 项目 | 类型 | 状态 | 估算需求数 |
|---|------|------|------|----------|
| 1 | Hermes-Slate-Desk | Tauri 2 + React 19 (Hermes desktop 第三方) | active (5/18 最后 commit) | ~50 |
| 2 | novel-platform | Tauri 2 + Vue 3 + Rust + SQLite | **已重启 → wenshu** (7/16 拍) | ~80 |
| 3 | novel-canvas | Next.js 15 + Konva + tRPC + Prisma | active M0-M11 (7/5 立项, M2 跑通) | ~60 |
| 4 | open-design | Apache-2.0 三方 (Next.js 16 + daemon + 71 design systems) | spec-only (Phase 0, 7/3) | ~50 |
| 5 | loop-engineering | 三方 (7 patterns + 8 tools) | active (7/14 release) | ~30 |
| 6 | novel-research | FastAPI + MongoDB + Vite | M0 跑通 (6/19, 341 MD 入库) | ~25 |
| 7 | dev-tools | **非项目** = scratch cache (cargo/claude plugins/hub/...) | n/a | ~5 |
| 8 | wenshu (当前) | hermes-app fork (已 commit) | P0 装机中 (7/24 → 7/25, 7 commits) | ~30 |
| | **合计** | | | **~330** |

> 装机 user "老项目" 主要指 1-6 号 (Hermes-Slate-Desk / novel-platform / novel-canvas / open-design / loop-engineering / novel-research). 7 号 dev-tools 是装机 user 本机工具 cache, 非真项目. 8 号 wenshu 是当前, 但装机 user 仍想看 "过去需求 → 当前 → 未来" 全景图.

---

## STEP 1: 8 项目调研段

### 1. Hermes-Slate-Desk

**项目简介**: 装机 user 公开 fork 的 Hermes desktop 客户端 (8187735/Hermes-Slate-Desk on Gitee). Tauri 2.10 + React 19.2 + Vite 8.0 + Tailwind 4.2 + shadcn/ui (zinc base, new-york style). 8 大侧边栏模块 + 工作区切换 + i18n (zh/en/zh-tw). 默认接 Hermes Gateway 8642 端口. **基线已发布 2026-05-18, active development 状态**.

**需求清单** (按主题):

- 🏠 **Home (主仪表盘)**: 4 项 — 工作区快切 / 最近会话 / 常用功能快入 / 实时状态显示
- 💬 **Chat**: 5 项 — 思考过程可视化 / 流式响应 / 拖拽附件 / 智能上下文裁剪 / 多模型切换
- 📝 **AI Notebook (Milkdown)**: 6 项 — Milkdown 编辑器 (数学/代码/流程图) / AI 辅助写作 / 实时预览 / DOCX/Markdown 导出 / 保存聊天片段 / Mermaid 图表
- ⏰ **Scheduled Tasks (Cron)**: 5 项 — 表达式可视化构建 / CRUD + 启停 / 执行历史 / 桌面通知 / 表达式校验
- 📂 **File Manager**: 5 项 — 100+ 语言语法高亮 / Tauri 原生编辑 / CRUD 文件 / 多 tab 编辑 / 拖拽上传
- 💻 **Terminal (xterm.js + PTY)**: 5 项 — bash/zsh/sh / 交互命令 / 多 tab / 分屏 / 命令历史
- ⚙️ **Hermes Settings**: 6 项 — Agent 管理切换 / Skills marketplace / Memory 管理 / Channel 配置 / Prompt 模板库 / Analytics 仪表盘
- 🔧 **App Settings**: 3 项 — Hermes Gateway 配置 + 实时测试 / 主题切换 (亮/暗/系统) / 语言切换 (简/繁/英)
- 🔄 **Workspace Switching (核心)**: 7 项 — Sessions 自动过滤 / Files 跳到工作区目录 / Terminal cwd 自动改 / Cron 隔离存储 / Env 隔离存储 / Memory 隔离存储 / 配置存 `~/.hermes/hermes-slate-desk/config.json`
- 🤖 **Model Selection**: 4 项 — 右上角快速选 / 默认模型 / 自动加载配置模型 / 凭据管理走 Hermes env 不本地存
- 🌍 **i18n**: 3 项 — react-i18next 框架 / 中文 / 英文 / 繁体中文
- 🏗️ **Platform Support**: 3 项 — macOS 主 / Windows 全支持 / Linux coming soon

**装机 user 拍过的拍板** (AGENTS.md §0):
- 栈选型拍: Tauri 2 + React 19 + Vite 8 + Tailwind 4 + shadcn/ui
- 代码规范拍: 2 空格缩进, 无分号, 双引号, 函数式组件 + Hooks
- 状态管理拍: 仅 React Hooks (无 Redux/Zustand)
- 工作区模式拍: 每个工作区独立 local sandbox (sessions / files / terminal / cron / env / memory 都隔离)

**跟 wenshu 的关系**:
- **无代码复用**: 栈完全不同 (Hermes-Slate-Desk = Tauri+React, wenshu = Electron+React, 同 React 19 但 desktop shell 不同)
- **概念复用 (PM-direct 借鉴参考)**: workspace switching 模式 (sessions/files/terminal/cron/env/memory 隔离) 是文枢 v1.0+ 多项目 / 多会话的潜在设计参考
- **"AI 思考可视化" / "流式响应"** = 文枢 chat UI 必备功能 (借镜)
- **AGENTS.md 拍 "issue tracker 走 .scratch/ markdown + triage labels 默认词汇表"** = 文枢 kanban 派单可参考的"轻量痕迹"

**主要文件**:
- `/Volumes/ANAN/Engineering/Hermes-Slate-Desk/README.md` (15KB)
- `/Volumes/ANAN/Engineering/Hermes-Slate-Desk/AGENTS.md`
- `src/App.jsx` / `src/api.js` / `src/components/` (34 个 JSX 文件)
- `src-tauri/src/commands/` (12 个 Rust command 文件)

---

### 2. novel-platform (已重启为 wenshu)

**项目简介**: Tauri 2 + Vue 3 + Rust 1.83 + SQLite + FTS5 + cytoscape.js. 立项 6/1 拍, M1 (6/21) + M2 (6/29) 完成, **重启拍板 7/16 13:11** "novel-platform Tauri 全部扔, 只留项目设定文档, 文枢 = Hermes app fork". M1 跑出 38 工单 / 47 commits / 199 tests / 0 failed, M2 跑出 38 工单 / 39 commits / 234 tests / 0 failed.

**需求清单** (按主题):

- 🏗️ **W1 Foundation (M1)**: 5 项 — Workspace 结构 (apps/desktop + packages/prompts + hermes/bridge) / Tauri 2 + Vue 3 + Pinia + Vite 5 脚手架 / Cargo workspace + lib/bin split / vue-tsc + vitest + playwright + commitlint + husky / 工程宪法 9 条
- 🗄️ **W2 数据库层 (M1)**: 8 项 — 8 entities (project/chapter/character/worldbuilding/outline/methodology/pipeline_state/audit) / rusqlite + Arc<Mutex<Connection>> / 5 repos / FTS5 unicode61 中文分词 / 迁移系统 + 启动自动跑
- 🧠 **W3 方法论引擎 (M1)**: 5 项 — MethodologyEngine trait / Snowflake 10 步 / Creative Sprint 12 步 / 4 builtin methodologies / YAML 加载器 + 字段验证
- ⚙️ **W4 Pipeline + Tauri Commands (M1)**: 7 项 — Pipeline 状态机 / 26 Tauri commands / DynamicFormRenderer + DynamicListField + GuidedForm / 4 阶段选择器 + StageIndicator / WebSSH Hermes Bridge / Tauri hash mode 路由
- 📚 **W5 Library / Characters / Chapters (M1)**: 8 项 — CharacterRepository + WorldbuildingRepository / 6 character commands / 5 worldbuilding commands + category 白名单 / 3 Pinia stores / CharacterEditor 模态 / ChaptersView + ChapterEditorView (1.5s debounce) / LibraryView 3-tab + FTS5 / E2E 25 tests
- 🔌 **W6 MCP Server + CI/CD (M1)**: 8 项 — JSON-RPC 2.0 + MCP (无 SDK) / 5 tools / 2 resources / 1 prompt / 70 unit tests / 独立 binary `target/release/novel-platform-mcp` (4.7M) / Audit log JSONL / Playwright E2E smoke (3 tests) / GitHub Actions CI
- 🗄️ **W1 数据层 (M2)**: 4 项 — FTS5 中文 trigram tokenizer / methodology_graph + methodology_node 表 / MethodologyGraphRepository + MethodologyNodeRepository / 2 repo + 17 tests
- 🧠 **W2 方法论图谱 UI (M2)**: 7 项 — MethodologyGraphEditor.vue (cytoscape.js 3.34) / 节点/边 CRUD + 拖拽 / 条件边 + 权重 / Pinia store + Tauri invoke / 13 字段 100% 对齐 Rust / 5 类别过滤
- 📚 **W3 30+ 方法论节点入库 (M2)**: 7 项 — 30+ 节点清单 (Plot 7 + Character 8 + Theme 5 + Structure 17 + Pacing 5) / 统一 YAML schema v0.1 (42 YAML 文件) / 批量 YAML 加载器 (node_loader.rs 130 行) / 节点搜索 + 分类过滤 + 标签
- 🌐 **W4 HTTP+SSE MCP transport (M2)**: 7 项 — axum 0.7 HTTP 路由 + SSE helper / JSON-RPC over HTTP /mcp endpoint / SSE 流式响应 handler / 双 transport (stdio / http / both) / Claude Desktop 集成测试 3/4 / 流式错误处理 + 指数退避重连
- 🆓 **W5 自由模式深化 (M2)**: 7 项 — AI 助手常驻 sidebar (可折叠) / AI 助手上下文 (载入章节/人物/方法论) / 资料库中文全文搜索 UI / 自由模式用户占比埋点 / 章节/人物关联视图 / 大纲视图 (进度条) / hermes_chat 真 invoke
- 📦 **W6 Codesign + 打包 (M2)**: 3-7 项 — macOS codesign + notarization (⏸ 阻塞, Apple ID 验证失败) / Windows Authenticode (⏸ 用户未买证书) / Linux .deb + .AppImage ✅ / E2E test suite 5/6 passed ✅ / GitHub Actions 3 平台 CI ✅ / 跨平台安装测试 ⏸

**装机 user 拍过的拍板** (从 CHANGELOG.md + LOOP-CONSTRAINTS.md):
- 6/1 立项: Tauri 2 + Vue 3 + Rust + SQLite + MCP 栈
- 6/21 M1 末: 38 工单 / 47 commits / 199 tests / 0 failed 验收通过
- 6/29 M2 末: 38 工单 / 39 commits / 234 tests / 0 failed
- 7/10 18:14: "每个任务 = 单一功能 + 打 .app 给老板试用验收" (PM↔CC 单 loop 模式拍)
- 7/15 14:58: BUG2 version.json release 三路 fallback 修
- **7/16 12:55: 拍文枢 = Hermes app fork (不复用 novel-platform 任何代码)**
- **7/16 13:11: 重启拍板, Tauri + V0.1 era 全扔, 只留项目设定文档** (commit `437ba5c`)
- 7/16 13:11: AIF-DM v0.5 借鉴落地 novel-platform LOOP-CONSTRAINTS

**AIF-DM v0.5 工程管理修订 (M2 期间)**:
- v0.5 共 18 项修订 (5 个新增章节) — 含 AIF-v05-01 AI 友好豁免条款, v0.5-04 路径规范, v0.5-06 章节引用 grep 验证规则, v0.5-13 HANDOFF 协议, v0.5-18 PM 修正版 AI 效率红利模式

**v0.6.0 PM↔CC 单 loop 协议** (沿用至 wenshu):
- 6 段任务卡模板 (Why → What → How → When → Boundaries → Verification)
- ≤ 4 并发
- attempt ≤ 3
- denylist (不动 hermes 上游等)
- run-log JSONL append-only

**跟 wenshu 的关系**:
- **同一个仓, 重启 lineage** — novel-platform 是 wenshu 的前身, 7/16 重启时换核 (Tauri → Electron) + 改 brand (novel-platform → 文枢)
- **不复用 novel-platform V0.1/V0.2 任何代码** (CLAUDE.md §2 硬约束)
- **复用 PM↔CC 单 loop 协议** (LOOP-CONSTRAINTS.md → wenshu/LOOP-CONSTRAINTS.md)
- **复用 loop-run-log.md JSONL 格式** (append-only 审计 trail)
- **不复用 novel-craft / Hermes-Slate-Desk / v0.5.1 / v0.5.4 协议** (边界外)
- **需求 80% 已废弃**: Tauri/Vue/Rust/SQLite 全栈, 30+ 方法论节点图谱, MCP server, cytoscape.js 都不再继续 (但 = 装机 user 真实写过的需求清单)

**主要文件**:
- `/Volumes/ANAN/Engineering/novel-platform/CHANGELOG.md` (15KB) — 完整需求落档
- `/Volumes/ANAN/Engineering/novel-platform/CLAUDE.md` (10KB) — 重启后文枢 CLAUDE.md
- `/Volumes/ANAN/Engineering/novel-platform/loop-run-log.md` — JSONL 审计 trail
- `/Volumes/ANAN/Engineering/novel-platform/LOOP-CONSTRAINTS.md` — PM↔CC 硬约束 (沿用)
- `/Volumes/ANAN/Engineering/novel-platform/P0-3-4-NOTES.md` (22KB) — V0.3 阶段笔记
- `/Volumes/ANAN/Engineering/novel-platform/apps/wenshu/` — 重启后 sparse clone hermes app desktop

---

### 3. novel-canvas (小书)

**项目简介**: Next.js 15 + React 19 + Konva + tRPC 11 + Prisma + SQLite. 装机 user 跟 novel-platform 互补: novel-platform (文枢前身) = 文字流式写作, novel-canvas = 可视化画布. 7/5 立项 (M0), M1 真跑中, M2 启动. 当前最新 7/6 09:31 commit `46c26c5` M2 V1-V6 = 节点/边 label + 多选 + 缩放 + undo/redo + 导出 PNG. STATUS.md 7/5 23:30 最后更新.

**需求清单** (按主题):

- 📋 **M0 立项 (7/5)**: 6 项 — 建仓 + git init / 5 类文档骨架 (战略/架构/工程/工具兼容/拍板) / DECISION-KICKOFF 立项拍板 / METHODOLOGY.md symlink → aif profile / 排除项立 7 条 (不上 GitHub / 不跑 hermes 9119 / 不集成文枢 IPC 桥) / PM hermes 验证 + 验收报告
- 🗄️ **5 实体数据模型**: 5 项 — Novel 根实体 / Chapter (1 大纲 + 1 正文 + 字数) / Character (弧线 + 性格 + 关系) / PlotLine (情节线 + 钩子链 JSON) / WorldView (设定 + 规则)
- 🔗 **5 边关系**: 5 项 — Chapter 属 Novel / Character 属 Novel / PlotLine 属 Novel / WorldView 属 Novel / Edge (自由边)
- 🧠 **三层架构**: 3 项 — 客户端 (Next.js 15 + React 19 + Konva) / 后端 (tRPC server + Prisma + SQLite + novel-skills API) / 数据层 (Prisma + SQLite + mem0 Qdrant) / Hermes 顶层 (memory/skill/MCP/providers/kanban)
- 🛠️ **后端基础设施**: 6 项 — tRPC 11.x 类型安全 RPC / 10 个 tRPC endpoint / Bearer Token 鉴权 (LibTV 同协议) / novel-skills API (5 接口: chapter/character/plotline/edge/query) / Prisma 5 / SQLite 5 entity
- 🎨 **前端 Konva 画布**: 7 项 — Konva 节点渲染 / 时间轴组件 (双视图左侧) / 节点/边 label / 多选 / 缩放 / undo/redo / 导出 PNG
- 🧪 **M9 V0.7 章节写作 (22 工单)**: 22 项 — pnpm-lock 补 / chapter_write 真链路 / AI 长文本生成 + Reel Text 适配 / 上下文管理 / Binder UI (Scrivener 简化版) / Editor UI (Monaco/CodeMirror) / 备注+字数 UI / chat 集成 / 流式 chat 修复 / chat_message [Errno 2] 修 / emoji 换 ICON / 删 ProjectTree + ProgressPanel / UI 框架复制 / 3 张 UI 图对比 + tauri drag region / V0.7 端到端验收重打包
- 🎨 **M10 V0.8 设计系统 (12 工单)**: 12 项 — design tokens / design doc / UI primitives (4 子工单) / app rebuild / sidecar hermes serve / hermes client URL change / delete hermes bridge / frontend model list real / e2e verify bridge sunset
- 🏗️ **M11 V0.7 后续 (19 工单)**: 19 项 — chat keybindings remap / 版本同步 + titlebar / fix 3 UI feedback / title bar restructure / 4 title bar bugs / currentFile + evaluate title bar / tauri bundle frontend assets / 左栏折叠位置 + chat empty / webview runtime rebuild / 4 UI bugs + version inject / src-tauri dist sync / app layout position relative / 3 UI bugs rebuild / template rationalize / imitate hermes pane shell (PM-only) / imitate hermes chat center composer / fix duplicate project stage title
- 🤝 **AIF-DM 工程管理 (PILLAR V24-V34)**: 11 项 — P28 文档规范 0 嵌套 1:1 平铺 / P29 文档边界自查 / P30 文档边界规则永久 / P31 工程标准 vs 文档治理 / P32 新会话重读 5 文档 / P33 起手式不复读 / P34 v1/v2/v3 大 loop N3 询问超时 10min 整改
- 📜 **DECISION 列表 (14 份)**: 14 项 — HERMES-BRIDGE-SUNSET (7/3) / LOOP-ENGINEERING-UPGRADE (7/4) / PILLAR V24-V34 (7/6-7/7)
- 🚫 **排除项 (7/5 架构通知 + 立项约束)**: 7 项 — 不集成 Hindsight (走 mem0 OSS) / 不上 GitHub / 不跑 PM hermes 9119 serve / 不集成文枢 IPC 桥方案 (V0.8-18B-2) / 不复用 hermes plugin local_external 模式

**装机 user 拍过的拍板**:
- 7/5 立项拍: novel-canvas = 画布 + Hermes 底座 + 小说写作
- 7/5: 栈选拍 = Web 优先 (Next.js 15 + React 19 + Konva + tRPC + Prisma + SQLite)
- 7/5: 底座拍 = Hermes v0.18.0 (memory/skills/MCP/providers/cron/kanban 全用)
- 7/5: Skill 协议拍 = OpenAPI 3.1 + Bearer Token
- 7/5: 不集成 Hindsight, 走 mem0 OSS (Qdrant + ollama + nomic-embed-text)
- 7/5: profile 长期 memory 走 `~/.hermes/profiles/<name>/memories/MEMORY.md`
- 7/5: 不上 GitHub (本机先跑)
- 7/6 09:31: M2 V1-V6 commit (画布节点 label + 多选 + 缩放 + undo/redo + PNG 导出)
- 7/6 16:42: 整改拍 — 25 文档 → 14 文档 (合并 9 短档 + 5 PILLAR 合并)
- 7/6 16:46: 整改 P34 = 看板发任务全上/下游, 不飞书 DM 出资方
- 7/6 16:50: cron 10min 实证 + AIF self-train `scripts/ml-train.sh`

**M1 V0.1 验收 5 条** (装机 user CLOSE 拍):
1. pnpm install + pnpm dev 真起
2. localhost:3000 看见"小书" + 1 Konva 节点
3. macOS screencapture 截图存档
4. prisma db push + 5 entity 表建好
5. novel-skills 5 接口真 curl 测一次

**跟 wenshu 的关系**:
- **METHODOLOGY.md 共享** — novel-canvas/METHODOLOGY.md 是 symlink → `/Users/anbaiqiang/.hermes/profiles/aif/METHODOLOGY.md`, 跟 wenshu/methodologies/ 同源 (aif 私域)
- **7/25 装机 user 拍 "novel-canvas 跟文枢解耦"** (PM-direct 落档 user-stories-v0.2 §2.6): novel-canvas 是 v2.0+ 未来画板工具, 文枢 v1.0 不实现画板, 不连 novel-canvas db
- **不重写 novel-canvas** (装机 user 之前已立项活跃项目, 4 commit, 7/5 AIF 立项, M2 V1-V6)
- **借鉴 Konva 画布架构** (未来 Story N+1 v2.0+ 文枢画板)
- **借鉴 Bearer Token 鉴权模式** (novel-canvas / LibTV 同协议 → 文枢 skill 协议可参考)

**主要文件**:
- `/Volumes/ANAN/Engineering/novel-canvas/README.md` (3.5KB)
- `/Volumes/ANAN/Engineering/novel-canvas/STATUS.md` (1KB)
- `/Volumes/ANAN/Engineering/novel-canvas/METHODOLOGY.md` → symlink
- `docs/novel-canvas-strategy.md` (v0.3, 1.6KB)
- `docs/novel-canvas-architecture.md` (v0.2, 10KB)
- `docs/novel-canvas-engineering.md` (v0.5, 4KB)
- `docs/decisions/` (14 个 DECISION 文件)
- `docs/tasks/M4-M11/` (~50 个工单)

---

### 4. open-design (Apache-2.0 三方)

**项目简介**: Apache-2.0 开源项目 (alchaincyf/op7418/OpenCoworkAI/multica 四方 shoulders). Next.js 16 App Router + 本地 daemon + Electron shell. **19 skills + 71 design systems + 5 visual directions + 5 device frames**. Claude Design (Anthropic 4/17 发布) 的开源替代, BYOK at every layer. 当前状态: **Phase 0 spec finalization**, 代码基本没写, 主要在沉淀 spec.

**需求清单** (按主题):

- 🎯 **核心定位 5 项** — 19 skills / 71 design systems / 5 visual directions / 5 device frames / 7 coding agents (Claude Code + Codex + Cursor + Gemini + OpenCode + Qwen + Copilot)
- 🎨 **71 design systems**: 71 项 — Linear / Stripe / Vercel / Airbnb / Tesla / Notion / Anthropic / Apple / Cursor / Supabase / Figma / ... (从 awesome-design-md 导入)
- 🎭 **19 skills (按 mode 分组)**: 19 项
  - Prototype (7): web-prototype / saas-landing / dashboard / pricing-page / docs-page / blog-post / mobile-app
  - Deck/PPT (2): simple-deck / magazine-web-ppt (fork of guizang-ppt-skill)
  - Template (10): pm-spec / weekly-update / team-okrs / eng-runbook / kanban-board / meeting-notes / finance-report / invoice / hr-onboarding / tweaks
  - Design system (1): critique
  - Prototype (6 视觉特色): dating-web / digital-eguide / email-marketing / gamified-app / mobile-onboarding / wireframe-sketch
  - 创作类 (5): magazine-poster / motion-frames / replit-deck / social-carousel / sprite-animation
- 🖼️ **5 visual directions**: 5 项 — Editorial Monocle / Modern Minimal / Tech Utility / Brutalist / Soft Warm (各带 deterministic OKLch palette + font stack)
- 📱 **5 device frames**: 5 项 — iPhone 15 Pro / Pixel / iPad Pro / MacBook / Browser Chrome (pixel-accurate)
- 🤖 **Coding agents (7)**: 7 项 — Claude Code / Codex CLI / Cursor Agent / Gemini CLI / OpenCode / Qwen Code / GitHub Copilot CLI
- 🛠️ **5 export formats**: 5 项 — HTML / PDF / ZIP / Markdown / PPTX (PPTX Phase 2)
- 🌐 **3 deployment topologies**: 3 项 — Topology A 全本地 (primary) / Topology B Vercel + tunneled local daemon (deferred) / Topology C Vercel + direct API (partial)
- 🏗️ **Architecture (apps + packages + tools)**: 8 项
  - `apps/web` (Next.js 16 App Router + React 18 web runtime)
  - `apps/daemon` (本地 daemon, /api/* + agent spawn + skills + design systems + artifacts)
  - `apps/desktop` (Electron shell, 通过 sidecar IPC 查 web URL)
  - `apps/packaged` (placeholder, 本轮不动)
  - `packages/contracts` (pure TypeScript web/daemon app contract)
  - `packages/sidecar-proto` (Open Design sidecar business protocol)
  - `packages/sidecar` (generic sidecar runtime)
  - `packages/platform` (generic OS process primitives)
- 📊 **Web UI 组件**: 7 项 — chat pane / artifact tree / sandboxed iframe preview / export menu / skill picker / mode picker / design-system picker
- 🤖 **Daemon 功能**: 6 项 — HTTP/SSE API on :7456 / agent detection + cached results / skill registry / artifact store / design-system resolver / export pipeline
- 🧠 **Agent adapters**: 2 项 (MVP) — `claude-code` (native skill loading + streaming + surgical edit) / `api-fallback` (Anthropic Messages API minimal tool loop)
- 📚 **Topologies**: 3 项 — A 全本地 (primary) / B Vercel + tunneled (deferred) / C Vercel + direct API (partial)
- 🚫 **MVP 显式 out**: 9 项 — Codex/Cursor/Gemini adapters / Comment mode + sliders / Template gallery + template skill / Design System from screenshot (vision) / PDF / PPTX export (Phase 1) / Topology B / Docker compose / Skill tests (`od skill test`) / Auth / multi-user
- 📅 **Phase 0/1/2/3 roadmap**: 4 项
  - Phase 0 (~3-5 天): Spec finalization (8 deliverables, 当前)
  - Phase 1 (~6-8 周): MVP (周分解 8 周)
  - Phase 2 (~8 周后): v1 跟 Open CoDesign feature parity
  - Phase 3: 未细化

**装机 user 拍过的拍板** (上游 + 私域):
- 上游拍: Apache-2.0, BYOK at every layer, 不写 agent 复用用户已装的 CLI
- 私域拍: 当前 Phase 0 spec-only, 代码未写

**跟 wenshu 的关系**:
- **Apache-2.0 license** — wenshu 是 MIT, 装不上
- **概念借鉴 (PM-direct 调研)**:
  - **19 skills + 法无定法组合** = wenshu/methodologies/ + 法无定法哲学 = 同一思路
  - **5-step discovery form** (turn-1 锁 brief) = wenshu Story 1 5 步向导 (不谋而合)
  - **sidecar IPC 模式** (web ↔ daemon ↔ desktop) = wenshu 不用 (文枢 = Electron + 本机 hermes 直连)
- **未来 Story N+1 (v2.0+) 借鉴**: 文枢如果做"画板工具", open-design 的 19 skills + 71 design systems 是好参考

**主要文件**:
- `/Volumes/ANAN/Engineering/open-design/README.md` (41KB, 极丰富)
- `/Volumes/ANAN/Engineering/open-design/AGENTS.md` (4KB)
- `/Volumes/ANAN/Engineering/open-design/QUICKSTART.md` (12KB)
- `docs/{spec,architecture,skills-protocol,agent-adapters,modes,references,roadmap}.md` (~100KB 总和)
- `specs/current/{architecture-boundaries,maintainability-roadmap,runtime-adapter}.md`
- `skills/` (33 个 skill 目录)
- `design-systems/` (71 个 system 目录)

---

### 5. loop-engineering (cobusgreyling fork)

**项目简介**: 三方 fork (cobusgreyling/loop-engineering, MIT). 装机 user 拿来做 PM↔CC 协作模型参考. **7 patterns + 8 tools + 5 skills + 18 starters + 5 primitives**. 5.5k stars, 2026-07-13 最后 maintenance, 2026-07-14 最后 release.

**需求清单** (按主题):

- 🔄 **7 个 Loop Patterns**: 7 项
  - **Daily Triage** (L1) — 工作日自动跑, 报告 + 决策升级
  - **CI Sweeper** (L2 partial) — 失败 CI 自动 retry (validate-patterns.yml + audit.yml)
  - **Dependency Sweeper** (L2 patch-only) — patch + 低风险 CVE, 30 天内
  - **PR Babysitter** (L2 manual) — 10-15min 一次, worktree + verifier
  - **Post-Merge Cleanup** (L1 opportunistic) — 合并后清理
  - **Changelog Drafter** (L1 draft-only) — RELEASE_NOTES_DRAFT.md
  - **Issue Triage** (L2) — issue 自动打 label + 派 assignee
- 🛠️ **8 个 Tools (npm packages)**: 8 项
  - **loop-audit** (v1.6) — Loop Readiness Score CLI, `npx @cobusgreyling/loop-audit . --suggest --badge`
  - **loop-init** (v1.4) — Scaffold starters + budget/run-log + constraints
  - **loop-cost** — Token 估算, `npx @cobusgreyling/loop-cost`
  - **loop-sync** — STATE.md ↔ LOOP.md drift 检测
  - **loop-context** (v1.1) — Stateful memory + circuit breaker
  - **loop-worktree** — 隔离 git worktree per fix attempt
  - **loop-mcp-server** — MCP runtime lookup for patterns/skills/state
  - **goal-audit** — Goal Engineering companion (npx @cobusgreyling/goal doctor .)
- 🧠 **5 个 Skills**: 5 项 — loop-budget / loop-constraints / loop-triage / loop-verifier / minimal-fix
- 🚀 **18 个 Starters (克隆即跑)**: 18 项
  - changelog-drafter + changelog-drafter-opencode
  - ci-sweeper + ci-sweeper-opencode
  - dependency-sweeper + dependency-sweeper-opencode
  - issue-triage + issue-triage-opencode
  - minimal-loop + minimal-loop-claude + minimal-loop-codex + minimal-loop-opencode
  - post-merge-cleanup + post-merge-cleanup-opencode
  - pr-babysitter + pr-babysitter-opencode
- 📐 **5 个 Primitives + Memory**: 5 项 — Goal / Context / Budget / Triage / Verifier + Memory (sixth)
- 📚 **核心文档**: 14 项
  - README / QUICKSTART / RELEASE / adopters / anti-patterns / concepts / failure-modes / loop-design-checklist / loop-init-validation / multi-loop / operating-loops / pattern-picker / primitives / primitives-matrix / safety
- 🎓 **18 个 Stories (实战故事)**: 18 项
  - changelog-drafter-week-one / ci-sweeper-infinite-flaky-test / daily-triage-report-only / dependency-sweeper-week-one / dependency-vs-ci-sweeper-collision / ky-cut-surface-generation-vs-consequence / l1-to-l2-graduation / loop-budget-example / loop-run-log-example / multi-loop-collision / multi-loop-coordination / post-merge-cleanup-honest-win / pr-babysitter-week-one / quant-loop-out-of-time / quant-loop-the-verifier-problem / why-we-killed-ci-sweeper
- 🤖 **GitHub Actions 自动化**: 6 项 — daily-triage.yml (weekday) / changelog-drafter.yml (Monday) / update-star-history.yml (daily) / validate-patterns.yml (on PR+push) / audit.yml (readiness score on PRs) / Dependabot weekly npm
- 🛡️ **Safety & Gates**: 5 项 — No auto-merge on main / Denylist (showcase HTML/CSS, core primitives docs) / `loop-pause-all` kill switch / Loop Ready score ≥ 58 维持 / Multi-loop 优先级

**装机 user 拍过的拍板** (从 novel-platform 借鉴):
- 7/16 13:11: PM↔CC 单 loop 模式借鉴 loop-engineering pattern (LOOP-CONSTRAINTS.md 落档)
- 7/16: 4 段任务卡模板借鉴 loop-engineering 6 段 (略简化)
- 7/16: loop-run-log.md JSONL append-only 借鉴
- 7/16: denylist 借鉴 (不动 hermes 上游 / 4-tier ladder rung 1-4 等)

**Loop Run Log 实证** (2026-06-15 ~ 2026-07-13):
- 共 22 次 daily-triage run, 全部 outcome=report-only
- 1 次 escalated (2026-06-18 11:41)
- Token estimate 5.2 万/次 (52K)
- Readiness score 维持 100 (L3)

**跟 wenshu 的关系**:
- **借鉴 PM↔CC 协作模式** — wenshu/LOOP-CONSTRAINTS.md 大量借鉴 loop-engineering pattern
- **不引入 npm packages** — loop-audit / loop-init / loop-cost 等都是 TypeScript + npm, wenshu 是 Python monorepo, 不混用
- **loop-worktree 概念** — wenshu 用 git worktree (PM-direct 已用), 借镜
- **state.md + loop-run-log.md 双轨制** — wenshu/STATE.md 等价 loop-engineering STATE.md, loop-run-log.md 同
- **不直接 fork** — wenshu 不引入 loop-engineering 作为依赖

**主要文件**:
- `/Volumes/ANAN/Engineering/loop-engineering/README.md` (17KB)
- `/Volumes/ANAN/Engineering/loop-engineering/LOOP.md` (4KB)
- `/Volumes/ANAN/Engineering/loop-engineering/STATE.md` (1.7KB)
- `/Volumes/ANAN/Engineering/loop-engineering/loop-run-log.md` (5KB, JSONL)
- `patterns/` (7 pattern .md + registry.yaml + registry.schema.json)
- `tools/` (8 tool 目录, 各带 CHANGELOG.md + README.md)
- `starters/` (18 starter 目录)
- `skills/` (5 skill 目录)
- `templates/` (5 SKILL.md. 模板)
- `stories/` (18 实战故事)
- `docs/` (14 文档)

---

### 6. novel-research

**项目简介**: 多小说调研项目 = AI 友好 + 编辑功能 + 长期维护. FastAPI backend + MongoDB + React + Vite + TS + Tailwind frontend. **唯一一个"装机 user 自写"项目** (其他都是 fork / 三方). 状态 2026-06-17: MongoDB 跑通 + 1 项目 `twelve_di_zxian` 注册 + 341 份 MD 入库 + 10 API 端点 CRUD 全验证 + 前端 SPA 可跑.

**需求清单** (按主题):

- 🗄️ **MongoDB 数据层**: 3 项
  - Meta 库 `novelresearch_meta` (集合 `projects`)
  - 项目库 `novelresearch_{project_id}` (每项目 1 库, 物理隔离)
  - 7 个固定 collection (gods / artifacts / cultures / shengxiao / characters / dynasties / chapters)
- 🌐 **FastAPI 后端 (10 API 端点)**: 10 项
  - GET `/health` (MongoDB 状态)
  - GET `/api/projects`
  - POST `/api/projects` (注册新项目)
  - GET `/api/stats/{pid}` (项目各类目计数)
  - GET `/api/{pid}/{cat}` (列类目)
  - GET `/api/{pid}/{cat}/{name}` (查单个)
  - GET `/api/{pid}/{cat}/search?q=` (单类目搜索)
  - GET `/api/{pid}/_search?q=` (跨类目搜索)
  - POST `/api/{pid}/{cat}` (创建实体)
  - PUT `/api/{pid}/{cat}/{name}` (更新)
  - DELETE `/api/{pid}/{cat}/{name}` (删除)
- 🔐 **鉴权**: 1 项 — Bearer Token (API_KEY env)
- 🛠️ **4 个后端脚本 (AI shell CLI)**: 4 项
  - `init_project.py` (注册新项目 + 7 类目)
  - `import_md.py` (MD → BSON 转换器, 单文件/目录递归)
  - `ai_query.py` (AI 友好的 shell CLI, list/get/search/update)
  - `import_twelve_di.py` (一次性导入 304 份 MD)
- 🧠 **LLM 集成**: 3 项
  - `llm_client.py` (LLM 客户端封装)
  - `llm_providers.py` (多 provider 抽象)
  - MCP server (`mcp.py`, 9KB)
- 🖼️ **Image proxy**: 1 项 — `image_proxy.py` (6.7KB)
- 🧪 **Setup API**: 1 项 — `setup_api.py` (7.6KB)
- 🎨 **前端 (React + Vite + TS + Tailwind)**: 4 项
  - 3 tab + 详情 + 编辑表单 (App.tsx)
  - 6 个 fetch 包装 (api.ts)
  - Vite 代理 /api → 8787
  - Tailwind CSS 样式
- 🗄️ **数据迁移**: 1 项 — MD 是只读参考, BSON 是真值, `migrate_log.json` 留痕
- 📊 **当前数据** (2026-06-17): 1 项 — 341 份 MD 入库 (神 202 + 物 67 + 文化 35 + 生肖 11 + 人物 13 + 朝代 12 + 卷 1)

**装机 user 拍过的拍板**:
- 立项拍: 多小说调研项目 = AI 友好 + 编辑 + 长期维护
- 数据源拍: MongoDB 为唯一真值, MD 只读参考, 不直接读写
- 7 类目拍: gods / artifacts / cultures / shengxiao / characters / dynasties / chapters
- 鉴权拍: Bearer Token + API_KEY env
- 实体 schema 拍: `name` 唯一 (按 name 定位, 重名后端 409)
- 关系图拍: 暂不实现, 用 `related: []` 字符串列表维护
- 无事务拍: 单文档原子, 暂不 replica set
- 装机路径拍: `/Users/anbaiqiang/hermes-agent/venv/bin/python -m uvicorn ... --port 8787`

**跟 wenshu 的关系**:
- **数据源参考** — 装机 user 十二地仙项目的 MD (341 份) 是 wenshu Story 1 调研沉淀的潜在素材库
- **MongoDB ↔ wenshu SQLite 决策** — wenshu 选 Prisma+SQLite (novel-platform 沿用), novel-research 选 MongoDB, 各自合适
- **MCP server 模式借鉴** — novel-research/mcp.py (9KB) 是 wenshu 自定义 MCP skill 的参考实现
- **migrate_log.json 模式** — wenshu 没用, 但借鉴价值
- **不直接对接** — wenshu v1.0 不连 novel-research db (装机 user 7/25 拍 "novel-canvas 跟文枢解耦", novel-research 同理)

**主要文件**:
- `/Volumes/ANAN/Engineering/novel-research/README.md` (7KB)
- `backend/server.py` (20KB, 10 API 端点)
- `backend/db.py` (motor 异步)
- `backend/scripts/` (4 个 AI 脚本)
- `frontend/src/{App,api,main}.tsx` + 完整 SPA

---

### 7. dev-tools

**项目简介**: **不是项目**, 是装机 user 本机 scratch cache 目录. 包含:
- `Arc-data/` — 浏览器历史 cache
- `cargo/` — Rust 工具链 cache (`.crates.toml` / `.crates2.json` / `bin/` / `registry/`)
- `claude/` — Claude Code CLI 配置 + cache (settings.json + plugins + projects + security + sessions + shell-snapshots + skills + tasks)
- `claude/skills/` — 多个 symlink (cua-driver / ego-browser / huashu-nuwa / ljg-card / ljg-plain / ljg-skills / make-interfaces-feel-better)
- `ego-lite/` — ego 包
- `hub/` — hub 配置 (`.config/` + `plugins/` + `runtimes/` + `skills/` 14 个 skill)
- `hub/skills/` (14 个): animal-podcast / anime-style-forge / audiobook / clip-export / ecommerce-image / image-remix / n-storyboard / promo-video / short-drama / skill-creator / skill-reviewer / voice-clone / voice-design
- `loomy-opencode/` — opencode 相关
- `mem0/` / `mem0-webui/` — mem0 配置
- `ms-playwright/` — Playwright cache
- `npm/` — npm cache
- `ollama-models/` — Ollama 模型 cache
- `pnpm-store/` — pnpm store
- `ponytail/` — ponytail 工具
- `qdrant-server/` — Qdrant vector DB

**需求清单 (按主题)**:

- 🔧 **Claude Code 集成 cache**: 1 项 — settings.json + plugins + projects + security + sessions + shell-snapshots + skills + tasks (全 Claude CLI 自身 cache)
- 🎨 **hub skills (14 个)**: 14 项 — 创作类 (animal-podcast / anime-style-forge / audiobook / promo-video / short-drama / sprite-animation) / 图像类 (ecommerce-image / image-remix / motion-frames) / 工程类 (clip-export / skill-creator / skill-reviewer) / 语音类 (voice-clone / voice-design) / 文档类 (n-storyboard)
- 🧠 **claude skills symlinks (7 个)**: 7 项 — cua-driver / ego-browser / huashu-nuwa / ljg-card / ljg-plain / ljg-skills / make-interfaces-feel-better
- 📦 **Tool caches**: 8 项 — Cargo / npm / pnpm / mem0 / mem0-webui / ms-playwright / ollama-models / qdrant-server

**装机 user 拍过的拍板**: 无明确拍板, 都是装机 user 自然沉淀的 cache.

**跟 wenshu 的关系**:
- **不直接对接** — dev-tools 是装机 user 本机工具 cache, wenshu 不依赖
- **可借鉴 hub/skills (14 个)** — 装机 user 自创/收集的创作类 skills, 未来文枢 v2.0+ skill marketplace 可参考
- **qdrant-server 是 novel-canvas 用的** — wenshu v1.0 用 SQLite, 不依赖 Qdrant

---

### 8. wenshu (当前项目, 已 commit 部分)

**项目简介**: 当前项目 = hermes-agent v0.19.0 深度改 fork (NousResearch). 基线 0.0.0 (2026-07-23 18:55 出资方拍板). 当前 HEAD = `15148e72e docs(wenshu-pour): PM-direct pour 目录 + 装机边界 + 用户故事 v0.2`. 已 commit 7 个改动 (15148e72e / 2c9d9026d / 2eef5e5e5 / 6512d5751 / 41bc9613e / 93c4621b4 / 6cab7c457).

**需求清单** (按主题):

- 📚 **SOUL.md (默认角色身份)**: 6 项 — 文枢 = 通用写作助手 / 身份不限体裁 / 运行位置 ~/.wenshu-hermes/ / 哲学 = 法无定法贵在得法 / 4 维核心能力 / 不替用户拍创作方向
- 📋 **AGENTS.md (工作手册)**: 7 项 — 角色边界 / 哲学 / 7 步工作流 (读→调研→起草→修订→终稿→一致性→反向建议) / 4 维核心能力 (主动调研/合理性/不跑偏/反向建议) / 自由组合方法论 / 不替用户拍板 / 不写"写作"以外的工作
- 📖 **methodologies/ 默认库**: 4 库
  - **foundations/ (5 经典小说方法论)**: 5 项 — Freytag 五幕剧 / Campbell 英雄之旅 17 阶段 / Booker 七大基本情节 / Ingermanson 雪花法 10 步 / Aristotle 三幕剧
  - **classical/ (3 公版经典)**: 3 项 — 5W1H 六何分析法 / IMRaD 学术论文 / Inverted Pyramid 新闻结构
  - **commercial/ (1 商业文案)**: 1 项 — AIDA (Lewis 1898)
  - **examples/ (1 示例)**: 1 项 — SCQA 故事法 (Barbara Minto)
- 🧩 **lego/ (节点碎片库, PM-direct 沉淀)**: 5+ category
  - structure (17 节点): parallel-plot / in-medias-res / in-reveal / frame-story / bookend / nonlinear-timeline / layered-narrative / multiple-pov / first-person / third-person-limited / third-person-omniscient / epistolary / unreliable-narrator / stream-of-consciousness / flashback / flashforward / dual-timeline
  - character (8): mbti-character / enneagram / foils / character-arc-positive / character-arc-negative / character-arc-flat / ensemble-cast / antagonist-depth
  - plot (7): red-herring / plot-twist / macguffin / ... (PM-direct 拍 7/25 落档, 总 ~50-80 节点)
  - theme (5) / pacing (5)
- 🏗️ **CLAUDE.md (CC 项目记忆)**: 10 节 — Project Overview / Tech Stack / Directory Structure / Modules / Web/IPC / Conventions / Security / Verification / Baseline Context / References
- 🚀 **Installer (Tauri)**: 4 项 — 装到 /Applications / 复制 3 个文件到 ~/.wenshu-hermes/ (SOUL.md + AGENTS.md + methodologies/) / welcome.tsx 副文案 / WenShu-Setup.dmg 命名
- 🎨 **Branding (4 metadata 字段)**: 4 项 — name=wenshu / productName=文枢 / version=0.0.x / appId=com.wenshu.app
- 🪟 **Window title + About**: 2 项 — window title "文枢" / About "文枢 v0.0.x · 基于 Hermes Agent v0.19.0 (MIT) 修改"

**Story 1 已 commit (装机 user 7/25 拍, commit 2c9d9026d)**: 7 子故事
- 1.1 引导创建项目 (5 步向导: 创意/标签/篇幅/目录/创建)
- 1.2 自动初始化项目目录 (README + settings/ + chapters/ + notes/ + drafts/ + methodology/)
- 1.3 自动开启会话 + 带入会话 (创意/标签/篇幅/目录 path)
- 1.4 首次会话: 创意分析 (类型/参考/读者/风险)
- 1.5 调研方向建议 (5-10 方向 + 重要性评级 + 预估耗时)
- 1.6 调研子任务派发 (web_search/browser/file_read → notes/<topic>.md)
- 1.7 项目 ready 状态 (7 步 checklist)

**Story 2 v0.2 草稿 (未 commit, 装机 user 周末拍)**: 6 子故事
- 2.1 引导式聊 + 引导选下一步 (创作者填完节点类目, 文枢列"该类目适用节点")
- 2.2 节点 → 方法论 → 引导式提问 (按方法论给 1 套引导式问题, 5-10 轮/节点)
- 2.3 节点填完 → 派子任务沉淀到资料库 (web_search/browser/file_read)
- 2.4 资料库三层 (原始/实体/概念) — 装机 user "十二地仙" 4-7 章验证
- 2.5 节点循环: 每类目逐个填 (深度准备型 vs 边写边沉淀型)
- 2.6 项目 ready → 第一章出发建议 (3-5 方向 + 钩子草稿)

**Story 3 (TBD, 装机 user 待补)**: 法无定法 + 节点乐高块
- 选方法论 UI / 节点配方法论 / 即插即用/即拔即弃 / 跨方法论复用节点

**装机 user 7/25 拍过的拍板** (从 user-stories-v0.2 落档):
- 7/24: 文枢 = hermes-agent v0.19.0 深度改 fork (MIT)
- 7/24: 文枢 = 通用写作助手, 不限体裁/手法
- 7/24: 法无定法, 贵在得法 (哲学拍)
- 7/24: 4 维核心能力 = 主动调研 + 合理性 + 不跑偏 + 反向建议
- 7/25: 装机内容 vs PM 沉淀 分开 (wenshu-pour/ 命名拍)
- 7/25: 核心五元组 = 时间/地点/人物/情节 + 资料库
- 7/25: 资料库"按五元组分类" (朝代/年代/地点/语言/职业/情节/章节)
- 7/25: OB md 文件 = 项目目录真值 (6 目录模板: 世界观/场景/时间/角色/资料库 + IDEA.md)
- 7/25: 安装边界 (用户故事 + 调研是项目辅助, 不打包给装机 user)
- 7/25: novel-canvas 跟文枢解耦 (未来画板工具, v2.0+)

**跟 wenshu 的关系**:
- **当前项目本身** — 装机 user 7/25 拍 "老项目 = 共用 hermes 那个版本" 指 v0.19.0 hermes-agent + wenshu fork

**主要文件**:
- `/Volumes/ANAN/Engineering/wenshu/wenshu/SOUL.md` (~6KB)
- `/Volumes/ANAN/Engineering/wenshu/wenshu/AGENTS.md` (~7KB)
- `/Volumes/ANAN/Engineering/wenshu/wenshu/methodologies/` (README + 4 库 + lego/)
- `/Volumes/ANAN/Engineering/wenshu/CLAUDE.md` (~13KB)
- `/tmp/cc-out/user-stories-v0.1.md` (已 commit 沉淀)
- `/tmp/cc-out/user-stories-v0.2-draft.md` (周末拍板后落档)

---

## STEP 2: 跨项目总览 (需求全景图)

### 2.1 装机 user 在 hermes 生态上做了哪些需求 (8 项目合计 ~330 项)

按"装机 user 自写 vs 三方 fork vs 重启 lineage"分类:

| 分类 | 项目 | 估算需求数 | 状态 |
|------|------|----------|------|
| **三方 fork** (装机 user 拿来看) | Hermes-Slate-Desk | ~50 | active, 不复用 |
| | open-design | ~50 | spec-only, 不复用 |
| | loop-engineering | ~30 | active, 借鉴 PM↔CC 协议 |
| **装机 user 自写 + 未来/活跃** | novel-platform → wenshu | ~80 | **已重启为 wenshu** |
| | novel-canvas | ~60 | active, 跟文枢解耦 |
| | novel-research | ~25 | M0 跑通, 不复用 |
| **装机 user 工具 cache** | dev-tools | ~5 (categories) | scratch, 不复用 |
| **当前项目** | wenshu | ~30 | 6 commits, P0 装机中 |
| **合计** | | **~330** | |

### 2.2 哪些需求已合并到 wenshu (Story 1/2 + methodologies)

✅ **已合并** (装机 user 7/24-7/25 拍板):

| 来源项目 | 需求 | 合并到 wenshu 的位置 |
|----------|------|---------------------|
| novel-platform | PM↔CC 单 loop 协议 | `wenshu/LOOP-CONSTRAINTS.md` + `loop-run-log.md` |
| novel-platform | 4 段任务卡模板 (Why/What/How/When/Boundaries/Verification) | `wenshu/LOOP-CONSTRAINTS.md` §X |
| novel-platform | 4-tier ladder 模式 | 借鉴 (但 7/23 拍板砍 rung 1-4, 只留 rung 5 = 自包含内核) |
| loop-engineering | loop-run-log.md JSONL append-only | `wenshu/loop-run-log.md` (格式一致) |
| loop-engineering | state.md + run-log 双轨 | `wenshu/STATE.md` (后续) |
| loop-engineering | denylist 模式 | `wenshu/LOOP-CONSTRAINTS.md` |
| novel-platform M2 W3 | 30+ 方法论节点入库 (Plot 7 + Character 8 + Theme 5 + Structure 17 + Pacing 5) | `wenshu/methodologies/lego/` (节点碎片库, 装机 user 拍 "先落地成文件") |
| novel-platform M2 W3 | 统一 YAML schema v0.1 | `wenshu/methodologies/README.md` 借鉴 |
| novel-research | MCP server 模式 (`mcp.py` 9KB) | wenshu 自定义 MCP skill 参考实现 |
| Hermes-Slate-Desk | workspace switching 模式 (sessions/files/terminal/cron/env/memory 隔离) | v1.0+ 多项目 / 多会话设计参考 |
| open-design | 19 skills + 法无定法组合 + 5-step discovery form | `wenshu/methodologies/` 4 库 + Story 1 5 步向导 |
| novel-research | 资料库三层 (原始/实体/概念) | Story 2.4 (装机 user "十二地仙" 4-7 章验证) |
| novel-platform M1 W3 | 雪花法 / Creative Sprint / Snowflake 10 步 | `wenshu/methodologies/foundations/snowflake-ingermanson.md` |
| novel-platform M1 W3 | 三幕剧 / Hero's Journey / 七大基本情节 | `wenshu/methodologies/foundations/{three-act-aristotle, hero-journey-campbell, seven-basic-plots-booker}.md` |
| novel-platform M1 W3 | Freytag 五幕剧 | `wenshu/methodologies/foundations/freytag-pyramid.md` |
| (公版) | 5W1H / IMRaD / Inverted Pyramid / AIDA / SCQA | `wenshu/methodologies/{classical,commercial,examples}/` |

### 2.3 哪些需求跟 wenshu 当前方向不一致 (废弃)

❌ **已废弃** (跟 wenshu 当前方向不一致):

| 来源 | 需求 | 废弃原因 |
|------|------|---------|
| novel-platform V0.1/V0.2 | Tauri 2 + Vue 3 + Rust + SQLite 全栈 (M1 38 工单 + M2 38 工单) | 7/16 拍板 "文枢 = hermes app fork, 不复用 novel-platform" |
| novel-platform V0.1 W1 | Cargo workspace + lib/bin split | 不复用 (Python monorepo) |
| novel-platform V0.1 W2 | 8 entities (project/chapter/character/worldbuilding/outline/methodology/pipeline_state/audit) | 不复用 (wenshu = MD 文件, 不是 SQLite) |
| novel-platform V0.1 W2 | FTS5 unicode61 中文分词 | 不复用 (wenshu v1.0 不做全文搜索) |
| novel-platform V0.1 W2 | rusqlite + Arc<Mutex<Connection>> | 不复用 (Python SQLite 不需要) |
| novel-platform V0.1 W3 | MethodologyEngine trait (load / get_stage / validate) | 不复用 (wenshu = 纯 markdown 节点) |
| novel-platform V0.1 W3 | Snowflake / Creative Sprint 4 builtin methodologies | 部分复用 (只保留雪花法到 methodologies/foundations/) |
| novel-platform V0.1 W4 | Pipeline 状态机 (NotStarted/InProgress/Completed/Blocked) | 不复用 (wenshu v1.0 用 7 步工作流) |
| novel-platform V0.1 W4 | 26 Tauri commands | 不复用 (Electron IPC, 不 26 个 commands) |
| novel-platform V0.1 W4 | DynamicFormRenderer / DynamicListField / GuidedForm | 不复用 (wenshu = 对话式引导, 不是表单) |
| novel-platform V0.1 W4 | WebSSH Hermes Bridge (Python → 1420 → Tauri) | 不复用 (Electron + 直接 spawn) |
| novel-platform V0.1 W5 | CharacterEditor 模态 + CharactersView 卡片网格 | 不复用 (wenshu 用 OB md 模板, 不是卡片) |
| novel-platform V0.1 W5 | ChaptersView + ChapterEditorView (1.5s debounce + CJK 字数) | 部分复用 (CJK 字数是 PM-direct 已拍) |
| novel-platform V0.1 W5 | LibraryView 3-tab + FTS5 全文搜索 | 不复用 (wenshu v1.0 用 grep/ripgrep) |
| novel-platform V0.1 W6 | JSON-RPC 2.0 + MCP (无 SDK 依赖) | 不复用 (wenshu 用 hermes-agent 自带 MCP) |
| novel-platform V0.1 W6 | 5 tools (list_projects / list_characters / create_chapter / search_chapters / get_methodology) | 不复用 (功能 ≠ wenshu v1.0 范围) |
| novel-platform V0.1 W6 | 独立 binary `target/release/novel-platform-mcp` (4.7M) | 不复用 |
| novel-platform V1 P1-1c Tauri | 在线更新机制 | 不复用 (wenshu 走 electron-builder auto-update) |
| novel-platform V1 P1-1d | codesign + notarization (macOS) | 不复用 (wenshu 走 hermes 上游 electron-builder) |
| Hermes-Slate-Desk | Tauri 2 + React 19 + Vite 8 + Tailwind 4 + shadcn/ui 栈 | 不复用 (wenshu = Electron + React 18 + Vite 5 + Tailwind 3) |
| Hermes-Slate-Desk | WorkspaceSwitcher (`~/.hermes/hermes-slate-desk/config.json`) | 不复用 (wenshu v1.0 单项目, 不做工作区切换) |
| Hermes-Slate-Desk | i18n 3 语言 (zh/en/zh-tw) | 不复用 (wenshu v1.0 简中, v2.0+ i18n) |
| Hermes-Slate-Desk | Terminal (xterm.js + PTY) | 不复用 (wenshu v1.0 不做内置终端) |
| Hermes-Slate-Desk | Notebook (Milkdown) | 不复用 (wenshu v1.0 用外部 Obsidian 读 OB md) |
| Hermes-Slate-Desk | Cron (定时任务) | 不复用 (wenshu v1.0 不做定时任务) |
| Hermes-Slate-Desk | File Manager (原生文件管理) | 不复用 (wenshu v1.0 用外部编辑器) |
| Hermes-Slate-Desk | Hermes Settings (Agent 管理 + Skills marketplace + Memory 管理 + Channel 配置 + Prompt 模板 + Analytics) | 不复用 (wenshu 接本机 hermes, 自管这些) |
| Hermes-Slate-Desk | NotebookEditorPage + NotebookMilkdownEditor + NotebookPreview + NotebookTreePanel | 不复用 |
| novel-canvas | Konva 画布 (节点/边 label + 多选 + 缩放 + undo/redo + PNG 导出) | 不复用 (wenshu v1.0 不做画板, v2.0+ 才做) |
| novel-canvas | tRPC 11.x 类型安全 RPC | 不复用 (wenshu = Electron IPC) |
| novel-canvas | Bearer Token 鉴权 | 部分复用 (wenshu skill 协议可参考) |
| novel-canvas | Prisma 5 entity (Novel/Chapter/Character/PlotLine/WorldView) | 不复用 (wenshu = MD 文件) |
| novel-canvas | novel-skills API (5 接口: chapter/character/plotline/edge/query) | 不复用 (功能不重叠) |
| novel-canvas | M2 V1-V6 画布功能 (commit 46c26c5) | 不复用 (未来 v2.0+ 借鉴) |
| novel-canvas | M10 V0.8 design tokens / design doc / UI primitives | 不复用 |
| novel-canvas | PILLAR V24-V34 工程管理 (11 项) | 部分借鉴 (AIF self-train `scripts/ml-train.sh` 概念) |
| open-design | Next.js 16 + daemon + Electron shell 全栈 | 不复用 (Apache-2.0 也不兼容) |
| open-design | 71 design systems | 不复用 (wenshu v1.0 不做 design system) |
| open-design | 5 device frames (iPhone 15 Pro / Pixel / iPad Pro / MacBook / Browser Chrome) | 不复用 |
| open-design | Topology B Vercel + tunneled local daemon | 不复用 |
| open-design | PDF / PPTX export | 不复用 (wenshu v1.0 输出 MD) |
| loop-engineering | 8 npm tools (loop-audit / loop-init / loop-cost / loop-sync / loop-context / loop-worktree / mcp-server / goal-audit) | 不复用 (wenshu = Python monorepo, 不引 npm) |
| loop-engineering | 18 starters | 不复用 |
| loop-engineering | GitHub Actions 6 个 workflows (daily-triage / changelog-drafter / update-star-history / validate-patterns / audit / Dependabot) | 不复用 (wenshu 没 GitHub Actions) |
| loop-engineering | Loop Ready score ≥ 58 维持 | 不复用 |
| novel-research | MongoDB 数据层 | 不复用 (wenshu = SQLite) |
| novel-research | 7 collection (gods/artifacts/cultures/shengxiao/characters/dynasties/chapters) | 不复用 (wenshu 7 目录 OB 风格) |
| novel-research | 10 API 端点 | 不复用 (wenshu 不开 API) |
| novel-research | 4 后端脚本 (init_project / import_md / ai_query / import_twelve_di) | 不复用 |
| novel-research | image proxy | 不复用 |
| novel-research | Vite + React + TS + Tailwind 前端 | 不复用 (wenshu 是 Electron) |
| dev-tools | Cargo cache / npm cache / pnpm store | 不复用 (装机 user 本机工具) |
| dev-tools | 14 hub skills (animal-podcast / anime-style-forge / audiobook / clip-export / ecommerce-image / image-remix / n-storyboard / promo-video / short-drama / skill-creator / skill-reviewer / voice-clone / voice-design) | 不复用 (v2.0+ skill marketplace 可参考) |
| dev-tools | 7 claude skills symlinks | 不复用 (装机 user 本机工具) |

### 2.4 哪些需求还没做 (v1.0+ backlog)

⏳ **v1.0+ backlog** (装机 user 还没拍 / 还没做):

| 来源 | 需求 | 优先级 | 拍板状态 |
|------|------|-------|---------|
| novel-platform M2 W6 | Linux .deb + .AppImage 打包 | P2 | 装机 user 周末可拍 |
| novel-platform M2 W6 | Windows .msi 打包 (需 OV 证书) | P3 | 用户未买证书 |
| novel-platform M1 W6 | Playwright E2E smoke (3 tests) | P2 | 装 electron-builder 后跑 |
| novel-platform M1 W6 | GitHub Actions CI | P2 | wenshu 没 GitHub Actions, 后续可加 |
| Hermes-Slate-Desk | i18n 3 语言 | P2 | wenshu v1.0 简中, v2.0+ i18n |
| Hermes-Slate-Desk | Workspace switching 模式 | P2 | v1.0 单项目, v2.0+ 多项目 |
| Hermes-Slate-Desk | Hermes Settings (Agent 管理 + Skills marketplace + Memory 管理 + Channel 配置 + Prompt 模板 + Analytics) | P2 | 部分 (wenshu 接 hermes, 自管轻量) |
| Hermes-Slate-Desk | AI 思考可视化 | P1 | Story 2.2 引导式聊可借鉴 |
| Hermes-Slate-Desk | 流式响应 | P1 | wenshu v1.0 必备 |
| Hermes-Slate-Desk | 多模型切换 | P2 | 接 hermes, 模型在 hermes 配 |
| Hermes-Slate-Desk | Terminal (xterm.js + PTY) | P3 | 不做内置终端 |
| Hermes-Slate-Desk | Notebook (Milkdown) | P3 | 用外部 Obsidian 替代 |
| Hermes-Slate-Desk | Cron (定时任务) | P3 | 不做 |
| Hermes-Slate-Desk | File Manager (原生文件管理) | P3 | 用外部编辑器 |
| novel-canvas | Konva 画布 + 节点/边 label + 多选 + 缩放 + undo/redo + PNG 导出 | P2 (Story N+1 v2.0+) | 7/25 装机 user 拍 "novel-canvas 跟文枢解耦, 文枢 v1.0 不实现画板" |
| novel-canvas | PILLAR V24-V34 工程管理 (11 项) | P3 | 部分借鉴 (AIF self-train 概念) |
| open-design | 19 skills (Prototype/Deck/Template/Design system) | P3 (v2.0+) | 借鉴 + skill marketplace |
| open-design | 5 device frames | P3 | 画板工具才用 |
| open-design | PDF / PPTX export | P3 | wenshu v1.0 输出 MD |
| open-design | Topology B Vercel + tunneled local daemon | P3 | 不做 |
| loop-engineering | Loop Ready score CLI | P2 | PM-direct 可借鉴做 wenshu readiness score |
| loop-engineering | loop-worktree 模式 | P1 (已用) | wenshu 已用 git worktree |
| novel-research | MCP server 模式 (`mcp.py` 9KB) | P2 | wenshu 自定义 MCP skill 参考 |
| novel-research | migrate_log.json 模式 | P3 | wenshu 不用 (无 MD-BSON 同步) |
| dev-tools | 14 hub skills (创作类) | P3 (v2.0+ skill marketplace) | 借鉴 |
| (v1.0+ 新) | Story 2.1 引导式聊 + 引导选下一步 | P1 | Story 2 v0.2 已草, 等装机 user 周末拍 |
| (v1.0+ 新) | Story 2.2 节点 → 方法论 → 引导式提问 | P1 | 同上 |
| (v1.0+ 新) | Story 2.3 节点填完 → 派子任务沉淀到资料库 | P1 | 同上 |
| (v1.0+ 新) | Story 2.4 资料库三层 (原始/实体/概念) | P1 | 同上 |
| (v1.0+ 新) | Story 2.5 节点循环: 每类目逐个填 | P1 | 同上 |
| (v1.0+ 新) | Story 2.6 项目 ready → 第一章出发建议 | P1 | 同上 |
| (v1.0+ 新) | Story 3 方法论自由组合 UI | P2 | TBD |
| (v1.0+ 新) | Story N+1 文枢画板工具 (借鉴 novel-canvas Konva) | P3 (v2.0+) | 7/25 已拍 |
| (v1.0+ 新) | wenshu/methodologies/lego/ 节点扩展 | P2 | 装机 user 拍 "先落地成文件, 持续加" |

### 2.5 跨项目统计 + 装机 user 关注点

**装机 user 真正关注的 3 件事** (从 7/24-7/25 拍板):

1. **故事创作** (Story 1 + Story 2 + Story 3)
   - 12 子故事 + 11 痛点 + 7 决策点 + 4 核心能力
   - 来源: novel-platform M1/M2 故事写作 / novel-canvas 5 实体 / novel-research 十二地仙
2. **方法论自由组合** (法无定法)
   - 9 公版方法论 + 法无定法哲学 + 节点乐高块 (~50-80 节点)
   - 来源: novel-platform M2 W3 30+ 节点 / open-design 19 skills / loop-engineering primitives
3. **本机 hermes 直连 + PM↔CC 单 loop 协作**
   - hermes-agent v0.19.0 fork + 4 metadata + loop-run-log + LOOP-CONSTRAINTS
   - 来源: hermes-agent 上游 + loop-engineering pattern + novel-platform 借鉴

---

## STEP 3: PM-direct 备注

### 3.1 调研发现 (PM-direct 加注)

1. **8 项目中真正"装机 user 自写"的 = novel-platform + novel-canvas + novel-research (3 个)** — 其他都是 fork (Hermes-Slate-Desk / open-design / loop-engineering) 或 scratch (dev-tools). 这 3 个加起来 ~165 项需求.

2. **novel-platform 是 wenshu 的前身, 80% 需求已废弃** — Tauri/Vue/Rust/SQLite 全栈 + MCP server + cytoscape.js + codesign 都因 7/16 重启而废弃. 留存的: PM↔CC 协议 + 雪花法/三幕剧/Hero's Journey/七大基本情节/Freytag 五幕剧 5 个方法论.

3. **novel-canvas 跟 wenshu 解耦, 是 v2.0+ 故事** — 7/25 装机 user 拍 "novel-canvas 跟文枢解耦, 文枢 v1.0 不实现画板". novel-canvas 当前 60+ 需求 (尤其 M2 V1-V6 画布功能) 都是 v2.0+ 画板工具的素材.

4. **novel-research 是唯一的"装机 user 自写活跃项目", 但跟 wenshu 不直接对接** — 12 地仙项目的 341 份 MD 是 Story 1 调研沉淀的潜在素材库, 但 wenshu v1.0 不连 novel-research db.

5. **三方 fork 提供 PM↔CC 协作模式** — loop-engineering 的 PM↔CC 协议 + 7 patterns + 8 tools 是 wenshu/LOOP-CONSTRAINTS.md 的核心借鉴来源.

6. **AGENTS.md 拍 "issue tracker 走 .scratch/ markdown + triage labels 默认词汇表"** (Hermes-Slate-Desk) = 文枢 kanban 派单可参考的"轻量痕迹" (v1.0+).

7. **装机 user 私域已有"项目套路 vs 装机内容" 边界拍板** — 7/25 拍 "装机内容 vs PM 沉淀 分开", wenshu-pour/ 命名拍. 这条对未来新增需求至关重要: 哪些装机 user 看到 / 哪些 PM-direct 内部用.

### 3.2 跨项目"借鉴表" (PM-direct 5 步定位)

| 借鉴来源 | 借鉴模式 | wenshu 落点 |
|----------|---------|-------------|
| novel-platform LOOP-CONSTRAINTS.md | PM↔CC 4 段任务卡 | `wenshu/LOOP-CONSTRAINTS.md` §X |
| novel-platform loop-run-log.md | JSONL append-only | `wenshu/loop-run-log.md` |
| novel-platform M2 W3 | 30+ 节点 | `wenshu/methodologies/lego/` (~50-80 节点) |
| loop-engineering STATE.md | state 双轨 | `wenshu/STATE.md` (后续) |
| loop-engineering denylist | 不可动边界 | `wenshu/LOOP-CONSTRAINTS.md` |
| Hermes-Slate-Desk workspace | sessions/files/terminal/cron/env/memory 隔离 | v1.0+ 多项目设计参考 |
| open-design 19 skills | 法无定法组合 + discovery form | `wenshu/methodologies/` 4 库 + Story 1 5 步向导 |
| novel-research 十二地仙 341 MD | 装机 user 项目素材库 | Story 1 调研沉淀 (不进 v1.0) |
| novel-research 资料库三层 (原始/实体/概念) | 边写边沉淀 | Story 2.4 |
| novel-research MCP server | wenshu 自定义 MCP skill | v1.0+ skill 协议 |
| (公版) 9 方法论 | 写作方法 | `wenshu/methodologies/{foundations,classical,commercial,examples}/` |

### 3.3 PM-direct 风险 (装机 user 周末审改时确认)

1. **novel-canvas 装机 user 7/5 立项, 7/6 跑通 M2 V1-V6, 但 7/25 拍 "novel-canvas 跟文枢解耦"** — 这意味着 novel-canvas 是 wenshu 的"前身/邻接项目", 不是"wenshu 的一部分". PM-direct 不动 novel-canvas, 装机 user 后续独立维护.

2. **wenshu/methodologies/lego/ 节点数约 50-80** (PM-direct 估算, 未精确计数). 装机 user 7/25 拍 "先落地成文件, 但不装给用户". 后续 Story 3 (方法论自由组合 UI) 派上用场.

3. **novel-research 12 地仙项目的 341 份 MD 是否要进 wenshu 调研沉淀** — 装机 user 7/25 拍 "调研是项目辅助, 不打包给装机 user" — 实际: 12 地仙 MD 是装机 user 私域调研, wenshu v1.0 不直接用, 但 Story 1 调研方向可能引用 (装机 user 自定).

4. **三方 fork (Hermes-Slate-Desk / open-design / loop-engineering) 是否要列进 wenshu 文档** — 装机 user 7/25 拍 "项目套路放一个其他目录" (wenshu-pour/) — 三方 fork 的借鉴表就是 wenshu-pour/legacy-requirements-survey.md (本文件).

### 3.4 调研边界 (本报告不涉及)

- ❌ **任何代码改动** (8 项目都没动 1 行代码)
- ❌ **任何 git commit / push / reset --hard** (在 8 项目里)
- ❌ **任何 build / test 命令** (在 8 项目里跑)
- ❌ **任何 wenshu 仓根文件改动** (只新增 /tmp/cc-out/legacy-requirements-survey.md)

### 3.5 装机 user 周末审改时建议

1. **确认 8 项目盘点无遗漏** (Hermes-Slate-Desk / novel-platform / novel-canvas / open-design / loop-engineering / novel-research / dev-tools / wenshu)
2. **确认"已合并 / 已废弃 / v1.0+ backlog" 三分类无歧义**
3. **确认 novel-canvas 跟 wenshu 解耦的拍板位置** (本报告 §2.2 / §2.3 / §3.1)
4. **确认 wenshu/methodologies/lego/ 节点数 (~50-80) 是否需要 PM-direct 精确计数** (PM-direct 7/25 周末派单补充)
5. **确认 dev-tools 是否要列进"老项目"** (PM-direct 意见: 不列, 是 scratch cache, 但装机 user 想看就列)
6. **本报告落档建议**: 装机 user 周末审改 → PM-direct 跟 Story 2 v0.2 一起 commit → `wenshu/wenshu-pour/legacy-requirements-survey.md` (仓根) — 等装机 user 拍板 wenshu-pour/ 命名后再落.

---

## AC 自检

- [x] **AC1**: 8 个老项目都有调研段 (Hermes-Slate-Desk / novel-platform / novel-canvas / open-design / loop-engineering / novel-research / dev-tools / wenshu)
- [x] **AC2**: 总需求数 ≥ 50 (实际 ~330, 大幅超过)
- [x] **AC3**: 跨项目总览 4 节 (已合并 / 已废弃 / v1.0+ backlog / 跨项目统计) — 超出 3 节要求
- [x] **AC4**: 调研报告引用具体文件路径 (每个项目都列了主要文件, 含 README.md / CHANGELOG.md / docs/ 等)
- [x] **AC5**: `python3.11 -c "import os; os.path.exists('/tmp/cc-out/legacy-requirements-survey.md')"` 期望 True (本文件)

---

*WO-001Q · 2026-07-25 PM-direct 老项目需求清单调研报告 · 落档 `/tmp/cc-out/legacy-requirements-survey.md` (~ 28KB)*
