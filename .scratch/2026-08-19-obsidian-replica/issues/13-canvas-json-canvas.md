# 13 — Canvas infinite canvas + JSON Canvas file format (1:1 compatible with Obsidian, 老板 2026-08-19 evening 拍)

**What to build:**
Obsidian replica scope A item 2: Canvas infinite canvas + JSON Canvas file format 1:1 implementation (open MIT spec).

**After change:**
- `Sources/WenshuApp/Core/Canvas/JSONCanvasCodec.swift` (Codable parse .canvas file nodes[] + edges[])
- `Sources/WenshuApp/Core/Canvas/CanvasView.swift` (SwiftUI Canvas draw nodes + edges, TimelineView 60 fps, same paradigm as LayoutShellView)
- `Sources/WenshuApp/Core/Canvas/CanvasEditor.swift` (node drag / edit / connect)
- Unit tests: JSONCanvasCodecTests round-trip (Obsidian .canvas → wenshu → Obsidian .canvas 1:1 compatible)
- Cross-tool compatibility test

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Canvas/JSONCanvasCodec.swift` 1:1 compatible with JSON Canvas 1.0 spec
- [ ] `Sources/WenshuApp/Core/Canvas/CanvasView.swift` SwiftUI Canvas + TimelineView 60 fps
- [ ] `Sources/WenshuApp/Core/Canvas/CanvasEditor.swift` node drag / edit / connect
- [ ] JSON Canvas round-trip test: Obsidian .canvas parse + encode 1:1
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0 (new tests + old 137)
- [ ] Do not touch hermes app
- [ ] Do not touch LayoutTokens / LayoutShellView / NativeSplitter

## Business-language description (老板 understands)

- Writing app strong requirement: whiteboard outline / character relationship graph
- JSON Canvas cross-tool compatibility: wenshu writes .canvas → Obsidian can read, Obsidian writes → wenshu can read

## Truth references

- JSON Canvas 1.0 spec: https://jsoncanvas.org/spec/1.0 (open MIT)
- JSON Canvas GitHub: https://github.com/obsidianmd/jsoncanvas
- Obsidian Canvas: https://obsidian.md/canvas