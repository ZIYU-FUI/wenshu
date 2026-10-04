# ADR-0011: Layout shell = Apple NavigationSplitView + NSSplitViewItem/NSHostingController (supersedes ADR-0007)

> Status: accepted (= replaces ADR-0007's status: accepted at v0.14 but superseded in implementation)
> Date: 2026-10-04
> Decision-maker(s): 老板 (2026-10-04 OOB confirmation: "现在的方法是对的,就是用的系统默认的")
> Supersedes: ADR-0007 (Layout shell pattern — HStack + hand-written NativeSplitter(view))
> Supersedes (indirect): ADR-0003 (drag-splitter-nsview)

## Context

Pre-2026-10, wenshu's homepage layout was specified as 6 zones (= Z-TITLE / Z-NOVEL upper-band 4 columns / Z-CHAT lower-band 2 columns) with 6 hand-written drag splitters per ADR-0007. The ADR mandated `HStack(spacing: 0) { 4 zone + 3 NativeSplitter(view) }` pattern with the rationale that:

1. `HSplitView / VSplitView` divider color is not modifiable (= long-known Apple limitation).
2. `NavigationSplitView` (= Apple official macOS 13+) is "the 3-column navigation pattern, doesn't map to the Sketch 6-zone layout" (= 老板 2026-08-19 rejection).
3. `Canvas + NSView overlay` has cursor cross-boundary + drag flicker issues (= v0.14.1 regression).

The v0.14-v1.x implementation honored this ADR with `NativeSplitter.swift` (= a View component wrapping `DragGesture + .pointerStyle + hover 4 PT accent capsule`). Per ADR-0007 L33-L37, "edit 1 place = all 6 drag splitters respond" was the maintenance invariant.

## The shift

During the 2026-10-03 Apple multi-column rewrite arc (= a sequence of 14 commits per the merge history at `bc38614f7`), the actual implementation moved away from the ADR-0007 `NativeSplitter` pattern:

- The layout root migrated to `Sources/WenshuApp/App/AppRootScene.swift` hosting a 4-column `NavigationSplitView` (= 46 occurrences across 8 files per `grep -rn "NavigationSplitView" Sources/WenshuApp/ | wc -l`).
- The 6 zone types (`LayoutShellView` / `UpperBandZone` / `LowerBandZone` / `ZoneModule` / `ZoneTopToolbar` / `ZoneBottomToolbar` / `ZoneSlot`) that ADR-0001 + ADR-0007 named as the canonical implementation are all absent from the current `Sources/WenshuApp/` tree.
- The `Sources/WenshuApp/Views/Layout/NativeSplitter.swift` file (= the canonical implementation file ADR-0007 cited) does not exist in the current `Sources/WenshuApp/` tree (= `find Sources -name "NativeSplitter*"` returns 0 hits).
- The drag-splitter UX now flows through AppKit `NSSplitViewItem` + `NSHostingController` (= the canonical Apple Keynote speaker-notes pattern documented in `wenshu-macos26-liquid-glass-pitfalls` skill).

This was the "我不懂写代码,你决定" arc (= 老板 OOB 2026-09-03 granting pocock push authority for the hermes-core-translation ship packet + the subsequent SwiftData migration phases). 老板 had no input on the 2026-10-03 shift itself; = the divergence from ADR-0007 happened silently.

2026-10-04 Q99 dual-axis spec audit surfaced this as P0 #6 (= the Q-NNN standing rule: "ADR status update needs explicit 老板拍"). On 2026-10-04 老板 OOB confirmed: **"现在的方法是对的,就是用的系统默认的"** (= the current method is correct, it uses the system default). This ADR formalizes the confirmation.

## Decision

The wenshu homepage layout = Apple `NavigationSplitView` + `NSSplitViewItem` + `NSHostingController` (= Apple's canonical multi-column macOS 27 layout primitive). Per 老板 2026-10-04 confirmation:

1. **Apple system defaults win over wenshu-rolled alternatives** for layout primitives. The original 8/19 rejection rationale (= "NavigationSplitView doesn't map to Sketch 6-zone") was valid at v0.14 but the implementation has since moved past that constraint (= the 2026-10-03 rewrite accepted Apple HIG's multi-column shape over the original Sketch 6-zone spec).
2. **Apple HIG (Human Interface Guidelines) is the canonical reference** for layout decisions (= per AGENTS.md §11.4 + `wenshu-apple-api-first` skill + `v3.0-design-system-rule.md` + `wenshu-macos26-liquid-glass-pitfalls` skill).
3. **No re-implementation of NSSplitView behavior** (= no hand-written `NativeSplitter` View). The hand-rolled pattern is the wrong layer (= it competes with AppKit's canonical bridge instead of composing with it).

## What changes (= 17+ cleanup sites)

The 2026-10-04 Q99 spec audit flagged 17+ documentation / comment references to `NativeSplitter.swift` (= all stale per the shift). These cleanup sites are bundled into the q99-spec-p0-batch3 commit batch:

| Reference site | Cleanup |
|---|---|
| `docs/adr/0002-sketch-symbol-componentization.md:26` | Remove "NativeSplitter.swift" single-file claim |
| `docs/adr/0003-drag-splitter-nsview.md` | Mark superseded by ADR-0011 (the ADR body itself is the pre-v0.10 history; = retain as historical record) |
| `docs/adr/0007-layout-shell-hstack-native-splitter.md` | Already flagged "superseded in implementation" in q99-spec-p0 commit `286f65eab`; = this ADR formalizes the supersession |
| `.hermes/SPECS/v0-scaffold-from-sketch.md:173` (= gitignored; = spec scratchpad only) | Out of scope for this commit (= see P0 #9 deferred note) |
| `CONTEXT.md:84,106,232,235,276` | Cleanup batch 3 (multiple-section touchpoint; = deferred until CONTEXT.md revision ticket) |
| `Sources/WenshuApp/UI/ComponentIndex.md:214,331,341` | Cleanup batch 3 |
| `Tests/WenshuAppTests/DragRegressionTests.swift:6,20` | Cleanup batch 3 (= update test comment to reference AppRootScene + NavigationSplitView) |
| `Sources/WenshuApp/Views/Workspace/LayoutPicker/LayoutEditBar.swift:41` | Cleanup batch 3 (= update code comment) |
| `docs/wenshu/LAYOUT-APPKIT-INVENTORY.md:95,132,328` | Cleanup batch 3 |
| 9 source-code comments referencing "LayoutShellView" (= the LayoutShellView/UpperBandZone/LowerBandZone/ZoneModule/ZoneTopToolbar/ZoneBottomToolbar/ZoneSlot SwiftUI types absent from tree) | Already converted to "LayoutShellView [no longer defined post-v0.72 — AppRootScene + NavigationSplitView; = ADR-0007 pending ADR-0010; = type references kept as historical landmarks pending 老板 拍]" in q99-spec-p0 commit `ad6d6b5bc`; = ADR-0007 superseded by ADR-0011 (= the historical-landmark annotations remain accurate) |

## Consequences

**Easier** (= Apple does the work):
- Drag-splitter UX, column resize, keyboard navigation, accessibility, light/dark mode = all from AppKit canonical paths (= no wenshu-maintained equivalents).
- Multi-column window resizing, persistence, and `.splitViewController` integration = handled by NSSplitView automatically (= no hand-rolled GeometryReader × ratio math).
- macOS 27 Liquid Glass / vibrancy / translucency = composes naturally with NSSplitViewItem (= the wenshu-pocock-workflow `wenshu-macos26-liquid-glass-pitfalls` skill was the canonical reference for this composition).

**Harder** (= less wenshu direct control):
- Split divider thickness / color = not modifiable from SwiftUI (= Apple limitation). Apple HIG canonical tint + thickness wins (= per AGENTS.md §11 design rule).
- 6-zone Sketch spec drift = the wenshu 4-column layout is no longer a literal 1:1 match to the Sketch `AF7B1C87-ADDD-41ED-8208-7CA5549070E2` artboard. The Sketch artboard remains the design source-of-truth (= per `.hermes/SPECS/v0-scaffold-from-sketch.md`) but the implementation is now a multi-column adaptive layout (= responsive to window width per Apple HIG).

**Locked in** (= per Q99 standing rule):
- Layout shell = Apple HIG primitives (NavigationSplitView + NSSplitViewItem + NSHostingController). Any future proposal to re-implement these primitives in wenshu-rolled code requires explicit 老板拍 (= no silent rollback).
- ADR-0007 (`HStack + hand-written NativeSplitter`) = superseded. ADR-0003 (`drag-splitter-nsview`) = also superseded (indirect).
- The 17+ documentation cleanup sites above = filed for batch 3 (= each spec doc; = no doc-only fix in this commit batch since they are tied to the `LayoutShellView` historical-landmark annotations from `ad6d6b5bc`).

## Alternatives considered

1. **Re-create `NativeSplitter.swift` + revert the 2026-10-03 rewrite**: Rejected by 老板 2026-10-04 OOB (= "现在的方法是对的,就是用的系统默认的").
2. **Keep ADR-0007 status as "accepted at v0.14 but superseded in implementation" + leave 17+ spec sites unfixed**: Rejected (= the Q99 standing rule requires either revert or formalize supersession; = half-state is a 老板 frustration vector).
3. **Adopt NavigationSplitView + retain NativeSplitter as the per-zone drag handle**: Rejected (= the hand-rolled NativeSplitter no longer composes cleanly with NSSplitViewItem; = mixing the two layers invites cursor/flicker regressions from ADR-0007 L17).
4. **Adopt NavigationSplitView + clean up all 17+ stale references** (= this ADR's decision + batch 3 commit): Accepted.

## Cross-references

- `wenshu-pocock-workflow` SKILL.md (workflow chain)
- `wenshu-apple-api-first` SKILL.md (= Apple HIG canonical patterns)
- `wenshu-macos26-liquid-glass-pitfalls` SKILL.md (= macOS 27 NSSplitViewItem/NSHostingController pattern)
- `wenshu-pocock-workflow` references/v3.0-design-system-rule.md (= Apple HIG design tokens)
- AGENTS.md §11 baseline (= Apple HIG canonical; = English-only; = boss-only address)
- ADR-0007 (= superseded; = retained as historical record for v0.14-v0.72 era)
- ADR-0003 (= superseded; = retained as historical record for pre-v0.10 era)
- ADR-0009 (= wenshu-side wins pattern still applies; = this ADR is layout-shape only, not agent-protocol)