# B-07 ticket 028-003: pane-zone mapping (boss 2026-09-04 OOB '同是你的建议')

## Goal

Define which functional module (= which `TabKind` / pane) ships into each
zone of wenshu's 6-zone (= 2-band upper row + 2-band lower row) default
layout. Lock down the default mapping in code so the 028-005 builtin
preset registration + the 028-006 edit-mode UI have a single source of
truth.

## Background

Wenshu's free-layout system = `.scratch/v0.08-28-v0-28-free-layout/`
(= v0.28 worktree). The 6 zones are the canonical `ZoneSlot` cases
declared in `Sources/WenshuApp/App.swift:1437`:

- `projectSidebar` (= 项目管理区 / Library)
- `projectPreview` (= 素材预览区 / Preview)
- `editor`         (= 编辑器 / Editor)
- `specializedTools` (= 工具区 / Tools)
- `aiChat`         (= 聊天区 / Chat)
- `aiDynamic`      (= 动态区 / Dynamic / Kanban + Todo)

The same six cases are the `TabKind` enum in
`Sources/WenshuApp/State/WorkspaceState.swift:55`.

`LayoutPreset.builtinDefault` (the FCP-Browser / 6-zone preset shipped
in 028-005) already wires each `TabKind` into its matching `ZoneSlot`
at `Sources/WenshuApp/State/WorkspaceStore.swift:505-621`. This ticket
extracts the mapping into a dedicated, testable data structure.

Two additional surfaces are deliberately NOT in the 6-zone layout:

- **Reference library** (= `library-public` Wiki / 全局 wiki) = opens
  as a separate window via Sidebar → "Open Reference Library".
- **Settings** (= global app settings) = separate `Settings` window.

These stay outside the zone grid. See `acceptance test #3 + #4`.

## Default mapping (= recommended starting point)

| Zone             | TabKind            | Module / Purpose           |
|------------------|--------------------|----------------------------|
| projectSidebar   | .projectSidebar    | Sidebar (Library outline)  |
| projectPreview   | .projectPreview    | Preview (chapter preview)  |
| editor           | .editor            | Editor (chapter + drafts)  |
| specializedTools | .specializedTools  | Tools (backlinks, outline) |
| aiChat           | .aiChat            | Chat (LLM chat panel)      |
| aiDynamic        | .aiDynamic         | Dynamic (Kanban + Todo)    |

Reference library = GLOBAL (= opens as separate window from Sidebar).
Settings = SEPARATE window (= macOS standard `Settings` scene).

This mapping matches the v0.30 boss 8/31 OOB ratio table
(`15/20/50/15` upper + `70/30` lower; see
`.scratch/v0.30-pane-routing-splitter-fix/spec.md`).

## Implementation

### New file: `Sources/WenshuApp/Views/Workspace/LayoutPicker/ZoneLayout.swift`

Defines:

```swift
/// PaneZoneLayout — single source of truth for which TabKind
/// ships into which ZoneSlot (= the default 6-zone layout). The
/// builtin preset registration (028-005) and edit-mode UI
/// (028-006..028-007) read this struct instead of hard-coding
/// the same mapping in 5+ places.
struct PaneZoneLayout: Equatable {
    /// The default module -> zone assignment (= 1:1 with ZoneSlot).
    /// Order in the array matches ZoneSlot.allCases (= projectSidebar,
    /// projectPreview, editor, specializedTools, aiChat, aiDynamic).
    static let `default`: PaneZoneLayout = ...

    /// Mutable lookup: zone -> module. Lets the user swap (= free
    /// layout) without changing the rest of the preset shape.
    var mapping: [ZoneSlot: TabKind]

    /// Lookup helpers.
    func module(for zone: ZoneSlot) -> TabKind?
    func zone(for module: TabKind) -> ZoneSlot?

    /// Free-layout primitives.
    func swapping(_ a: ZoneSlot, _ b: ZoneSlot) -> PaneZoneLayout
    mutating func swap(_ a: ZoneSlot, _ b: ZoneSlot)
}

extension ZoneSlot {
    /// All 6 zones (= canonical ordering; used by the picker UI).
    static let allCases: [ZoneSlot] = [
        .projectSidebar, .projectPreview, .editor,
        .specializedTools, .aiChat, .aiDynamic
    ]
}
```

The mapping is `Equatable` so tests can compare swaps round-trip.

### No renderer changes

The existing `builtinDefaultPreset()` keeps its hard-coded tree
(= the FCP Browser 3-pane / 6-zone hybrid); `PaneZoneLayout.default`
is the document, not the renderer. Future 028-005 followup will
have the preset read `PaneZoneLayout.default.mapping` instead of
hard-coding.

### No new dependencies

ADR-0008 holds: zero new third-party entries in `Package.swift`.

## Tests

### New file: `Tests/WenshuAppTests/Workspace/PaneZoneMappingTests.swift`

Four `@Test` cases per the boss brief:

1. `testPaneZoneMapping_6zones` — verify `PaneZoneLayout.default`
   covers all six `ZoneSlot` cases with the expected `TabKind`
   assignment (= each zone has exactly one default module).
2. `testPaneZoneMapping_swapZones` — verify `.swapping(a, b)` returns
   a new layout where `a` and `b` exchange modules; original layout
   unchanged (= free-layout semantics = immutable swap).
3. `testPaneZoneMapping_referenceLibrary` — verify the reference
   library is NOT in any of the 6 zones (= it's a global surface,
   not a zone-local module).
4. `testPaneZoneMapping_settings` — verify Settings is NOT in any
   of the 6 zones (= it lives in its own macOS `Settings` scene,
   not a zone-local module).

## Hard rules

- English-only in commit message + file comments.
- DO NOT touch `AGENTS.md` / `CLAUDE.md` / `README.md` / `CHANGELOG.md`.
- DO NOT introduce any new third-party dependency (= ADR-0008).
- DO NOT remove any existing zone. (= no zone is dropped; the 6-zone
  shape is preserved 1:1.)
- DO NOT modify the existing `builtinDefaultPreset()` shape
  (= the v0.30 ratio comments stay; this ticket only EXTRACTS the
  mapping into a separate type).

## Acceptance

- `swift build` exit 0
- `swift build --target WenshuAppTests` exit 0
- `swift test --filter PaneZoneMapping` = 4 tests pass
- Working tree clean after push

## Frontend verification dependency

**YES** — boss needs to verify the 6-zone layout shows the expected
modules in each zone. Do NOT do CUA visual verification (this ticket
is data-only; the renderer change is a separate followup).

## Workspace

`/Volumes/ANAN/Engineering/wenshu`. Do NOT switch branches.

## Report back

- spec path: `.scratch/2026-09-04-b-07-028-003-pane-zone-mapping-spec.md`
- commit hash
- swift build + test results
- The 4 test results
- push status
- Acceptance block at end:

```
B-07 ticket 028-003 shipped: pane-zone mapping spec + ZoneLayout.swift
extracted as single source of truth (= PaneZoneLayout struct with
default mapping + swap primitive + lookup helpers); 4 tests pass;
1 commit pushed.
```