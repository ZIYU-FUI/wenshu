// ShellMiddleColumn.swift · Wenshu · v1.42 ticket 001
//
// Extracted from NavigationSplitShell.swift (= v1.0.0-m1-shell boss OOB).
//
// Per boss OOB 2026-09-16 '按优先级推' + '自己一口气推完' (= keep
// pushing until done). v1.34 + v1.38 + v1.39 + v1.42 (= this ticket)
// continue the NavigationSplitShell split pattern. ShellMiddleColumn
// (= 440 NLOC = the largest sibling = the Apple HIG middle column
// hosting the card grid + the toolbar) is extracted verbatim.
//
// Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: extract
// ShellMiddleColumn to its own file. The 26-line Apple HIG doc + the
// 410-line SwiftUI body (= card grid wrapper + sort toolbar) move
// verbatim. 0 behavior change.
//
// Out of scope (= explicit, future ticket v1.43):
// - ShellDetailColumn (= 471 NLOC)

import SwiftUI

/// Apple HIG content column (= 1 zone: the card grid).
/// Per boss 2026-09-10 'visual 5 columns' + 'the cards zone goes in middle-left, that's wrong,
/// we don't need that red-box area': the middle column carries exactly 1 zone
/// (PreviewPane = the card grid). The previously rendered bottom
/// outline sub-area (= NewLibraryOutlineView = the same
/// directory tree the sidebar uses) is removed (= the outline
/// is the sidebar's job; duplicating it in the middle column
/// is noise).
///
/// Boss 2026-09-10 'remove the tab, keep just the cards content — and since the image picker isn't implemented anyway, just remove it too for now':
/// the sidebar bottom card zone (= previously ZoneContentView
/// with two tabs 'Preview / Image' = a .pickerStyle(.segmented) TabBar
/// over a PreviewPane) is gone. PreviewPane now renders the
/// card grid without any tab chrome (= Apple's empty state +
/// search bar + the actual grid = the canonical pattern Xcode /
/// Photos / Music use for unfiltered list views).
///
/// v0.66 boss 2026-09-10 OOB 'drop the floating panel, just split the
/// middle column in two': the previous float-over-document layout
/// fought NSTextView's hit test (= an NSTextView on top of another
/// NSTextView makes cursor + click ownership ambiguous). The
/// previous VSplitView held cards on top + outline on bottom; per
/// the next boss OOB (= 'we don't need that red-box area' = the outline sub-area)
/// the VSplitView is gone too and the card zone owns the full
/// column height.
struct ShellMiddleColumn: View {
    // v1.0.0-m1-shell boss 2026-09-10 OOB 'library-tree selection and
    // the cards in the assets zone weren't aligned and didn't filter' (= the cards column did not
    // re-render when the user clicked a reference category in the
    // sidebar). Root cause: `let appState: AppState` (= a plain
    // stored property holding an `@Observable` instance) does NOT
    // participate in SwiftUI's Observation Framework tracking when
    // the view body reads `appState.sidebarSelection`. The
    // `@Observable` macro generates `withObservationTracking`
    // hooks keyed to the *direct* property access on a tracked
    // reference (= `@Environment` / `@State` / `@Bindable`); a
    // plain `let` field is treated as a non-tracked read, so the
    // view body never re-renders when `sidebarSelection` mutates.
    //
    // Fix: switch to `@Bindable var envAppState: AppState` (= the
    // canonical SwiftUI Observation entry point for `@Observable`
    // instances; = reads of `envAppState.x` register tracking; = body
    // re-renders on every mutation; = supports `$envAppState.x`
    // binding syntax for Picker/Toggle). The `init` / call sites that
    // previously passed `appState: appState` as a parameter can
    // keep passing it for backwards compat (= the let field is
    // kept as a no-op shim so callers don't have to change) but
    // the @Bindable entry takes precedence for observation
    // tracking inside body.
    @Bindable var envAppState: AppState
    let appState: AppState
    // v1.0.0-m1-shell boss 2026-09-12 OOB 'doc-open pipeline fix':
    // openCardInEditor needs BookStore.referenceStore to load
    // reference bodies for double-clicked cards (= the same env
    // chain WorkspaceView.openCardInEditor uses via
    // @Environment(BookStore.self)). Optional because the
    // env chain may not be ready on early launch (= silent
    // no-op fallback in openCardInEditor).
    @Environment(BookStore.self) private var envBookStore

    private var bookStore: BookStore? { envBookStore }

    // v1.27 component-architecture (2026-09-17): previewSortOrder
    // promoted from `@State private var` (= column-local, ephemeral,
    // = 3 independent copies in ShellMiddleColumn + WorkspaceView
    // + PreviewPane that drifted) to `AppState.previewSortOrder`
    // (= single source of truth; = shared across all columns;
    // = survives column collapse-expand; = future changes to one
    // place propagate to all readers).
    //
    // Access pattern: `$envAppState.previewSortOrder` is the
    // SwiftUI binding (= AppState is @Observable; = property
    // changes trigger view re-render via Observation framework).

    // v1.0.0-m1-shell boss 2026-09-10 OOB 'global search': use
    // envAppState.searchText (= the AppState @Observable
    // property) instead of a local @State. This lets the
    // .searchable modifier on the cards column share the same
    // search state with any future .searchable modifiers on
    // the sidebar / inspector (= the canonical SwiftUI
    // Observation pattern for app-wide search state; = single
    // source of truth; = no string-threading across columns).
    // envAppState is the @Environment(AppState.self) entry that
    // already registers Observation tracking on the cards
    // column body (= body re-renders on every mutation).
    private var searchText: String {
        get { envAppState.searchText }
        nonmutating set { envAppState.searchText = newValue }
    }

    /// v1.0.0-m1-shell boss 2026-09-10 OOB 'tree selection — the cards column doesn't
    /// react to the tree selection' + follow-up 'pick something in the left-side
    /// tree and no cards appear in the middle assets zone' (= selecting .book(worldview)
    /// in the sidebar showed .empty in the cards column instead of
    /// the book's .md cards). The previous version mapped .book /
    /// .shelf / .folder ALL to .empty (= cards column blanked out
    /// for any user-scope row). The correct mapping per PreviewScope
    /// enum (= see PreviewPane.swift lines 139-152):
    /// - .referenceLibraryRoot / nil → .referenceScope(nil)
    ///   (= overview grid of all entities across categories)
    /// - .referenceCategory(let dirName) → .referenceScope(
    ///   EntityCategory(rawValue: dirName)) (= one category only)
    /// - .book(let id) → .bookScope(bookId: id, folderName: nil)
    ///   (= the book with ALL its folders' .md cards = the user
    ///   wants to see the book's content; = the boss's report
    ///   'pick Worldview on the left, no cards in the middle' = the book WAS selected
    ///   but the preview was .empty)
    /// - .shelf(let id) → .shelfScope(shelfId: id) (= shelf hint,
    ///   per PreviewScope comment: 'shelves are a tree level, not
    ///   a document scope' = the preview pane shows a hint to
    ///   drill into a book)
    /// - .folder(let bookId, let folderName) → .bookScope(bookId,
    ///   folderName: folderName) (= the folder's .md cards only)
    /// - Invalid dirName (= no matching EntityCategory) falls back
    ///   to .referenceScope(nil) so a broken reference selection
    ///   doesn't lock the user out.
    /// Without this fix, selecting ANY user-scope sidebar row (=
    /// book / shelf / folder) showed 'Please pick a node on the left to view the document' even
    /// though a real selection was active (= the boss's bug).
    /// v1.0.0-m1-shell boss 2026-09-10 OOB 'library-tree selection and
    /// the cards in the assets zone weren't aligned and didn't filter': map sidebarSelection →
    /// PreviewScope. The case-mismatch bug (sidebar wrote lowercase
    /// directoryName 'b' but entities JSON stored uppercase
    /// rawValue 'B') was fixed at the sidebar tag + onChange lookup
    /// sites (= see NewLibraryOutlineView.swift line ~525 for the
    /// `.tag(SidebarItem.referenceCategory(category.rawValue))`
    /// site + line ~745 for the `appState.sidebarSelection =
    /// .referenceCategory(cat.directoryName)` write site;
    /// v0.71 P1 batch 9 dual-axis followup: lines were ~501 / ~721
    /// before the v0.34 + v0.40 refactors that added per-category
    /// entity loaders; = approximate refs are OK since the line
    /// numbers drift as new features land);
    /// by the time `previewScope()` reads `appState.sidebarSelection`,
    /// the dirName is already the uppercase rawValue, so
    /// `EntityCategory(rawValue: dirName)` succeeds (= .b for
    /// Philosophy / 'B') and `.referenceScope(cat)` reaches
    /// `categoryGrid(category: cat, ...)` which filters
    /// `allEntities.filter { $0.category == category }` correctly.
    private func previewScope() -> PreviewScope {
        // v1.0.0-m1-shell boss 2026-09-10 OOB: read from envAppState
        // (= the @Environment-tracked Observable instance), NOT
        // from the `let appState` field (= which doesn't register
        // Observation tracking; = previous code's `previewScope()`
        // read stale data because the body never re-rendered).
        switch envAppState.sidebarSelection {
        case .referenceLibraryRoot:
            return .referenceScope(nil)
        case .referenceCategory(let dirName):
            return .referenceScope(EntityCategory(rawValue: dirName))
        case .book(let bookId):
            return .bookScope(bookId: bookId, folderName: nil)
        case .shelf(let shelfId):
            return .shelfScope(shelfId: shelfId)
        case .folder(let bookId, let folderName):
            return .bookScope(bookId: bookId, folderName: folderName)
        case nil:
            return .referenceScope(nil)
        }
    }

    // v1.0.0-m1-shell boss 2026-09-12 OOB 'doc-open pipeline fix:
    // documents open in the middle column's editor zone. No separate windows. The editor zone is
    // the document's editing area; opening a document means edit state. The editor uses SM, the third-party
    // Markdown editor we brought in — the backend is already wired': card double-
    // click handler (= the user double-clicks a card in the cards
    // column = PreviewPane's onDoubleClick fires). Mirrors
    // WorkspaceView.openCardInEditor logic (= reads the actually-
    // clicked CardSource from the parameter, not the topmost
    // card; = prevents the 'clicking Dufu card opens a tab with
    // wrong name' regression = boss 9/8 OOB).
    //
    // Differences from WorkspaceView.openCardInEditor:
    // 1. Reads `previewScope()` (= NavigationSplitShell's helper;
    //    = the equivalent of WorkspaceView's `previewScope`
    //    computed property).
    // 2. mode = .edit (= boss's 'opening a document means edit state' = the
    //    user wants the WenshuMarkdownEditor's editable NSTextView,
    //    NOT the read-only preview; = uses the SM third-party md
    //    editor's edit surface directly).
    // 3. Reads `bookStore?` (= NavigationSplitShell threads it as
    //    an optional via @Environment(BookStore.self); = if nil,
    //    falls back to the empty body path).
    //
    // The duplicate-tab fingerprint check (= first 200 chars of
    // content) is preserved (= the boss 9/3 OOB Safari-style
    // 'switch to existing tab if same .md already open' behavior
    // still applies; = no duplicate tabs).
    private func openCardInEditor(source: CardSource?) {
        let scope = previewScope()
        let (path, content, title): (String?, String, String)
        switch scope {
        case .referenceScope(let category):
            // Mirror WorkspaceView.openCardInEditor's reference-scope
            // logic. Use the actually-clicked card's Reference if the
            // caller passed one (= BOSS 9/8 'clicking Dufu card
            // opens tab with wrong name' fix); fall back to
            // filtered.first otherwise.
            let entities: [Reference] = (try? bookStore?.referenceStore.loadAllReferences()) ?? []
            let filtered = entities.filter { entity in
                entity.layer == .layerEntities
                    && (category == nil || entity.category == category)
            }
            let picked: Reference? = {
                if case .reference(let r) = source { return r }
                return filtered.first
            }()
            if let first = picked {
                let body = bookStore?.referenceStore.loadReferenceBody(id: first.id) ?? first.summary
                path = nil
                content = body
                title = first.title
            } else {
                path = nil; content = ""; title = category?.displayName ?? WenshuI18n.t("tab.title.reference_library")
            }
        case .bookScope:
            // Deferred to ticket 027-35 for absolute path resolution.
            if case .bookDoc(let doc) = source {
                path = nil
                content = doc.summary
                title = doc.title
            } else {
                path = nil; content = ""; title = "book-doc"
            }
        case .shelfScope, .empty:
            path = nil; content = ""; title = ""
        }

        // No content = silent no-op per boss 9/3 feedback.
        guard !content.isEmpty else { return }

        // Duplicate-tab fingerprint check (= Safari behavior).
        let fingerprint = String(content.prefix(200))
        if let existingIdx = envAppState.openTabs.firstIndex(where: {
            String($0.originalBody.prefix(200)) == fingerprint
        }) {
            envAppState.activeTabId = envAppState.openTabs[existingIdx].id
            return
        }

        // Open as new tab. mode = .edit per boss's 'opening a document means
        // edit state' directive (= the WenshuMarkdownEditor editable
        // surface from the start; = no separate preview step).
        //
        // v1.0.0-m1-shell boss 2026-09-12 OOB 'the tab title didn't go to the document
        // name' bug': pass the entity / book-doc title (= 'Battle of Red Cliffs' etc.)
        // so the tab strip shows the real name instead of the
        // 'preview-sample' placeholder. The title fallback chain in
        // EditorPlaceholder.tabDisplayTitle uses basename first
        // (= still wins once documentPath lands), then `title`
        // (= new), then 'preview-sample' (= old fallback).
        let newTab = EditorTab(
            id: UUID(),
            documentPath: path,
            draft: content,
            originalBody: content,
            mode: .edit,
            title: title.isEmpty ? nil : title
        )
        newTab.sourceScope = scope
        envAppState.openTabs.append(newTab)
        envAppState.activeTabId = newTab.id
    }

    var body: some View {
        // Boss 2026-09-10 'the cards zone goes in middle-left' + 'we only need the original assets cards':
        // the middle column is exactly 1 zone = the reference library
        // overview grid (= PreviewPane with scope = .referenceScope(nil)
        // = ALL entities across categories). This is the canonical
        // 'material cards' view = Xcode's project navigator cards /
        // Photos' library = unfiltered entity grid per category with
        // sort = first letter (= the boss 8/30 OOB default).
        //
        // Why .referenceScope(nil) and not .empty:
        // - .empty renders Apple's ContentUnavailableView (= an
        //   informational placeholder = NOT the cards themselves).
        //   Per boss 2026-09-10 'we only need the original assets cards', the column
        //   must show the actual card grid (= the entities), even
        //   with no sidebar selection.
        // - .referenceScope(nil) = overview grid of all entities in
        //   the reference library (= Characters / Worldview / Books / Volumes / etc.). When
        //   the user later clicks a sidebar row, AppState can route
        //   a category-scoped scope (= .referenceScope(.some)) into
        //   the PreviewPane for filtered view.
        //
        // No VSplitView wrapper, no outline sub-area, no chapter tree.
        // No navigationTitle: per boss 2026-09-10 OOB 'can we drop the title inside the red box',
        // the column-level header (= the NavigationSplitView column
        // title bar = 'Cards' + library subtitle 'anbaiqiang.ws') is
        // removed. The column content (= the cards themselves) is
        // self-explanatory; an extra title bar is noise on a single-
        // zone column.
        //
        // v0.77 boss 2026-09-10 OOB 'wrong position — it should sit at the top INSIDE the middle-left column':
        // the previous `.toolbar { ToolbarItem(.principal) { ...
        // } }` route (= commit dff49498d) put the search field in
        // the window toolbar (= not in the column body). Drop the
        // .toolbar wrapper and let PreviewPane's internal
        // `previewSearchBar` render inline (= Apple's macOS 13+
        // rounded-pill pattern hosted at the top of the column
        // body = same visual slot as the sidebar's `.searchable`
        // field at the top of the sidebar column).
        //
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'tree selection — the cards column doesn't react
        // to the tree selection': the previous `.referenceScope(nil)`
        // (= unfiltered overview grid of every entity in the library)
        // ignored sidebar selection entirely (= clicking Philosophy & Religion
        // / Military / Economics / Literature / History & Geography / Other in the sidebar had
        // no effect on the cards column = the bug boss is reporting).
        // Switch the scope based on `appState.sidebarSelection` so the
        // cards column follows the sidebar:
        //   - sidebarSelection == .referenceLibraryRoot or nil
        //     → .referenceScope(nil) (= overview; = the 6 categories
        //     collapse state on the sidebar root; = same as before)
        //   - sidebarSelection == .referenceCategory(let dirName)
        //     → .referenceScope(.some(dirName)) (= only entities in
        //     the picked category show up)
        //   - sidebarSelection == .book(let bookId) / .shelf(...) /
        //     .folder(...) → .empty (= no preview yet; = clicking a
        //     user shelf or book is preview-zone's blank state)
        // All branches are exhaustive over SidebarItem cases (= no
        // unknown-sidebar-selection fallback path = the bug can't
        // reappear silently).
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'if the Apple API supports it, just use that directly':
        // wire the Apple `.searchable` system-styled search field to
        // the live `envAppState.searchText` (= the AppState
        // @Observable property; = single source of truth for app-wide
        // search state; = multiple columns can attach .searchable
        // to the same binding to share search text). Pass the
        // binding to PreviewPane so its `searchQuery` Binding resolves
        // to the live `envAppState.searchText` (= the filter applies
        // correctly; = survives PreviewPane re-instantiation).
        VStack(spacing: 0) {
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'first, can you put the search field
            // on the left?': per the boss's request, place the search
            // field at the LEADING (= left) edge of the cards column's
            // top bar (= flush to the column's left margin). The
            // SwiftUI `.searchable` modifier is hard-wired to render
            // in the TRAILING edge of any column toolbar (= Apple
            // macOS 27 Mail / Notes / Finder all have their search
            // box on the trailing side, so that's the framework
            // default). To override the boss's preference for a
            // LEADING-positioned search field, drop the `.searchable`
            // modifier and render a custom TextField instead (= the
            // same TextField-with-search-icon that `.searchable`
            // produces internally; = bound to the same
            // `envAppState.searchText` state so the search filter
            // in PreviewPane keeps working). Place the custom
            // search field in a `.frame(maxWidth:.infinity,
            // alignment: .leading)` so it sits flush to the LEFT
            // edge of the cards column. ⌘F still works (= Apple
            // system shortcut) because the search field IS in the
            // view hierarchy.
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'fill the width automatically,
            // grow with the drag just like the cards do': the search field now fills
            // the full column width (= .frame(maxWidth: .infinity,
            // alignment: .leading) so it stretches as the user
            // drags the column wider, matching the card grid's
            // intrinsic width). Removed the previous hard-coded
            // .frame(minWidth: 120, maxWidth: 240) (= a fixed 120-240
            // PT search bar that didn't track the column's width).
            //
            // Note: dropped `.searchable` because the framework's
            // own search box was rendering trailing regardless of
            // the `placement:` parameter (= `.automatic` /
            // `.toolbar` both = trailing in macOS 27 NavigationSplit
            // columns; = a documented framework limitation).
            // The custom TextField below gives us full control
            // over placement (= left-aligned, per the boss).
            //
            // Note: PreviewPane does NOT take a `searchText:` arg
            // (= the search state lives in envAppState.searchText,
            // a global; = PreviewPane's `searchQuery: Binding<String?>`
            // already reads/writes through envAppState). The
            // wrapper stays as a thin pass-through; = the search
            // field rendered here and the search filter inside
            // PreviewPane share the SAME binding = typing in one
            // updates the other live (= the same envAppState.searchText).
            PreviewPane(
                scope: previewScope(),
                // v1.0.0-m1-shell boss 2026-09-12 OOB 'doc-open pipeline fix':
                // card double-click opens the document in the editor
                // pane (= mode = .edit = the WenshuMarkdownEditor
                // editable surface from the start; = not a separate
                // window). Forward the clicked CardSource so the
                // correct entity opens (= not the topmost card =
                // BOSS 9/8 'clicking Dufu card opens tab with wrong
                // name' regression).
                onDoubleClick: { source in
                    openCardInEditor(source: source)
                },
                previewSortOrder: $envAppState.previewSortOrder,
                searchQuery: Binding<String?>(
                    get: { envAppState.searchText },
                    set: { newValue in envAppState.searchText = newValue ?? "" }
                ),
                customLeadingSearch: AnyView(
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(
                            WenshuI18n.t("preview.search.placeholder"),
                            text: Binding(
                                get: { envAppState.searchText },
                                set: { newValue in envAppState.searchText = newValue }
                            )
                        )
                        // v1.0.0-m1-shell boss 2026-09-11 OOB
                        // 'the search field is a bit too short — change it to
                        // 30pt tall' + 'if the search field height can only
                        // be hard-coded to 30pt, then don't hard-code — use the closest
                        // Apple-standard expression for height': apply
                        // `.controlSize(.regular)` (= the canonical
                        // macOS 13+ SwiftUI semantic expression for
                        // standard form-control height = maps to
                        // NSTextField regular controlSize = 22 PT
                        // = matches Apple's Mail / Notes / Finder
                        // search field heights). NO hard-coded
                        // `.frame(height: 30)` per the boss's
                        // explicit request.
                        .controlSize(.regular)
                        .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, DesignTokens.zoneContentInset)
                    // v1.0.0-m1-shell boss 2026-09-11 OOB 'search field,
                    // spacing between it and the first card — is there a hand-written padding, and if
                    // so, drop it': drop the manual `.padding(.vertical,
                    // 4)` (= 4 PT top + 4 PT bottom = hand-rolled
                    // breathing room inside the search HStack) =
                    // the outer PreviewPane layer handles vertical
                    // spacing (= `.padding(.top, 4)` for the gap
                    // above the search field; = no bottom padding
                    // so the search field sits flush against the
                    // first card; = the LazyVGrid handles card-to-
                    // card spacing). Keep only the `.padding(.horizontal,
                    // 8)` (= Apple HIG 8-point grid for inline
                    // content horizontal inset).
                    // v1.0.0-m1-shell boss 2026-09-11 OOB 'fill the width automatically,
                    // grow with the drag just like the cards do': the search field
                    // now fills the full column width (= the
                    // `.frame(maxWidth: .infinity)` modifier
                    // forces SwiftUI to stretch this HStack to
                    // consume all available horizontal space in
                    // its parent; = the search field now matches
                    // the LazyVGrid's full grid width; = as the
                    // user drags the column wider, both the cards
                    // and the search field stretch together).
                    //
                    // Why not use `alignment: .leading` (= the
                    // boss's earlier preference for left-alignment):
                    // the LazyVGrid cards are center-aligned within
                    // the column (= the card grid is centered to
                    // keep the 2-column rhythm visually balanced);
                    // = the search field should also be center-
                    // aligned to track the cards' visual position.
                    // The inner HStack's leading-left Image +
                    // TextField still keep the icon flush to the
                    // search field's left edge (= the field is
                    // wider but the icon stays at the field's own
                    // left; = no visual change inside the field).
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    )
                    .overlay(
                        // macOS 27 doc-alignment (boss 9/18 OOB
                        // '全都改一下', audit ticket 6):
                        // HierarchicalShapeStyle.separator is the
                        // Apple semantic ShapeStyle that
                        // auto-adapts to dark mode + Liquid Glass
                        // (= 1 PT hairline by default; = not the
                        // solid NSColor.separatorColor which fails
                        // on dark mode + glass tint backgrounds per
                        // wenshu-macos26-liquid-glass-pitfalls
                        // Pitfall 1 = Attempt 1/2 boss-rejected).
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(.separator, lineWidth: 0.5)
                    )
                )
            )
        }
    }
}
