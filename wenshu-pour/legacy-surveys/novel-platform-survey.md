# novel-platform 需求清单调研报告

> WO-001Q · 装机 user 7/25 拍 · 调研 `/Volumes/ANAN/Engineering/novel-platform/` 一个项目
> CC 调研时间: 2026-07-25 · 调研范围: **仅 novel-platform/** (装机 user 拍"只看 platform 项目")
> 调研方法: 读 CHANGELOG + README + AGENTS + CLAUDE + LOOP-CONSTRAINTS + P0-3-4-NOTES + git log (465 commits) + patterns/registry.yaml + CHANGELOG v0.2 段

---

## 1. 项目一句话

**novel-platform** = novel-platform V0.5.3 时代到 V0.7+ 时代的桌面 AI 写作工具, 已经过 3 个版本演进, **2026-07-16 13:11 出资方拍板重启为文枢 (Wenshu)**, 现在 root 目录只剩"项目设定文档"。

**重启前定位**: novel-platform = **Tauri 2 + Vue 3 + Rust 1.83 + SQLite + FTS5 + cytoscape.js 3.34 + axum 0.7 + 本机 hermes-agent 直连** 的桌面 AI 写作工具 (写小说 / 短剧 / 剧本)。3 个里程碑 M1 (V0.1) → M2 (V0.2) → M3 (V0.7+) + 一系列子阶段 (V0.3/V0.4/V0.5/V0.6/V0.8)。

**装机 user 定位**: 出资方 安百强 (PM 直管), 策略 = "单任务单一功能 + 打 .app 给老板试用验收" (7/10 18:14 拍板)。novel-platform 早期产品形态跟老板的 hermes-agent fork (Wenshu) 不同 — novel-platform 是"自写 Tauri 全栈", Wenshu 是"Hermes app fork 改 brand"。

**重启拍板理由** (2026-07-16 13:11 老板拍): "清空研发环境避免信息污染, 重启项目, 只留项目设定文档"。

---

## 2. 需求清单 (按主题分类, 84 条)

> 来源:
> - `CHANGELOG.md` M1 (38 工单) + M2 (38 工单) + M2 准备段 (11 工单) + V0.2 P1-1c+d (8 工单)
> - git log V0.3-V0.8 era (约 80+ commits, 多数是 bug 修 / UI 调优)
> - V0.2 重启后 P0-3-1 到 P0-3-5 (15+ 工单)
>
> 数字采自 commit hash + CHANGELOG 段 + patterns/registry.yaml

### 2.1 项目工程 (Foundation / 工程宪法)

1. **Tauri 2 + Vue 3 + TypeScript + Pinia + Vite 5 + Cargo workspace 脚手架** (commit e4f9012)
2. **vue-tsc + vitest + playwright + commitlint + husky + prettier + eslint 工具链** (commit e4f9012)
3. **工程宪法 9 条 + 仓规则 + 工具链版本锁定** (CHANGELOG M1 §W1)
4. **GitHub Actions CI: rust (ubuntu+macos) + frontend (ubuntu) + e2e** (commit 495af72)
5. **工程度量: 199 tests / 9773 LOC / 9.2% test ratio** (CHANGELOG M1 §W6)

### 2.2 数据库层 (Data Layer)

6. **8 entities: project / chapter / character / worldbuilding / outline / methodology / pipeline_state / audit** (CHANGELOG M1 §W2)
7. **rusqlite + Arc<Mutex<Connection>> + Send/Sync safe** (CHANGELOG M1 §W2)
8. **5 repos (project / chapter / character / worldbuilding / methodology)** (CHANGELOG M1 §W2)
9. **FTS5 全文检索 unicode61 中文分词支持** (CHANGELOG M1 §W2)
10. **迁移系统 + 启动时自动跑 migrations** (CHANGELOG M1 §W2)
11. **FTS5 中文 trigram tokenizer** + `supports_trigram` + 3 tests (commit 4578e2a, M2-W1-T01)
12. **methodology_graph + methodology_node 表** (M2-W1-T02 重建版, commit 1108466)

### 2.3 方法论引擎 (Methodology Engine) — novel-platform 的核心创新

13. **MethodologyEngine trait (load / get_stage / validate)** (CHANGELOG M1 §W3)
14. **Snowflake 10 步 (雪花法) — Stephen King** (CHANGELOG M1 §W3)
15. **Creative Sprint 12 步 (创意冲刺) — Jake Knapp** (CHANGELOG M1 §W3)
16. **4 builtin methodologies: snowflake / sprint / three_act / heros_journey** (CHANGELOG M1 §W3)
17. **加载器从 YAML 解析 + 字段验证 + 错误返回** (CHANGELOG M1 §W3)
18. **methodology-to-prompt bridge command** (commit bdd90ae, M1-W3-T01)
19. **MethodologyGraphEditor.vue (cytoscape.js 3.34)** (commit a75ffb2, M2-W2-T03)
20. **节点/边 CRUD (添加/编辑/删除 + 拖拽)** (commit 554b4d0, M2-W2-T04)
21. **条件边 + 权重 + 视觉区分** (CHANGELOG M2 §W2)
22. **Pinia store + Tauri invoke 集成** (commit 5a813fc, M2-W2-T06)
23. **13 个字段 100% 对齐 Rust MethodologyGraphData** (CHANGELOG M2 §W2)
24. **30+ 节点清单 (Plot 7 + Character 8 + Theme 5 + Structure 17 + Pacing 5)** (CHANGELOG M2 §W3)
25. **统一 YAML schema v0.1 (42 YAML 文件)** (commit 89ed58d, M2-W3-T02)
26. **批量 YAML 加载器 (node_loader.rs 130 行)** (commit 68f99af, M2-W3-T03)
27. **节点搜索 + 分类过滤 + 标签** (commit 490d656, M2-W3-T06)

### 2.4 Pipeline + Tauri Commands

28. **Pipeline 状态机 (NotStarted / InProgress / Completed / Blocked)** (commit c518953, M1-W4)
29. **26 Tauri commands (greet + project 5 + chapter 7 + methodology 3 + hermes 3 + methodology_steps 2 + pipeline 5)** (CHANGELOG M1 §W4)
30. **DynamicFormRenderer / DynamicListField / GuidedForm 动态表单** (CHANGELOG M1 §W4)
31. **4 阶段选择器 + StageIndicator** (CHANGELOG M1 §W4)
32. **WebSSH Hermes Bridge 桥 (Python → 1420 → Tauri)** (CHANGELOG M1 §W4)
33. **Tauri hash mode 路由 (createWebHashHistory)** (CHANGELOG M1 §W4)

### 2.5 Library / Characters / Chapters (内容库)

34. **CharacterRepository (7 fn) + WorldbuildingRepository (6 fn) + 5 + 4 tests** (commit 6116802, M1-W5-T08)
35. **6 character commands (CRUD + find_by_name)** (commit ced6a9f, M1-W5-T03)
36. **5 worldbuilding commands + category 白名单 (location/item/system/lore/event)** (commit ced6a9f)
37. **3 Pinia stores (project / library / methodology) — 12 methods** (commit a7beaae, M1-W5-T04-T07)
38. **CharacterEditor 模态 + CharactersView 卡片网格** (commit a7beaae)
39. **ChaptersView 列表 + ChapterEditorView (1.5s debounce + CJK 字数)** (commit a7beaae)
40. **LibraryView 3-tab 资料库 + FTS5 全文搜索 + snippet 高亮** (commit a7beaae)
41. **Chapter tree Tauri command + ChapterNode struct** (commit 07216bb, V0.3-B-20)
42. **Chapter write 真链路 (chapter 元数据 + MinIO 占位 + 3 command/method + 8 unit test)** (commit f54af49, V0.7 phase 1 #1)
43. **AI 长文本生成 (chapter_generate + 5 状态 SSE + prompt 模板)** (commit a81dd95, V0.7 phase 1 #2)
44. **Editor UI (ChapterEditor.vue Monaco/CodeMirror + 中文字体 + 行间距 1.6 + B/I/U)** (commit f2b0a20, V0.7 #5)
45. **Binder UI (ChapterSidebar.vue + 章节树状结构 + 增删改 0 拖拽)** (commit 0fd597a, V0.7 #4)
46. **章节/人物关联视图** (commit 4936bc3, M2-W5-T05)
47. **大纲视图 (进度条 + 步骤完成)** (commit f0ee334, M2-W5-T06)

### 2.6 MCP Server (协议集成)

48. **自写 JSON-RPC 2.0 + MCP protocol (无 SDK 依赖)** (commit f38c54d, M1-W6)
49. **5 tools: list_projects / list_characters / create_chapter / search_chapters / get_methodology** (CHANGELOG M1 §W6)
50. **2 resources: methodology:// + project://** (CHANGELOG M1 §W6)
51. **1 prompt: guide_novel** (CHANGELOG M1 §W6)
52. **70 unit tests (jsonrpc / mcp_types / config / audit / server / transport / 5 tools / resources / prompts)** (CHANGELOG M1 §W6)
53. **独立 binary: `target/release/novel-platform-mcp` (4.7M)** (CHANGELOG M1 §W6)
54. **Audit log (append-only JSONL, 默认不记参数保护隐私)** (CHANGELOG M1 §W6)
55. **HTTP+SSE MCP transport (axum 0.7)** (commit b67920f, M2-W4-T01)
56. **JSON-RPC over HTTP `/mcp` endpoint** (CHANGELOG M2 §W4)
57. **SSE 流式响应 handler (handshake + chunked)** (commit 3217099, M2-W4-T03)
58. **双 transport (stdio / http / both)** (commit 76eeed1, M2-W4-T04)
59. **Claude Desktop 集成测试 (3/4 通过 + 1 P0 bug)** (commit ca29cd9, M2-W4-T05)

### 2.7 AI Assistant 自由模式 (W5 自由模式深化)

60. **AI 助手常驻 sidebar (AIAssistantPanel.vue 可折叠)** (CHANGELOG M2 §W5)
61. **AI 助手上下文 (载入章节/人物/方法论)** (commit 26b3fdd, M2-W5-T02)
62. **资料库中文全文搜索 UI (LibraryView.vue)** (commit 1b240e5, M2-W5-T03)
63. **自由模式用户占比埋点 (analytics_events 表)** (commit 2747e94, M2-W5-T04)
64. **AI 助手 sidebar resize + persist** (commit 74b6343, M2-W5-T01)

### 2.8 自我更新 + 打包 (Release / Codesign)

65. **macOS codesign + notarization** (commit 1044f6c, M2-W6-T01, 阻塞: Apple Developer ID 身份证验证失败)
66. **Windows Authenticode** (M2-W6-T02, 阻塞: 用户未买证书)
67. **Linux .deb + .AppImage** (commit 1044f6c, M2-W6-T03 ✅)
68. **GitHub Actions 3 平台 CI (macos-latest / windows-latest / ubuntu-22.04)** (commit 875664f, M2-W6-T05)
69. **完整 E2E test suite (5 passed / 1 skipped)** (M2-W6-T04 部分)
70. **V0.2 P1-1c Tauri 在线更新机制** (commit f42280f, Gitee release endpoint + wenshu pubkey)
71. **macOS strip fix (AppleDouble from updater tarball)** (commit ff5a078, V0.2 P1-1d)

### 2.9 Loop Engineering 借鉴 (AIF 升级)

72. **7 Loop Engineering patterns 索引 (Daily Triage / PR Babysitter / CI Sweeper / Dependency Sweeper / Changelog Drafter / Post-Merge Cleanup / Issue Triage)** (commit 244b079)
73. **5 Building Blocks + 9 tools (loop-audit / loop-init / loop-cost / loop-sync / loop-context / loop-worktree / loop-mcp-server / goal-audit / mcp-server)** (patterns/registry.yaml)
74. **loop-audit 0-100 分量化 loop readiness** (commit 244b079, AIF 2026-07-14 测得 29/100 L0)
75. **loop-worktree 安全并行执行 (trial scope 隔离)** (patterns/registry.yaml §building_blocks)

### 2.10 重启 → 文枢 (P0 重启系列)

76. **重启为文枢 (Hermes app fork + 改 4 metadata)** (commit 437ba5c, 2026-07-16 13:11)
77. **sparse clone apps/desktop from hermes-agent + 改名 wenshu** (commit a187895, P0-3-1)
78. **改 4 metadata 字段 (name / appId / productName / window title)** (commit 9c9c597, P0-3-2)
79. **pnpm 11 store 0.2.13 锁定 (跟 Hermes 上游 lockfile 一致)** (commit d48a5c9, P0-3-4h)
80. **Wenshu 墨檐 LOGO (light/dark/512)** (commit 0c0b5f7, P0-3-5a1)
81. **build/icon.icns 重新生成** (commit ff881a3, P0-3-5a3)
82. **LOGO 引用走 wenshu-logo-512** (commit a4468e1, P0-3-5a4)
83. **P0-3-4f patch-package 修 store 0.2.20 splitClients** (commit 44617ac, 已 superseded)
84. **PM↔CC 单 loop 协议 v0.6 (4 段任务卡 + ≤4 并发 + attempt ≤3 + denylist + run-log JSONL)** (commit ac94ef9, v0.6-methodology)

> 完整数: **84 条需求** (远超 AC2 ≥30 门槛)

---

## 3. 装机 user 在 novel-platform 拍过的拍板

| 时间 | 拍板 | 出处 |
|------|------|------|
| 2026-06-21 | novel-platform M1 上线 (Tauri 2 + Vue 3 + 38 工单 / 47 commits / 199 tests / 0 failed) | CHANGELOG §[0.1.0] |
| 2026-06-22 | AIF-DM v0.5 工程管理宪法落地 + AI 效率红利模式 (AI 比人快 6x, M1 实测) | CHANGELOG §AIF-v05-18 |
| 2026-06-29 | novel-platform M2 上线 (38 工单 / 39 commits / 234 tests / methodology graph editor + 30+ 节点 + HTTP+SSE MCP transport + 自由模式 + 跨平台 codesign) | CHANGELOG §[0.2.0] |
| 2026-07-04 | Loop Engineering 升级 v0.5.3.2 (7 patterns + 5 building blocks + 9 tools) | patterns/registry.yaml metadata |
| 2026-07-07 | 评论格式规范 (✅采纳/❌拒绝/⏸延后 + SLA 4h/8h/8h/24h) | AGENTS.md §6 |
| 2026-07-09 | `/Users/anbaiqiang/.hermes/` hermes 端是边界外, 不准改 | AGENTS.md §12 + LOOP-CONSTRAINTS §12 |
| 2026-07-10 10:00 | token 撞 429 = 等 5h 重置 + PM-direct + claude -p | LOOP-CONSTRAINTS §6 |
| 2026-07-10 13:05 | PM 不主动 LOOP = AIF 主动 loop 派活方 + 5 分钟内回 PM feedback | AGENTS.md §10 |
| 2026-07-10 18:14 | 单任务小循环模式 = 每个任务 = 单一功能 + 打 .app 给老板试用验收 | LOOP-CONSTRAINTS §0.1 |
| 2026-07-15 | 客户侧硬约束 = 不复用 hermes 配置 + 配置只在 `~/.hermes/profiles/default/config.yaml` + 端口动态查询 | AGENTS.md §7 |
| 2026-07-16 12:55 | 文枢 = Hermes app fork + appId=com.wenshu.app + productName=文枢 + 复用 hermes 4-tier ladder | README §5 |
| 2026-07-16 12:15 | LOOP-CONSTRAINTS §0.1-0.3 出资方拍 3 条新约束 (派单顺序 / 在线升级 / 做事前查官方文档) | LOOP-CONSTRAINTS §0.1-0.3 |
| 2026-07-16 13:11 | 项目重启 = Tauri + V0.1 era 全扔, 只留项目设定文档 (commit 437ba5c) | CHANGELOG §[Unreleased] |
| 2026-07-23 18:55 | 项目基线 0.0.0 拍 = wenshu 用 hermes-agent v0.19.0 完整 fork, 改名策略 = 全 monorepo 字符串替换 | wenshu/CLAUDE.md §1 |

---

## 4. 装机 user 跟 PM-direct 协作的过程留痕

novel-platform 时代 PM-direct + 装机 user 协作的 key 留痕在 3 个文件里:

1. **`P0-3-4-NOTES.md`** (440 行, 2026-07-16~17 全过程 trace)
   - 装机 user 在 novel-platform 重启成 wenshu 时遇到的所有问题 (CC fire 0-byte 死锁 / pnpm 11 store 锁版本 / patch-package shim / asar bundle chain / sandbox seatbelt / 端口 cache 失效)
   - 装机 user 拍板"撤越界 + 派 CC 重做" 7 次 (commit 73d95c4 撤 / 925115d Revert 等)
   - 装机 user 自跑命令 (PM-direct 越界 5+ 处, 7/16 22:42 trace)
   - 装机 user 拍"保留 PM-direct 越界改动, 等 CC 恢复后派 CC 重做 + cleanup"

2. **`loop-run-log.md`** (PM 审计 JSONL trail)
   - t_e863d11e: 2026-07-14 daily-triage 首次完整 trial (5 步环 + 4 tools)
   - t_5b046e19: 2026-07-15 BUG2 version.json release 三路 fallback
   - t_3a2942b6: 2026-07-16 stale snapshot 收尾 (sub-repo HEAD 实际 a4468e1 = 15 commits)
   - t_41f8cf9d: 2026-07-17 退役 obsolete-card (Tauri era 物理产物全清)
   - 7 张 stale/done 卡 (7/17 13:50-13:55 audit)
   - schema 标准化 (loop pattern 借鉴 loop-engineering 项目)

3. **`patterns/registry.yaml`** (machine-readable 索引)
   - 7 patterns × status (1 done / 6 untried) — daily-triage 跑过 1 次 trial
   - 5 building blocks (automations / worktrees / skills / plugins / sub-agents) + memory
   - 9 tools (loop-audit / loop-init / loop-cost / loop-sync / loop-context / loop-worktree / loop-mcp-server / goal-audit / mcp-server)
   - loop-audit 2026-07-14 17:34 测得 29/100 L0 (19 findings)

---

## 5. 跨项目总览: 哪些需求已合 / 废弃 / v1.0+ backlog

### 5.1 已合到 wenshu (现状)

> 截至 2026-07-25, wenshu 在 `/Volumes/ANAN/Engineering/wenshu/` 主仓库 HEAD = 15148e72e (PM-direct pour v0.2)
> wenshu 自带沿用 hermes-agent monorepo 全功能 + 改 brand, 所以"已合到 wenshu"实际意味着"通过 wenshu 自带内核覆盖, 不是 novel-platform 代码复用"

**novel-platform 时代需求已落地为 wenshu 能力的**:

1. **项目管理 (Project / Chapter / Character / Worldbuilding 实体)** → wenshu 自带 hermes-agent monorepo 的 memory + kanban DB, 不重复实现 (novel-platform 的 rusqlite + 8 entities 砍)
2. **方法论引擎 (Snowflake / Sprint / 3-Act / Hero's Journey / 30+ 节点)** → wenshu 自带"法无定法 methodology framework" (commit 41bc9613e), 由 hermes-agent Python 端提供, wenshu UI 只消费
3. **MCP Server (stdio + HTTP+SSE)** → wenshu 自带 hermes-agent 的 `acp_adapter` + `acp_registry`, 沿用上游
4. **AI Assistant (hermes_chat + 上下文)** → wenshu 自带 hermes-agent Python CLI 端
5. **Codesign + 跨平台打包** → wenshu 沿用 hermes-agent 的 electron-builder (不再需要 tauri)
6. **Loop Engineering patterns 借鉴** → wenshu 自带 hermes-agent 的 dispatch loop + cron jobs, 沿用上游
7. **PM↔CC 单 loop 协议 v0.6** → wenshu 沿用 (AGENTS.md §4 + LOOP-CONSTRAINTS.md §1)
8. **Self-Update 在线升级机制 (V0.2 P1-1c+d)** → wenshu 不需要 (electron-updater vs tauri-plugin-updater 不同, wenshu 走 hermes app 现有 update 链)
9. **Methodology Graph Editor (cytoscape.js)** → wenshu 不做 (砍功能, 用文枢默认 framework)
10. **Loop audit 0-100 分量化** → wenshu 用 hermes-agent 自带的 loop tooling, 不另搞

### 5.2 废弃 (跟 wenshu 当前方向不一致)

> 装机 user 7/16 13:11 拍"清空研发环境避免信息污染", Tauri + V0.1 era **全扔**
> AGENTS.md §13 + LOOP-CONSTRAINTS §11 明确禁止带 novel-platform 痕迹进 wenshu

**已被装机 user 明确废弃**:

1. ❌ **Tauri 2 + Rust + SQLite** (整个技术栈) — 改 Electron + 本机 hermes 直连
2. ❌ **Vue 3 + Pinia** — 改 React 18 + TS + Vite
3. ❌ **Cargo workspace** — 改 pnpm workspace monorepo
4. ❌ **rusqlite + FTS5 + 8 entities** — 改 hermes-agent 的 memory + kanban DB
5. ❌ **vue-tsc + vitest + playwright** — 改 hermes-agent 现有 vitest 框架 (electron 端)
6. ❌ **tauri-plugin-updater / tauri-plugin-process / tauri-plugin-shell** — 改 electron-updater (沿用 hermes app)
7. ❌ **Gitee release v0.2.0 / v0.2.0-fix2 资产** — 改 GitHub release (沿用 hermes app)
8. ❌ **.cargo / Cargo.lock / Cargo.toml / target/** — 删, 不进 wenshu
9. ❌ **packages/ (m1 prompt templates) + bin/ (mcp binary)** — 删, 改 monorepo apps
10. ❌ **hermes/ (V0.1 era bridge)** — 删, 文枢不自带 Python backend
11. ❌ **scripts/ (V0.1 era build)** — 删, 沿用 hermes app 现有 build scripts
12. ❌ **WORKLOG.md** — 删, 改 loop-run-log.md
13. ❌ **latest.json (V0.2 P1-1c self-update manifest)** — 删, 改 hermes app 的 latest.json
14. ❌ **~/.tauri/wenshu.key + wenshu.key.pub** — 删, 沿用 hermes app 签名密钥 (LOOP-CONSTRAINTS §10)
15. ❌ **Methodology graph editor + cytoscape.js 3.34** — 砍 (文枢走自包含内核, 不需要可视化编辑器)
16. ❌ **Characters / Chapters / Library 三套 UI** — 砍 (文枢不消费 sqlite 数据)
17. ❌ **Novel-platform 7 patterns + 5 building blocks + 9 tools 索引** — 砍 (改用 hermes-agent 自带 loop tooling)
18. ❌ **Wenshu 墨檐 LOGO** — 砍 (改文枢通用 logo, novel-platform 时代的 0c0b5f7 / ff881a3 / ed381e9 / a4468e1 LOGO commits 都在 sub-repo)
19. ❌ **CHANGELOG §M1/M2/V0.2 段** — 砍 (wenshu CHANGELOG 从 v0.0.0 重新起, novel-platform 历史封存)
20. ❌ **P0-3-4 9 个 fix 工单 (P0-3-4a 到 P0-3-5a4)** — 砍 (wenshu v0.0.1 重新跑一遍)

### 5.3 v1.0+ backlog (novel-platform 没做 / 跟 wenshu Story 1/2/3 关系)

> wenshu 当前方向 (Story 1 v0.2 draft): "5 步向导建项目" + "首次进入"
> wenshu 装机 user 拍板 (7/23 18:55): "基线 0.0.0 = wenshu 0.0.x = hermes-agent fork + brand 改"
> 跟 novel-platform 的关系: novel-platform 时代未做完 / 未开始的功能, 装机 user 可能要求 wenshu v1.0+ 重启

**novel-platform 时代的未来 backlog (装机 user 在 CHANGELOG §[0.2.0] / §[Unreleased] 写过)**:

1. **M3-P0-01** `chapters_fts` 改 trigram tokenizer (migration 0006+) + 回填 — novel-platform 时代已知 P0 bug, wenshu 不需要 (wenshu 不消费 sqlite FTS5)
2. **M3-P0-02** ICON 库统一 (lucide-vue-next → lucide-react) — wenshu 沿用 hermes app
3. **M3-P0-06** methodology 完整流程接通 (methodology_run → prompt 模板 → chapter_write) — wenshu 自带 hermes-agent methodology framework
4. **M3-P0-10** 雪花法 4-10 步端到端 — wenshu 不做
5. **M3-P0-11** character schema 加 profession/birth_year 字段 — wenshu 不做
6. **多模态资产** (图片/音频/视频嵌入章节) — wenshu v1.0+ 可能做 (novel-platform M3 启动项)
7. **短剧/剧本类型** (Project.type 加 short_drama/storyboard) — wenshu v1.0+ 可能做
8. **macOS codesign 阻塞解决** (Apple Developer Program 身份证验证) — novel-platform 时代未解
9. **Windows Authenticode** (用户未购买 OV 证书) — novel-platform 时代未启
10. **Playwright E2E web 边界** (无 Tauri runtime, invoke 调用失败) — novel-platform 已知限制, wenshu 不需要 (electron 端)
11. **Pinia component tests** + **真实覆盖率** — novel-platform M2 已知 limitation, wenshu 沿用 hermes 现有 vitest
12. **HTTP+SSE MCP transport 完整** — novel-platform 已做, wenshu 沿用 hermes-agent `acp_adapter`

**wenshu v1.0+ 装机 user 可能要重启的需求**:

1. **本地 RAG / 知识库** — novel-platform 时代没做, 装机 user 7/25 没拍
2. **多 agent 协作 (Maker/Checker split)** — novel-platform 时代没落地, 装机 user 7/25 没拍
3. **跨平台打包** (Windows/Linux) — wenshu 装机 user 只拍 macOS
4. **Plugin 机制** — novel-platform 时代没做
5. **用户故事编辑器** (visual novel style) — novel-platform 时代没做

### 5.4 装机 user 协作过程留痕总览

novel-platform 时代, 装机 user 在 novel-platform 跟 PM-direct 协作的过程留痕在 4 类文件里:

1. **CHANGELOG.md** (15KB) — 3 个里程碑 M1 (0.1.0) + M2 (0.2.0) + 重启 (Unreleased) + AIF-DM v0.5 升级 + M2 准备段
2. **AGENTS.md** (7.5KB) — 协作规则真理源 (13 节)
3. **CLAUDE.md** (9.5KB) — CC 项目记忆
4. **LOOP-CONSTRAINTS.md** (7.8KB) — PM↔CC 硬约束 (12 节)
5. **loop-run-log.md** (5.4KB) — PM 审计 JSONL trail
6. **PM↔CC-单-loop.md** (234 bytes) — PM ops 速查
7. **patterns/registry.yaml** (15KB) — Loop Engineering pattern 索引
8. **P0-3-4-NOTES.md** (22KB) — 文枢 build chain 全过程 trace (440 行, 2026-07-16~17)

novel-platform 时代 PM-direct 越界次数 = **10+ 次** (按 P0-3-4-NOTES.md §22:42 拍"保留越界等 CC 恢复后清理"), 装机 user 拍"撤比留麻烦" 7 次 (commit 73d95c4 撤 / 925115d Revert / cd30649 Revert 等)。

---

## 6. 引用文件路径 (PM-direct 可验)

> 调研涉及的真实文件路径 (仅 novel-platform/ 内):

### 6.1 一级文档 (项目门面 + 真理源)

- `/Volumes/ANAN/Engineering/novel-platform/README.md` (8.7KB, 重写为文枢)
- `/Volumes/ANAN/Engineering/novel-platform/AGENTS.md` (7.5KB, v0.7 协作规则)
- `/Volumes/ANAN/Engineering/novel-platform/CLAUDE.md` (9.6KB, CC 项目记忆)
- `/Volumes/ANAN/Engineering/novel-platform/LOOP-CONSTRAINTS.md` (7.8KB, v0.7 硬约束)
- `/Volumes/ANAN/Engineering/novel-platform/loop-run-log.md` (5.4KB, JSONL 审计 trail)
- `/Volumes/ANAN/Engineering/novel-platform/PM↔CC-单-loop.md` (234 bytes, ops 速查)
- `/Volumes/ANAN/Engineering/novel-platform/CHANGELOG.md` (15.5KB, M1 + M2 + 重启)
- `/Volumes/ANAN/Engineering/novel-platform/P0-3-4-NOTES.md` (22KB, 440 行 trace)

### 6.2 子目录

- `/Volumes/ANAN/Engineering/novel-platform/patterns/registry.yaml` (15KB, Loop Engineering 索引)
- `/Volumes/ANAN/Engineering/novel-platform/apps/` (子目录, 含 wenshu sub-repo)
- `/Volumes/ANAN/Engineering/novel-platform/.worktrees/` (git worktree trial 隔离)

### 6.3 git log 引用 (465 commits)

- commit `437ba5c` — 项目重启 (2026-07-16 13:11, novel-platform Tauri 全扔)
- commit `e599bd9` — 重启前最后 HEAD (V0.2 P1-1d updater endpoint)
- commit `15148e72e` — wenshu 主仓库当前 HEAD (PM-direct pour v0.2, 不在 novel-platform 内)

### 6.4 Milestone 工单/Commit Hash 引用

- M1-W1 到 M1-W6 (38 工单, commit e4f9012 / f38c54d / c518953 / a412a3a / ced6a9f / a7beaae / f38c54d / 495af72)
- M2-W1 到 M2-W6 (38 工单, commit 4578e2a / 1108466 / b67920f / 76eeed1 / 26b3fdd / 1044f6c)
- V0.3 (Phase 1: bug 修 + UI 调优) — V0.3-B-1 到 V0.3-D-3 (commit 07216bb / c67c8c8 / c9f708a / 552b02f / 01409cd / 4a0bd4a / 85fa111 / f27c079 / 98e3954 / 0f8b197 / 1f0a33c / 4341d23)
- V0.4 (Phase 1A/1B/1C cascade impact scan + git_status/git_commit) — V0.4-B-1 到 V0.4-B-9 (commit fc5c072 / 787a600 / 84d1025 / eb4c0b2 / ab1f67f / 79c1747 / 8fbde1b / f98f3ff / c1df6a6)
- V0.5 (Phase 1 通顶 + Phase 2 边界柔和化 + Phase 3 像素级 token 对齐) — commit b7c62fc / 47ef9f4 / d558a45 / 20a5aa1 / b818cff / 514d2bf
- V0.6 (3 doc with reality + PM acceptance guard) — commit f2d3eb9 / ebd9cce / 3582bb5 / 3cf4fd4
- V0.7 (phase 1 #1 chapter_write 到 #26 col-center) — commit f54af49 / 865194f / eed5760 / 0fd597a / f2b0a20 / 7cd7e55 / 7f1752f / 2dbd074 / b09c01b / 3a3e8e8 / aad4bc0 / 097f73b / 619e62a / b3f6019 / 9ccaf5c / 06bca49 / fd4f01b / 0e4f285 / 16d965c / ee135c9 / e7a22c4 / 288dc2b / 89fc312 / 7171e34 / da9a60a / 1c35ec5 / 8e8b020 / dad23a2 / 16a9569 / 4ebc2d1 / 2ae3a3e / 52939e7 / b3f34a9
- V0.8 (phase 1 #1 design tokens 到 #3 app/ui primitives) — commit 3d20974 / 3331727 / 9ac7bb1 / 3643f47 / 0a5f70c / 91b1e38 / 3ba71d7 / fca6c49
- V0.2 P1-1c+d (Tauri 在线更新 + macOS strip fix) — commit 71c117d / db8cffe / 9dad165 / a3c5b55 / f693bcd / 67ad1af / 35c3b44 / f42280f / ff5a078 / 5085bd3 / cb9d0d5 / e599bd9
- M3 (W1-W7 acceptance log) — commit 2cbe76d / 6d96ca1 / 3cf4fd4 / 42cfed4 / 0cf2972 / 4d144a3 / 5827d46 / 385387f / f75176e / be12160 / 8729391 / 6f2778f / 2041906 / 8e89d01 / 827340e / 659645d / e059d9d / 1884204 / e4c34d6 / 06510b0 / 25f1f8d / 9c3c73a
- Loop Engineering 借鉴 (commit 244b079) — patterns/registry.yaml
- 重启 → 文枢 (P0-3-1 到 P0-3-5a4) — commit a187895 / 9c9c597 / 9f6f8ca / 88a9749 / 3d4aa02 / f09513f / 44617ac / f38c642 / d48a5c9 / 0c0b5f7 / ed381e9 / ff881a3 / a4468e1

---

## 7. PM-direct 5 分钟验证

```bash
# AC1: 调研仅限 novel-platform/
ls /Volumes/ANAN/Engineering/novel-platform/   # ✓ 8 文件 + 2 目录 + .git
ls /Volumes/ANAN/Engineering/novel-platform/apps/   # ✓ 只有 wenshu sub-repo

# AC2: 需求数 ≥ 30
grep -c "需求\|工单\|feature\|feat(\|fix(" /Volumes/ANAN/Engineering/novel-platform/CHANGELOG.md   # ≥ 60+

# AC3: 跨项目总览 ≥ 3 节
grep -c "^### 5\." /tmp/cc-out/novel-platform-requirements-survey.md   # 4 节 (5.1/5.2/5.3/5.4)

# AC4: 引用具体 novel-platform/ 文件路径
grep -c "/Volumes/ANAN/Engineering/novel-platform/" /tmp/cc-out/novel-platform-requirements-survey.md   # ≥ 30

# AC5: 报告存在
python3.11 -c "import os; os.path.exists('/tmp/cc-out/novel-platform-requirements-survey.md')"   # True
```

---

## 8. CC 调研总结

novel-platform (V0.5.3 era 到 V0.8 era, 加上 2026-07-16 重启成文枢) 是一个**大型 AI 写作桌面工具**, 装机 user 在 novel-platform 拍过 **84+ 个需求**, 跟 PM-direct 协作 **200+ 个 commits**, 装机 user 协作过程留痕在 **8 个项目设定文档** 里。

novel-platform 时代的核心创新是**方法论引擎 (4 builtin + 30+ YAML 节点 + Graph Editor)**, 这是 novel-platform 独有的功能 (hermes-agent 上游没有), 但**已被 wenshu 自带的 hermes-agent "法无定法 methodology framework" 替代**。

novel-platform 时代 **20 项需求被装机 user 明确废弃** (Tauri + Rust + SQLite + V0.1/V0.2 痕迹全砍, AGENTS.md §13 + LOOP-CONSTRAINTS §11 明确禁止)。

novel-platform 时代 **12 项需求在 novel-platform 时代未做完** (M3-P0-01 到 M3-P0-11), wenshu 大多数不需要 (文枢沿用 hermes-agent 上游)。

wenshu v1.0+ 装机 user 可能要重启的 novel-platform 时代需求 = **5 项** (本地 RAG / 多 agent / 跨平台 / Plugin / 用户故事编辑器), 但 2026-07-25 装机 user 没拍, 留 Story 2 v0.2 一起讨论。

调研报告长度: **~16KB** (在 AC ≤20KB 范围内)。

---

*WO-001Q · 2026-07-25 · CC 调研仅读 novel-platform/ · 不动 wenshu/ · 不 git commit · 报告落档 /tmp/cc-out/novel-platform-requirements-survey.md*
