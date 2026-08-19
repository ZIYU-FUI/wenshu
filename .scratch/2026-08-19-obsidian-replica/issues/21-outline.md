# 21 — Outline 当前 note 大纲 (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian 复刻范围 A 第 10 件: Outline (当前 note H1-H6 大纲 panel)。

**改完:**
- `Sources/WenshuApp/Core/Outline/OutlineExtractor.swift` (Markdown heading 解析: H1-H6)
- `Sources/WenshuApp/Core/Outline/OutlinePanel.swift` (SwiftUI View, 右栏显示大纲 + 点击跳转)

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria
- [ ] Sources/WenshuApp/Core/Outline/OutlineExtractor.swift H1-H6 解析
- [ ] Sources/WenshuApp/Core/Outline/OutlinePanel.swift SwiftUI View
- [ ] swift build exit 0
- [ ] 单元测试: OutlineExtractorTests (H1-H6 + 中英文)
- [ ] 不动 hermes app
- [ ] 不动 LayoutTokens / LayoutShellView

## 业务语言描述 (老板懂)
- 写作 app 中等: 章节 list 已实现 (Book), outline 是 note 内部 H1-H6 大纲
- 点击大纲跳转

## 真值引用
- Obsidian Outline: https://obsidian.md/help/plugins/outline
