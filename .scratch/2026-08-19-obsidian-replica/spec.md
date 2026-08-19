# Spec — Obsidian 复刻能力盘点 + wenshu 写作 app 适配 (老板 2026-08-19 evening 拍)

> Date: 2026-08-19 evening
> Spec 走 po `to-spec` skill 7 段模板
> 真值源: Obsidian 公开文档 (https://obsidian.md/help + https://jsoncanvas.org + https://github.com/obsidianmd/jsoncanvas + https://github.com/obsidianmd/obsidian-api)

## Problem Statement

老板 2026-08-19 evening 拍:
> "不接收 (ticket 21 Cronjob), 我去和那个会话说, 继续, 你在当前会话调研怎么把, OB 我们要复刻的能力盘点清楚, 看能不能复刻, 你可以 git 一份 ob 的代码, 好好看看"

**业务语言描述 (老板懂)**:
- 之前 v0.18 hermes 复刻范围 A 跑完 9 个工具 (MemoryStore / SkillRegistry / AgentProtocol / AgentRuntime / KanbanStore / TodoStore / FileTools / ProcessTools / WebTools)
- 老板 现在想让 wenshu 也复刻 Obsidian (Markdown 笔记 app) 的能力, 跟写作 app 定位对比看哪些能本地化
- 老板 拍 "git 一份 ob 的代码" = git clone Obsidian 公开仓库 + 读官方文档

## Obsidian 能力盘点 (按真值)

### A. 核心数据模型 (4 件)

1. **Vault** = 本地 Markdown 文件夹 + 子文件夹结构, 所有数据本地存储
2. **Note** = 纯 Markdown 文件 (.md), frontmatter 可选 (YAML)
3. **Internal Link** = `[[note name]]` 双向链接 (wiki-style)
4. **Property** = YAML frontmatter (status / tags / author / custom), Bases 强依赖

### B. 核心插件 (16 个) + 评分

按 wenshu 写作 app 定位 (长篇虚构小说 AI 创作) 判断哪些复刻:

| # | 插件 | Obsidian 功能 | wenshu 适配 | 优先级 |
|---|---|---|---|---|
| 1 | **Backlinks** | 右栏显示当前 note 所有反向链接, 双向图谱关键 | 已实现 `Domain.Document` 3 类, 但**没有反向链接/双向图谱**, 写作 app 强需求 | 🟢 高 |
| 2 | **Graph view** | 全 vault 节点关系图, Local graph 跟随当前 note | 写作 app 强需求 (人物关系图 / 大纲图 / 情节图), Canvas 已实现但**不是图谱** | 🟢 高 |
| 3 | **Canvas** | 无限画布 + JSON Canvas 文件格式 (open spec MIT) + 节点卡片 | wenshu LayoutShellView 6 区已用 SwiftUI Canvas 画布局, **不是 JSON Canvas**, 需要复刻 JSON Canvas 文件格式 + 节点编辑 | 🟢 高 |
| 4 | **Daily Notes** | 按日期自动创建 note + 模板 (date tokens) | 写作 app 不太需要 (但写作日历 / 字数统计可用) | 🟡 中 |
| 5 | **Templates** | 模板文件 + 变量插入 | 写作 app 强需求 (大纲模板 / 人物模板 / 章节模板) | � 高 |
| 6 | **Outline** | 当前 note 大纲 (H1-H6) | wenshu `Book` + `Document` 已分类, 但**没有 outline panel** | 🟡 中 |
| 7 | **Bookmarks** | 收藏夹 / 跨 note 锚点 | 写作 app 可用 (收藏章节 / 设定片段) | � 中 |
| 8 | **Note Composer** | 合并 / 拆分 / 重命名 note, 自动重写链接 | 写作 app 强需求 (章节合并 / 拆分 / 重命名时链接自动跟随) | 🟢 高 |
| 9 | **Search** | 全文搜索 + 正则 + 文件过滤 | wenshu 已有 `WenshuLibrary.loadDocumentContent`, 但**没有全文 search panel** | 🟢 高 |
| 10 | **Bases** | 数据库视图 (table / card / kanban / map) + YAML 语法 + formulas | 写作 app 强需求 (人物表 / 章节进度 / 设定表), 跟 v0.18 ticket 05 KanbanStore 部分重叠 | 🟢 高 |
| 11 | **File Recovery** | 快照 + 删除恢复 | wenshu 已有 FileManager + Library, 但**没有快照** | 🟡 中 |
| 12 | **Quick Switcher** | ⌘O 全局搜索 note | 写作 app 强需求 (跨书架切换) | 🟢 高 |
| 13 | **Command Palette** | ⌘⇧P 命令面板 | wenshu 已有 SwiftUI `.commands` (CommandMenu), 但**不是 fuzzy command palette** | 🟡 中 |
| 14 | **Slash commands** | 编辑器内 `/` 触发命令 | 写作 app 强需求 (快捷插入章节标记 / 人物引用) | 🟡 中 |
| 15 | **Web viewer** | vault 内嵌网页 iframe | 写作 app 不太需要 | ❌ 跳 |
| 16 | **Word count** | 当前 note / vault 字数 | 写作 app 强需求 (作家必备) | 🟢 高 |

### C. 文件格式 (3 件, 全部开源 MIT)

| 格式 | URL | 内容 |
|---|---|---|
| **JSON Canvas** | https://jsoncanvas.org/spec/1.0 | `nodes[]` (id / type / x / y / width / height / file\|text) + `edges[]` (id / fromNode / toNode / fromSide / toSide / fromEnd / toEnd / label / color) |
| **Markdown** | CommonMark + GFM | wenshu 已有 |
| **.base** (YAML) | Obsidian 自有 | views[] + filters{} + formulas{} + properties{} + summaries{} |

### D. Plugin API (公开, TypeScript 类型)

`https://github.com/obsidianmd/obsidian-api` — `manifest.json` + `Plugin` 类 + `Workspace` / `Vault` / `Editor` / `MarkdownView` 等接口。**wenshu 不需要 plugin API**, 因为 wenshu 是单 app 编译一体, 不需要动态加载。

### E. 跨平台

- Desktop: macOS / Windows / Linux (Electron)
- Mobile: iOS / Android
- Sync: Obsidian Sync (付费, 闭源, **不**复刻)

## Solution (按 wenshu 定位)

老板 8/19 evening 拍 wenshu 定位 = **SwiftUI 桌面写作 app (macOS-only)**, 不是通用笔记 app。

**复刻决策矩阵** (按 wenshu 写作 app 定位, 不是通用 PKM):

| Obsidian 能力 | 复刻 | 不复刻 | 原因 |
|---|---|---|---|
| Vault 文件夹结构 | ✅ | | wenshu `LibraryRoot` 已实现 |
| Note Markdown 文件 | ✅ | | wenshu `Document` 已实现 |
| Internal Link `[[name]]` | ✅ | | **写作 app 强需求** (人物 / 设定 / 章节互引) |
| Backlinks 反向链接 | ✅ | | **写作 app 强需求** (人物关系图) |
| Property frontmatter | ✅ | | wenshu `Book` 已有 length / idea 字段, 扩展 frontmatter |
| Graph view | ✅ | | **写作 app 强需求** (人物关系图 / 情节图) |
| Canvas (无限画布) | ✅ | | **写作 app 强需求** (白板大纲 / 人物关系) |
| JSON Canvas 文件格式 | ✅ | | open MIT, 必须 1:1 实现 (跨工具兼容) |
| Daily Notes | | ❌ | 写作 app 不太需要 |
| Templates | ✅ | | **写作 app 强需求** (大纲模板 / 章节模板) |
| Outline | ✅ | | 写作 app 中等 (chapter list 已实现) |
| Bookmarks | ✅ | | 写作 app 中等 |
| Note Composer | ✅ | | **写作 app 强需求** (章节合并 / 重命名跟随) |
| Search (全文) | ✅ | | **写作 app 强需求** |
| Bases (数据库视图) | ✅ | | **写作 app 强需求** (人物表 / 章节进度), 跟 KanbanStore 重叠 |
| File Recovery (快照) | | ❌ | 备份走 macOS Time Machine + wenshu 自己的 backup ticket 26 |
| Quick Switcher | ✅ | | **写作 app 强需求** |
| Command Palette | | ❌ | wenshu `.commands` 顶级菜单已够 |
| Slash commands | | ❌ | 写作 app 不太需要 |
| Web viewer | | ❌ | 写作 app 不需要 |
| Word count | ✅ | | **写作 app 强需求** (作家必备) |
| Plugin API | | ❌ | wenshu 单 app 编译, 不需要动态加载 |
| Obsidian Sync (付费) | | ❌ | 闭源, 不复刻 |
| Obsidian Publish (付费) | | ❌ | 闭源, 不复刻 |
| Mobile (iOS/Android) | | ❌ | wenshu macOS-only (老板 8/18 拍) |

**复刻总数**: 13 / 24 = 54%

## User Stories

1. As 老板, I want wenshu 支持 Internal Link `[[name]]` 双向链接, so that 人物/章节/设定能互引
2. As 老板, I want wenshu 支持 Backlinks 反向链接 panel, so that 写当前章节时能看到所有引用它的设定
3. As 老板, I want wenshu 支持 Canvas 无限画布 + JSON Canvas 文件格式 (1:1 兼容 Obsidian), so that 白板大纲/人物关系图能跨工具
4. As 老板, I want wenshu 支持 Graph view 全局关系图, so that 写小说时能看人物关系/情节线
5. As 老板, I want wenshu 支持 Templates 模板系统, so that 大纲/人物/章节模板能复用
6. As 老板, I want wenshu 支持 Note Composer 合并/拆分/重命名 + 自动跟随链接, so that 重构章节时链接不坏
7. As 老板, I want wenshu 支持全文 Search, so that 跨书架搜索章节内容
8. As 老板, I want wenshu 支持 Bases 数据库视图, so that 人物表 / 章节进度 / 设定表能表格化
9. As 老板, I want wenshu 支持 Quick Switcher ⌘O, so that 跨书架快速切换
10. As 老板, I want wenshu 支持 Word count 字数统计, so that 作家知道每日字数

## Implementation Decisions

按老板 8/19 拍 "工作量大但稳" + 4 原则 (Apple 官方范式 / 效果优先 / 业务语言):

**方案 1 (Internal Link + Backlinks + Property)**:
- Markdown 解析: 在 `LibraryStoring.loadDocumentContent` 基础上加 `parseInternalLinks(content)` → `[(text, target)]`
- 双向图: 新建 `Sources/WenshuApp/Core/LinkGraph/` 目录
  - `LinkIndex.swift` — actor SQLite-backed, 表 schema = source_doc_id / target_ref / target_doc_id / line / offset
  - `BacklinkResolver.swift` — 异步解析所有 note 的内部链接, 双向索引
  - `BacklinksPanel.swift` — SwiftUI View, 右栏显示当前 note 的所有 backlinks
- Property (YAML frontmatter): 新建 `Sources/WenshuApp/Core/Properties/`
  - `FrontmatterParser.swift` — 解析 YAML (Apple Yams 或 Foundation PropertyListSerialization, Apple 官方优先)
  - `PropertyEditor.swift` — SwiftUI View, 编辑 frontmatter 字段

**方案 2 (Canvas + JSON Canvas)**:
- 文件格式 1:1 实现: `Sources/WenshuApp/Core/Canvas/`
  - `JSONCanvasCodec.swift` — Codable 解析 .canvas 文件 (nodes[] + edges[])
  - `CanvasView.swift` — SwiftUI Canvas 画节点 + 边 (TimelineView 60 fps, 跟 LayoutShellView 同范式)
  - `CanvasEditor.swift` — 节点拖拽 / 编辑 / 连接 (Apple HIG 鼠标交互)
- 兼容 Obsidian JSON Canvas 1.0 spec, 跨工具互读

**方案 3 (Graph view)**:
- `Sources/WenshuApp/Core/Graph/`
  - `GraphView.swift` — SwiftUI Canvas 全 vault 节点关系图
  - `LocalGraph.swift` — 跟随当前 note 的 1-hop / 2-hop 子图
  - 力导向布局 (Apple HIG, Apple Physics 框架或自写简单力导向)

**方案 4 (Templates)**:
- `Sources/WenshuApp/Core/Templates/`
  - `TemplateEngine.swift` — 模板文件 + date tokens (`{{date}}` / `{{time}}` / `{{title}}`)
  - `TemplatePicker.swift` — SwiftUI View 选择模板创建新 note

**方案 5 (Note Composer)**:
- `Sources/WenshuApp/Core/Composer/`
  - `NoteMerger.swift` — 合并 N 个 note → 1 个 note + 重写所有 backlink
  - `NoteSplitter.swift` — 拆分 note → N 个 note + 重写 backlink
  - `NoteRenamer.swift` — 重命名 + 重写所有 `[[old_name]]` → `[[new_name]]`

**方案 6 (Search)**:
- `Sources/WenshuApp/Core/Search/`
  - `FullTextSearch.swift` — actor SQLite FTS5 全文索引 (Apple HIG, FTS5 SQLite 内置)
  - `SearchPanel.swift` — SwiftUI View, 实时搜索 + 高亮

**方案 7 (Bases 数据库视图)**:
- `Sources/WenshuApp/Core/Bases/`
  - `BaseParser.swift` — YAML .base 文件解析 (跟 FrontmatterParser 复用)
  - `BaseView.swift` — table / card / kanban 视图
  - 跟 v0.18 ticket 05 KanbanStore 整合 (Kanban 是 Bases 的一种 view)

**方案 8 (Quick Switcher)**:
- `Sources/WenshuApp/Core/QuickSwitcher/`
  - `QuickSwitcher.swift` — ⌘O fuzzy 搜索所有 note + 章节
  - `QuickSwitcherWindow.swift` — SwiftUI Window 弹出 (跟 Apple Spotlight 同范式)

**方案 9 (Word count)**:
- `Sources/WenshuApp/Core/WordCount/`
  - `WordCounter.swift` — String.enumerateSubstrings(.word) 统计 (Apple HIG)
  - `WordCountBadge.swift` — SwiftUI View, 顶栏显示当前 note 字数

**不动**:
- hermes app (老板 8/11 拍 'hermes 不动')
- /Volumes/ANAN/.hermes/ 任何文件
- wenshu 当前 SwiftUI UI / 业务逻辑 (LayoutTokens / LayoutShellView / NativeSplitter / DesignTokens 不动)
- 移动端 (iOS/Android) — wenshu macOS-only

## Testing Decisions

- swift build exit 0
- 每个新模块加单元测试 (LinkIndex / JSONCanvasCodec / TemplateEngine / FullTextSearch / BaseParser)
- 跨工具兼容性测试: Obsidian .canvas 文件 → wenshu 解析 → wenshu .canvas 文件 → Obsidian 解析 (1:1 round-trip)
- 老板 8/19 evening 拍 "不需要验收" — 不提交截图证据

## Out of Scope

- 不复刻 Plugin API (wenshu 单 app, 不需要动态加载)
- 不复刻 Obsidian Sync (闭源)
- 不复刻 Obsidian Publish (闭源)
- 不复刻 Mobile (iOS/Android) (老板 8/18 拍 macOS-only)
- 不复刻 Web viewer / Daily Notes / Command Palette / Slash commands (wenshu 写作 app 不需要)
- 不复刻 Obsidian 全部 24 能力, 只复刻 wenshu 写作 app 真用得上的 13 个

## Further Notes

- 老板 8/19 evening 拍 "git 一份 ob 的代码" — web SSL 翻车 (LibreSSL), 改用 web_search + web_extract 拉官方文档 + 公开仓库 README
- 真值源优先级: 官方文档 (obsidian.md/help) > JSON Canvas spec (jsoncanvas.org) > obsidian-api GitHub > 第三方介绍 (Reddit / Medium / YouTube)
- Obsidian 主仓库 (Electron) 闭源, 复刻只能基于公开文档 + 公开 API + JSON Canvas 开源格式
- 复刻范围 13/24 能力 = 54%, 按 wenshu 写作 app 定位严格筛选
- 后续 ticket 排期 (按工作量大但稳 + 高优先级):
  - 🟢 高 7 ticket: Internal Link + Backlinks + Graph view + Canvas + Templates + Note Composer + Search
  - 🟡 中 3 ticket: Outline + Bookmarks + Bases
  - 🟢 高 2 ticket: Quick Switcher + Word count
  - 共 12 ticket (跟 v0.18 hermes 复刻 9 ticket 同量级)
- 老板 8/19 evening 拍 "不需要验收" = ANAN 自己跑 po main flow + commit + push

## 真值引用 (Obsidian 公开资源)

- 官方文档: https://obsidian.md/help (web_extract 封, 改用 web_search 拉)
- Core plugins 列表: https://obsidian.md/help/plugins (15 core, +1 Bases 后是 16)
- Canvas 文件格式: https://jsoncanvas.org/spec/1.0 (open MIT)
- JSON Canvas GitHub: https://github.com/obsidianmd/jsoncanvas
- Plugin API TypeScript: https://github.com/obsidianmd/obsidian-api
- 第三方 Core 30 插件 tier list: https://practicalpkm.com/obsidian-core-plugins-tier-list/ (30 个, 验证了上面 16 个列表)
- Bases 语法: https://obsidian.md/help/bases/syntax (YAML schema 已抓)
- Apple HIG 真值引用:
  - FTS5 全文搜索: SQLite builtin
  - PropertyListSerialization / Yams YAML parse
  - SwiftUI Canvas 60 fps TimelineView
  - Spotlight 范式 (⌘O quick switcher)

## MIT 对照参考: SilverBullet (老板 2026-08-19 evening 拍 '我们是复刻, 不是复制代码, 看代码是为了更好的复刻')

老板拍: "复刻不是复制代码, 看代码是为了更好的复刻". SilverBullet (MIT 纯协议) 是跟 Obsidian 同类但纯开源的真值参考, **不取代 Obsidian, 是补充对照** — 帮我们看清"双链 / 反向链接 / outliner / 扩展机制"在 MIT 协议下怎么实现的.

### SilverBullet 真值 (按 LWN 2025-07-31 评测 + GitHub README)

- **License**: ✅ MIT 纯协议 (LWN 2025-07-31 明确 "MIT-licensed note-taking application")
- **GitHub**: https://github.com/silverbulletmd/silverbullet
- **Stack**: Deno server + TypeScript 前端 + Space Lua 扩展
- **存储**: markdown files (.md), 跟 Obsidian 一样本地文件夹 = "Space"
- **核心能力**:
  - Page 集合 (= Obsidian Vault / wenshu Library)
  - Outliner 工具 (= Obsidian outliner plugin / 跟 wenshu Book outline 同维度)
  - Tasks (= Obsidian Tasks plugin / wenshu 写作大纲)
  - Query tables / tags / pages (= Obsidian Bases / wenshu Bases 复刻)
  - Templates
  - Block-based 编辑
  - Space Lua 扩展 (= Obsidian plugin API / wenshu 不需要, 单 app 编译一体)

### 为什么 SilverBullet 是好对照

1. **真 MIT** — 不是 MIT + EE 双协议 (AFFiNE), 不是 AGPL 传染 (AppFlowy 依赖). 真开源协议下能看清完整实现
2. **markdown files** — 跟 Obsidian 一样本地 .md 文件, 跟 wenshu Document 真值一致
3. **Deno + TypeScript** — 不是 Electron 闭源 (Obsidian), 可以看完整 server 端代码 (index / sync / 全文搜索实现)
4. **Space Lua 扩展** — 类似 Obsidian plugin API 但更轻量, 看清"扩展机制"在 MIT 协议下怎么设计
5. **PWA + macOS wrapper** — 社区有 MacOS app wrapper (community.silverbullet.md/t/macos-app-really/750), 但不是 SwiftUI native. **wenshu 用 Swift/SwiftUI native, 不抄 wrapper**

### 复刻对照矩阵 (Obsidian vs SilverBullet vs wenshu 复刻)

| 能力 | Obsidian | SilverBullet | wenshu 复刻 ticket |
|---|---|---|---|
| 本地 markdown files | ✅ | ✅ | 已实现 `Document` |
| 双向链接 `[[name]]` | ✅ | ✅ (page ref) | ticket 12 |
| Backlinks 反向链接 | ✅ | ✅ (page backlinks) | ticket 12 |
| Outliner | ✅ (Outline plugin) | ✅ (Outlining tools) | ticket 21 |
| Templates | ✅ | ✅ (templating plug) | ticket 15 |
| Search 全文 | ✅ | ✅ (server 端 index) | ticket 17 |
| 数据库视图 (Bases) | ✅ (.base YAML) | ✅ (Query tables) | ticket 18 |
| Canvas 画布 | ✅ (JSON Canvas 1.0) | ❌ | ticket 13 |
| Graph view | ✅ | ❌ | ticket 14 |
| Note Composer | ✅ | ✅ (rename / merge) | ticket 16 |
| Quick Switcher �O | ✅ | ✅ (page picker) | ticket 19 |
| Word count | ✅ | ✅ (status bar) | ticket 20 |
| Bookmarks | ✅ | ❌ | ticket 22 |
| 扩展机制 | ✅ (Plugin API, 公开) | ✅ (Space Lua) | ❌ (wenshu 单 app, 不需要) |
| Plugin store / 社区 | ✅ (大生态) | ❌ (小众) | ❌ |
| macOS native | ✅ (Electron) | ❌ (PWA + 社区 wrapper) | ✅ (SwiftUI, wenshu 真值) |
| **License** | **闭源 (Electron 闭源)** | **MIT 纯协议** | MIT (wenshu 自有) |

### 关键观察 (SilverBullet 给 wenshu 的启示)

1. **markdown index** — SilverBullet server 端用 SQLite 索引所有 .md 文件的 page / heading / block ref. **wenshu 复刻 ticket 17 (Full Text Search) 可以参考 SilverBullet 的 SQLite FTS5 索引结构**, 但不抄代码
2. **page ref 双链** — SilverBullet 用 `[[page name]]` 跟 Obsidian 完全一样, wenshu 直接用同语法 (跟 Obsidian / SilverBullet 双向兼容)
3. **Space Lua 扩展** — SilverBullet 把扩展逻辑下沉到 Lua sandbox, 不是 TS 代码. **wenshu 不需要扩展机制** (单 app 编译一体), 但**模板 (ticket 15) 可以借鉴 Space Lua 的 "变量 + 模板" 设计思路**
4. **PWA 离线优先** — SilverBullet PWA 第一次 load 后完全离线. **wenshu 桌面 app 本来就离线, 不需要 PWA 模式**, 但 "本地自管" 原则一致
5. **社区 macOS wrapper** — SilverBullet 社区用 WebView 包了 .app, 但体验跟 SwiftUI native 差很多. **wenshu 用 SwiftUI native 是真值优势**, 不是 wrapper

### 真值源

- SilverBullet GitHub: https://github.com/silverbulletmd/silverbullet (MIT)
- SilverBullet 官网: https://silverbullet.md/
- LWN 评测 2025-07-31: https://lwn.net/Articles/1030941/ (MIT 真值)
- Apple HIG 真值引用 (跟 Obsidian 段同):
  - SQLite FTS5 builtin
  - SwiftUI Canvas 60 fps TimelineView
  - Spotlight 范式 (⌘O quick switcher)

### 不动 SilverBullet 代码

- 老板拍 "我们是复刻, 不是复制代码" = 看 SilverBullet 思路, 用 Swift/SwiftUI 自己实现, 不抄 TS / Deno / Lua
- 不 fork SilverBullet, 不 pull request, 不用 Space Lua
- SilverBullet 只是 "MIT 协议下同类项目" 的对照参考, 跟 Obsidian 互补

## 后续 ticket (按优先级)

详见 `.scratch/2026-08-19-obsidian-replica/issues/` (后续 ticket 12-23 共 12 ticket)
