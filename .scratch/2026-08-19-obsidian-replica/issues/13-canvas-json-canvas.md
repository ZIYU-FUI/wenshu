# 13 — Canvas 无限画布 + JSON Canvas 文件格式 (1:1 兼容 Obsidian, 老板 2026-08-19 evening 拍)

**What to build:**
Obsidian 复刻范围 A 第 2 件: Canvas 无限画布 + JSON Canvas 文件格式 1:1 实现 (open MIT spec)。

**改完:**
- `Sources/WenshuApp/Core/Canvas/JSONCanvasCodec.swift` (Codable 解析 .canvas 文件 nodes[] + edges[])
- `Sources/WenshuApp/Core/Canvas/CanvasView.swift` (SwiftUI Canvas 画节点 + 边, TimelineView 60 fps, 跟 LayoutShellView 同范式)
- `Sources/WenshuApp/Core/Canvas/CanvasEditor.swift` (节点拖拽 / 编辑 / 连接)
- 单元测试: JSONCanvasCodecTests round-trip (Obsidian .canvas → wenshu → Obsidian .canvas 1:1 兼容)
- 跨工具兼容性测试

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria
- [ ] Sources/WenshuApp/Core/Canvas/JSONCanvasCodec.swift 1:1 兼容 JSON Canvas 1.0 spec
- [ ] Sources/WenshuApp/Core/Canvas/CanvasView.swift SwiftUI Canvas + TimelineView 60 fps
- [ ] Sources/WenshuApp/Core/Canvas/CanvasEditor.swift 节点拖拽 / 编辑 / 连接
- [ ] JSON Canvas round-trip 测试: Obsidian .canvas 解析 + 编码 1:1
- [ ] swift build exit 0
- [ ] swift test exit 0 (新测试 + 老 137)
- [ ] 不动 hermes app
- [ ] 不动 LayoutTokens / LayoutShellView / NativeSplitter

## 业务语言描述 (老板懂)
- 写作 app 强需求: 白板大纲 / 人物关系图
- JSON Canvas 跨工具兼容: wenshu 写 .canvas → Obsidian 能读, Obsidian 写 → wenshu 能读

## 真值引用
- JSON Canvas 1.0 spec: https://jsoncanvas.org/spec/1.0 (open MIT)
- JSON Canvas GitHub: https://github.com/obsidianmd/jsoncanvas
- Obsidian Canvas: https://obsidian.md/canvas
