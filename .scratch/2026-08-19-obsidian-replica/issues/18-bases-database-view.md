# 18 — Bases 数据库视图 (table / card / kanban) + .base YAML (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian 复刻范围 A 第 7 件: Bases 数据库视图 (1:1 兼容 .base YAML 文件, 跟 v0.18 ticket 05 KanbanStore 整合)。

**改完:**
- `Sources/WenshuApp/Core/Bases/BaseParser.swift` (YAML .base 文件解析, 跟 FrontmatterParser 复用)
- `Sources/WenshuApp/Core/Bases/BaseView.swift` (table / card / kanban 视图)
- 跟 v0.18 ticket 05 KanbanStore 整合 (Kanban 是 Bases 的一种 view)

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria
- [ ] Sources/WenshuApp/Core/Bases/BaseParser.swift YAML .base
- [ ] Sources/WenshuApp/Core/Bases/BaseView.swift table / card / kanban
- [ ] 跟 KanbanStore 整合 (复用 ticket 05)
- [ ] swift build exit 0
- [ ] 单元测试: BaseParserTests (YAML round-trip) + BaseViewTests
- [ ] 不动 hermes app
- [ ] 不动 LayoutTokens / LayoutShellView

## 业务语言描述 (老板懂)
- 写作 app 强需求: 人物表 / 章节进度 / 设定表
- 跟 KanbanStore 整合, 不重复造轮子

## 真值引用
- Obsidian Bases: https://obsidian.md/help/bases
- Bases syntax: https://obsidian.md/help/bases/syntax (YAML schema)
- 复用 v0.18 ticket 05 KanbanStore (commit 2172c421c)
