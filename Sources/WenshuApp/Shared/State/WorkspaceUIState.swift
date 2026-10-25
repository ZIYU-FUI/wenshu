//
//  WorkspaceUIState.swift · Wenshu
//
//  Per-window observable for the 2 column-local UI state fields
//  (= previewSortOrder + editMode) that survive shell lifecycle
//  changes (= different scope than shell chrome).
//
//  Why bundle previewSortOrder + editMode (= not 2 separate classes):
//  - Both are column-local UI state (= shared across WorkspaceView
//    descendants).
//  - Both reset together on shell collapse-expand (= co-vary).
//  - Both are read by WorkspaceView.body (= the same call sites;
//    = splitting creates 2 callers per split = more cost than
//    benefit).
//
//  Persistence: in-memory only (= column-local; = matches the
//  pre-existing AppState semantics for these fields; = resets
//  to default on relaunch per the user's 'should disappear on
//  restart' expectation for column-local UI).
//
//  Environment injection: WorkspaceUIState is injected once at
//  the AppRootScene root; = descendants read via
//  @Environment(WorkspaceUIState.self).
//
//  WorkspaceUIState is one of 3 new state classes added this arc
//  (= WorkspaceUIState / SheetRequestState / EditorCounters;
//  = the original 4-class arc was reduced when ShellState was
//  absorbed into WorkspaceUIState).
//

import Foundation

/// Per-window observable for column-local UI state (= preview
/// sort order + layout edit mode + active tag filter + chat-zone
/// visibility + inspector page).
///
/// Owned by `WenshuApp` (= the App struct, = per-window via
/// `@State`), injected via `.environment(workspaceUI)` on
/// WiredShell. Descendants read it with
/// `@Environment(WorkspaceUIState.self) private var workspaceUI`.
///
/// All fields are in-memory only (= no UserDefaults
/// persistence); = column-local; = matches the user's
/// 'should disappear on restart' expectation for ephemeral UI
/// state.
///
/// chatVisible + inspectorPage were previously on `ShellState`
/// (= a separate 4-property @Observable class). Apple HIG
/// treats all 5 fields here as the same shape (= view-local UI
/// state shared across column descendants; = the Pages /
/// Numbers / Keynote pattern is to keep them in one
/// environment-injected class, not split across multiple
/// sibling classes).
@MainActor
@Observable
final class WorkspaceUIState {

    /// Preview card-grid sort order (= shared across
    /// PreviewPane's cards / unwrap sort menu in the preview
    /// pane's tab bar trailing slot + WorkspaceView's
    /// previewScope). Default = .pinyinFirstLetter (= the
    /// spec).
    ///
    /// Removed the 3 independent `@State` copies (= previously
    /// in the now-deleted ShellMiddleColumn + WorkspaceView +
    /// PreviewPane = drifted). Lives on WorkspaceUIState (= single
    /// source of truth; = batch 3 = WorkspaceUIState split from
    /// AppState).
    var previewSortOrder: EntitySortOrder = .pinyinFirstLetter

    /// Active tag filter (= the user clicked a `.tag(String)`
    /// sidebar item; = the preview pane renders only references
    /// whose `tags` set contains this string). `nil` means
    /// "no tag filter" (= show all references).
    /// Lives on WorkspaceUIState (= the §11.13 P2-06 split
    /// pattern; = per-window via @State in WenshuApp).
    var activeTag: String?

    /// Chat zone visibility (= the bottom half of the detail
    /// column = an `NSSplitViewItem` inside
    /// `EditorChatNSController`). The macOS menu bar View >
    /// Show/Hide Chat Zone toggle (= `⌥⌘K`) writes here.
    ///
    /// When `chatVisible = true`, the chat zone NSSplitViewItem
    /// is visible (= editor + chat = 50/50 detail column).
    /// When `chatVisible = false`, the NSSplitViewItem
    /// `.isCollapsed` (= editor fills the full detail column;
    /// = matches Keynote's 'presenter notes' Show/Hide
    /// behavior).
    ///
    /// Toggled via a macOS menu item (= cross-view
    /// column-local state; = single source of truth lives here).
    var chatVisible: Bool = true

    /// The active page of the trailing inspector column (= one
    /// page: status). The column's toolbar toggle writes here, so the
    /// selection survives the column being hidden and shown.
    ///
    /// Lives here (= not as `@State` inside the inspector column)
    /// because the column reads it across the view boundary.
    var inspectorPage: InspectorPage = .status

    /// Sidebar tree selection (= the row the user picked; = nil = nothing
    /// selected). Drives Preview pane scope (= see
    /// WorkspaceView.previewScope).
    ///
    /// The value IS the current part's remembered selection: setting it
    /// records it under the current part, and reading it gives the
    /// current part's row. The property stays the one every other part
    /// of the app reads, so no other call site changes.
    ///
    /// Persisted to `wenshu.sidebarSelection` UserDefaults key
    /// (= JSON via Codable; = set by didSet = write back on every
    /// change; = read by WorkspaceUIState.init() at launch).
    /// The previous ShellState behavior is preserved 1:1.
    var sidebarSelection: SidebarItem? = nil {
        didSet {
            // didSet is NOT called during init (= Swift property
            // wrapper semantics), so this does NOT trigger a write
            // back to UserDefaults on launch (= pure read-side
            // migration). Encoded as JSON via the existing
            // Codable conformance (= SidebarItem: Hashable,
            // Codable, declared at `Views/Library/SidebarItem.swift`
            // post-v1.69c split).
            guard !isRestoring else { return }
            guard oldValue != sidebarSelection else { return }
            selections[currentSidebarPart] = sidebarSelection
            persistSelections()
            if let item = sidebarSelection,
               let data = try? JSONEncoder().encode(item) {
                store.setData(data, forKey: .sidebarSelection)
            } else {
                store.remove(.sidebarSelection)
            }
        }
    }

    /// The part of the sidebar that is showing.
    ///
    /// The sidebar holds three unrelated hierarchies (= the shelves, the
    /// reference library, and a reserved part for whole books imported
    /// as ebooks). Switching parts must not lose what was selected in
    /// the part being left, so the selection is remembered per part.
    ///
    /// Persisted to `wenshu.sidebar.part` UserDefaults key (= the raw
    /// value; = the same shape as `sidebarSelection`: write on change,
    /// read back in init).
    var currentSidebarPart: SidebarPart = .shelves {
        didSet {
            guard !isRestoring else { return }
            guard oldValue != currentSidebarPart else { return }
            store.setString(currentSidebarPart.rawValue, forKey: .sidebarPart)
            // The part's own remembered selection becomes the selection.
            sidebarSelection = selections[currentSidebarPart]
        }
    }

    /// The remembered selection of each part.
    ///
    /// Encoded as one value (= a dictionary keyed by the part; = the
    /// selection values use the same coder as `sidebarSelection`).
    var selections: [SidebarPart: SidebarItem] = [:]

    /// Write the per-part selections to the user's defaults.
    ///
    /// The map is encoded with the part's raw value as the key, so the
    /// stored value is one JSON object (= the same coder the single
    /// selection uses).
    private func persistSelections() {
        let byRawValue = Dictionary(
            uniqueKeysWithValues: selections.map { ($0.key.rawValue, $0.value) }
        )
        guard let data = try? JSONEncoder().encode(byRawValue) else { return }
        store.setData(data, forKey: .sidebarSelections)
    }

    /// How the editor column and the chat zone sit next to each
    /// other. `.automatic` lets the split follow the window
    /// width (= side by side when the window gives both panes
    /// room; = stacked when it does not); the two manual cases
    /// pin the arrangement and win over the width rule.
    ///
    /// Persisted to the `wenshu.editor.layoutMode` UserDefaults
    /// key (= the raw value; = the same shape as
    /// `sidebarSelection`: write on change, read back in init).
    var editorLayoutMode: EditorLayoutMode = .automatic {
        didSet {
            // didSet is NOT called during init (= Swift property
            // wrapper semantics), so this does NOT trigger a write
            // back to UserDefaults on launch (= pure read-side
            // restoration).
            guard oldValue != editorLayoutMode else { return }
            store.setString(editorLayoutMode.rawValue, forKey: .editorLayoutMode)
        }
    }

    /// Whether the state is being restored.
    ///
    /// The persisted fields are observed properties, and an observed
    /// property's observer fires when the value is assigned (= the
    /// assignment in the initialiser counts, because the value is set
    /// after the property's own initialisation). Without this flag the
    /// restore would write back what it just read, and the part's
    /// observer would clear the selection it is restoring.
    private var isRestoring = true

    /// The store the persisted fields read and write.
    ///
    /// Injected so a test can point the state at its own defaults
    /// (= the production path uses the shared store).
    private let store: UserDefaultsStore

    init(store: UserDefaultsStore = .shared) {
        self.store = store
        // In-memory only (= no UserDefaults read).
        //
        // Sidebar selection is the one field that persists across
        // relaunch (= UserDefaults JSON via Codable; = matches the
        // previous ShellState behavior). The didSet on
        // `sidebarSelection` writes back, and the explicit read
        // here in init() restores the last value (= didSet is
        // suppressed during init = no write-back triggered).
        if let data = store.data(forKey: .sidebarSelection),
           let decoded = try? JSONDecoder().decode(SidebarItem.self, from: data) {
            self.sidebarSelection = decoded
        }

        // The per-part selections (= one dictionary; = read back before
        // the part, so the part's remembered selection wins).
        if let data = store.data(forKey: .sidebarSelections),
           let decoded = try? JSONDecoder().decode([String: SidebarItem].self, from: data) {
            self.selections = decoded.reduce(into: [:]) { acc, pair in
                guard let part = SidebarPart(rawValue: pair.key) else { return }
                acc[part] = pair.value
            }
        }
        if let part = SidebarPart(rawValue: store.string(forKey: .sidebarPart)) {
            self.currentSidebarPart = part
            // The part's remembered selection is the selection, so the
            // sidebar and the preview pane agree after a relaunch.
            if let remembered = selections[part] {
                self.sidebarSelection = remembered
            }
        }
        // The layout mode persists the same way (= the raw value
        // of the enum; = an unknown or absent value falls back to
        // `.automatic`, which is the default).
        if let mode = EditorLayoutMode(rawValue: store.string(forKey: .editorLayoutMode)) {
            self.editorLayoutMode = mode
        }
        // The restore is over: the observers write from now on.
        self.isRestoring = false
    }
}

// MARK: - SidebarPart

/// The parts of the sidebar.
///
/// The sidebar holds three unrelated hierarchies: the user's shelves, the
/// reference library, and a reserved part for whole books imported as
/// ebooks. One tree per part, switched by a segmented control.
///
/// Each case carries the KEY of its display name, because the user reads
/// the names in the segmented control and the names come from the string
/// catalog (= the catalog is the only place a Chinese label may live).
enum SidebarPart: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    /// The user's shelves (= the shelf and book management).
    case shelves
    /// The reference library (= the grouped tag surface).
    case library
    /// Reserved for whole books imported as ebooks.
    case referenceBooks

    var id: String { rawValue }

    /// The key of the display name in the string catalog.
    var displayNameKey: String {
        switch self {
        case .shelves: return "sidebar.part.shelves.title"
        case .library: return "sidebar.part.library.title"
        case .referenceBooks: return "sidebar.part.reference_books.title"
        }
    }

    /// The name the user reads in the segmented control.
    ///
    /// The key is a runtime value, so the catalog is read through
    /// `NSLocalizedString` (= the form the codebase uses for a key it
    /// cannot write as a literal).
    var displayName: String {
        NSLocalizedString(displayNameKey, comment: "Sidebar part name")
    }
}

// MARK: - EditorLayoutMode

/// The arrangement the user asked for between the editor column
/// and the chat zone. The automatic case follows the window
/// width; the two manual cases pin the arrangement.
enum EditorLayoutMode: String, CaseIterable, Sendable {
    case automatic
    case stacked
    case sideBySide

    var localizedTitle: String {
        switch self {
        case .automatic:   return String(localized: "menu.view.editor_layout.automatic")
        case .stacked:     return String(localized: "menu.view.editor_layout.stacked")
        case .sideBySide:  return String(localized: "menu.view.editor_layout.side_by_side")
        }
    }
}

// MARK: - InspectorPage

/// The pages of the trailing inspector column: Status.
///
/// The page owns the column's content. A page without content
/// renders the shared empty state (= the column body has no tool
/// to show until a page owns one).
///
/// The case order IS the tab order (= the toolbar picker reads
/// `InspectorPage.allCases`).
enum InspectorPage: Hashable, CaseIterable {
    case status

    var localizedTitle: String {
        switch self {
        case .status: return String(localized: "inspector.page.status")
        }
    }

    var icon: String {
        switch self {
        case .status: return "waveform.path.ecg"
        }
    }
}
