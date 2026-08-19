# 14 — Graph view 全 vault 关系图 + Local Graph (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian 复刻范围 A 第 3 件: Graph view (全局节点关系图) + Local Graph (跟随当前 note)。

**改完:**
- `Sources/WenshuApp/Core/Graph/GraphView.swift` (SwiftUI Canvas 全 vault 节点 + 边)
- `Sources/WenshuApp/Core/Graph/LocalGraph.swift` (跟随当前 note 的 1-hop / 2-hop 子图)
- 力导向布局 (Apple Physics 框架 或自写简单力导向)
- 复用 LinkIndex (ticket 12) 作为数据源

**Blocked by:** ticket 12 (LinkIndex)

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria
- [ ] Sources/WenshuApp/Core/Graph/GraphView.swift SwiftUI Canvas 全 vault
- [ ] Sources/WenshuApp/Core/Graph/LocalGraph.swift 跟随当前 note
- [ ] 力导向布局 (Apple HIG)
- [ ] swift build exit 0
- [ ] 单元测试: GraphLayoutTests (力导向算法)
- [ ] 不动 LayoutTokens / LayoutShellView / NativeSplitter
- [ ] 不动 hermes app

## 业务语言描述 (老板懂)
- 写作 app 强需求: 人物关系图 / 情节图 / 大纲可视化
- Local Graph = 写当前章节时只看相关节点, 减少噪音

## 真值引用
- Obsidian Graph view: https://obsidian.md/help/plugins/graph
- Apple HIG SwiftUI Canvas + TimelineView
