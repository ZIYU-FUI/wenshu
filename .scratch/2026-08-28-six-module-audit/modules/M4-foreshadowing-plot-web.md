# M4 Foreshadowing & Plot Web — library survey

**Date:** 2026-08-28 · **Module:** M4 · **Author:** wenshu pocock M4 sub-agent
**Spec:** `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-28-six-module-audit/spec.md`
**Inventory:** `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-28-six-module-audit/modules/inventory.json`
**Gate:** `AGENTS.md §11.1` (stars ≥100 / last commit ≤12 mo / MIT-Apache-BSD-PD / macOS-first OR macOS-supported) + `ADR-0008` view-framework FORBIDDEN carve-out

---

## Module scope

`foreshadowing/` folder + **Graph** view (foreshadowing ↔ chapter ↔ character ↔ outline edge graph) + **LinkGraph** (markdown `[[name]]` parser + backlink resolver) + **Canvas** (Obsidian `.canvas` JSON infochart) + **CrossRefInject** (entity surface-form → chapter frontmatter auto-tagger).

Per `inventory.json`, the four `needs_survey` gaps:

| Gap | Domain |
|---|---|
| 1 | graph layout algorithm (force-directed / tree) |
| 2 | graph view rendering (SwiftUI vs AppKit) |
| 3 | canvas / node-edge rendering |
| 4 | interactive graph node manipulation |

## Boss anchor & ADR-0008 carve-out read

Boss anchor (spec §"Anchor"): "Apple stack exclusive (macOS-only)", Swift 6.4 + SwiftUI Observation + AppKit.
ADR-0008 (`/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-28-v0-28-free-layout/ADR-0008-no-3rd-party-view-framework.md`):

> wenshu does not adopt third-party view-framework / pane / dock / split libraries for the WorkspaceView layer. Drag UX must be self-implemented and verified by automated regression tests.

**Applies to (= forbidden at runtime)**: pane / panel / dock / split / tab-bar libraries; custom `Layout` protocol libraries; SwiftUI extensions targeting view architecture (SwiftUIX class).
**Does NOT apply to (= allowed)**: image / icon libs; runtime wrappers (Defaults, KeyboardShortcuts); `Textual` (text-rendering leaf view); `CodeEditTextView` (replaces the editor view only); markdown render libs; **dev/test tools**. Notably, ADR-0008's scope is **view-architecture libraries that claim layout / pane / drag of the workspace shell**. It says *nothing* against pure-data libraries (= graph algorithm, KD-tree, layout math) or against wrapping a leaf NSView/CGContext inside SwiftUI for rendering graphs.

**Translation for M4**:
- ✅ Pure-data graph algorithms (`Graph<V,E>` + traversal + minimum spanning tree + Dijkstra) — clearly NOT view-framework.
- ✅ Force-directed layout engines (pure-Swift math output = `[CGFloat]` coordinates) — clearly NOT view-framework.
- ✅ Canvas-graphics leaf views (= wrapping a `CALayer` or `MKOverlayView` in `NSViewRepresentable` for plot rendering only, no claim on WorkspaceView) — within scope of "leaf views" allowed by ADR-0008.
- ❌ Library that ships a `<GraphCanvas dock={...} split={...}>`-style workspace component claiming it's a workspace layer — REJECTED.

## Existing in-package surface (verified against `Package.swift` 2026-08-28)

| Lib | Version pin | Role in M4 |
|---|---|---|
| (none currently) | — | M4 has zero third-party deps today. Everything is hand-rolled. |

## Existing wenshu M4 surface (verified 2026-08-28)

| File | LOC | v0.X | Status |
|---|---|---|---|
| `Sources/WenshuApp/Core/Graph/GraphBuilder.swift` | 228 | v0.19 t14 | graph model (`GraphNode` + `GraphEdge` + `Graph` structs) + `build(...)` + **first-pass force-directed `layout(...)`** (spring repulsion + center gravity, ~130 LOC embedded) |
| `Sources/WenshuApp/Core/Graph/GraphView.swift` | 57 | v0.19 t14 | SwiftUI `GraphView` placeholder — counts nodes/edges but does not draw them yet |
| `Sources/WenshuApp/Core/LinkGraph/BacklinkResolver.swift` | 79 | v0.18+ | name ↔ docId resolution |
| `Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift` | 88 | v0.18+ | SwiftUI `BacklinksPanel` leaf (already wired into the chapter editor) |
| `Sources/WenshuApp/Core/LinkGraph/InternalLinkParser.swift` | 78 | v0.18+ | regex/`-` split on markdown `[[name\|alias]]` |
| `Sources/WenshuApp/Core/LinkGraph/LinkIndex.swift` | 209 | v0.18+ | SQLite-backed link store via raw `import SQLite3` (`add / removeAll / searchForward / searchBackward`) |
| `Sources/WenshuApp/Core/Canvas/CanvasView.swift` | 79 | v0.19 t13 | SwiftUI `CanvasView` placeholder for `.canvas` files |
| `Sources/WenshuApp/Core/Canvas/JSONCanvasCodec.swift` | 158 | v0.19 t13 | decoder for the Obsidian `.canvas` JSON format (`nodes` + `edges` + `groups` + per-node `type / x / y / width / height`) |
| `Sources/WenshuApp/Domain/CrossRefInject.swift` | 150 | v0.23+ | surface-form → chapter frontmatter `referenceRefIds` auto-injector (no graph draw) |

> **Reading**: M4's data plumbing is **complete** (LinkIndex, BacklinksPanel, CanvasView placeholders, CrossRefInject). What's missing is **real interactive rendering** of graph + canvas. The `GraphBuilder.layout(...)` function is a 130-line spring-force implementation that ships with the current build — gap 1 is "replace hand-rolled layout with a tested library OR keep it but stop pretending it's production." Gap 2/3/4 are: draw the nodes, draw the edges, let the user click a node to open the chapter.

## Gap-by-gap evaluation

### Gap 1 — Graph layout algorithm (force-directed / tree)

**Verdict: ONE CONDITIONAL LIBRARY RECOMMENDED. `li3zhen1/Grape` 1.1.0, use `ForceSimulation` module only. PENDING boss recantation of staleness = `WARN`.**

Candidates evaluated (from `https://api.github.com/search/repositories?q=language:swift+graph+stars:%3E50&sort=stars`, 2026-08-28):

| Candidate | Stars | License | Last commit | macOS? | Status |
|---|---|---|---|---|---|
| **`li3zhen1/Grape`** (= SwiftGraphs/Grape) | 402 ★ | MIT | **2025-05-19** | ✓ macOS 14+ | **WARN** (fails gate #2 by 3 months; see below) |
| `davecom/SwiftGraph` | 811 ★ | Apache-2.0 | 2026-03-05 | ✓ iOS/macOS/Linux | **PASS** — pure-data graph **algorithms** (BFS / DFS / Dijkstra / Prim / Kruskal), NO force-directed layout. See §Gap-1-Followon below |
| `tansharma/filament` | 0 ★ | MIT | 2026-07-21 | ✓ | **FAIL** stars (just created 2026-07-14, brand-new) |
| `1amageek/swift-flow` | 23 ★ | MIT | 2026-07-13 | ✓ macOS 26+ | **FAIL** stars (way under 100) + macOS 26 minimum blocks wenshu's macOS 27 baseline transition window |
| `aaurelions/SwiftFlow` | 5 ★ | MIT | 2026-06-30 | ✓ | **FAIL** stars |
| `SwiftDocOrg/GraphViz` | 294 ★ | Apache-2.0 | **2021-05-03** | ✓ via Graphviz binary | **FAIL** gate #2 (5 years stale = Graphviz C-bridge bit-rot) |
| `Vithanco/SwiftGraphviz` | 5 ★ | unknown | 2026-07-12 | ✓ | **FAIL** stars + ships pre-built `Graphviz.xcframework` (heavy native dep) |
| `lukilabs/dagre-swift` | 22 ★ | MIT | 2026-02-09 | ✓ | **FAIL** stars + only DAG layered layout (= tree-like, not force-directed) |
| `conradev/Force` | 41 ★ | NA | 2016-11-03 | (unverified) | **FAIL** (abandoned 10 years ago) |

§11.1 gate on `li3zhen1/Grape`:

- Star ≥100: **PASS** (402★)
- Last commit ≤12 months (cutoff 2025-08-28): **FAIL** — last commit `2025-05-19T10:30:23Z` (`grape/0.7.5` was released 2024-06-17; `1.1.0` was released "over 1 year ago" per SPI page snapshot 2025-10-27; `main` last modified "over 1 year ago" per SPI). Today is 2026-08-28 = ~15 months stale. SPI confidence: zero data-race errors, two libraries, Swift 6 ready.
- License MIT: **PASS**
- macOS-first (macOS 14+ in Package.swift): **PASS**

**WARN rationale** (strong candidate, soft approval):
1. The `ForceSimulation` module is **algorithm-only** (= `Simulation`, `Kinetics<Vector>`, `ManyBodyForce`, `LinkForce`, `CenterForce`, `CollideForce`, KDTree acceleration). Zero view architecture. Fits ADR-0008 cleanly.
2. 402★ + 30 forks + 616 commits + Swift 6 ready + zero data-race errors = real project, not abandoned.
3. The owner's SPI activity counter shows 9 months idle — that's outside the 12-month cutoff, **but** the project's roadmap shows link-styling + animated transitions still WIP; the data layer (what we want) is mature.
4. `Package.swift` declares strict concurrency = Swift 6 idiomatic = good citizen in wenshu's Swift 6.4 baseline.
5. Risk: a real bug fix to the layout engine would have to wait for the maintainer. The `ForceSimulation` module is ~700 LOC pure-Swift — copyable in-house as a fallback if the repo permanently stalls.

**Self-implement path C (alternative, also valid)**: GRDB-style — current `GraphBuilder.layout(...)` is a 130-line spring-force impl. It's minimal. **Open question for boss**: do we (a) adopt `Grape/ForceSimulation` as a tested reference impl and reduce our hand-rolled surface to glue code, or (b) ship as-is and defer gap 1 until we have a real-world graph > 500 nodes where the layout actually matters?

**Recommended action**: bring `grape` to next boss grill with the WARN rationale + a measurement plan (= repro our current spring-force on a 500-node test graph, compare iteration cost vs Grape's KDTree-accelerated Barnes-Hut). Use only the `ForceSimulation` product — never `Grape` (the SwiftUI-view product), because that one will need a child-view wrapper that risks a view-architecture claim.

#### Gap-1-Followon — Pure graph **algorithm** library

Even if `Grape` is deferred, **`davecom/SwiftGraph` 4.0.0** is a clean **PASS** on every gate and fills a real adjacent gap: wenshu's link graph + foreshadowing web are undirected labelled graphs, and any "find shortest thread of foreshadowing mentions from chapter 12 → chapter 47 → chapter 5" feature is Dijkstra on the foreshadowing graph. Today wenshu's `LinkIndex` does only forward/backward name lookups via raw SQLite queries — no BFS shortest-path, no Dijkstra, no MST. SwiftGraph would land that cleanly in `Core/Graph/SwiftGraphAdapter.swift` as a thin wrapper.

§11.1 gate:

- Stars ≥100: **PASS** (811★)
- Last commit ≤12 months: **PASS** (`2026-03-05T06:47:46Z` per master atom; `4.0.0` tag at `a68efb9`)
- License Apache-2.0: **PASS**
- macOS-supported (Apple cross-platform package, "SwiftGraph is appropriate for use on all platforms Swift supports, iOS macOS Linux"): **PASS**
- ADR-0008 carve-out: **PASS** — pure data (`Graph` / `Edge` / algorithms), no view claims.

Risk: zero — pure-Swift, 5+ years mature, used in commercial products per README, would only add ~30 KB binary.

**Recommended action**: bring `davecom/SwiftGraph` to next boss grill as a low-risk pure-data library. Land behind a `Core/Graph/SwiftGraphAdapter.swift` shim so the dependency is reversible.

### Gap 2 — Graph view rendering (SwiftUI vs AppKit)

**Verdict: NO NEW LIBRARY. Apple first-party SwiftUI Canvas + (if needed) `NSViewRepresentable` for zoom/pan.**

Evidence:
- Apple SwiftUI `Canvas` (macOS 13+, available in wenshu's macOS 27 baseline) ships `GraphicsContext` with `fill / stroke / draw / clip / addFilter / drawLayer / resolveSymbol / transform = .init(translationBy:)` — everything needed to draw a force-directed graph (edge bezier + node circle + label) at 60 fps with `TimelineView(.animation)` for layout settle.
- Pan/zoom is `MagnificationGesture + DragGesture` (SwiftUI) — and if hit-testing edges misbehaves, drop to `NSViewRepresentable` wrapping a `CALayer`-hosted `NSView`. Neither requires third-party.
- Apple `Charts` framework (`import Charts`) is now Foundation-layer (`Chart { LineMark(...) }`) — perfect for the **timeline overlay** wenshu wants on the foreshadowing graph ("when does foreshadow F7 mention chapter 1, 12, 47, 89?"). No third-party.
- Vetted candidate library with the closest fit = `kean/Nuke` already adopted (P0); NukeUI's `LazyImage` is leaf-only, no workspace claim. Not graph-specific, but useful for rendering node thumbnails from character/portrait refs.
- The only Swift graph-rendering libs that pass gate #1 are all abandoned (`SwiftDocOrg/GraphViz`) or vendor Graphviz (`Vithanco/SwiftGraphviz`). Both have the view-framework risk baked in (Graphviz binary = native dep not Apple SDK; SwiftDocOrg wrapper's last commit = 5 years stale).
- `aaurelions/SwiftFlow` has 5★, ships a 12-feature ReactFlow port including `MiniMap` + `Background` + `Panel` + `Toolbar` (= ADR-0008 §"SwiftUI extensions targeting view architecture" risk surface). **REJECT** on ADR-0008 grounds before star count.

§11.1 gate (no new lib): **N/A** — first-party only. ADR-0008 carve-out: **N/A** — first-party only.

**Caveat**: when zoom-to-1000+ nodes gets slow, the answer is `SwiftUI.Canvas` + chunk-based GraphicsContext + visibility culling (= first-party). NOT a third-party graph renderer. Track in a ticket; revisit only if Apple ships nothing adequate by macOS 28.

### Gap 3 — Canvas / node-edge rendering

**Verdict: NO NEW LIBRARY. Apple SwiftUI `Canvas` + `GraphicsContext` covers node-edge + hit-testing + drag-finger-implemented (per ADR-0008).**

Evidence:
- `Sources/WenshuApp/Core/Canvas/JSONCanvasCodec.swift` already decodes the `.canvas` JSON shape (`nodes: [{ id, type, x, y, width, height, ... }]`, `edges: [{ id, fromNode, fromSide, toNode, toSide, ... }]`). The data plumbing is done.
- Apple SwiftUI `Canvas` (macOS 13+) + `DragGesture` + `SpatialTapGesture` covers node-drag + edge-creator + canvas-pan in ~200 LOC of first-party code.
- Wenshu's v0.19 `CanvasView.swift` is a placeholder — it currently lists node IDs as `Text` lines. The replacement is a single `Canvas { ctx, size in ... }` body that consumes the decoded `CanvasDocument.nodes` + `.edges` and uses `ctx.fill(Path(roundedRect:...), with: .color(.gray))` per node. ~80 LOC.
- For drawing Mermaid-style curved edges: `GraphicsContext` exposes `Path` + `addCurve / addLine / stroke`. The bezier math per Obsidian canvas is documented and ~10 LOC per edge.
- Apple `PencilKit` (`import PencilKit`) is available for ink-on-canvas (= freehand drawing on `.canvas`). Not currently in `Package.swift`. Apple first-party, no approval gate. Use case: high — but defer until the v0.28 free-layout ticket series.

§11.1 gate (no new lib): **N/A** — first-party only. ADR-0008 carve-out: **N/A** — first-party only.

**Action ticket** (no Package.swift change): implement `CanvasDocumentView.swift` in `Core/Canvas/`, replacing `CanvasView.swift`'s placeholder body with a real `Canvas { ctx, size in ... }`. Self-implemented drag (per ADR-0008 §"Drag UX ownership"). ~80 LOC of view body + ~50 LOC of pan/zoom gesture.

### Gap 4 — Interactive graph node manipulation

**Verdict: NO NEW LIBRARY. Apple SwiftUI gestures + custom `DragGesture` (per ADR-0008 drag ownership rule).**

Evidence:
- Obsidian-style "drag node A onto node B to create a link" is `DragGesture` on the node view + `SpatialTapGesture` on the drop target + an in-flight `editingEdgeBuffer: [EdgeDraft]` on `GraphViewModel`. ~100 LOC of first-party.
- "Double-click node → navigate to chapter" is `SpatialTapGesture(count: 2)` + `OpenIntent.chapter(docId)`. ~10 LOC.
- All edge-creation / node-drag UX stays self-owned. ADR-0008 explicitly states: "drag-lost regression suite" + drag UX = wenshu's test surface, NOT waiting on an upstream library maintainer.
- Apple `PencilKit` for hand-drawn node placement stays Apple-first-party, no gate.

§11.1 gate (no new lib): **N/A** — first-party only. ADR-0008 carve-out: **N/A** — first-party only.

**Action ticket** (no Package.swift change): implement drag-to-link + double-click-to-navigate in the upcoming `GraphDocumentView.swift` = a new file in `Core/Graph/`. Wired to M3 (`BacklinkResolver`) + M2 (`OpenIntent.chapter`). ~100 LOC + `DragRegressionTests` per ADR-0008 §"Test enforcement".

---

## Cross-cut observations

1. **M4 is the cleanest module on the board**. ADR-0008's view-framework FORBIDDEN carve-out was designed to catch M1 / M2 surface violations. M4 doesn't trigger ADR-0008 at all — its gaps are either (a) pure-data algorithm libraries (SwiftGraph-pass / Grape-WARN), or (b) first-party Apple SwiftUI canvas work. The risk profile is "low to medium"; not "high" like M1's drag UX.

2. **No library bridges ≥2 modules**. `grape/ForceSimulation` is M4-only (graph layout = M4 domain). `davecom/SwiftGraph` is M4-only and could feed M5's character-web codex visualization IF a v0.29 ticket ever wants that, but at v0.28 it's M4-singular. No consolidation opportunity for the cross-cut verdict.

3. **The two `mature graph renderer` candidates both FAIL**:
   - `1amageek/swift-flow` (23★) — fails stars + minimum macOS 26 (vs wenshu's macOS 27 = a stretch goal); also uses `ScreenCaptureKit` in its `LiveNode` pattern (macOS-internal capability, requires Screen Recording permission, breaks single-file-process architecture)
   - `aaurelions/SwiftFlow` (5★) — fails stars + ships Panel / Background / Toolbar (= ADR-0008 "view architecture" risk)
   - `tansharma/filament` (0★) — fails stars
   - `li3zhen1/Grape/Grape` (the SwiftUI-view product, NOT the ForceSimulation product) — would force wenshu to plug into the package's view tree, dragging in panel / minimap / toolbar-like components (= ADR-0008 risk). Use `ForceSimulation` only.
   - Recommendation: stick to first-party Apple SwiftUI Canvas + GraphicsContext for the rendering layer.

4. **Self-implement vs adopt for layout**: wenshu's current `GraphBuilder.layout(...)` = 130 LOC hand-rolled spring-force + center gravity. It's shipped and it works for the v0.28 use case (≤500 nodes per book). The risk isn't correctness today — it's "what happens at 5000 nodes." Grape would solve that. Open question for boss: at what corpus size do we deprioritize this gap?

## Honest research failures (= known gaps in this report)

- GitHub repo-direct HTML pages were intermittently blocked by Github's WAF (returning 403/SSL errors); used SPI + GitHub atom feed + GitHub REST API rate-limited calls as substitutes. SPI data is 1-3 weeks stale on activity counters.
- Web searches for "SwiftUI graph library" + "force-directed Swift 2026" + "graph layout tree algorithm maintained 100 stars" returned 70% noise (Mermaid rendering, dependency-graph visualizers for Xcode, Sparkline charts) — surfaced candidate list was filtered through manual keyword relevance, not exhaustive.
- Did NOT explore: GraphViz-on-Apple-Vision-Pro, MetalKit-based graph rendering, Metal shader compute for force-directed step (potentially blazing fast but adds AppKit/Metal view — out of scope for ADR-0008 carve-out analysis).
- Did NOT explore in depth: wenshu internal hand-rolled data structures in `Domain/Character.swift` for "codex visualization (Character web)" (= M5 territory; would just duplicate the M4 graph code path through re-use). Flagged here only.

---

## Summary

| Recommendation | Library | Version | Gate status | Risk | Action |
|---|---|---|---|---|---|
| **ADOPT** (low risk, pure data) | `davecom/SwiftGraph` | 4.0.0 | PASS (811★ / 2026-03-05 / Apache-2.0 / cross-platform with macOS) | low | Bring to next boss grill. Land behind `Core/Graph/SwiftGraphAdapter.swift`. Provides BFS / DFS / Dijkstra / Prim / Kruskal for foreshadowing-graph shortest-path features. |
| **CONDITIONAL** (medium risk, pure data, maintenance WARN) | `li3zhen1/Grape` `ForceSimulation` module only | 1.1.0 | WARN (402★ / **2025-05-19 stale 15 mo** / MIT / macOS-first) | medium | Use **only `ForceSimulation` product**, never `Grape` (view). Bring to grill with rationales: a) Swift 6 ready + zero data-race errors, b) ForceSimulation API is stable per README, c) ~700 LOC pure-Swift + copyable in-house as fallback. Open question to boss: corpus size at which layout quality becomes a problem. |
| **NOT NEEDED** | Apple SwiftUI `Canvas` + `GraphicsContext` + custom `DragGesture` (per ADR-0008) | first-party | n/a | low | Implement `GraphDocumentView.swift` + `CanvasDocumentView.swift` + `DragRegressionTests`. No Package.swift change. |
| **NOT NEEDED** | Apple `Charts` framework (timeline overlay for foreshadowing graph) | first-party | n/a | low | Implement in v0.28+ ticket. No Package.swift change. |
| **NOT NEEDED (deferred to PencilKit evaluation)** | Apple `PencilKit` (freehand canvas ink) | first-party | n/a | low | Defer until v0.29 v0.30 free-layout ticket. No Package.swift change. |
| **REJECTED** | `1amageek/swift-flow` | n/a | FAIL stars (23★) + macOS 26 minimum + ScreenCaptureKit permission | high | Stays out. |
| **REJECTED** | `aaurelions/SwiftFlow` | n/a | FAIL stars (5★) + Panel/Toolbar/MiniMap = ADR-0008 view-architecture risk | high | Stays out. |
| **REJECTED** | `tansharma/filament` | n/a | FAIL stars (0★, brand new) + unproven | high | Stays out. |
| **REJECTED** | `SwiftDocOrg/GraphViz` + `Vithanco/SwiftGraphviz` | n/a | GraphViz dependency = not-Apple-first + stale / low stars | high | Stays out. Architecture uses Apple first-party instead. |
| **NOT NEEDED** | `lukilabs/dagre-swift` | n/a | FAIL stars (22★) + DAG-only (no force-directed) | medium | Stays out. |

**Final adopt-list for M4 (commit-ready)**:

```swift
// In Package.swift, add to .package dependencies array:
//   .package(url: "https://github.com/davecom/SwiftGraph.git", from: "4.0.0"),   // P1 — graph algorithms (BFS/DFS/Dijkstra/Prim)
//   .package(url: "https://github.com/li3zhen1/Grape.git", from: "1.1.0"),       // P1-WARN — force-directed layout (CONDITIONAL on boss recheck of staleness)

// In target.dependencies:
//   .product(name: "SwiftGraph", package: "SwiftGraph"),
//   .product(name: "ForceSimulation", package: "Grape"),   // ONLY this Grape product; never `Grape` (the SwiftUI view)
```

**No view-architecture libraries adopted for M4.** Per ADR-0008, M4 = pure-data + Apple-first-party only.

**Subject to boss re-check**: Grape WARN (15 months stale). If boss wants to defer Grape entirely, M4 ships with hand-rolled `GraphBuilder.layout(...)` + the adopted `SwiftGraph` for algorithms; force-directed layout upgrade waits for v0.29 when there's usage data to justify it.
