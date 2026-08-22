# 14 — Graph view full vault relationship graph + Local Graph (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian replica scope A item 3: Graph view (global node relationship graph) + Local Graph (follows current note).

**After change:**
- `Sources/WenshuApp/Core/Graph/GraphView.swift` (SwiftUI Canvas full vault nodes + edges)
- `Sources/WenshuApp/Core/Graph/LocalGraph.swift` (follows current note's 1-hop / 2-hop sub-graph)
- Force-directed layout (Apple Physics framework or self-write simple force-directed)
- Reuse LinkIndex (ticket 12) as data source

**Blocked by:** ticket 12 (LinkIndex)

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Graph/GraphView.swift` SwiftUI Canvas full vault
- [ ] `Sources/WenshuApp/Core/Graph/LocalGraph.swift` follows current note
- [ ] Force-directed layout (Apple HIG)
- [ ] `swift build` exit 0
- [ ] Unit tests: GraphLayoutTests (force-directed algorithm)
- [ ] Do not touch LayoutTokens / LayoutShellView / NativeSplitter
- [ ] Do not touch hermes app

## Business-language description (老板 understands)

- Writing app strong requirement: character relationship graph / plot graph / outline visualization
- Local Graph = when writing current chapter only see related nodes, reduce noise

## Truth references

- Obsidian Graph view: https://obsidian.md/help/plugins/graph
- Apple HIG SwiftUI Canvas + TimelineView