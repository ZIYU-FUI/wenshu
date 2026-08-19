# 12 — Internal Link + Backlinks 双向链接 (老板 2026-08-19 evening 拍 Obsidian 复刻范围 A)

**What to build:**
Obsidian 复刻范围 A 第 1 件: 双向链接 (Internal Link + Backlinks)。Markdown `[[name]]` 解析 + 反向链接 panel。

老板 2026-08-19 evening 拍: '复刻构建的后端服务, 前端现在验不了, 前端要做但先不接入核心项目'.

**改完 (按后端 / 前端拆):**

**后端 (本 ticket 主做, 老板先验):**
- `Sources/WenshuApp/Core/LinkGraph/LinkIndex.swift` (actor SQLite-backed, 表 schema = source_doc_id / target_ref / target_doc_id / line / offset / created_at)
- `Sources/WenshuApp/Core/LinkGraph/BacklinkResolver.swift` (异步解析所有 note 内部链接 + 双向索引)
- `Sources/WenshuApp/Core/LinkGraph/InternalLinkParser.swift` (Markdown `[[name]]` 静态解析, 跟 v0.18 ticket 05 KanbanStore 的 SQLite actor 同范式)
- Markdown 解析 `parseInternalLinks(content) -> [(text, target, line, offset)]` 接 `LibraryStoring.loadDocumentContent`
- 单元测试 (LinkIndexTests add / search / resolve, BacklinkResolverTests, InternalLinkParserTests 中英文 / 嵌套 / 转义)

**前端 (做但不接入, 留 standalone SwiftUI View 等老板验 macOS):**
- `Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift` (SwiftUI View, 右栏显示当前 note backlinks)
- 单元测试 (BacklinksPanelTests ViewModel 渲染逻辑, 不渲染实际视图)
- **不接入核心项目**: 不接 LayoutShellView, 不接 BookEditorSheet, 不接 LibraryOutlineView, 留 standalone 模块

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit + push (老板 8/19 evening '不需要验收' + 自行决策授权)

## Acceptance criteria

**后端 (老板验):**
- [ ] Sources/WenshuApp/Core/LinkGraph/LinkIndex.swift actor SQLite-backed
- [ ] Sources/WenshuApp/Core/LinkGraph/BacklinkResolver.swift 双向索引
- [ ] Sources/WenshuApp/Core/LinkGraph/InternalLinkParser.swift Markdown `[[name]]` 解析
- [ ] Markdown parseInternalLinks(content) 接 LibraryStoring (optional 集成)
- [ ] swift build exit 0
- [ ] swift test exit 0 (新测试 + 老 137)
- [ ] 单元测试: LinkIndexTests + BacklinkResolverTests + InternalLinkParserTests

**前端 (做但不接入):**
- [ ] Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift SwiftUI View
- [ ] BacklinksPanelTests ViewModel 渲染逻辑 (不接 LayoutShellView)

**不动:**
- [ ] hermes app / ~/.hermes/profiles/pocock/
- [ ] wenshu 当前 SwiftUI UI / 业务逻辑 (LayoutTokens / LayoutShellView / NativeSplitter)
- [ ] BacklinksPanel **不接入核心项目** (留 standalone 等老板 macOS 验)

## 业务语言描述 (老板懂)
- 写作 app 强需求: 人物/章节/设定能互引 + 写当前章节时能看到所有引用它的设定
- 后端先做 (actor + SQLite + 解析 + 测试), 老板 swift build + swift test 验
- 前端 View 做但不接入, 等老板 macOS 验
- 工程管理老板授权, 不需要验收

## 真值引用
- Obsidian Backlinks plugin: https://obsidian.md/help/plugins/backlinks
- Apple HIG SQLite 真值: https://developer.apple.com/documentation/sqlite
- v0.18 ticket 01 MemoryStore actor SQLite 范式: commit 047b43cfa (老板 8/19 拍)
- SilverBullet page ref `[[name]]` 同样语法 (跟 Obsidian / SilverBullet 双向兼容)
