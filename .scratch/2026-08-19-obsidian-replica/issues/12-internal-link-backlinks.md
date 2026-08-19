# 12 — Internal Link + Backlinks 双向链接 (老板 2026-08-19 evening 拍 Obsidian 复刻范围 A)

**What to build:**
Obsidian 复刻范围 A 第 1 件: 双向链接 (Internal Link + Backlinks)。Markdown `[[name]]` 解析 + 反向链接 panel。

**改完:**
- `Sources/WenshuApp/Core/LinkGraph/LinkIndex.swift` (actor SQLite-backed, 表 schema = source_doc_id / target_ref / target_doc_id / line / offset)
- `Sources/WenshuApp/Core/LinkGraph/BacklinkResolver.swift` (异步解析所有 note 内部链接 + 双向索引)
- `Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift` (SwiftUI View, 右栏显示当前 note backlinks)
- Markdown 解析 `parseInternalLinks(content) -> [(text, target)]` 接 `LibraryStoring.loadDocumentContent`
- 单元测试 (LinkIndex add / search / BacklinkResolver resolve)

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit + push (老板 8/19 evening '不需要验收' + 自行决策授权)

## Acceptance criteria
- [ ] Sources/WenshuApp/Core/LinkGraph/LinkIndex.swift actor SQLite-backed
- [ ] Sources/WenshuApp/Core/LinkGraph/BacklinkResolver.swift 双向索引
- [ ] Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift SwiftUI View
- [ ] Markdown parseInternalLinks(content) 接 LibraryStoring
- [ ] swift build exit 0
- [ ] 单元测试: LinkIndexTests + BacklinkResolverTests
- [ ] 不动 hermes app / ~/.hermes/profiles/pocock/
- [ ] 不动 wenshu 当前 SwiftUI UI / 业务逻辑 (LayoutTokens / LayoutShellView / NativeSplitter)

## 业务语言描述 (老板懂)
- 写作 app 强需求: 人物/章节/设定能互引 + 写当前章节时能看到所有引用它的设定
- 工程管理老板授权, 不需要验收

## 真值引用
- Obsidian Backlinks plugin: https://obsidian.md/help/plugins/backlinks
- Apple HIG SQLite 真值: https://developer.apple.com/documentation/sqlite
