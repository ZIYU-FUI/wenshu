# v0.30 AppState = Global Cross-Zone @Observable Store

## Boss 2026-08-31 OOB

Boss asked for an elegant solution for cross-zone communication that allows future extensibility. Boss picked **方案 A** (= `@Environment(AppState.self)` global @Observable store) over B (= NotificationCenter) and C (= pointfreeco/swift-sharing). Boss拍 "刚刚已经定了, 跨区通信的方案用 A. 你推进实现吧".

## Why A

| Axis | A (@Environment AppState) | B (NotificationCenter) | C (@Shared) |
|---|---|---|---|
| Cross- zone state sync (= sidebar X → preview Y) | ★★★★★ instant | ★★★ async post | ★★★★★ instant |
| Code readability for future maintainers | ★★★★★ 1 line | ★★ 3 file coordination | ★★★★★ 1 line |
| Debug visibility (= boss console print) | ★★★★★ directly observable | ★★ grep post names | ★★★★★ observable |
| Adding new cross- zone signal | ★★★★★ add 1 var | ★★★ 3 places | ★★★★★ add 1 var |
| Type safety | ★★★★★ Swift compile check | ★★★ userInfo: Any | ★★★★★ |
| Multi-window support | ★★★★ AppState per-window @State | ★★ global broadcast | ★★★★★ |
| Third-party dep | ★★★★★ 0 | ★★★★★ 0 | ★★★ needs AGENTS.md §11.1 approval |
| Persistence | ★★★★ already done via @AppStorage | ★★★ not built-in | ★★★★★ auto @Shared(.appStorage) |

Boss picked A. 关键 reasons:
1. 0 dependencies (= Apple native Observation, wenshu already uses it)
2. Code readability for future maintainers (= 1 line vs 3-file coordination)
3. wenshu already solved persistence via @AppStorage (= commit a82397943 sidebar selection persistence)
4. Multi-window ready (= boss 8/27 OOB 自由布局 future plan)

## Design

### File: `Sources/WenshuApp/State/AppState.swift`

```swift
import Observation
import SwiftUI

/// App-wide observable state for cross-zone communication.
///
/// v0.30 boss 8/31 OOB '各区域之间的联动' (= adopted option A =
/// global @Observable + @Environment injection). Owned by App root,
/// injected once via `.environment(appState)`. Replaces the
/// 4-layer @Binding chain (= WorkspaceView → PaneRenderer →
/// TabContentDispatcher → ZoneModuleView → NewLibraryOutlineView)
/// and the 3 separate @Binding vars (= sidebarSelection,
/// selectedEntityCategory, selectedEntity) scattered across
/// WorkspaceView / PaneRenderer / ZoneModuleView / NewLibraryOutlineView.
///
/// Adding a new cross-zone signal = add 1 var here, done.
/// No init/binding plumbing required for downstream views
/// (= they just `@Environment(AppState.self) var appState`).
@Observable
@MainActor
final class AppState {
    /// Sidebar tree selection (= 5 cases: .book / .folder /
    /// .shelf / .referenceCategory / nil). Drives preview pane
    /// scope (= see WorkspaceView.previewScope).
    var sidebarSelection: SidebarItem? = nil

    /// Reference library detail selection (= the entity card
    /// currently being viewed in detail mode). Separate from
    /// sidebarSelection so detail mode can render without
    /// changing the sidebar tree.
    var selectedEntity: Reference? = nil

    /// Reference library category (= which category the sidebar
    /// pointed at, = 资料库 → 文学 / 哲学 etc.).
    var selectedEntityCategory: EntityCategory? = nil

    /// Preview pane sort order (= applies to both entity scope
    /// and book scope cards). Default = 拼音首字母.
    var previewSortOrder: EntitySortOrder = .pinyinFirstLetter

    /// Future cross-zone signals (= add new vars here, no init
    /// plumbing needed):
    /// - selectedChapter: BookDoc? (= when editor loads a chapter)
    /// - selectedForeshadowing: BookDoc? (= when tools zone
    ///   edits a foreshadowing)
    /// - kanbanOpenCardID: UUID? (= when kanban opens a card)
    /// - todoOpenItemID: UUID? (= when todo opens an item)
}
```

### Changes to existing files

| File | Change | Lines |
|---|---|---|
| `App.swift` | Add `@State private var appState = AppState()` + `.environment(appState)` on WiredShell | +3 |
| `WorkspaceView.swift` | Replace `@State sidebarSelection` / `@AppStorage` / `@State selectedEntity*` / `previewScope` computed with `@Environment(AppState.self) var appState` + persisted onChange | -25, +15 |
| `PaneRenderer.swift` | Remove `@Binding sidebarSelection` (= thread from commit d845fe9c9) — replace with `@Environment(AppState.self) var appState` in `TabContentDispatcher` | -10, +5 |
| `ZoneModuleView` (= in `WorkspaceView.swift`) | Remove `@Binding sidebarSelection` — replace with `@Environment(AppState.self) var appState`; remove duplicated `previewScope` (= read from AppState) | -20, +8 |
| `NewLibraryOutlineView.swift` | Remove `@Binding sidebarSelection` (= a Binding in a View struct is unusual) — use `@Environment(AppState.self) var appState`; remove sidebar persistence `.onChange` (= move to WorkspaceView's AppState observer) | -15, +8 |

Net change: ~-50 lines (init/binding plumbing) + ~40 lines (AppState + observers).

### Persistence

- AppState itself is NOT Codable / doesn't auto-persist (= per-window, not disk)
- `sidebarSelection` is persisted to UserDefaults by WorkspaceView's `.onChange(of: appState.sidebarSelection)` (= unchanged from commit a82397943)
- `previewSortOrder` similarly persistable
- On app boot, WorkspaceView's `.onAppear` reads AppStorage → sets `appState.sidebarSelection` (= unchanged)

### Multi-window

- Each `WindowGroup` instance creates its own `@State private var appState = AppState()` (= per-window state isolation)
- NotificationCenter events (= wenshuNewBookRequested etc.) stay as-is (= cross-window, but they're events not state)
- No multi-window sync (= not needed yet; future ticket if boss asks)

### What STAYS unchanged (= not in scope)

| Mechanism | Why keep |
|---|---|
| `NotificationCenter` events (= wenshuNewBookRequested etc.) | Already established pattern for ONE-SHOT trigger events (= button → open sheet). Per the wenshu-pocock-workflow reference `swiftui-cross-instance-state-signaling.md`, NotificationCenter is the right answer when AnyView identity erasure prevents @State from working (= e.g. trailing-slot button in zone header). |
| `@Environment(BookStore.self)` | Business data (= shelves / books / references), not cross-zone UI state. |
| `@Environment(WorkspaceStore.self)` | Layout tree state (= persistent workspace JSON). Not cross-zone UI state. |
| `@AppStorage` | Persistence (= per-key UserDefaults round-trip). Used by AppState's observer to round-trip sidebarSelection etc. |

### Acceptance criteria

1. App launches → first frame renders (= no layout regression from removing @Binding chain)
2. Click sidebar shelf row → preview pane shows "选中书查看文档" (= empty state for shelf scope)
3. Click book row → preview pane shows that book's .md files (= boss 8/31 scope)
4. Click folder row → preview pane shows only that folder's .md files
5. Click 资料库 category → preview pane shows that category's entity cards
6. Click 资料库 root → preview pane shows all entity cards (= overview)
8. Close APP → reopen → sidebarSelection restored (= persistence via @AppStorage + onChange)
9. Drag the splitter (= from commit 386aae1a0) → weights change visually (= ratio bug from commit cace9337 not regressed)
10. Add a NEW cross-zone signal (= e.g. `var selectedChapter: BookDoc?`) → only 1 file edit (= AppState.swift) — proves extensibility

## Out of scope (= not this ticket)

- Multi-window AppState sync (= future if boss asks)
- Type-safe persistence (= future — could replace @AppStorage + onChange pattern with @Shared, but that's方案 C)
- Migrate NotificationCenter events to AppState (= each event is unique to its receiver, so no general pattern helps)

## Why I picked this scope

- A small focused PR (= single new file + 5 file edits)
- Net negative LoC (= -10 lines after accounting for new AppState file's body)
- No behavior change for end user (= visual identical to current state)
- Future extensibility proven by criterion #10