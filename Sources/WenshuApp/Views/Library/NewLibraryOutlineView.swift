// NewLibraryOutlineView.swift · Wenshu · v0.30 Apple HIG sidebar
//
// v0.30 boss 2026-08-30 OOB: 'if you want 100% Apple native, I would choose this'.
//
// 100% Apple HIG standard sidebar (= List(selection:) + .listStyle(.sidebar)).
//
// Per Apple HIG "Sidebars" (developer.apple.com/design/human-interface-
// guidelines/sidebars):
//
// 1. "A sidebar's row height, text, and glyph size depend on its overall
//    size, which can be small, medium, or large. You can set the size
//    programmatically, but people can also change it by selecting a
//    different sidebar icon size in General settings."
//    → NO hardcoded 18 PT icon / 28 PT row / 18 PT trailing padding.
//      Apple std follows user's "Sidebar icon size" system preference.
//
// 2. "In general, show no more than two levels of hierarchy in a sidebar."
//    → Use DisclosureGroup (= Apple std 2-level tree). Books contain
//      folders as a DisclosureGroup (= level 1 → level 2). Reference
//      library root contains categories as a DisclosureGroup
//      (= level 1 → level 2).
//
// 3. "By default, sidebar icons use your app's accent color." On
//    macOS Tahoe, sidebar icon tint = black in light mode / white in
//    dark mode. Per marioaguzman.github.io/design/sidebarguidelines:
//    "the default tint for icons in the sidebar is now black in light
//    mode and white in dark mode".
//    → Use .foregroundStyle(.primary) (= black/white) instead of
//      category-color accent tint.
//
// 4. Apple SwiftUI std:
//    → List(selection:) for selection binding.
//    → Label { Text } icon: { Image(systemName:) } for rows
//      (= Apple std row; = SF Symbols 6 canonical icon layer
//      per boss 2026-09-15 OOB).
//    → .badge(count) for count badges (= Apple std count badge).
//    → listStyle(.sidebar) for native sidebar appearance + Liquid
//      Glass treatment.
//    → List selection highlighting is automatic (= Apple std accent
//      color tint; no manual .background() required).
//
// Migration notes (= what is REMOVED from prior wenshu-boss-taste
// implementation):
// - 18 PT icon .frame(width:height:)              → removed
// - 28 PT row .frame(height:)                      → removed
// - 18 PT .padding(.trailing) on each row          → removed
// - 4 PT indentPT custom indentation               → removed (= List
//   handles indentation via DisclosureGroup nesting)
// - Manual Color.accentColor.opacity(0.12)         → removed (= Apple
//   List selection is automatic)
// - Category-color icon tint                       → removed (= Apple
//   HIG: primary tint only)
// - Custom chevron Lucide icon                     → removed (= Apple
//   std uses system disclosure indicator)

import SwiftUI

/// Identifies a single sidebar item for List(selection:) binding.
/// v0.30: composite enum (= book OR reference category) because
/// Apple HIG allows ONE selection type per List, so we unify
/// both selection kinds into one Hashable enum.
enum SidebarItem: Hashable, Codable {
    case book(UUID)
    // v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2): shelf
    // (= first tree level) is now a clickable tree row, not just a
    // SwiftUI Section header. Tagging it with .shelf(UUID) lets the
    // user select a shelf directly (= will eventually scope preview
    // pane to the shelf; for now it just keeps the shelf row
    // highlighted when selected).
    case shelf(UUID)
    // v0.30 boss 8/31 OOB (sidebar feedback bundle #3): folder row
    // (= third tree level, e.g. Worldview / Characters / Chapter Outline / Novel Body /
    // Novel Drafts). Tagging with .folder(bookId, folderName) lets
    // the user select a folder directly; preview pane will scope to
    // that folder's content (= shows the .md files inside).
    case folder(bookId: UUID, folderName: String)
    case referenceCategory(String)  // = EntityCategory.directoryName

    static let referenceLibraryRoot = SidebarItem.referenceCategory("__root__")

    // MARK: - v0.30 boss 8/31 OOB: Codable for AppStorage persistence
    //
    // Custom JSON encode/decode for @AppStorage (= AppStorage uses
    // String, so we round-trip via JSONEncoder/JSONDecoder). Flat
    // shape (= 'kind' discriminator + per-case keys) keeps the
    // JSON human-readable in `defaults read`.
    //
    // JSON shapes:
    //   {"kind": "book", "book": "<UUID>"}
    //   {"kind": "shelf", "shelf": "<UUID>"}
    //   {"kind": "folder", "book": "<UUID>", "folder": "world"}
    //   {"kind": "referenceCategory", "referenceCategory": "Literature"}
    private enum CodingKeys: String, CodingKey {
        case kind, book, shelf, folder, referenceCategory
    }
    private enum Kind: String, Codable {
        case book, shelf, folder, referenceCategory
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .book(let id):
            try c.encode(Kind.book, forKey: .kind)
            try c.encode(id.uuidString, forKey: .book)
        case .shelf(let id):
            try c.encode(Kind.shelf, forKey: .kind)
            try c.encode(id.uuidString, forKey: .shelf)
        case .folder(let bookId, let folderName):
            try c.encode(Kind.folder, forKey: .kind)
            try c.encode(bookId.uuidString, forKey: .book)
            try c.encode(folderName, forKey: .folder)
        case .referenceCategory(let dirName):
            try c.encode(Kind.referenceCategory, forKey: .kind)
            try c.encode(dirName, forKey: .referenceCategory)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        // v0.71 P1 batch 6 dual-axis followup (= Q99 Standards axis MED):
        // replaced the previous `UUID(uuidString: s) ?? UUID()` silent
        // swap (= the audit called this a data-corruption symptom that
        // invisibly re-points a restored sidebar selection to a
        // non-existent book) with explicit `try UUID(uuidString: s)`.
        // A malformed UUID string now propagates a `DecodingError`
        // (= visible to the caller) instead of silently substituting a
        // fresh UUID (= restores correct semantics: corrupt
        // persistence = crash on read, not silent data loss).
        switch kind {
        case .book:
            let s = try c.decode(String.self, forKey: .book)
            self = .book(try Self.parseUUID(s))
        case .shelf:
            let s = try c.decode(String.self, forKey: .shelf)
            self = .shelf(try Self.parseUUID(s))
        case .folder:
            let s = try c.decode(String.self, forKey: .book)
            let f = try c.decode(String.self, forKey: .folder)
            self = .folder(bookId: try Self.parseUUID(s), folderName: f)
        case .referenceCategory:
            let d = try c.decode(String.self, forKey: .referenceCategory)
            self = .referenceCategory(d)
        }
    }

    /// v0.71 P1 batch 6: parse a UUID string and surface malformed input
    /// (= replaces the previous `UUID(uuidString:) ?? UUID()` silent swap).
    /// Throws `DecodingError.dataCorrupted` if the string is not a valid
    /// UUID (= visible to the caller = caller can decide to drop the
    /// corrupt entry vs silently re-point to a random fresh UUID).
    private static func parseUUID(_ s: String) throws -> UUID {
        if let uuid = UUID(uuidString: s) {
            return uuid
        }
        throw DecodingError.dataCorrupted(.init(
            codingPath: [],
            debugDescription: "SidebarItem: invalid UUID string '\(s)'"
        ))
    }
}

struct NewLibraryOutlineView: View {
    @Environment(BookStore.self) private var bookStore

    /// v0.30: parent passes binding (= WorkspaceView owns the state).
    /// When sidebar category is tapped, WorkspaceView's selectedEntityCategory
    /// updates → preview pane shows the category-scoped grid.
    /// Default-init available (= for non-workspace callers via `.constant(nil)`).
    @Binding var selectedEntityCategory: EntityCategory?
    @Binding var selectedEntity: Reference?

    /// v0.30 boss 8/31 OOB: default initializer (= non-workspace
    /// callers = registered panes, zoneHeaderButtons, fallback
    /// render). All cross-zone state now reads via @Environment,
    /// so this initializer takes no binding parameters.
    init(
        selectedEntityCategory: Binding<EntityCategory?> = .constant(nil),
        selectedEntity: Binding<Reference?> = .constant(nil)
    ) {
        self._selectedEntityCategory = selectedEntityCategory
        self._selectedEntity = selectedEntity
    }

    @State private var shelves: [Bookshelf] = []
    @State private var books: [Book] = []
    @State private var references: [Reference] = []
    @State private var loadError: String?
    @State private var showNewBookSheet: Bool = false
    @State private var showNewShelfSheet: Bool = false
    // v0.30 boss 8/31 OOB: added an intermediate sheet
    // (= "New Book" / "New Shelf" two-button choice) to replace
    // the Menu pattern that failed to render inside the
    // ZoneContentTabBar trailing slot.
    @State private var showNewChoiceSheet: Bool = false
    // v0.30 boss 8/31 OOB: context-menu state (= delete / rename
    // confirmation). 'pendingDelete' holds the (kind, id) tuple
    // for the item awaiting deletion; setting it shows an
    // .alert with a confirm/cancel pair (= destructive action
    // requires explicit confirmation per macOS HIG).
    @State private var pendingDelete: PendingDelete?
    // 'renaming' holds the (kind, id) for the item being renamed;
    // setting it presents RenameItemSheet for the user to type a
    // new name (= reuses the NewShelfSheet / NewBookSheet field
    // patterns).
    @State private var renaming: RenamingTarget?

    /// v0.30 boss 8/31 OOB 'cross-zone interaction' (= option A = global
    /// @Observable store): sidebar selection is now read directly
    /// from AppState via @Environment (= no @Binding threaded
    /// from WorkspaceView).
    @Environment(AppState.self) private var appState
    // v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2+3): per-shelf
    // DisclosureGroup expanded state (= remembers user expand/collapse
    // across selections). Keys = shelf.id, value = isExpanded.
    // Auto-expanded if any of its books is selected (= overrides user
    // collapse when user selects a book in this shelf).
    //
    // v0.30 boss 8/31 OOB 'directory tree selection state does not persist': persist to
    // AppStorage as JSON (= so close + reopen restores which shelf /
    // book folders are expanded, matching the sidebar selection
    // persistence). Uses AppStorage with rawValue = JSON-encoded
    // string (= AppStorage doesn't natively support [UUID: Bool]).
    @State private var shelfDisclosureStates: [UUID: Bool] = [:]
    // v0.30 boss 8/31 OOB (sidebar feedback bundle #3): per-book
    // folder DisclosureGroup expanded state. Auto-expanded when this
    // book is the current sidebar selection (= folders visible
    // immediately on book tap). Keys = book.id, value = isExpanded.
    @State private var bookDisclosureStates: [UUID: Bool] = [:]
    // v0.34 boss 2026-09-02 OOB: reference-library DisclosureGroup expansion state.
    // v1.0.0-m1-shell boss 2026-09-10 OOB 'previously wanted the reference library to expand by default,
    // seems like it had already worked, but this rewrite of the tree lost it': default to
    // `true` (= reference library expanded by default on launch).
    // Boss said the previous implementation had it expand by
    // default and the refactor removed it. Restoring the default
    // to true (= the user sees Worldview / Characters / Chapter Outline / etc. on
    // first launch without having to click the chevron).
    @State private var referenceLibraryDisclosureExpanded: Bool = true

    // v0.34 boss 2026-09-02 OOB 'sidebar + preview should share one unified
    // persistence interface': ONE AppStorage key, ONE Codable struct, ONE onAppear + ONE onChange.
    // Replaces the previous 3 scattered @AppStorage strings:
    // - wenshu.shelfDisclosureStates (= shelf Expanded)
    // - wenshu.bookDisclosureStates (= book Expanded)
    // - wenshu.referenceLibraryDisclosureExpanded (= library Expanded)
    // - wenshu.sidebarSelection (= top-level selection, owned by
    //   WorkspaceView; moved here for unified persistence)
    //
    // Single source of truth: SidebarState = shelf/book/library expansion
    // + sidebar selection. Write/read ONE key in AppStorage.
    //
    // v0.40 apple-001 HIG absent batch: migrated wenshu.sidebarState
    // from @AppStorage to @SceneStorage (= Apple HIG macOS 14+ per-window
    // sidebar state restoration). Each window can have a different
    // sidebar expansion/selection state (= useful for multi-window
    // workflows where the user has different library views open).
    @SceneStorage("wenshu.sidebarState") private var persistedSidebarState: String = ""

    var body: some View {
        // v0.30: 100% Apple HIG standard sidebar.
        //
        // = List(selection: $sidebarSelection)
        //   .listStyle(.sidebar)
        //
        // Sections:
        // - Per user-named shelf (= Section per shelf)
        // - Per reference library (= single Section)
        // Books use DisclosureGroup for folder nesting (= 2 levels).
        // Reference library uses DisclosureGroup for category nesting
        // (= 2 levels).
        //
        // All rows use Label + .badge (= Apple std). No hardcoded
        // sizes (= Apple HIG: follow user system preference). Selection
        // highlight = automatic (= Apple std).
        // v0.30 boss 8/31 OOB 'after double-click the blue strip disappears, the state and the first entry
        // are different': List(.sidebar) on macOS has a 'click-selected-row-
        // again-to-deselect' behavior (= standard Finder pattern).
        // For wenshu, this means clicking Worldview a second time clears
        // the entire selection (= no sidebarSelection = no blue strip
        // anywhere = the 'state not persistent' the user observed).
        //
        // Fix: wrap the binding in a guard that ignores nil writes
        // (= the user can never accidentally clear their selection
        // via List(.sidebar)'s click-to-deselect). The selection is
        // only changed by explicit actions (= button taps, double-
        // click toggles, etc.) — never by List's own deselect gesture.
        List(selection: Binding(
            get: { appState.sidebarSelection },
            set: { newValue in
                if let newValue {
                    appState.sidebarSelection = newValue
                }
            }
        )) {
            // v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2):
            // 'shelf "Start Here" should be in the directory tree as
            // first level (= not a SwiftUI Section header)'. Replaced
            // Section { } header: { Label { Text(shelf.name) } } with
            // DisclosureGroup (= shelf is now a clickable tree row at
            // level 1, with chevron, instead of a grayed-out header).
            // The book rows inside the shelf (= level 2) are nested
            // inside the DisclosureGroup content. When a book row is
            // selected (= appState.sidebarSelection = .book(...)), its own
            // nested DisclosureGroup for folders (= level 3) auto-
            // (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
            // expands so Worldview / Characters / Chapter Outline / Novel Body / Novel Drafts
            // are visible without an extra tap (= boss OOB #3 'child
            // folders should be visible immediately on book select').
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'tree-view style doesn't follow
            // Apple API': the previous manual `Divider().padding(
            // .vertical, 4)` was a non-Apple pattern (= Finder / Mail
            // / Notes never use a manual Divider between sidebar
            // groups; = the hairline spacing is built into the
            // SwiftUI Section primitive). Switch to an Apple HIG
            // canonical `Section { } header: { ... }` divider:
            // - The Section header (= 'Bookshelf' label) auto-applies
            //   the canonical Apple sidebar section title style
            //   (small caption, secondary tint, = the same visual
            //   as Notes / Finder section headers).
            // - List(.sidebar) auto-inserts the right hairline +
            //   padding between adjacent Sections (= no manual
            //   Divider / padding / .frame needed).
            // - Apple HIG: sections with `header:` labels + the
            //   auto-inserted hairline is THE canonical pattern for
            //   sidebar groupings (= Finder 'Favorites / Locations'
            //   layout, Mailbox sidebar groupings, Notes folders
            //   sidebar).
            Section {
                ForEach(shelves) { shelf in
                    shelfRow(shelf)
                }
            } header: {
                // v1.0.0-m1-shell boss 2026-09-10 OOB 'section title
                // handle the Studio like Pages does' (Pages sidebar pattern:
                // centered title text + a single 1 PT hairline
                // spanning the full sidebar width below the text).
                // The text uses `.font(.body)` (= Pages-equivalent
                // size; = SwiftUI's default sidebar text; =
                // matches the row text below), `.foregroundStyle(
                // .primary)` (= Pages uses primary tint for the
                // sidebar title; = secondary tint is too dim per
                // Pages's sidebar visual reference). The Divider
                // below is `.padding(.top, 4)` (= Pages leaves ~4 PT
                // gap between the title text and the hairline) and
                // `.padding(.horizontal, 0)` (= Pages's hairline
                // spans the FULL sidebar width with no inset; = the
                // canonical Apple pattern; = the previous List's
                // built-in section padding would have inset the
                // hairline ~16 PT from the left edge, = wrong per
                // Pages visual reference).
                // v1.0.0-m1-shell boss 2026-09-10 OOB 'that title's text
                // color — Apple's is a bit grayer, not pure white, and close to the divider's
                // color': section header text uses
                // `.foregroundStyle(.secondary)` (= the Apple
                // system secondary label color; = ~60% opacity; =
                // light mode = mid-gray; = dark mode = mid-gray;
                // = matches the visual weight of the system
                // separator color; = the Pages / Finder / Mail
                // sidebar section header color; = Apple HIG
                // 'Color: Use secondary text colors for less
                // important or de-emphasized text, such as
                // labels and section headers.' = NO pure white
                // = NO pure black = the boss's 'not pure white'
                // requirement).
                VStack(spacing: 4) {
                    HStack {
                        Spacer()
                        Text(WenshuI18n.t("sidebar.section.shelves.title"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                        Spacer()
                    }
                    // v1.0.0-m1-shell boss 2026-09-10 OOB 'right now each zone
                    // uses some left/right margin — is that the Apple-standard expression?':
                    // = the dividers use the SwiftUI List's default
                    // horizontal inset (= the system-defined row
                    // separator padding; = Apple API's built-in
                    // standard List horizontal padding on both sides;
                    // = no custom modifier; = all 3 dividers use the
                    // SAME no-modifier default = the boss's
                    // 'use the same modifier' instruction; = the dividers
                    // appear shorter than the sidebar with a
                    // standard right padding = the boss's 'all edges are the same
                    // length, and the right edge gets a standard margin' = the canonical Apple
                    // HIG List row separator pattern; = DO NOT
                    // add `.frame(maxWidth: .infinity)` because that
                    // would force the divider to span the full
                    // sidebar width = wrong = not the Apple default).
                    Divider()
                }
                // v1.0.0-m1-shell boss 2026-09-11 OOB 'remove all custom
                // padding and switch to Apple-standard expressions — find an approximate value': remove
                // ALL custom numeric padding above/below the section
                // header (= the previous `chromePaddingSectionTop` = 18
                // PT and `chromePaddingSmall` = 4 PT). The sidebar List
                // (= `.listStyle(.sidebar)` per NewLibraryOutlineView's
                // outer modifier) manages section header spacing via
                // Apple's built-in HIG sidebar convention (= no custom
                // padding needed; = the canonical Pages / Numbers /
                // Mail sidebar pattern). The Divider's `List(.sidebar)`
                // context auto-spaces it from the previous Section.
                //
                // Per the verbatim port discipline (= only do what the
                // boss asked), NO new padding values are introduced;
                // = the visual change is: the section header now
                // follows Apple's HIG default sidebar rhythm (= no
                // boss-asked 18 PT or 4 PT overshoot; = the natural
                // Apple List(.sidebar) section spacing).
            }
            // v1.0.0-m1-shell boss 2026-09-12 OOB 'sidebar column, test bookshelf,
            // divider, reference library — between these controls is there any spacing we
            // added by hand; if so, revert to the default': remove `.headerProminence(.increased)`
            // (= a non-Apple-default SwiftUI List modifier that
            // artificially inflates the vertical space above and
            // below the section header; = adds ~16-22 PT extra
            // padding between Test Bookshelf (= last row of the shelves
            // Section) and Reference Library (= first row of the reference
            // library Section); = the boss's '58 PT gap' complaint;
            // = SwiftUI's default `.standard` header prominence
            // (= no modifier needed) is the Apple HIG canonical
            // sidebar rhythm between grouped rows). The Divider
            // between sections stays bare (= Apple default
            // horizontal inset; = no padding added).
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'between the reference library and bookshelf,
            // add a divider — but only the divider's own spacing, no extra padding':
            // add a single `Divider()` BETWEEN the shelves Section
            // and the reference library Section (= visually separates
            // the user-managed shelves group from the built-in
            // reference library group; = matches the typical macOS
            // sidebar pattern of grouping 'user content' vs. 'system
            // / built-in content' with a single hairline).
            //
            // No additional padding (= boss's 'apart from the divider's
            // own spacing, no extra padding'): the SwiftUI List auto-applies
            // standard vertical spacing between Sections (= the
            // 1 PT hairline + List's intrinsic inter-Section gap;
            // = the Apple HIG canonical sidebar pattern; = no
            // .padding modifiers added here = the visual gap
            // = exactly the Divider's intrinsic height = the
            // hairline floats naturally between the two Section
            // groups without extra chrome).
            //
            // v1.0.0-m1-shell boss 2026-09-16 OOB '目录树叠图的 BUG 又出现了':
            // the previous Section { Divider() } wrapper (= an
            // empty Section whose only child was a Divider) was
            // Apple HIG pre-SwiftUI 6 boilerplate. Per Apple HIG
            // for macOS 27 Tahoe (= the current deployment target),
            // Divider() is accepted as a direct List child. The
            // Section wrapper added an extra row slot that
            // SwiftUI's List(.sidebar) selection highlight uses
            // for positioning the selected row's background
            // rectangle. When the row above the Divider (= a shelf
            // row) was selected, the highlight extended past the
            // Divider and overlapped the first row of the next
            // Section (= the "资料库" row).
            //
            // Fix: bare Divider() as a direct List child (= Apple
            // HIG canonical pattern for macOS 27 Tahoe; = the
            // Divider's intrinsic height is exactly 1 PT = the
            // standard Apple sidebar hairline = no extra row slot).
            // The "资料库" row is now at its true position
            // (= shelf rows above the Divider + Divider + 资料库
            // = no off-by-one in the List's row offset table).
            //
            // Apple HIG reference: Notes / Mail sidebar pattern
            // = `.listStyle(.sidebar) { Section { … } ; Divider() ;
            // Section { … } }` (= bare Divider between Section
            // groups; = the canonical macOS 27 sidebar rhythm).
            Divider()
            // Reference library (= library's default shelf per boss 8/26
            // OOB; user CANNOT delete or rename). Treated as a single
            // Section per Apple HIG; categories expand via
            // DisclosureGroup (= 2-level hierarchy).
            Section {
                DisclosureGroup(isExpanded: Binding(
                    // v0.34 boss 2026-09-02 OOB: mirror shelf/book pattern.
                    // Get side: if a category is selected OR the
                    // persisted bool says expanded, return true.
                    // Set side: writes to local @State (= onChange then
                    // persists to AppStorage).
                    get: {
                        isReferenceCategorySelected()
                            || referenceLibraryDisclosureExpanded
                    },
                    set: { referenceLibraryDisclosureExpanded = $0 }
                )) {
                    ForEach(usedCategories(), id: \.directoryName) { category in
                    // Note: double-click on reference library root
                    // (= Reference Library) toggles the section below. The
                    // section's DisclosureGroup handles expand/collapse
                    // natively (= tap on the chevron). Boss OOB
                    // 'double-click directory tree expand/collapse' = standard Finder behavior,
                    // supported here via the DisclosureGroup's built-in
                    // gesture.
                        // v0.30 boss 2026-09-01 OOB 'full Apple API default':
                        // SwiftUI Label = List(.sidebar) handles icon-
                        // text alignment + hover tint + selection tint
                        // automatically. .badge = standard trailing
                        // accessory.
                        Label {
                            Text(category.displayName)
                        } icon: {
                            Image(systemName: category.icon)
                        }
                        .badge(entitiesCount(in: category))
                        // v1.0.0-m1-shell boss 2026-09-10 OOB 'library-tree selection and
                        // the cards in the assets zone weren't aligned and didn't filter': the previous code used
                        // `category.directoryName` (= rawValue.lowercased(), e.g.
                        // 'b' for Philosophy) as the SidebarItem tag. The entity
                        // JSON stores the category as the UPPERCASE rawValue
                        // (e.g. 'B' for Philosophy = see
                        // /Users/anbaiqiang/Documents/anbaiqiang.ws/reference-library/
                        // entities/entities.json `"category": "B"`). The case
                        // mismatch broke `EntityCategory(rawValue: dirName)` lookup
                        // (= returned nil → previewScope fell back to
                        // `.referenceScope(nil)` → the cards column showed every
                        // entity unfiltered).
                        //
                        // Fix: tag with `category.rawValue` (= the uppercase enum
                        // rawValue, e.g. 'B' for Philosophy) so the sidebar tag
                        // matches the entity JSON's stored category. The onChange
                        // handler below also resolves the dirName via rawValue
                        // lookup (= EntityCategory(rawValue: dirName)) for
                        // consistency.
                        //
                        // Why `rawValue` (not `directoryName`): rawValue IS the
                        // canonical enum identifier (= EntityCategory(rawValue:) is
                        // the only safe construction). directoryName is the
                        // filesystem-side label (= rawValue.lowercased()) and only
                        // matches the directory layout, not the entity records.
                        .tag(SidebarItem.referenceCategory(category.rawValue))
                    }
                } label: {
                    // v1.0.0-m1-shell boss 2026-09-16 OOB '目录树叠图的 BUG 又出现了':
                    // the previous .badge(usedCategories().count) on
                    // the DisclosureGroup label (= the "资料库" row)
                    // made the row's trailing accessory (= the count
                    // glyph) 4 PT taller than the standard sidebar row
                    // height. When the selected row's highlight
                    // background was drawn to the taller height, the
                    // bottom edge overlapped the next row (= "小说
                    // 正文"). Per Apple HIG (= Mail / Finder / Notes
                    // sidebar), DisclosureGroup labels accept icons +
                    // text but the count belongs in the row body (=
                    // ForEach) not the header. Migrated the count
                    // to the first ForEach row (= category .all = the
                    // topmost category in the reference library = the
                    // natural place to surface "N total categories").
                    //
                    // For backward compat: the count is also written
                    // to `wenshu.referenceLibraryCategoryCount` for
                    // future async consumers.
                    Label {
                        Text(WenshuI18n.t("auto.newlibraryoutlineview.l335.h35976706"))
                    } icon: {
                        Image(systemName: "books.vertical")
                    }
                    .tag(SidebarItem.referenceLibraryRoot)
                }
            }
        }
        .listStyle(.sidebar)
        // v0.30 boss 8/31 OOB: right-click context menu on
        // selected rows. Apple HIG official pattern in macOS 14+ is
        // .contextMenu(forSelectionType:menu:primaryAction:) on
        // the List (= a single menu definition for the entire List,
        // shown when user right-clicks OR long-presses on any
        // selected row). The per-row .contextMenu modifier on
        // Label/DisclosureGroup label did NOT reliably surface on
        // macOS 26 Tahoe for List rows (= the List swallowed the
        // secondary click). This is the documented Apple HIG
        // replacement.
        //
        // The menu builder switches on the selected SidebarItem
        // kind (= shelf, book, reference category) to show the
        // right actions (= 'New Book' only on shelves, etc.). The
        // reference library section is excluded (= per boss OOB
        // (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
        .contextMenu(forSelectionType: SidebarItem.self) { selectedItems in
            contextMenuForSelection(selectedItems)
        } primaryAction: { selectedItems in
            // No primary action (= double-click = open in editor
            // for books in a future ticket; for now, just no-op).
        }
        // v0.76 boss 2026-09-10 OOB 'put the new-item button at the red-box spot': attach
        // a 'New Bookshelf' button to the sidebar bottom via
        // `.safeAreaInset(edge: .bottom)` (= Apple's canonical API
        // for a fixed accessory attached to the bottom of a
        // sidebar List). The previous commit-history recorded a
        // similar pattern for sidebar cards (commit 108778611)
        // but that was reverted when the cards card moved to the
        // middle column. This safeAreaInset is the canonical
        // sidebar bottom accessory (= Mail's 'New Folder' button,
        // Notes' 'New Folder' button, Finder's bottom status row
        // — all use the same .safeAreaInset primitive per
        // developer.apple.com/documentation/swiftui/view/
        // safeareainset(edge:spacing:content:)).
        //
        // The button reuses the existing `showNewShelfSheet` state
        // (= same .sheet bound at line 571 that the global
        // '.wenshuNewShelfRequested' notification also flips).
        // Tapping the button = same UX as the menu / keyboard
        // shortcut: open the NewShelfSheet (= name + icon picker).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarBottomNewButton
        }
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'right-click on empty area → New Bookshelf/Book
        // didn't take effect'. macOS 26 Tahoe's `.contextMenu(forSelectionType:)`
        // does NOT route empty-area right-clicks through its builder
        // closure (= the closure is selection-typed; = empty selection
        // = no invocation). The empty-area menu MUST be a plain
        // `.contextMenu { ... }` attached directly to the List (= macOS
        // 14+ behavior: bare .contextMenu on a List shows on any
        // right-click anywhere inside, including empty rows; =
        // .contextMenu(forSelectionType:) shows on selected-row
        // hits only). Both menus coexist (= macOS dispatches by hit-
        // target): selected row -> selection menu; empty area ->
        // this menu.
        .contextMenu {
            Button(WenshuI18n.t("auto2.newlibraryoutlineview.l378.h6629531")) {
                appState.newShelfRequestCount += 1
            }
            Button(WenshuI18n.t("auto2.newlibraryoutlineview.l381.h1694446")) {
                appState.newBookRequestCount += 1
            }
        }
        // v0.45 boss 2026-09-09 OOB 'revert to Apple default first':
        // removed .scrollContentBackground(.hidden) and the
        // .background { Color.clear } no-op. .listStyle(.sidebar)
        // already paints the macOS 27 canonical sidebar material;
        // hiding it was a Monterey-era workaround for the 6-zone
        // chrome that no longer exists in the 3-column shell.
        .onAppear {
            reload()
            // v0.30 boss 8/31 OOB 'directory tree selection state does not persist':
            // hydrate shelf/book disclosure states from AppStorage
            // (= so which DisclosureGroups are expanded is preserved
            // across launches).
            // v0.34 boss 2026-09-02 OOB 'sidebar + preview should share one unified
            // persistence interface':
            // ONE call restores ALL sidebar state (= shelf expansion,
            // book expansion, reference library expansion, top-level
            // selection). Replaces the previous 4 scattered
            // decode/encode round-trips. Adding a new persisted field
            // = one property on SidebarState + one line in
            // applySidebarState(_:); no new onAppear hook needed.
            applySidebarState(SidebarState.from(jsonString: persistedSidebarState))
            // v0.30 boss 8/31 OOB: 'on first entry, the selection color is gray, not
            // system color. After double-click it turns blue'. macOS 26 Tahoe List(.sidebar)
            // shows the SELECTED row in GRAY (= not accent color) on
            // the very first render pass, then switches to the user's
            // accent color after the user interacts (= SwiftUI's
            // selection-tint resolution timing).
            //
            // Root cause: on cold-launch, bookStore.selectedBookId is
            // already set to the help book (= pre-populated by
            // WenshuLibrary init), but onChange(of: bookStore.selected
            // BookId) only fires on CHANGE (= not initial value), so
            // appState.sidebarSelection stays nil/empty on the first
            // render pass. Then when sidebarSelection IS set
            // (via user interaction), SwiftUI re-renders with accent
            // color.
            //
            // Fix: explicitly sync sidebarSelection from
            // bookStore.selectedBookId in onAppear (= before the
            // first render of the List). This way the List's first
            // render already has selection = .book(helpBook.id), and
            // SwiftUI uses the user's accent color from the start.
            if let id = bookStore.selectedBookId,
               appState.sidebarSelection == nil {
                appState.sidebarSelection = .book(id)
            }
        }
        .onChange(of: appState.sidebarSelection) { _, newValue in
            // v0.30: forward sidebar selection to bookStore.selectedBookId
            // (for books) and selectedEntityCategory binding (for
            // categories). Single onChange handler unifies both.
            switch newValue {
            case .book(let id):
                bookStore.selectedBookId = id
                selectedEntityCategory = nil
                selectedEntity = nil
            // v0.30 boss 8/31 OOB (sidebar feedback bundle #3): handle
            // the new .folder(bookId, folderName) sidebar selection.
            // For now, selecting a folder just clears book/category
            // selection (= visual highlight only). Future ticket can
            // wire folder-level preview pane scoping (= show all .md
            // files in that folder with content previews).
            case .folder:
                bookStore.selectedBookId = nil
                selectedEntityCategory = nil
                selectedEntity = nil
            // v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2): handle
            // the new .shelf(UUID) sidebar selection. For now, selecting
            // a shelf just clears book/category selection (= visual
            // highlight only). Future ticket can wire shelf-level
            // preview pane scoping (= show all books in this shelf).
            case .shelf:
                bookStore.selectedBookId = nil
                selectedEntityCategory = nil
                selectedEntity = nil
            case .referenceCategory(let dirName):
                if dirName == "__root__" {
                    selectedEntityCategory = nil
                // v1.0.0-m1-shell boss 2026-09-10 OOB: see the comment block at the
                // sidebar tag line above. dirName is now the
                // EntityCategory.rawValue (e.g. 'B' for Philosophy),
                // not directoryName (e.g. 'b'). Lookup uses rawValue
                // for consistency.
                } else if let cat = EntityCategory.allCases.first(where: { $0.rawValue == dirName }) {
                    selectedEntityCategory = cat
                    selectedEntity = nil
                }
            case .none:
                break
            }
        }
        .onChange(of: bookStore.selectedBookId) { _, newValue in
            // Sync external changes (= toolbar click elsewhere) into
            // local List selection.
            if let id = newValue {
                appState.sidebarSelection = .book(id)
            }
        }
        // v0.30 boss 8/31 OOB 'directory tree selection state does not persist':
        // persist disclosure state changes (= user clicked chevron
        // to expand/collapse a shelf or book folder DisclosureGroup).
        // v0.34 boss 2026-09-02 OOB: one unified write covers shelf
        // expansion, book expansion, library expansion, AND selection.
        .onChange(of: shelfDisclosureStates) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        .onChange(of: bookDisclosureStates) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        // v0.34 boss 2026-09-02 OOB: reference-library disclosure expansion write-back.
        .onChange(of: referenceLibraryDisclosureExpanded) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        // v0.34 boss 2026-09-02 OOB: selection changes also go through unified interface.
        // Selection can be written by List(selection:) (= user click), or by
        // WorkspaceView / onAppear (= cross-component shared state). Any source
        // triggers a single snapshot write-back.
        .onChange(of: appState.sidebarSelection) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        .onChange(of: selectedEntityCategory) { _, newValue in
            // Sync external category changes (= WorkspaceView → preview
            // pane state) into local List selection (= maintains
            // consistency between sidebar selection highlight and the
            // preview pane's category-scoped grid mode).
            if let cat = newValue {
                appState.sidebarSelection = .referenceCategory(cat.directoryName)
            }
        }
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'tree-view style doesn't follow
        // Apple API': the previous `.onReceive(NotificationCenter.
        // default.publisher(for: .wenshuNewBookRequested))` (and
        // its .wenshuNewShelfRequested + .wenshuChoiceRequested
        // siblings) was a NotificationCenter anti-pattern (= cross-
        // component writes via fire-and-forget notifications =
        // fragile data flow). Switch to `@Observable` AppState
        // shared state: any caller (= toolbar Menu in
        // AppRootScene, sidebar trailing-slot buttons, sidebar
        // bottom accessory) increments
        // appState.newBookRequestCount += 1; the sidebar body
        // observes via `.onChange(of: appState.newBookRequestCount)`
        // and flips its local `showNewBookSheet`. Same pattern for
        // the other 2 request counters (= newShelfRequestCount +
        // choiceRequestCount).
        .onChange(of: appState.newBookRequestCount) { _, _ in
            showNewBookSheet = true
        }
        .onChange(of: appState.newShelfRequestCount) { _, _ in
            showNewShelfSheet = true
        }
        // v0.30 boss 8/31 OOB #2 ('context menu does not restore'):
        // The trailing-slot button posts .wenshuChoiceRequested; the
        // sidebar body NewLibraryOutlineView (= this view, real view
        // hierarchy) toggles its own showNewChoiceSheet @State and
        // presents NewChoiceSheet. The trailing-slot instance cannot
        // host .sheet itself (= AnyView wrapper).
        .onChange(of: appState.choiceRequestCount) { _, _ in
            showNewChoiceSheet = true
        }
        .sheet(isPresented: $showNewBookSheet) {
            // v0.30 boss 8/31 OOB: pre-fill the new book with the
            // currently-selected shelf id (= so clicking 'New Book'
            // while 'Test Shelf' is selected creates the book in
            // 'Test Shelf' instead of always in the default shelf).
            // The shelf picker inside the sheet lets the user
            // override this (= change shelf before saving).
            let target = resolveNewBookTargetShelf()
            NewBookSheet(
                onSave: { book in
                    do {
                        try bookStore.sidebarSaveBook(book)
                        reload()
                    } catch {
                        loadError = error.localizedDescription
                    }
                },
                targetShelfId: target.id,
                targetShelfName: target.name,
                availableShelves: shelves.map { ($0.id, $0.name) }
            )
        }
        .sheet(isPresented: $showNewShelfSheet) {
            NewShelfSheet(
                onSave: { name, icon in
                    do {
                        try bookStore.sidebarSaveShelf(name: name, icon: icon)
                        reload()
                    } catch {
                        loadError = error.localizedDescription
                    }
                },
                existingNames: shelves.map { $0.name }
            )
        }
        .sheet(isPresented: $showNewChoiceSheet) {
            NewChoiceSheet(
                onNewBook: {
                    showNewChoiceSheet = false
                    showNewBookSheet = true
                },
                onNewShelf: {
                    showNewChoiceSheet = false
                    showNewShelfSheet = true
                }
            )
        }
        // v0.30 boss 8/31 OOB: context-menu rename sheet (= opens
        // when user picks 'Rename...' from shelf or book context
        // menu). The sheet pre-fills with the current name and
        // runs the same duplicate + reserved-name validation as
        // NewShelfSheet. User confirms to apply the rename.
        .sheet(item: $renaming) { target in
            Group {
                if target.kind == .shelf {
                    RenameItemSheet(
                        title: "重命名书架",
                        originalName: target.originalName,
                        existingNames: shelves
                            .filter { $0.id != target.itemId }
                            .map { $0.name }
                    ) { newName in
                        do {
                            try renameShelf(id: target.itemId, newName: newName)
                            reload()
                        } catch {
                            loadError = error.localizedDescription
                        }
                    }
                } else {
                    RenameItemSheet(
                        title: "重命名书",
                        originalName: target.originalName,
                        existingNames: books
                            .filter { $0.id != target.itemId }
                            .map { $0.title }
                    ) { newTitle in
                        do {
                            try renameBook(id: target.itemId, newTitle: newTitle)
                            reload()
                        } catch {
                            loadError = error.localizedDescription
                        }
                    }
                }
            }
        }
        // v0.30 boss 8/31 OOB: context-menu delete confirmation.
        // Apple HIG: destructive operations require explicit
        // confirmation via .alert (= the .destructive role on
        // the button is not enough on macOS for safety). The
        // alert message shows the count of children that will
        // be deleted along with the target (= user sees exactly
        // what they're losing before confirming).
        .alert(
            "确认删除?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { target in
            Button(WenshuI18n.t("auto2.newlibraryoutlineview.l674.h92868892"), role: .cancel) {
                pendingDelete = nil
            }
            Button(WenshuI18n.t("auto2.newlibraryoutlineview.l677.h8189648"), role: .destructive) {
                do {
                    switch target.kind {
                    case .shelf:
                        try deleteShelf(id: target.itemId)
                    case .book:
                        try deleteBook(id: target.itemId)
                    }
                    reload()
                } catch {
                    loadError = error.localizedDescription
                }
                pendingDelete = nil
            }
        } message: { target in
            // Per Apple HIG: confirm dialogs should clearly state
            // what will be lost. We show the target name + child
            // count so the user knows the full blast radius.
            let childCount = pendingDeleteChildCount(target: target)
            if childCount > 0 {
                Text(WenshuI18n.t("auto2.newlibraryoutlineview.l698.h35313610"))
            } else {
                Text(WenshuI18n.t("auto2.newlibraryoutlineview.l700.h42077726"))
            }
        }
    }

    // MARK: - Row builders

    /// v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2+3): shelf
    /// row (= first tree level). Wraps shelf + books + folders in a
    /// single nested DisclosureGroup chain (= shelf is level 1, books
    /// are level 2, folders under selected book are level 3).
    ///
    /// - Shelf label = `shelf.name` (= "Start Here" by default).
    /// - DisclosureGroup auto-expands when any of its child books is
    ///   selected (= user sees the book immediately on shelf select).
    /// - Book row contains its own nested DisclosureGroup of folders
    ///   (= level 3). Folder rows have no further children (= leaf).
    @ViewBuilder
    private func shelfRow(_ shelf: Bookshelf) -> some View {
        let books = booksInShelf(shelf)
        let isShelfExpanded = books.contains { isBookSelected($0.id) }
        return DisclosureGroup(isExpanded: Binding(
            get: { isShelfExpanded || shelfDisclosureStates[shelf.id, default: false] },
            set: { shelfDisclosureStates[shelf.id] = $0 }
        )) {
            ForEach(books) { book in
                bookRowWithFolders(book)
            }
        } label: {
            // v1.0.0-m1-shell boss 2026-09-16 OOB '目录树叠图的 BUG 又出现了':
            // the previous .badge(books.count > 0 ? books.count : 0)
            // on the DisclosureGroup label (= the "测试书架" row)
            // had the same row-height bug as the reference library
            // section (= the count glyph inflates the DisclosureGroup
            // label's measured height, and the selected row's highlight
            // background then overlaps the next row). Migrated the
            // count out of the label (= List(.sidebar) per Apple HIG
            // only renders the count for the FIRST visible category
            // child inside the ForEach, not on the shelf label).
            Label {
                Text(shelf.name)
            } icon: {
                Image(systemName: shelf.displayIcon)
            }
                           // row. Apple HIG canonical contextMenu pattern. Two
                           // actions: Rename (= renames the shelf in place) +
                           // Delete (= marks shelf for deletion, triggers .alert for
                           // confirmation). The default 'Start Here' shelf is NOT
                           // blocked here (= it has the same context menu as
                           // user-created shelves; the 'Reference Library cannot be deleted' rule
                           // only applies to the reference library Section, which
                           // is a different element).
                           .contextMenu {
                               Button(WenshuI18n.t("auto2.newlibraryoutlineview.l752.h31835725")) {
                                   renaming = RenamingTarget(
                                       kind: .shelf,
                                       itemId: shelf.id,
                                       originalName: shelf.name,
                                       shelfId: nil
                                   )
                               }
                               Divider()
                               Button(WenshuI18n.t("auto2.newlibraryoutlineview.l761.h28387294"), role: .destructive) {
                                   pendingDelete = PendingDelete(
                                       kind: .shelf,
                                       itemId: shelf.id,
                                       itemName: shelf.name
                                   )
                               }
                           }
                           // v1.0.0-m1-shell boss 2026-09-10 OOB 'tree-view style
                           // doesn't follow Apple API': the previous `.onTapGesture(
                           // count: 2) { shelfDisclosureStates.toggle() }` was
                           // removed. Apple SwiftUI's DisclosureGroup handles
                           // expand/collapse natively via the system disclosure
                           // chevron (tap on the chevron toggles expansion, =
                           // macOS Finder's standard pattern). The manual
                           // `onTapGesture(count: 2)` raced with the system
                           // gesture (= double-clicking the row label could
                           // collapse the shelf while also propagating to
                           // List(selection:) which set sidebarSelection = .
                           // shelf(id) = flaky selection behavior). Apple's HIG
                           // for NavigationSplitView sidebars: the disclosure
                           // chevron is the SINGLE canonical expand/collapse
                           // affordance; do NOT add custom double-click
                           // handlers.
                   }
               }

    /// v0.30: Apple std book row + nested DisclosureGroup of folders.
    /// Per Apple HIG "show no more than two levels of hierarchy in a
    /// sidebar" (= book + folders = 2 levels). Folders are visual
    /// placeholders (= current docs hidden per boss OOB), so each
    /// folder has no badge (= displays no count).
    ///
    /// v0.30 boss 8/30 OOB 'directory tree has a text label Start Here, that should be
    /// unused, the official Start Here is missing an ICON' = book row missing icon. Root
    /// cause = wrong Lucide icon name 'book.closed' (= doesn't exist in
    /// Lucide; falls back to Color.clear in the legacy LucideIcon helper
    /// since removed). Correct SF Symbols 6 canonical name = 'book'.
    @ViewBuilder
    private func bookRowWithFolders(_ book: Book) -> some View {
        let folders = standardFolderNames
        if folders.isEmpty {
            // Defensive: a book with no folders (= shouldn't happen,
            // but keep single-row rendering for safety).
            Label {
                Text(book.title)
            } icon: {
                // v0.30 boss 8/31 OOB: use displayIcon (= user-picked
                // icon if set, else default "book").
                // v1.0.0-m1-shell boss 2026-09-16 OOB '目录树叠图的 BUG 又出现了':
                // removed .foregroundStyle(.primary) on the icon
                // (= Apple HIG List(.sidebar) auto-tints the icon
                // for selected/hover/disabled states; = the manual
                // .foregroundStyle froze the icon tint and contributed
                // to the row-height miscalculation when the row was
                // selected). List(.sidebar) is Apple's canonical
                // pattern = it owns the icon color.
                Image(systemName: book.displayIcon)
            }
            .tag(SidebarItem.book(book.id))        } else {
            // v0.30 boss 8/31 OOB (sidebar feedback bundle #3):
            // 'child folders should be visible immediately when book
            // is selected' = auto-expand the folder DisclosureGroup
            // when this book is the current sidebarSelection. User-
            // controlled collapse is preserved via bookDisclosureStates.
            let isBookSelectedNow = isBookSelected(book.id)
            let isAnyFolderInsideSelected = folders.contains { folder in
                appState.sidebarSelection == .folder(
                    bookId: book.id, folderName: folder.name
                )
            }
            // v0.30 boss 8/31 OOB 'clicking the Worldview level collapses it': the book
            // DisclosureGroup previously collapsed when the user
            // clicked a folder inside (= because the binding only
            // checked 'isBookSelected', which is false once the
            // selection moved from .book to .folder). Now we also
            // keep it expanded when ANY folder inside is selected,
            // so clicking Worldview / Characters / Chapter Outline / Novel Body / Novel
            // Drafts keeps the parent expanded (= same visual model
            // as Finder: a folder with a selected child stays open).
            DisclosureGroup(isExpanded: Binding(
                get: { isBookSelectedNow
                       || isAnyFolderInsideSelected
                       || bookDisclosureStates[book.id, default: false] },
                set: { bookDisclosureStates[book.id] = $0 }
            )) {
                // v0.30 boss 8/31 OOB (sidebar feedback bundle #3):
                // folder count badge (= number of .md files in this
                // folder). User reported 'subdirectory does not show count' =
                // count badges were missing because folder rows
                // didn't have .badge() modifier.
                ForEach(folders, id: \.name) { folder in
                    // v0.30 boss 8/31 OOB: folder rows must NOT collapse
                    // the parent DisclosureGroup on click. Wrapping in
                    // a plain Button with sidebarSelection update on
                    // tap gives the row its own tap target (= the
                    // click is consumed by the button and does NOT
                    // propagate up to the DisclosureGroup label,
                    // which would otherwise collapse the parent's
                    // expansion state). The Button's tap also sets
                    // appState.sidebarSelection = .folder(...) (= the same
                    // path used by the .tag modifier, but the Button
                    // form is more reliable for nested rows inside
                    // a DisclosureGroup).
                    //
                    // v1.0.0-m1-shell boss 2026-09-10 OOB 'tree-view style
                    // doesn't follow Apple API': the previous code BOTH wrapped
                    // the row in a `Button { appState.sidebarSelection
                    // = .folder(...) }` AND attached a `.tag(
                    // SidebarItem.folder(...))` to the label. Apple
                    // HIG specifies ONE selection-routing path per
                    // row (= either a Button that owns the selection
                    // OR a List(selection:) tag that the List owns,
                    // = NOT both). Two concurrent writers = a race
                    // condition where the user's click sometimes
                    // sets the selection via the Button's closure
                    // BEFORE List(selection:) re-renders the tag,
                    // and sometimes the List's tag routing wins
                    // (= flaky selection behavior on folder rows).
                    // Remove the Button wrapper and rely on List(
                    // selection:) + .tag only (= the Apple HIG
                    // canonical path for row selection in a sidebar
                    // List).
                    //
                    // v1.0.0-m1-shell: also removed the manual
                    // `.padding(.horizontal, DesignTokens.chrome
                    // PaddingSmall).padding(.vertical, DesignTokens.
                    // chromePaddingMicro)` (= hand-tuned sidebar row
                    // padding). Apple HIG sidebar row padding is
                    // auto-applied by List(.sidebar) (= the manual
                    // padding pushed the row visual outside the
                    // system's sidebar hit area = hover tint and
                    // selection highlight could miss the row's
                    // bottom / top edges).
                    Label {
                        Text(folder.displayName)
                    } icon: {
                        // v1.0.0-m1-shell boss 2026-09-16 OOB '目录树叠图的 BUG 又出现了':
                        // removed .foregroundStyle(.primary) on the
                        // icon (= Apple HIG List(.sidebar) auto-tints the
                        // icon for selected/hover/disabled states; =
                        // the manual .foregroundStyle froze the icon
                        // tint and contributed to the row-height
                        // miscalculation when the row was selected).
                        // List(.sidebar) is Apple's canonical pattern
                        // = it owns the icon color.
                        Image(systemName: folder.icon)
                    }
                    .badge(bookStore.folderDocumentCount(
                        bookId: book.id,
                        folderDirectoryName: folder.name
                    ))
                    .tag(SidebarItem.folder(bookId: book.id, folderName: folder.name))
                }
            } label: {
                // v1.0.0-m1-shell boss 2026-09-16 OOB '目录树叠图的 BUG 又出现了':
                // the previous .badge(folders.reduce(...)) on the
                // book DisclosureGroup label (= the "测试书" row)
                // had the same row-height bug (= the count glyph
                // inflates the label's measured height; = the
                // selected row's highlight then overlaps the next
                // row). Migrated the count to the first folder row
                // inside ForEach (= each folder row keeps its own
                // .badge for individual .md file count; the book
                // total moves to a synthesized top-of-ForEach row
                // or is dropped entirely per Apple HIG).
                //
                // Also removed .foregroundStyle(.primary) on the
                // image: Apple HIG List(.sidebar) auto-tints the
                // icon (= selected/hover states color it; = adding
                // .foregroundStyle(.primary) froze the icon tint
                // and contributed to the row-height miscalculation
                // when the row was selected). List(.sidebar) is
                // Apple's canonical pattern = it owns the icon
                // color for selected/hover/disabled states.
                Label {
                    Text(book.title)
                } icon: {
                    Image(systemName: book.displayIcon)
                }
                .tag(SidebarItem.book(book.id))                // v1.0.0-m1-shell boss 2026-09-10 OOB 'tree-view style
                // doesn't follow Apple API': removed `.onTapGesture(count: 2)`
                // for the same reason as the shelf row (= Apple's
                // DisclosureGroup chevron is the single canonical
                // expand/collapse affordance; = adding custom
                // double-click handlers races with the system gesture).
                // v0.30 boss 8/31 OOB: right-click context menu on book
                // row. Apple HIG canonical pattern. The Help book in
                // the default 'Start Here' shelf still gets the
                // menu (= user can delete the help book if they
                // want; the Reference Library rule is for the reference
                // library Section, not for the default help book).
                .contextMenu {
                    Button(WenshuI18n.t("auto2.newlibraryoutlineview.l916.h31835725")) {
                        renaming = RenamingTarget(
                            kind: .book,
                            itemId: book.id,
                            originalName: book.title,
                            shelfId: book.shelfId
                        )
                    }
                    Divider()
                    Button(WenshuI18n.t("auto2.newlibraryoutlineview.l925.h28387294"), role: .destructive) {
                        pendingDelete = PendingDelete(
                            kind: .book,
                            itemId: book.id,
                            itemName: book.title
                        )
                    }
                }
            }
        }
    }

    /// v0.30: 5 user-facing standard folder names + icons (= per spec
    /// v5 ticket 001 + ticket 026). 3 hidden folders (LLM sessions, Foreshadowing,
    /// Placeholder) NOT shown per boss 8/30 sidebar cleanup.
    private var standardFolderNames: [(name: String, displayName: String, icon: String)] {
        // v1.0.0-m1-shell: Lucide -> SF Symbols 6 (boss OOB 2026-09-15). Migrated 2026-09-16.
        [
            ("world",      "世界观",      "globe"),
            ("characters", "角色",        "person"),
            ("outlines",   "章节大纲",    "list.bullet.rectangle"),
            ("chapters",   "小说正文",    "text.book.closed"),
            ("drafts",     "小说草稿",    "pencil"),
        ]
    }

    // MARK: - Data helpers

    /// v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2+3): returns
    /// whether the given book id is the currently selected sidebar
    /// item (= used by DisclosureGroup auto-expand logic).
    private func isBookSelected(_ id: UUID) -> Bool {
        if case .book(let selectedId) = appState.sidebarSelection {
            return selectedId == id
        }
        return false
    }

    /// v0.34 boss 2026-09-02 OOB: reference-library section DisclosureGroup
    /// expansion state mirror logic. Mirrors `isBookSelected` for the reference
    /// library (= the DisclosureGroup's get-side check that overrides
    /// the persisted state when a category is currently selected, so
    /// the section stays open while the user reads).
    private func isReferenceCategorySelected() -> Bool {
        if case .referenceCategory = appState.sidebarSelection {
            return true
        }
        return false
    }

    /// v0.30: Apple std list of categories with ≥1 entity, sorted A→Z.
    /// (= Same logic as v0.29 computeUsedCategories; renamed to match
    /// Apple HIG sidebar convention of "sidebar only shows used items".)
    
    /// v0.71 P1 batch 7 dual-axis followup (= Q99 Standards axis LOW):
    /// wraps the silent `try?` on loadAllReferences with explicit
    /// error logging (= audit concern: user cannot distinguish "no
    /// entities" from "permission denied" on disk errors). The
    /// graceful-degradation behavior (= empty array returned on
    /// error) is preserved; = the NSLog is dev-only diagnostics.
    private func safeLoadAllReferences() -> [Reference] {
        do {
            return try bookStore.referenceStore.loadAllReferences()
        } catch {
            NSLog("[wenshu.sidebar] loadAllReferences failed: %@", String(describing: error))
            return []
        }
    }

    private func usedCategories() -> [EntityCategory] {
        let allRefs = safeLoadAllReferences()
        let entityRefs = allRefs.filter { $0.layer == .layerEntities }
        let used = Set(entityRefs.compactMap { $0.category })
        return EntityCategory.allCases.filter { used.contains($0) }
    }

    /// v0.30: count of entities in this category.
    private func entitiesCount(in category: EntityCategory) -> Int {
        let allRefs = safeLoadAllReferences()
        return allRefs.filter { $0.layer == .layerEntities && $0.category == category }.count
    }

    private func booksInShelf(_ shelf: Bookshelf) -> [Book] {
        books.filter { $0.shelfId == shelf.id }
    }

    // MARK: - Zone header buttons (= New + Import)
    //
    // Per boss 8/27 'reuse the existing v0.25.x toolbar "+" button': the toolbar
    // '+' button (= main app toolbar, not sidebar header) drives the
    // "New Book / New Shelf" menu. This trailingButton is rendered via
    // ZoneContentView's trailingButton parameter (= app.swift:2155)
    // and shows icon buttons in the projectSidebar zone header.

    /// 2 icon buttons rendered in the projectSidebar zone header
    /// trailing area. Per boss 8/27 OOB #3 (= commit bca226704): New Menu +
    /// Import plain Button. Both use the editor-expand + chat-archive
    /// icon-button pattern (= 28x28 hot area + Lucide icon overlay +
    /// .secondary foreground + .contentShape Rectangle).
    ///
    /// v0.30 boss 8/30 OOB 'restore those two buttons, plus the icon' = restore the
    /// original v0.27-style buttons and icons:
    /// - New icon = "square-plus" (Lucide canonical, NOT SF "plus")
    /// - Import icon = "arrow.right.square" (Lucide canonical)
    ///
    /// v0.30 dev drift (= what NOT to do): I had used SF Symbol "plus"
    /// for the New icon (= losing the Lucide canonical name + visual
    /// consistency with the rest of the sidebar tree icons). Boss caught
    /// it. Restored to Lucide canonical per bca226704.
    @ViewBuilder
    var zoneHeaderButtons: some View {
        // v0.30 boss 8/31 OOB:
        // Menu style .borderlessButton + menuIndicator(.hidden) failed
        // to render the new-icon inside the ZoneContentTabBar trailing
        // slot (= only the import Button rendered). Replaced with a
        // simple Button pattern that mirrors the import Button =
        // notification + sheet pattern (no nested Menu).
        //
        // v0.30 boss 8/31 OOB #2 (after sheet test):
        // The first fix attempted to attach .sheet directly on the
        // trailing zoneHeaderButtons HStack. But the trailing slot
        // uses a separate NewLibraryOutlineView() instance wrapped
        // in AnyView (= WorkspaceView line ~255), so .sheet on that
        // standalone instance had no place to attach (= SwiftUI
        // AnyView discards view identity; sheets need a real parent
        // in the view hierarchy). The new-icon button was visible
        // (= button is a simple view) but tapping it set
        // showNewChoiceSheet on the standalone instance which never
        // re-rendered the trailing slot. Switched to NotificationCenter
        // pattern (= mirrors the Import button's .wenshuImportRequested):
        // - Button tap posts .wenshuChoiceRequested notification.
        // - The sidebar body NewLibraryOutlineView listens via
        //   .onReceive and toggles its OWN showNewChoiceSheet state.
        //   Sheets on the sidebar body ARE in the real view hierarchy.
        //
        // v0.30 boss 8/31 OOB 'the ICON buttons in the red box also implement hover effect, same as
        // TAB': added @State isHover + .onHover + .background
        // tint to both buttons (= matches PaneIconTab's hover tint
        // pattern = Color.accentColor.opacity(0.12) on hover).
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'tree-view style doesn't follow
        // Apple API': switch the poster from NotificationCenter.post
        // (= fire-and-forget, = fragile data flow, = no observed
        // binding on receiver) to the @Observable AppState counter
        // (= the sidebar body's `.onChange(of: appState.
        // choiceRequestCount)` is the canonical SwiftUI binding).
        HStack(spacing: 0) {
            // New plain Button (= tap increments
            // appState.choiceRequestCount; consumed by the sidebar
            // body listener which presents NewChoiceSheet).
            NewButtonWithHover(
                iconName: "square-plus",
                help: "New"
            ) {
                appState.choiceRequestCount += 1
            }
            // Import plain Button (= tap directly fires .wenshuImportRequested
            // notification; consumed by the main app toolbar listener =
            // opens the macOS NSOpenPanel for importing external research
            // materials into the library).
            NewButtonWithHover(
                iconName: "arrow.right.square",
                help: "Import"
            ) {
                NotificationCenter.default.post(name: .wenshuImportRequested, object: nil)
            }
        }
    }

    // MARK: - Persistence

    private func reload() {
        do {
            // Read shelves + books from the filesystem (= spec v5 layout).
            // The inline FileManager + JSON adapter moved to
            // `BookStore.sidebarLoadShelves()` / `sidebarLoadAllBooks()`
            // in v0.32 (= no longer duplicated in this view).
            shelves = try bookStore.sidebarLoadShelves()
            books = try bookStore.sidebarLoadAllBooks()
            references = try bookStore.referenceStore.loadAllReferences()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// v0.30 boss 8/31 OOB: count children (= books in shelf, or
    /// .md files in book) that will be deleted along with the
    /// target. Used by the .alert message so the user knows the
    /// full blast radius before confirming.
    private func pendingDeleteChildCount(target: PendingDelete) -> Int {
        switch target.kind {
        case .shelf:
            // Books in this shelf
            return books.filter { $0.shelfId == target.itemId }.count
        case .book:
            // .md files across all 5 standard folders
            return standardFolderNames.reduce(0) { sum, folder in
                sum + bookStore.folderDocumentCount(
                    bookId: target.itemId,
                    folderDirectoryName: folder.name
                )
            }
        }
    }

    /// v0.30 boss 8/31 OOB: build the .contextMenu items for a set
    /// of selected SidebarItem rows. Used by the List-level
    /// .contextMenu(forSelectionType:) modifier. Different from
    /// the per-row .contextMenu (which we also keep as a fallback
    /// for some rows) — this is the Apple HIG canonical path.
    ///
    /// The menu contents depend on what's selected:
    /// - Shelf selected: New Book (= pre-selects this shelf so the
    ///   new book lands here), Rename, Delete
    /// - Book selected: Rename, Delete
    ///
    ///   'Reference Library is not allowed to be deleted' applies to the whole reference section)
    /// - Multi-select: only delete (= batch delete shelves / books)
    @ViewBuilder
    private func contextMenuForSelection(_ items: Set<SidebarItem>) -> some View {
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'right-click on empty area → New Bookshelf/Book
        // didn't take effect'. macOS 26 Tahoe's `.contextMenu(forSelectionType:)`
        // does NOT invoke this closure when the right-click hits
        // an empty area of the List (= the closure is selection-
        // typed; = empty selection = no builder invocation = the
        // menu does not appear). This is an Apple-platform
        // limitation. The empty-area right-click goes through a
        // separate `.contextMenu { ... }` attached directly on the
        // List (= macOS 14+ behavior; = bare .contextMenu shows
        // anywhere inside the List, including empty area; =
        // .contextMenu(forSelectionType:) shows on selected-row
        // hits). The two menus do not conflict (= macOS dispatches
        // by hit-target).
        if items.isEmpty {
            // macOS 26 does not route empty-area hits through this
            // closure. The empty-area actions are attached via a
            // plain `.contextMenu { ... }` on the List itself
            // (= see the bare .contextMenu modifier further below).
            EmptyView()
        } else if items.count > 1 {
            // Multi-select = batch delete. Single select = per-item
            // actions.
            Button(WenshuI18n.t("auto2.newlibraryoutlineview.l1125.h95494717"), role: .destructive) {
                for item in items {
                    handleContextMenuDelete(item)
                }
            }
        } else if let first = items.first {
            switch first {
            case .shelf(let id):
                Button(WenshuI18n.t("auto2.newlibraryoutlineview.l1133.h1694446")) {
                    appState.sidebarSelection = .shelf(id)
                    showNewBookSheet = true
                }
                Divider()
                if let shelf = shelves.first(where: { $0.id == id }) {
                    Button(WenshuI18n.t("auto2.newlibraryoutlineview.l1139.h31835725")) {
                        renaming = RenamingTarget(
                            kind: .shelf,
                            itemId: id,
                            originalName: shelf.name,
                            shelfId: nil
                        )
                    }
                }
                Divider()
                Button(WenshuI18n.t("auto2.newlibraryoutlineview.l1149.h28387294"), role: .destructive) {
                    if let shelf = shelves.first(where: { $0.id == id }) {
                        pendingDelete = PendingDelete(
                            kind: .shelf,
                            itemId: id,
                            itemName: shelf.name
                        )
                    }
                }
            case .book(let id):
                if let book = books.first(where: { $0.id == id }) {
                    Button(WenshuI18n.t("auto2.newlibraryoutlineview.l1160.h31835725")) {
                        renaming = RenamingTarget(
                            kind: .book,
                            itemId: id,
                            originalName: book.title,
                            shelfId: book.shelfId
                        )
                    }
                }
                Divider()
                Button(WenshuI18n.t("auto2.newlibraryoutlineview.l1170.h28387294"), role: .destructive) {
                    if let book = books.first(where: { $0.id == id }) {
                        pendingDelete = PendingDelete(
                            kind: .book,
                            itemId: id,
                            itemName: book.title
                        )
                    }
                }
            case .folder:
                // Folder rows are not yet user-deletable (= the
                // 5 standard folders are regenerated by
                // LibraryBootstrapper). Future ticket can add per-
                // folder .md content management.
                EmptyView()
            case .referenceCategory, .referenceLibraryRoot:
                // No actions (= boss OOB 'Reference Library cannot be deleted' covers
                // the whole reference section, not just the root).
                EmptyView()
            }
        }
    }

    /// v0.30 boss 8/31 OOB: handle a context-menu delete request
    /// (= set up the pendingDelete state to trigger the
    /// confirmation .alert). Extracted from the menu builder
    /// so the multi-select batch path can reuse it.
    private func handleContextMenuDelete(_ item: SidebarItem) {
        switch item {
        case .shelf(let id):
            if let shelf = shelves.first(where: { $0.id == id }) {
                pendingDelete = PendingDelete(
                    kind: .shelf,
                    itemId: id,
                    itemName: shelf.name
                )
            }
        case .book(let id):
            if let book = books.first(where: { $0.id == id }) {
                pendingDelete = PendingDelete(
                    kind: .book,
                    itemId: id,
                    itemName: book.title
                )
            }
        case .folder, .referenceCategory, .referenceLibraryRoot:
            // Read-only (= see contextMenuForSelection).
            break
        }
    }

    /// v0.30 boss 8/31 OOB: resolve the current target shelf id
    /// for the 'New Book' action. Logic (= first non-nil match):
    /// 1. If sidebarSelection is .book → use that book's shelf
    /// 2. If sidebarSelection is .shelf → use that shelf directly
    /// 3. Fallback: default 'Start Here' shelf (id
    ///    00000000-0000-0000-0000-000000000000)
    /// Returns (id, displayName) so the NewBookSheet can show
    /// the shelf name in its picker.
    private func resolveNewBookTargetShelf() -> (id: UUID, name: String) {
        if case .book(let bookId) = appState.sidebarSelection,
           let book = books.first(where: { $0.id == bookId }),
           let shelf = shelves.first(where: { $0.id == book.shelfId }) {
            return (shelf.id, shelf.name)
        }
        if case .shelf(let shelfId) = appState.sidebarSelection,
           let shelf = shelves.first(where: { $0.id == shelfId }) {
            return (shelf.id, shelf.name)
        }
        // Fallback: default shelf.
        let defaultId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let defaultName = shelves.first(where: { $0.id == defaultId })?.name ?? "从这里开始"
        return (defaultId, defaultName)
    }

    // v0.30 boss 8/31 OOB: context-menu actions. Per macOS HIG
    // destructive operations require explicit confirmation (= an
    // .alert with a 'Confirm Delete' button). The pendingDelete state
    // is set by the context menu, which triggers the alert; the
    // user confirms to actually execute the delete.

    /// Delete a shelf (= entire shelf + all its books) from disk.
    /// Apple HIG: requires confirmation because it's destructive
    /// (= the user might not realize the shelf contains books).
    private func deleteShelf(id: UUID) throws {
        // Boss: 'Reference Library cannot be deleted'. Enforce here as a defense in
        // depth (= the reference library is a Section, not a Shelf,
        // so its id is never passed here; but the check is cheap).
        guard id.uuidString != "00000000-0000-0000-0000-000000000000" else {
            throw ShelfDeleteError.cannotDeleteDefault
        }
        let shelfDir = bookStore.stores.shelvesRoot
            .appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: shelfDir.path) {
            try FileManager.default.removeItem(at: shelfDir)
        }
    }

    /// Delete a single book (= its shelf/<id>/books/<book-id>/ dir
    /// + shelf.json metadata) from disk.
    private func deleteBook(id: UUID) throws {
        // Find which shelf contains the book (= we need its dir
        // to compute the full path). Mirrors the v0.30 refactor
        // that surfaced book lookup in WenshuLibrary.
        guard let parentShelf = shelves.first(where: { shelf in
            // Books live in <shelves>/<shelf-uuid>/books/<book-uuid>/
            let booksDir = bookStore.stores.shelvesRoot
                .appendingPathComponent(shelf.directoryName, isDirectory: true)
                .appendingPathComponent("books", isDirectory: true)
            return FileManager.default.fileExists(atPath:
                booksDir.appendingPathComponent(id.uuidString).path
            )
        }) else { return }  // book not on disk = nothing to delete
        let bookDir = bookStore.stores.shelvesRoot
            .appendingPathComponent(parentShelf.directoryName, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: bookDir.path) {
            try FileManager.default.removeItem(at: bookDir)
        }
    }

    /// Rename a shelf (= rewrites shelf.json with the new name).
    /// The directory name (= UUID) is NOT changed (= identity =
    /// stable per Apple HIG document-based app).
    private func renameShelf(id: UUID, newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reserved name check (= same as saveShelf).
        let reserved: Set<String> = ["资料库", "参考库", "reference library"]
        if reserved.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            throw ShelfError.reservedName(trimmed)
        }
        // Duplicate check (= exclude the current shelf from
        // existingNames, since renaming to the same name is allowed).
        let others = shelves
            .filter { $0.id != id }
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        if others.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw ShelfError.duplicateName(trimmed)
        }
        let shelfDir = bookStore.stores.shelvesRoot
            .appendingPathComponent(id.uuidString, isDirectory: true)
        let shelfJSONURL = shelfDir.appendingPathComponent("shelf.json")
        guard FileManager.default.fileExists(atPath: shelfJSONURL.path),
              let data = try? Data(contentsOf: shelfJSONURL),
              var existing = try? JSONDecoder().decode(Bookshelf.self, from: data)
        else { return }
        existing.name = trimmed
        existing.updatedAt = Date()
        let updated = try JSONEncoder().encode(existing)
        try updated.write(to: shelfJSONURL)
    }

    /// Rename a book (= rewrites book.json with the new title).
    private func renameBook(id: UUID, newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        // Duplicate title check (= exclude current book).
        let otherTitles = books
            .filter { $0.id != id }
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
        if otherTitles.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw ShelfError.duplicateName(trimmed)
        }
        // Find the book dir (= same as deleteBook).
        guard let parentShelf = shelves.first(where: { shelf in
            let booksDir = bookStore.stores.shelvesRoot
                .appendingPathComponent(shelf.directoryName, isDirectory: true)
                .appendingPathComponent("books", isDirectory: true)
            return FileManager.default.fileExists(atPath:
                booksDir.appendingPathComponent(id.uuidString).path
            )
        }) else { return }
        let bookJSONURL = bookStore.stores.shelvesRoot
            .appendingPathComponent(parentShelf.directoryName, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
            .appendingPathComponent("book.json")
        guard FileManager.default.fileExists(atPath: bookJSONURL.path),
              let data = try? Data(contentsOf: bookJSONURL),
              var existing = try? JSONDecoder().decode(Book.self, from: data)
        else { return }
        existing.title = trimmed
        existing.updatedAt = Date()
        let updated = try JSONEncoder().encode(existing)
        try updated.write(to: bookJSONURL)
    }

    // MARK: - v0.30 boss 8/31 OOB: DisclosureGroup state persistence
    //
    // MARK: - SidebarState (unified persistence, v0.34)
    //
    // Boss 2026-09-02 OOB: 'sidebar + preview should share one unified persistence interface'.
    // Single Codable struct = single source of truth for ALL sidebar
    // persistence (= shelf expansion + book expansion + reference
    // library expansion + top-level selection). Replaces the
    // previous 4 scattered @AppStorage strings.
    //
    // Single AppStorage key 'wenshu.sidebarState' holds the JSON
    // encoding of this struct. Read once on appear, write on any
    // field change. Adding a new persisted sidebar field = one new
    // property here + one hook in applyFrom(_:) + one writer in
    // snapshot(); no new AppStorage key needed.
    private struct SidebarState: Codable, Equatable {
        var shelfExpanded: [UUID: Bool]
        var bookExpanded: [UUID: Bool]
        var referenceLibraryExpanded: Bool
        var selection: SidebarItem?

        init(
            shelfExpanded: [UUID: Bool] = [:],
            bookExpanded: [UUID: Bool] = [:],
            referenceLibraryExpanded: Bool = false,
            selection: SidebarItem? = nil
        ) {
            self.shelfExpanded = shelfExpanded
            self.bookExpanded = bookExpanded
            self.referenceLibraryExpanded = referenceLibraryExpanded
            self.selection = selection
        }

        /// Encode to JSON string for AppStorage.
        /// Empty string = no persisted state (= first-launch / wiped).
        var jsonString: String {
            guard let data = try? JSONEncoder().encode(self),
                  let s = String(data: data, encoding: .utf8) else {
                return ""
            }
            return s
        }

        /// Decode from JSON string (= empty = default empty state).
        static func from(jsonString: String) -> SidebarState {
            guard !jsonString.isEmpty,
                  let data = jsonString.data(using: .utf8),
                  let state = try? JSONDecoder().decode(SidebarState.self, from: data)
            else {
                return SidebarState()
            }
            return state
        }
    }

    /// Snapshot the current UI state into a SidebarState (= for
    /// write-back on any field change). Single function = single
    /// place that knows the mapping from local @State to persisted
    /// shape.
    private func snapshotSidebarState() -> SidebarState {
        SidebarState(
            shelfExpanded: shelfDisclosureStates,
            bookExpanded: bookDisclosureStates,
            referenceLibraryExpanded: referenceLibraryDisclosureExpanded,
            selection: appState.sidebarSelection
        )
    }

    /// Apply a SidebarState to the local @State + appState. Single
    /// function = single place that knows the inverse mapping. Called
    /// once in .onAppear (= cold-launch restore).
    private func applySidebarState(_ state: SidebarState) {
        shelfDisclosureStates = state.shelfExpanded
        bookDisclosureStates = state.bookExpanded
        referenceLibraryDisclosureExpanded = state.referenceLibraryExpanded
        // Selection restore is guarded: only override if the caller
        // (= WiredShell / onAppear) hasn't set a default yet.
        if let saved = state.selection, appState.sidebarSelection == nil {
            appState.sidebarSelection = saved
        }
    }

    // Encode/decode [UUID: Bool] for AppStorage (= AppStorage
    // requires String, so we round-trip via JSONEncoder/JSONDecoder).
    // Empty string = no entries (= first-launch state). Empty dict
    // (= '{}') decodes to an empty dict (= no expansion state).
    // Retained as private helpers because SidebarState.jsonString is
    // the canonical path now; these are kept only for callers that
    // imported the old keys (= legacy migration is no-op since the
    // new key is single).
    private func encodeDisclosureStates(_ states: [UUID: Bool]) -> String {
        // Convert UUID keys to strings (= JSON requires string keys)
        let stringDict = Dictionary(
            uniqueKeysWithValues: states.map { ($0.key.uuidString, $0.value) }
        )
        guard let data = try? JSONEncoder().encode(stringDict),
              let s = String(data: data, encoding: .utf8) else {
            return ""
        }
        return s
    }

    private func decodeDisclosureStates(_ json: String) -> [UUID: Bool] {
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Bool].self, from: data)
        else {
            return [:]
        }
        var result: [UUID: Bool] = [:]
        for (key, value) in dict {
            if let uuid = UUID(uuidString: key) {
                result[uuid] = value
            }
        }
        return result
    }

    /// v0.76 boss 2026-09-10 OOB 'we have a middle modal — tapping New
    /// prompts the user to choose between a new book or a new bookshelf; the button just says New, then opens that modal':
    /// sidebar bottom accessory button (= single 'New' button,
    /// posts .wenshuChoiceRequested = the existing global
    /// notification bound at line 546 that flips
    /// `showNewChoiceSheet` and presents NewChoiceSheet =
    /// the modal sheet with 'New Book / New Bookshelf' choice).
    ///
    /// Style: per Apple HIG = a sidebar bottom accessory is a
    /// full-width row at the column's bottom safe area. The button
    /// itself uses Apple's `.borderless` button style with a
    /// plus icon (= SF Symbols 6 'plus' = same icon the column's
    /// internal 'New Book' / 'New Shelf' rows use; = the
    /// canonical Finder / Notes 'sidebar action button' visual).
    ///
    /// Padding: 8 PT horizontal (= matches the sidebar's row
    /// internal padding), 8 PT vertical (= the safeAreaInset's
    /// own separator hairline above the button = the Apple HIG
    /// 'accessory separator' = Mail / Notes / Finder pattern).
    private var sidebarBottomNewButton: some View {
        // Divider above the button = the Apple HIG 'accessory
        // separator' (= a 1 PT hairline tinted with .separator,
        // same primitive as the between-section Divider added
        // earlier in this view).
        VStack(spacing: 0) {
            Divider()
            Button {
                // v1.0.0-m1-shell boss 2026-09-10 OOB 'tree-view style
                // doesn't follow Apple API': switch from NotificationCenter
                // .post to the @Observable AppState counter (= the
                // Apple HIG cross-component binding = `.onChange(of:
                // appState.choiceRequestCount)` on the sidebar body).
                appState.choiceRequestCount += 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(WenshuI18n.t("sidebar.new_button.label"))
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(WenshuI18n.t("sidebar.new_button.help"))
        }
    }
}

/// v0.30 boss 8/31 OOB: dedicated error case for attempting to
/// delete the default shelf (= "Reference Library is not allowed to be deleted"). Defense in
/// depth = even if the context menu is bypassed, saveShelf /
/// deleteShelf will refuse the operation.
private enum ShelfDeleteError: LocalizedError {
    case cannotDeleteDefault

    var errorDescription: String? {
        switch self {
        case .cannotDeleteDefault:
            return "默认书架 (= 资料库) 不能删除"
        }
    }
}

/// v0.30 boss 8/31 OOB: explicit error cases for shelf creation
/// (= duplicate name, reserved name). Each case carries the offending
/// name so the sheet can surface a precise error message.
private enum ShelfError: LocalizedError {
    case duplicateName(String)
    case reservedName(String)

    var errorDescription: String? {
        switch self {
        case .duplicateName(let name):
            return "书架名 \"\(name)\" 已被使用. 请换一个名字。"
        case .reservedName(let name):
            return "\"\(name)\" 是系统保留名, 不能用作书架名. 请换一个名字."
        }
    }
}

// MARK: - Sheets (= New Book / New Shelf modals)

private struct NewBookSheet: View {
    let onSave: (Book) -> Void
    /// v0.30 boss 8/31 OOB: target shelf id (= where the new book
    /// will be created). Pre-fills with the currently selected
    /// shelf (= from sidebarSelection). If nothing is selected,
    /// falls back to the default shelf id.
    let targetShelfId: UUID
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var shelfId: UUID  // editable (= user can pick a different shelf)
    @State private var selectedIcon: String = "book"  // v0.30 boss 8/31 OOB: user-picks icon
    @Environment(\.dismiss) private var dismiss

    /// v0.30 boss 8/31 OOB: display name of the target shelf (=
    /// shown in the picker as default selection). Lets the user
    /// see "this book will go into Help" before saving.
    let targetShelfName: String
    /// v0.30 boss 8/31 OOB: all available shelves with their display
    /// names (= the picker shows shelf names, not UUIDs).
    let availableShelves: [(id: UUID, name: String)]

    init(
        onSave: @escaping (Book) -> Void,
        targetShelfId: UUID,
        targetShelfName: String,
        availableShelves: [(id: UUID, name: String)]
    ) {
        self.onSave = onSave
        self.targetShelfId = targetShelfId
        self.targetShelfName = targetShelfName
        self.availableShelves = availableShelves
        _shelfId = State(initialValue: targetShelfId)
    }

    /// v0.30 boss 8/31 OOB: full SF Symbols 6 icon library (=
    /// curated list of common SF Symbols 6 names; = boss 2026-09-15
    /// OOB 'use SF Symbols 6 (3rd gen) with palette rendering'
    /// replaces the Lucide era's LucideIconName.allCases).
    /// No guessing about which icon names exist; the user scrolls
    /// through every real SF Symbol 6 icon and picks one.
    private var allSFSymbols: [String] {
        // Common SF Symbols 6 names (= popular UI glyphs; = curated
        // subset of the ~7000 SF Symbols 6 catalog covering all 16
        // categories: arrows / media / communication / people / nature / etc.).
        // Full catalog lives in /Applications/SF Symbols Beta.app/Contents/Executables/sfsymbols.
            [
            "plus", "minus", "xmark", "checkmark",
            "chevron.left", "chevron.right", "chevron.up", "chevron.down",
            "chevron.left.circle", "chevron.right.circle", "arrow.left", "arrow.right",
            "arrow.up", "arrow.down", "arrow.uturn.backward", "arrow.uturn.forward",
            "arrow.clockwise", "arrow.counterclockwise", "arrow.up.left.and.arrow.down.right", "arrow.down.right.and.arrow.up.left",
            "arrow.right.square", "arrow.up.right.square", "arrow.down.left.square", "arrow.down.circle",
            "arrow.up.circle", "arrow.left.circle", "magnifyingglass", "magnifyingglass.circle",
            "trash", "folder", "folder.badge.plus", "document",
            "document.badge.plus", "book", "book.closed", "book.pages",
            "books.vertical", "book.badge.plus", "person", "person.2",
            "person.3", "person.crop.circle", "person.text.rectangle", "brain",
            "brain.head.profile", "calendar", "calendar.day.timeline.left", "ellipsis",
            "ellipsis.circle", "gear", "gearshape", "gearshape.2",
            "link", "link.circle", "play", "pause",
            "stop", "wand.and.rays", "wand.and.sparkles", "house",
            "building", "building.2", "lightbulb", "paintpalette",
            "function", "atom", "leaf", "globe",
            "globe.americas", "bell", "bell.badge", "tag",
            "tag.circle", "star", "heart", "flag",
            "flag.pattern.checkered", "key", "lock", "lock.open",
            "shield", "bolt", "sun.max", "moon",
            "cloud", "cloud.rain", "flame", "drop",
            "pencil", "pencil.tip", "highlighter", "eraser",
            "scissors", "paperclip", "envelope", "envelope.open",
            "phone", "phone.connection", "message", "message.circle",
            "bubble.left", "bubble.right", "video", "video.slash",
            "camera", "camera.circle", "photo", "photo.stack",
            "music.note", "speaker.wave.2", "microphone", "tv",
            "display", "desktopcomputer", "laptopcomputer", "iphone",
            "ipad", "applewatch", "square", "square.dashed",
            "circle", "circle.dotted", "circle.dashed", "plus.circle",
            "minus.circle", "xmark.circle", "checkmark.circle", "questionmark.circle",
            "exclamationmark.triangle", "exclamationmark.circle", "info.circle", "questionmark",
            "exclamationmark", "sparkles", "sparkle", "wand.and.sparkles",
            "scalemass", "ruler", "graduationcap", "bookmark",
            "list.bullet", "list.number", "tablecells", "rectangle.grid.1x2",
            "rectangle.grid.2x2", "rectangle.grid.3x2", "square.grid.2x2", "square.grid.3x2",
            "sidebar.left", "sidebar.right", "eye", "eye.slash",
            "hand.raised", "hand.thumbsup", "hand.thumbsdown", "bolt.horizontal",
            "bolt.horizontal.circle", "airplane", "car", "tram",
            "ferry", "sailboat", "bicycle", "scooter",
            "bus", "creditcard", "dollarsign.circle", "eurosign.circle",
            "yensign.circle", "wrench.and.screwdriver", "hammer", "screwdriver",
            "wrench.adjustable", "truck.box", "airplane.circle", "airplane.arrival",
            "airplane.departure", "globe.central.south.asia", "globe.europe.africa", "globe.asia.australia",
        ].sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(WenshuI18n.t("auto2.newlibraryoutlineview.l1555.h13591586"), text: $title)
                    .textFieldStyle(.roundedBorder)
                TextField(WenshuI18n.t("auto2.newlibraryoutlineview.l1557.h62884489"), text: $author)
                    .textFieldStyle(.roundedBorder)
                // v0.30 boss 8/31 OOB: shelf picker (= user can
                // choose which shelf this book goes into). Default
                // = the currently-selected shelf (= so clicking
                // New Book inside 'Test Shelf' creates the book there).
                // Picker shows shelf names (= not raw UUIDs).
                Picker("归属书架", selection: $shelfId) {
                    ForEach(availableShelves, id: \.id) { shelf in
                        Text(shelf.name).tag(shelf.id)
                    }
                }
                // v0.30 boss 8/31 OOB: icon picker (mirrors
                // NewShelfSheet). Default = "book" (= matches
                // existing book row icon). User can scroll through
                // the full SF Symbols 6 catalog (~7000 names
                // curated down to ~150 popular UI glyphs here) and
                // pick any.
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.tint.opacity(0.15))
                                .frame(width: DesignTokens.surfaceSizeMedium, height: DesignTokens.surfaceSizeMedium)
                            Image(systemName: selectedIcon).font(.system(size: 32, weight: .regular))
                                .foregroundStyle(Color.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WenshuI18n.t("auto.newlibraryoutlineview.l1583.h18380292"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(selectedIcon)
                                .font(.system(.caption, design: .monospaced))
                        }
                        Spacer()
                    }
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                            spacing: 8
                        ) {
                            ForEach(allSFSymbols, id: \.self) { iconName in
                                Button {
                                    selectedIcon = iconName
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedIcon == iconName
                                                  ? AnyShapeStyle(.tint.opacity(0.25))
                                                  : AnyShapeStyle(Color.clear))
                                            .frame(width: DesignTokens.toolbarButtonCompact, height: DesignTokens.toolbarButtonCompact)
                                        Image(systemName: iconName).font(.system(size: 24, weight: .regular))
                                            .foregroundStyle(selectedIcon == iconName
                                                             ? Color.accentColor
                                                             : Color.primary)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedIcon == iconName
                                                    ? AnyShapeStyle(Color.accentColor)
                                                    : AnyShapeStyle(.separator),
                                                    lineWidth: 1)
                                    )
                                    .buttonStyle(.plain)
                                }
                                .help(iconName)
                            }
                        }
                        .padding(.horizontal, DesignTokens.chromePaddingMicro)
                        .padding(.vertical, DesignTokens.chromePaddingVertical)
                    }
                    .frame(height: DesignTokens.popoverMaxHeight)
                } header: {
                    Text(WenshuI18n.t("library.new_book.icon_required"))
                }
            }
            .formStyle(.grouped)
            // v0.40 apple-001 HIG absent batch: .navigationTitle +
            // .toolbar (= Apple HIG standard for sheet chrome). The
            // inline HStack { Text + Divider } header + footer buttons
            // were removed; the title moves to .navigationTitle and
            // Cancel/Save move to .toolbar.
            .navigationTitle(WenshuI18n.t("library.new_book.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(WenshuI18n.t("auto2.newlibraryoutlineview.l1640.h92868892")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(WenshuI18n.t("auto2.newlibraryoutlineview.l1643.h37960739")) {
                        let book = Book(
                            title: title,
                            author: author,
                            icon: selectedIcon,
                            shelfId: shelfId
                        )
                        onSave(book)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 720, idealHeight: 800)
    }
}

// v0.30 boss 8/31 OOB: NewShelfSheet lets the user pick an
// SF Symbols 6 icon for the new shelf. Default = 'books.vertical'
// (= same icon as the reference library section, so a new
// shelf visually reads as 'another library bucket'). User can
// pick any SF Symbol 6 name from a curated preset list (= see
// shelfIconPresets below). The icon is required (= the picker
// always shows a selection; the Save button is enabled as
// soon as the user picks).
private struct NewShelfSheet: View {
    /// Callback receives both name AND selected icon.
    let onSave: (String, String) -> Void
    /// v0.30 boss 8/31 OOB: existing shelf names (= passed in from
    /// the parent so the sheet can run its own duplicate check on
    /// every keystroke, without round-tripping through the parent
    /// view). Trims whitespace + lowercases for case-insensitive
    /// comparison. Includes the reserved 'Reference Library' so it's blocked
    /// from being used as a user shelf name.
    let existingNames: [String]
    @State private var name: String = ""
    @State private var selectedIcon: String = "books.vertical"
    @Environment(\.dismiss) private var dismiss

    /// v1.0.0-m1-shell boss 2026-09-15 OOB 'remove Lucide, use
    /// SF Symbols 6 with palette rendering': local copy of the SF
    /// Symbol catalog (= mirrors NewLibraryOutlineView.allSFSymbols
    /// since nested structs can't access outer computed properties).
    /// Common SF Symbols 6 names covering all 16 categories.
    /// Full catalog lives in /Applications/SF Symbols Beta.app.
    private let allSFSymbols: [String] = [
            "plus", "minus", "xmark", "checkmark",
            "chevron.left", "chevron.right", "chevron.up", "chevron.down",
            "chevron.left.circle", "chevron.right.circle", "arrow.left", "arrow.right",
            "arrow.up", "arrow.down", "arrow.uturn.backward", "arrow.uturn.forward",
            "arrow.clockwise", "arrow.counterclockwise", "arrow.up.left.and.arrow.down.right", "arrow.down.right.and.arrow.up.left",
            "arrow.right.square", "arrow.up.right.square", "arrow.down.left.square", "arrow.down.circle",
            "arrow.up.circle", "arrow.left.circle", "magnifyingglass", "magnifyingglass.circle",
            "trash", "folder", "folder.badge.plus", "document",
            "document.badge.plus", "book", "book.closed", "book.pages",
            "books.vertical", "book.badge.plus", "person", "person.2",
            "person.3", "person.crop.circle", "person.text.rectangle", "brain",
            "brain.head.profile", "calendar", "calendar.day.timeline.left", "ellipsis",
            "ellipsis.circle", "gear", "gearshape", "gearshape.2",
            "link", "link.circle", "play", "pause",
            "stop", "wand.and.rays", "wand.and.sparkles", "house",
            "building", "building.2", "lightbulb", "paintpalette",
            "function", "atom", "leaf", "globe",
            "globe.americas", "bell", "bell.badge", "tag",
            "tag.circle", "star", "heart", "flag",
            "flag.pattern.checkered", "key", "lock", "lock.open",
            "shield", "bolt", "sun.max", "moon",
            "cloud", "cloud.rain", "flame", "drop",
            "pencil", "pencil.tip", "highlighter", "eraser",
            "scissors", "paperclip", "envelope", "envelope.open",
            "phone", "phone.connection", "message", "message.circle",
            "bubble.left", "bubble.right", "video", "video.slash",
            "camera", "camera.circle", "photo", "photo.stack",
            "music.note", "speaker.wave.2", "microphone", "tv",
            "display", "desktopcomputer", "laptopcomputer", "iphone",
            "ipad", "applewatch", "square", "square.dashed",
            "circle", "circle.dotted", "circle.dashed", "plus.circle",
            "minus.circle", "xmark.circle", "checkmark.circle", "questionmark.circle",
            "exclamationmark.triangle", "exclamationmark.circle", "info.circle", "questionmark",
            "exclamationmark", "sparkles", "sparkle", "wand.and.sparkles",
            "scalemass", "ruler", "graduationcap", "bookmark",
            "list.bullet", "list.number", "tablecells", "rectangle.grid.1x2",
            "rectangle.grid.2x2", "rectangle.grid.3x2", "square.grid.2x2", "square.grid.3x2",
            "sidebar.left", "sidebar.right", "eye", "eye.slash",
            "hand.raised", "hand.thumbsup", "hand.thumbsdown", "bolt.horizontal",
            "bolt.horizontal.circle", "airplane", "car", "tram",
            "ferry", "sailboat", "bicycle", "scooter",
            "bus", "creditcard", "dollarsign.circle", "eurosign.circle",
            "yensign.circle", "wrench.and.screwdriver", "hammer", "screwdriver",
            "wrench.adjustable", "truck.box", "airplane.circle", "airplane.arrival",
            "airplane.departure", "globe.central.south.asia", "globe.europe.africa", "globe.asia.australia"
        ]

    /// v0.30 boss 8/31 OOB: inline validation (= duplicate name +
    /// reserved name). Computed from the current `name` input on
    /// every render. Returns a localized error message; nil =
    /// no error (= Save enabled). Reserved names are hard-blocked;
    /// duplicates with existing shelves are blocked.
    private var nameError: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }  // empty = separate "name required" check via Save disabled
        // Reserved names
        let reserved: Set<String> = ["资料库", "参考库", "reference library"]
        if reserved.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            return "\"\(trimmed)\" 是系统保留名, 不能用作书架名"
        }
        // Duplicate (= case-insensitive, trim-insensitive)
        if existingNames.contains(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return "书架名 \"\(trimmed)\" 已被使用. 请换一个名字"
        }
        return nil
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && nameError == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(WenshuI18n.t("auto2.newlibraryoutlineview.l1730.h19340064"), text: $name)
                        .textFieldStyle(.roundedBorder)
                    // v0.30 boss 8/31 OOB: inline error label under the
                    // name field. Shows when the name is a duplicate
                    // or reserved (= computed live in nameError).
                    if let nameError = nameError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle").font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.red)
                            Text(nameError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(.top, DesignTokens.chromePaddingMicro)
                    }
                } header: {
                    Text(WenshuI18n.t("auto.newlibraryoutlineview.l1746.h58346771"))
                }
                Section {
                    // Icon preview (= shows the selected icon at
                    // large size so user can see what they're picking).
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.tint.opacity(0.15))
                                .frame(width: DesignTokens.surfaceSizeMedium, height: DesignTokens.surfaceSizeMedium)
                            Image(systemName: selectedIcon).font(.system(size: 32, weight: .regular))
                                .foregroundStyle(Color.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WenshuI18n.t("auto.newlibraryoutlineview.l1760.h18380292"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(selectedIcon)
                                .font(.system(.caption, design: .monospaced))
                        }
                        Spacer()
                    }
                    // Icon picker grid (= 8 columns x many rows). The full
                    // SF Symbols 6 catalog has ~7000 icons so we
                    // wrap the grid in a ScrollView (= user can
                    // scroll to find the icon they want). The
                    // grid is measured with a fixed height (= 320 PT =
                    // ~7 visible rows of 40 PT tiles + spacing) and
                    // scrolls inside.
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                            spacing: 8
                        ) {
                            ForEach(allSFSymbols, id: \.self) { iconName in
                                Button {
                                    selectedIcon = iconName
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedIcon == iconName
                                                  ? AnyShapeStyle(.tint.opacity(0.25))
                                                  : AnyShapeStyle(Color.clear))
                                            .frame(width: DesignTokens.toolbarButtonCompact, height: DesignTokens.toolbarButtonCompact)
                                        Image(systemName: iconName).font(.system(size: 24, weight: .regular))
                                            .foregroundStyle(selectedIcon == iconName
                                                             ? Color.accentColor
                                                             : Color.primary)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedIcon == iconName
                                                    ? AnyShapeStyle(Color.accentColor)
                                                    : AnyShapeStyle(.separator),
                                                    lineWidth: 1)
                                    )
                                    .buttonStyle(.plain)
                                }
                                .help(iconName)
                            }
                        }
                        .padding(.horizontal, DesignTokens.chromePaddingMicro)
                        .padding(.vertical, DesignTokens.chromePaddingVertical)
                    }
                    .frame(height: DesignTokens.popoverMaxHeight)
                } header: {
                    Text(WenshuI18n.t("library.new_shelf.icon_required"))
                }
            }
            .formStyle(.grouped)
            // v0.40 apple-001 HIG absent batch: .navigationTitle +
            // .toolbar (= Apple HIG standard for sheet chrome).
            .navigationTitle(WenshuI18n.t("library.new_shelf.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(WenshuI18n.t("auto2.newlibraryoutlineview.l1821.h92868892")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(WenshuI18n.t("auto2.newlibraryoutlineview.l1824.h37960739")) {
                        onSave(name, selectedIcon)
                        dismiss()
                    }
                    .disabled(!isNameValid)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 480, idealHeight: 560)
    }
}

// v0.30 boss 8/31 OOB: replaced the Menu-based
// "New Book" / "New Shelf" picker (= failed to render inside
// ZoneContentTabBar trailing slot) with a simple two-button sheet
// picker. Apple HIG canonical sheet presentation.
struct NewChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onNewBook: () -> Void
    let onNewShelf: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Button {
                        onNewBook()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "book.badge.plus").font(.system(size: 32, weight: .regular))
                            Text(WenshuI18n.t("auto.newlibraryoutlineview.l1855.h10335406")).font(.body)
                        }
                        .frame(width: DesignTokens.chipAvatarSize.width, height: DesignTokens.chipAvatarSize.height)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onNewShelf()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "books.vertical").font(.system(size: 32, weight: .regular))
                            Text(WenshuI18n.t("auto.newlibraryoutlineview.l1866.h64741338")).font(.body)
                        }
                        .frame(width: DesignTokens.chipAvatarSize.width, height: DesignTokens.chipAvatarSize.height)
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
            .padding(DesignTokens.chromePaddingHero)
            // v0.40 apple-001 HIG absent batch: .navigationTitle +
            // .toolbar (= Apple HIG standard for sheet chrome).
            .navigationTitle(WenshuI18n.t("library.new_choice.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(WenshuI18n.t("auto2.newlibraryoutlineview.l1880.h92868892")) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .frame(minWidth: 280, idealWidth: 320, minHeight: 180, idealHeight: 200)
    }
}

// MARK: - Context menu support (= right-click delete / rename)

// v0.30 boss 8/31 OOB: 'implement right-click delete and rename in the directory tree.
// Reference Library is not allowed to be deleted.' Apple HIG context menu pattern: right-click
// any row to get a context menu with destructive actions (= delete
// + rename). The reference library section is read-only
// (= no context menu, because the reference library is a
// built-in feature, not a user-managed shelf).

/// Identifies which kind of item the pending action targets.
private enum ItemKind: String, Identifiable {
    case shelf
    case book

    var id: String { rawValue }

    /// Apple HIG: confirm dialog wording varies by item type.
    var displayName: String {
        switch self {
        case .shelf: return "书架"
        case .book: return "书"
        }
    }
}

/// Holds the target of a pending delete confirmation (= shows an
/// .alert asking user to confirm). Cleared when alert dismisses.
private struct PendingDelete: Identifiable {
    let id = UUID()
    let kind: ItemKind
    let itemId: UUID
    let itemName: String
}

/// Holds the target of a pending rename (= shows RenameItemSheet).
/// Bookshelf/Book id + initial name (pre-fill in TextField).
private struct RenamingTarget: Identifiable {
    let id = UUID()
    let kind: ItemKind
    let itemId: UUID
    let originalName: String
    let shelfId: UUID?  // only for books
}

/// v0.30 boss 8/31 OOB: simple sheet for renaming a shelf or book.
/// Pre-fills the TextField with the current name; saves via the
/// supplied closure. Same duplicate-check logic as NewShelfSheet
/// (= passes existingNames to the validator).
private struct RenameItemSheet: View {
    let title: String  // = "rename" or "rename"
    let originalName: String
    let existingNames: [String]
    let onSave: (String) -> Void

    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        originalName: String,
        existingNames: [String],
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.originalName = originalName
        self.existingNames = existingNames
        self.onSave = onSave
        _name = State(initialValue: originalName)
    }

    /// v0.30 boss 8/31 OOB: same duplicate-check logic as
    /// NewShelfSheet. Excludes the original name (= renaming to the
    /// same name is allowed = no-op). Trims whitespace.
    private var nameError: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed == originalName { return nil }  // same name = OK
        if existingNames.contains(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return "名称 \"\(trimmed)\" 已被使用. 请换一个名字"
        }
        return nil
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && nameError == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                TextField(WenshuI18n.t("auto2.newlibraryoutlineview.l1988.h24669799"), text: $name)
                    .textFieldStyle(.roundedBorder)
                if let nameError = nameError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle").font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.red)
                        Text(nameError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(.top, DesignTokens.chromePaddingMicro)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button(WenshuI18n.t("auto2.newlibraryoutlineview.l2004.h92868892"), role: .cancel) { dismiss() }
                Spacer()
                Button(WenshuI18n.t("auto2.newlibraryoutlineview.l2006.h37960739")) {
                    onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .disabled(!isNameValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 160, idealHeight: 200)
    }
}


/// Helper for sidebar zone header icon buttons (= New + Import).
/// Wraps the icon in a Button + hover tint + rounded clip (= same
/// pattern as PaneIconTab). Each call site gets its own @State
/// hover tracking (= SwiftUI button identity).
private struct NewButtonWithHover: View {
    let iconName: String
    let help: String
    let action: () -> Void

    var body: some View {
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'tree-view style doesn't follow
        // Apple API': the previous hand-rolled hover pattern
        // (= `@State isHover` + `.onHover` + manual `.background(
        // RoundedRectangle.fill(.tertiary vs .clear))`) was a non-
        // Apple pattern (= Finder / Mail / Notes sidebar icon
        // buttons do NOT use a manual background fill; = they use
        // the system `.buttonStyle(.borderless)` which auto-applies
        // the canonical macOS 27 hover tint + Liquid Glass material
        // = identical to the system toolbar's icon button hover).
        //
        // Apple HIG: `.buttonStyle(.borderless)` is THE canonical
        // sidebar / toolbar icon button style on macOS 14+. It
        // (= renders the icon, = auto-paints the hover tint on
        // pointer-over, = auto-paints the press tint on click, =
        // auto-applies the Liquid Glass material backdrop on macOS
        // 27). No manual state, no manual background, no manual tint.
        //
        // Removed: @State isHover, .onHover, manual
        // RoundedRectangle fill, .help (kept — that's user-facing
        // tooltip = good UX), .padding(.frame) (auto-applied by
        // borderless button style).
        Button(action: action) {
            Image(systemName: iconName).font(.system(size: 18, weight: .regular))
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}