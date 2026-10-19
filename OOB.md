# OOB.md — Boss Out-of-Band Directives (SSOT index)

Source-of-truth index for boss OOB directives. Each entry = 1 line = fact.
Single-shot narrative (commit message length, fix attempts, retro) lives at
`.archive/.oob-v3.1-archive/OOB.md.original` (= full pre-v3.1 history).
New entries = append 1 line. Outdated = delete (= per AGENTS.md §10.3).


> Quick use: any (see OOB.md #YYYY-MM-DD) reference = look up by date below; entry must exist (= add 1 line when introducing a new date key).
## Format

- Each entry = `YYYY-MM-DD | <1-line summary>`.
- Code comment refs use `(see OOB.md #YYYY-MM-DD)` to point at entry date.

## Entries

### Date unknown (pre-§11 snapshot; = referenced from existing source comments)

| Key | Fact (1 line) |
|-----|---------------|
| v1.67 | App/AppRootScene.swift references v1.67 compliance |
| v0.30 | BookStore/WenshuLibrary/LibraryMigrator/PreviewPane: show + split-one-feature-per-doc |
| v0.28 | AGENTS.md references v1→v2 break-risk + Highlighter (SPM product = `Highlighter` not `HighlighterSwift`) |
| v0.27 | 引入三方库允许 ("不重复造轮子") |
| (unknown) | PreviewPane/SettingsOps/SidebarService/PaneNSController/ShellMiddleColumn/InspectorCatalog/AppState/AgentLifecycleTracker: canonical-path references |
| 2026-07-23 (v0.74 boss OOB) | chat persistence ordering fix + 双击"清明" tab open fix + 未接住错误 retriable + underlying error handling (4 inline refs in CardOpenOps / ChatSessionViewModel / LLMConnector / PreviewPane / AssetsPane) |
| 2026-08-30 | PaneTabBar.swift: historical CJK content removed; recoverable via `git blame` |
| 2026-09-03 | CardOpen: silent no-op (= no .alert noise) on `content.isEmpty` + duplicate-tab check |
| 2026-09-04 | Continue work-tree first (= no premature acceptance) + WenshuI18n swift-comment placeholder |
| 2026-09-14 | Editor placeholder + shell placeholder + zone module = "要修" continue; clear all pending |
| 2026-09-15 | SF Symbols 6 (3rd gen) palette rendering canonical |
| 2026-09-16 | Shell middle/content/detail: 按优先级推 + 拆了一半 |
| 2026-09-20 | SQLite 全弃用; SwiftData only; Apple-default-first = Core Spotlight 替代 FTS5 |
| 2026-09-21 | SQLite 数据库不要再用 |
| 2026-09-22 | DesignTokens 距底 30PT; 业务层不许摸基础设施 |
| 2026-10-02 | AGENTS/CLAUDE 大文件治理; color sweep 直走 HIG; skill auto-load before code; 颜色盘一次; sweep 继续推 |
| 2026-10-06 | 中央工厂保留 + 一个区域一个定义 (SFRegions source) |
| 2026-09-25 | SidebarService adopted option 3 = facet (= 4 facet scopes: per-book / per-tab / per-shelf / per-mode) |
| 2026-10-04 | "wins" rule for conflict resolution in PromptBuilder (= priority order when multiple OOBs collide) |
| 2026-10-05 | EditChapterActor #8 FileSystem*Store split (= 8 dedicated stores per feature surface) |
| 2026-10-07 | 多语言 zsh fallback = `Scripts/build-app.sh` 没复制 `.lproj` 到 `.app/Resources`; 资料库默认共享跨书 |
| 2026-10-11 | LaTeX rendering enabled via SwiftMathBridge (= MarkdownEngineLatex module; = math blocks render inline) |
| 2026-10-12 | Settings = 双栏 NavigationSplitView; Apple 系统设置 1:1; i18n 先正确再 UI; per-app Language picker; accent-color/topic size 走 Apple HIG canonical; 默认窗口 950x517; 内部 padding 调整 |
| 2026-10-08 | IconStyles monochrome fallback (per-library .monochrome; = not per-OS .accent) |
| 2026-10-09 | ImportEnvelope directive "导入" / "File > 导入" menu = canonical entry point for the import flow |
| 2026-10-10 | BookChapterTool / BookManagerTool / BookEntityTool round-NN contracts (= file round-36 + 61 + 66 + 67 + 69 + 71; = the boss 2026-10-10 batch of librarian behavior fixes) |
| 2026-10-14 | CardOpenOps auto-open behavior (= click the card to open chapter; = no double-click required) |
| 2026-10-15 | agent thinking visibility (= wenshu agent reply must expose reasoning trace; = matches hermes dev tool step-by-step transparency) |
| 2026-10-16 | 11 个独立 window 按钮 = 11 Features 1:1 创建 (Kanban/Todo/Canvas/Composer/Foreshadowing/Cron/Attachments/Manifest/Summaries/LibraryMigration/MemoryHistory); toolbar 11 button row 1:1 复刻 |
| 2026-10-16 | Chrome 大区创建 (Features/Chrome/View/ = 标题栏/工具栏独立目录) |
| 2026-10-16 | §6.2 4-slot spec relax = Views/Model/Service/Store/ (project actual shape; = 按需来; = leaf features ≤3 file 跳 Store/) |
| 2026-10-16 | §6.5 file naming relax = View/Ops/Service/State (project actual suffixes; = 不用 Apple Backyard Birds suffixes) |
| 2026-10-16 | "标题栏重复入口" = 删 InspectorView 9 个 openWindow buttons = 1 source of truth = ChromeMainToolbar; = WindowOpenButton 1 格式 |
| 2026-10-16 | "11 个 ICON 没关联面板" = 误判 (= 11 windows 都有 panel per A93); 撤 disabled placeholder 概念 (= isEnabled default true) |
| 2026-10-16 | "SF 符号绕远" = 撤 SFIcon wrapper for toolbar button; 改 Image(systemName:) Apple 1:1 path (font 14pt .regular + .secondary) |
| 2026-10-16 | "NFI 重点" = §1.11 nervous file index 持续更新 (A107 增 15 缺失 + 3 TODO closure + 1 god-class TODO) |
| 2026-10-16 | "Features/Shared/ 没分析完" = 4 文件分散, 3 移 (Backup→Features/Backup/, AppNotifications→App/, App.swift→App/WenshuAppMain.swift) + 1 删 (BaseParser dead code 0 caller) |
| 2026-10-16 | "Features/Shared/ 与 Shared/ 整理" = 3 sub-dir 复用 (UI/State/Foundation) + 顶层 App.swift + DesignTokens + Resources + Features (5 类互斥) |
| 2026-10-16 | "标题栏/工具栏应该拆独立目录" = Features/Chrome/ 创建 |
| 2026-10-16 | "3 层目录 Core/" = 1 design doc 撑 3 层 = 虚; 移到 Features/Agent/Store/ 跟实代码 = 1 source of truth |
| 2026-10-16 | docblock collapse algorithm = A112 启 + A113 batch 41 files = -8585 LOC (23 files 降到 1.0x cap) |
| 2026-10-16 | "拆同时有没有死代码" = 持续扫描: A116 删 3 dead private funcs (-175) + A119 删 2 dead @State (-2) |
| 2026-10-16 | "有没有重复代码" = A117 合并 DiffUtil (188 dup → 140 single) + A118 合并 buildImportTarget (49 dup → 22 helper) |
| 2026-10-16 | "全做完" = auto-pilot mode = 持续推, 每个 arc 自驱动 commit 1 票 + build + test |
| 2026-10-16 | 工程治理 ticket count = A1-A119 = 119 票; = main = 300 ahead of old-origin |
| 2026-10-16 | 原始需求 = 抽包 + 接入 + 清理老代码 = 3 件事 (boss OOB "原始需求抽包, 接入, 清理老代码, 做到了没？") | `eac2adf0c` |
| 2026-10-16 | "把切换包的事清干净" = 4 boundary violation 全清: WenshuConductor.verifier field 删 + WenshuConductor.init(verifier:) 参数删 + AgentProtocol.verifier 改 conductor + WenshuAppDelegate.sharedVerifier 静态删 + _setSharedConductor bridge setter 删 + 11 test files 迁 | `eac2adf0c` |
| 2026-10-16 | "你别建议了, 你明知道退不了 push 还一直建议" = ANAN sandbox 启不了 push 是已知事实 = 老板 manual push = 不再建议 push (= standing rule) | — |
| 2026-10-16 | "好, 规划收尾吧" = 本 arc 收口 = 3 件事原始需求全 done (抽包 + 接入 + 清理老代码) = 31 commits local unpushed | `eac2adf0c` |
| 2026-10-16 | "你怎么角色又串了" = 我 = ANAN = hermes 大管家 = wenshu project owner = 不是外部 sandbox = "ANAN sandbox" = 我的电脑 = 直接说 "我启不了" | — |
| 2026-10-16 | "打包 app 试了? 测试都做了?" = ANAN sandbox 内 launch 启不了 (codesign + com.apple.provenance + uid 502 + no GUI session + launchd reentrancy) = build 0 + 57/57 tests pass + 45 MB binary 完整 = 老板 sandbox 外 (`MacBook`) 启 | `eac2adf0c` |


## When to update

| Trigger | Action |
|---------|--------|
| Boss OOB in current session | Append 1-line entry. Save the long narrative at `.scratch/<ticket>/oob.md` only if commit-message replay needed. |
| Code comment adds `(see OOB.md #YYYY-MM-DD)` | Entry MUST exist in this file. If not, add the 1-line now. |
| Rule from OOB migrates to AGENTS.md | This OOB entry becomes a 1-line "superseded by AGENTS.md §X.Y" pointer. |
| Outdated | Delete the row (= no archive; = AGENTS.md §10.3). |

> First line fact: OOB.md is the SSOT index for boss OOB directives, 1 line per entry.
> Last line fact: Single-shot narrative lives at `.archive/.oob-v3.1-archive/OOB.md.original`.
| 2026-10-16 | 钥匙串开关 (Settings → Providers 顶部): ON = Apple Keychain (canonical); OFF = `~/Library/Application Support/com.wenshu.app/provider-keys.json` 0600 (非 .ws 内, AI agent `libraryRoot` 沙箱外) | `2a132f25c` |
| 2026-10-16 | "重起后上次配的 key 没了" = Apple Keychain 路径下 key 也不持久 (= 推测 `AppleKeychainStore` 在 wenshu 重装/迁移后丢 key; 实际触发条件待复现) = **延后**待老板下一步 |
| 2026-10-17 | push blocked 4-check = ssh-add agent refused + github.com HTTPS 000 + gitcode.com HTTPS 000 + git push old-origin = "No user exists for uid 502" (= 我这台机器 push 不可达 = 老板 manual push from MacBook) = 工程记录 .scratch/2026-10-17-pocock-push-blocked/ticket.md (per B.19) | — |
| 2026-10-18 | formatReadout 完全移除 + 未来不接入 (= D1 右栏 .documentTools 第 1 sub-tool 整个删; = `EditorDocumentToolsSubTool.formatReadout` enum case + 其 body + 默认 selection + `InspectorView` 不直接引用; = `Features/Editor/View/EditorFormatReadoutView.swift` 整文件删; = 7 个 `inspector.documentTools.formatReadout.*` Localizable.xcstrings keys 删; = T-05 测试集 2 个删 + T-04 覆盖率从 5 sub-tool 改成 4; = 后续工单 T-05 不许再加回, 任何 .formatReadout 复活尝试按本行 OOB 拒绝) | — |
| 2026-10-18 | "文档 = 向量, 小说 = 模型" 比喻定调 (= 单篇文档内容 NLP embedding, 不是图节点; 整部小说作模型结构理解; = 收尾后新弧 §11.26 草案; 涉及 World/Character/Scene/Foreshadowing/Setting/Reference/Chapter 实体 + 关系) | — |
| 2026-10-18 | "mem0 严重滞后于文枢项目" = 老板二次强调; = 文枢现状/状态/commit/build/test 全部 SSOT = 仓库文件 (= OOB.md + AGENTS.md + Sources/ + Tests/ + .scratch/ + git log) = mem0 仅 hint 角色 = 冲突时以仓库为准 = (reaffirm 2026-10-16 standing rule) | — |
| 2026-10-18 | §11.26 弧向量模型落地策略 = 第三方 embedding 模型 + 首次按需后台下载 (类似 Xcode 模拟器下载模式) + 0 影响包大小 / 启动 / 首页 / 初次建库; = 模型多选 (Settings 选); = 默认按系统语言判断 (zh-* = bge-small-zh-v1.5, 其它 = bge-m3 多语言); = PoC 验完 Apple NLEmbedding 短+长文本 sentence 全部 0.91-1.00 坍缩不可用, word-avg 仅 0.20-0.72 区分勉强可用但上限低, 必须引入第三方 | — |
| 2026-10-18 | §11.26 弧模型管理页 = 在 Settings → 模型 (sparkles pane) 加 "Embedding 模型" section (类似 Xcode → Settings → Components 1:1) + 后台下载 + 进度 + 重试 + 删除 + 默认选择 + 启用/停用; = 不新加 Pane; = 复用现有 modelsPane Form 风格 | — |
| 2026-10-18 | §11.26 弧模型管理默认行为 (= boss 拍: 5 待拍点 = (1) 1.1GB bge-m3 显示+标"大模型 需 1.1GB" / (2) 默认模型按 Locale 自动 (zh-* bge-small-zh, 其它 bge-m3) / (3) 单选默认 / (4) 删默认=弹确认+切下一个 / (5) 下载源 HF 直连) | — |
| 2026-10-18 | sandbox github.com HTTPS 限速 <1KB/s (= 老板明天到公司继续; = git clone 60s 0 字节 "Operation too slow"; = mlx-swift-lm SPM resolve 跑不完; = 跟 2026-10-17 push-blocked 同源, sandbox 网络层问题, 工程代码没问题; = MacBook 不受限; = §11.26 ticket 03 暂留, 老板明天选 A2/A'/B) | — |
| 2026-10-19 | "网络层 sandbox 卡" 诊断修正 (= 老板发现 sandbox 仅拦 SSH outbound 22, HTTPS 走 macOS 系统代理 127.0.0.1:7897 全程通; = 之前 OOB "github.com 限速 <1KB/s" 实际是 SSH protocol 失败被误诊为 HTTPS 限速; = git clone https://github.com/... 实测 2.8s 通; = old-origin HTTPS push 走代理可推; = Apple Metal Toolchain 仍要 Apple ID 授权, 跟网络无关; = 推论: 41 ahead old-origin 是 stale 记忆, 实际 fetch 后 main == old-origin/main) | — |
