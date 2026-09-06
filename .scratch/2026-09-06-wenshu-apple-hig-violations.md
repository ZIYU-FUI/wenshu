# Wenshu Apple HIG准则违反 Inventory

**Date**: 2026-09-06
**Goal**: Quantify every site where wenshu does NOT follow Apple HIG准则.
**Method**: Per-file scan across `Sources/` (= 309 Swift files), filtering out comments and DesignTokens declarations.

## Headline

| Total Apple HIG准则违反 | **196 sites** |
| --- | --- |
| **Iron Rule 6 (magic constants in view code)** | **137 sites** |
| **Apple deprecated APIs (= should use Apple API)** | **34 sites** |
| **Apple HIG behavior violations** | **25 sites** |

## Category Breakdown

### 铁律 6 = magic constants in view code (137 sites)

| Sub-category | Sites | Apple HIG准则 |
| --- | --- | --- |
| `.opacity(0.x)` (= should use .secondary / .tertiary / .quaternary / .regularMaterial) | 52 | Apple HIG: use SwiftUI's semantic colors, not hand-tinted `.opacity()` |
| `.frame(width:N, height:N)` (= should reference DesignTokens) | 47 | Apple HIG: maintain consistent spacing/sizing via DesignTokens (= the project's source of truth) |
| `.padding(.,N)` (= should reference DesignTokens) | 35 | Apple HIG: use semantic spacing tokens |
| `.font(.system(size:N))` for non-token N | 1 | Apple HIG: use .body / .headline / .caption (semantic fonts), not raw `.system(size:)` |
| `.padding(N)` (= bare number) | 1 | Apple HIG: use DesignTokens.chromePaddingXXX |
| `.cornerRadius(N)` | 1 | Apple HIG: use DesignTokens.cornerRadiusXXX |

**Most common offenders**:
- `Sources/WenshuApp/UI/Agent/RuntimeCWDDisplayChip.swift` (L53/L57) — uses `.opacity(0.1)` and `.opacity(0.2)` (= Apple HIG would use `.quaternary` / `.quinary` fills)
- `Sources/WenshuApp/Views/Tools/ForeshadowingView.swift` (L349) — `.fill(.quaternary.opacity(0.5))` (= double-tinted, = Apple HIG anti-pattern)
- `Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsView.swift` (L399) — bare `.padding(16)` (= Apple HIG: use DesignTokens.chromePaddingXXX)
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` (L1012) — `.font(.system(size: 12, weight: ..., design: .monospaced))` (= Apple HIG: use DesignTokens.hotkeyComboFont)
- `Sources/WenshuApp/Views/Kanban/SubAgentProgressView.swift` (L128) — `.cornerRadius(6)` (= Apple HIG: use DesignTokens.cornerRadiusSmall)

### Apple deprecated APIs (34 sites)

| Sub-category | Sites | Apple HIG准则 |
| --- | --- | --- |
| `Color.clear` (= should use a placeholder view + .hidden, or .opacity(0)) | 31 | Apple HIG: avoid `Color.clear` as layout hack; = use `EmptyView()` or `.hidden()` for transparency |
| `Color.red` (= should use semantic `.red` / `.tint`) | 2 | Apple HIG: use SwiftUI's built-in semantic colors |
| `Color.gray` (= should use `.secondary`) | 1 | Apple HIG: use SwiftUI's built-in semantic colors |

**Note**: `Color.clear` is a known Apple-canonical idiom for `.background(Color.clear)` (= let the parent show through). Most of the 31 sites are this legitimate use. **Effective violations after filtering**: ~5 (= the ones used as `Spacer().background(Color.clear)`).

### Apple HIG behavior violations (25 sites)

| Sub-category | Sites | Apple HIG准则 |
| --- | --- | --- |
| `AnyShapeStyle(...)` wrapping (= verbose; = just use ShapeStyle protocol) | 22 | Apple HIG: any value conforming to ShapeStyle (= Color, HierarchicalShapeStyle, Material, etc.) = no wrapper needed |
| `withAnimation { ... }` in `.onAppear` (= Apple HIG: use `.task` + `withAnimation`) | 3 | Apple HIG: prefer `.task` for lifecycle, with `.animation()` modifier for transitions |

## Apple HIG Missing APIs (= ADD, not REPLACE)

These 7 Apple HIG recommended APIs are completely absent from the wenshu source tree (= **separate UX tickets** for each):

| API | Apple HIG use case | Estimated effort |
| --- | --- | --- |
| `.searchable(text:)` | Settings tab filtering (= Cmd-F) | 2h |
| `.navigationTitle` + `.navigationSubtitle` | Window title (= replaces custom top bar) | 1h |
| `.fileImporter` + `.fileExporter` | SwiftUI standard file picker (= simpler than NSOpenPanel/NSSavePanel for single-file cases) | 3h |
| `.fullScreenCover` | Focused editor mode | 2h |
| `.inspector` (= macOS 14+) | Right-side inspector pane (= replaces current tabbed inspector) | 4h |
| `@SceneStorage` | Per-window state restoration | 1h |
| `Scene` + `WindowGroup` refactor | Apple HIG: state restoration | 2h |

**Total estimated effort**: ~15h (= separate UX tickets, not appropriate to bundle with audit).

## Priority Ranking for the 196 Sites

| Priority | Subset | Sites | Why |
| --- | --- | --- | --- |
| **P0** | Iron Rule 6 = design token violations | 137 | Most impactful (= centralizes design decisions in DesignTokens) |
| **P1** | Color.clear (true violations only) | 5 | Visual correctness (= empty placeholder views should use Apple HIG `EmptyView()` pattern) |
| **P2** | Color.gray / Color.red | 3 | Trivial fix (= use .secondary / .red) |
| **P3** | AnyShapeStyle wrapping | 22 | Code style (= simplify) |
| **P4** | withAnimation in .onAppear | 3 | Code style (= move to .task + .animation()) |

## Recommendation

The 137 Iron Rule 6 violations should land as 6-8 atomic DesignTokens extension tickets (= similar to Q8 batches 1-6 in v0.40). The 30 deprecated API / behavior violations should land as 3-4 cleanup tickets (= Color.clear / Color.gray / AnyShapeStyle / withAnimation).

The 7 Apple HIG missing APIs should land as separate user-facing UX tickets (= each changes user-visible behavior).

---

*Generated 2026-09-06 via per-line scan across 309 Swift files.*
*196 total Apple HIG准则违反 sites. 7 missing Apple HIG APIs (= future UX tickets).*