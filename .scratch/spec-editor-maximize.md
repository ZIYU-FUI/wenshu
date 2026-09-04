# Editor zone maximize feature spec (= ticket 029 — single feature, 4 sub-tickets)

## Boss 2026-08-26 OOB
Editor zone top toolbar = add 1 new ICON at the rightmost position (= Lucide `.expand`).
Click expand → editor occupies whole window (= other 5 zones hidden).
ICON becomes `.shrink`. Click shrink → restore pre-expand state.
Constraint: NOT restore default; if zone was hidden pre-expand, it stays hidden post-shrink.

## Design (= per boss 8/25 spec + Apple HIG fullscreen-style)

### Ticket 029a — State layer (= 1 file: App.swift):
- Add `@AppStorage("wenshu.editor.maximized") private var editorMaximized: Bool = false`
  (= persists across app launches per boss 8/19 cross-launch persistence spec).
- Add `@AppStorage("wenshu.editor.preExpandVisibility") private var preExpandVisibilityJSON: String = ""`
  (= JSON snapshot of 5 zone-toggle flags at the moment expand was clicked;
   on shrink, parse JSON + write back to AppStorage flags + clear).
- struct `VisibilitySnapshot { let projectSidebar: Bool; let projectPreview: Bool; let specializedTools: Bool; let aiChat: Bool; let aiDynamic: Bool }`
  (= Codable for JSON roundtrip).
- `expand()` method:
  1. Snapshot current 5 AppStorage flags → encode to JSON → save to preExpandVisibilityJSON.
  2. Set 5 flags = false (= hide all other zones).
  3. Set editorMaximized = true.
- `shrink()` method:
  1. Decode preExpandVisibilityJSON → restore 5 flags via AppStorage setter.
  2. Clear preExpandVisibilityJSON.
  3. Set editorMaximized = false.
- On app launch with editorMaximized = true + empty preExpandVisibilityJSON
  (= first launch after crash): treat as noop shrink (= default 5 flags = true = open).

### Ticket 029b — UI layer (= 1 file: App.swift editor ZoneContentView tab tuple):
- Add 4th tab to editor zone tab tuple:
  ```
  ZoneContentView(zoneSlug: "editor", tabs: [
      ("编辑", "book-open-text", AnyView(...)),
      ("大纲", "puzzle", AnyView(OutlinePanel())),
      ("反链", "link", AnyView(BacklinksPanel())),
      ("展开", "expand", AnyView(EmptyView())),  // ticket 029b — expand/shrink tab
  ])
  ```
- For other zones (projectSidebar / projectPreview / specializedTools / chat / dynamic), if editorMaximized = true, hide them (= each zone's content area is empty when maximized).
- ICON swaps: tab4 icon = "expand" if !editorMaximized, else "shrink".
- 28×28 PT hot area preserved (= ticket 011 + 020 + 021 + 022 patterns).
- Apple HIG animation = .animation(.default, value: editorMaximized) on the zone visibility flags (= smooth cross-fade).

### Ticket 029c — Action layer (= 1 file: App.swift):
- Expand action: invoke expand() (= when not editorMaximized).
- Shrink action: invoke shrink() (= when editorMaximized = true).
- Wrap in IconButtonStyle + Color.clear BASE 28×28 hot area (= ticket 021 canonical).
- Apply .buttonStyle(IconButtonStyle()) for Apple HIG hit-area pattern.

### Ticket 029d — Edge cases + persistence + animation polish:
- App launch with editorMaximized = true + no snapshot: noop shrink behavior on first click.
- Persist snapshot to AppStorage = survives app quit during expanded state.
- Animation: SwiftUI @AppStorage flag changes trigger default cross-fade (= Apple HIG default).
- Test: hide projectSidebar BEFORE expand → expand → shrink → projectSidebar STILL hidden (= NOT restored to visible).
- Test: show all zones BEFORE expand → expand → shrink → all zones visible (= no change).

## Files to modify (= 1 to 2):
- Sources/WenshuApp/App.swift (= state vars + action methods + editor ZoneContentView tab tuple + visibility logic)
- (= optionally: separate ZoneState.swift file IF boss prefers clean separation)

## Acceptance criteria (= per boss 8/25 ticket-by-review spec):
- AXButton for expand ICON visible in editor zone top toolbar (= rightmost position).
- Click expand: 5 other zones hidden (= visible flags all false), editor zone fills window.
- ICON becomes `.shrink`.
- Click shrink: 5 flags restored to pre-expand snapshot (= NOT default).
- Test case: hide projectSidebar BEFORE expand → expand → shrink → projectSidebar STILL hidden (= NOT restored to visible).
- Test case: show all zones BEFORE expand → expand → shrink → all zones visible (= no change since default = show all).
- Test case: persist across app launches (= editorMaximized = true persisted, on relaunch same state).

## Out of scope (= 不做):
- macOS native fullscreen (= not this feature).
- Drag splitters behavior during maximize (= preserve current behavior).
- Animation timing tuning (= Apple HIG default cross-fade).
- Multiple maximize zones (= single editor zone only).

## Risks:
- AppStorage writes on 5 views simultaneously = SwiftUI re-render on multiple @AppStorage writers.
- Snapshot persistence edge case (= crash mid-expand).
- Editor toolbar ICON count = 4 in editor zone (now bigger than other zones = visual asymmetry = need Spacer to push to right).