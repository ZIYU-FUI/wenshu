// Sources/WenshuApp/UI/Editor/EditorHeaderView.swift
//
// Toolbar-style chrome band for the chapter editor. Renders above the
// NSTextView (= fed as `header:` on `NativeTextViewWrapper`). Apple HIG
// macOS document-toolbar idiom (= Pages / Numbers / Xcode document chrome):
// fixed 28 PT height (= DesignTokens.paneTabHotArea, Safari-tab stop
// standard), 8 PT horizontal padding (= DesignTokens.spacingStandard),
// left = document title placeholder, right = chrome widget cluster
// (= autosave dot, spell-check toggle hook for later tickets).
//
// Design constraints:
// - Pure render surface; = no @State / @Observable / business logic.
//   The host (`EditorView`) supplies `isDirty`, `hasUnsavedExternalChange`,
//   etc. via `let` parameters. This keeps EditorHeaderView decoupled from
//   AppState (= the header can be unit-tested as a plain View without a
//   full SwiftData container).
// - No `AnyView` in the body; = no opaque-return-type penalty under Swift 6.
//   chrome 5 widgets total; = SwiftUI infers concrete types from HStacks.
// - Wrapped in `UI/Editor/` (= the editor chrome's stable home; = future
//   edits land here, not in the SwiftUI source tree at the top level).
import SwiftUI

/// Editor-zone toolbar header. Slim 28 PT band above the markdown engine's
/// NSTextView. Apple HIG macOS document-toolbar idiom (= Pages / Numbers).
struct EditorHeaderView: View {
    /// Document title (= shows "Untitled" when nil until chapter focus
    /// lock or documentPath resolves).
    let title: String

    /// Dirty marker (= a small colored dot on the right of the title).
    /// nil = clean (= no dot shown).
    let dirtyState: EditorHeaderDirtyState?

    /// Right-side chrome widget slots. Empty array hides the right cluster
    /// entirely (= just the title remains). Default = empty.
    let chrome: [EditorHeaderChrome]

    /// Custom leading slot. When non-nil, REPLACES the
    /// `title + dirtyState` cluster (= same leading position;
    /// same 28 PT row height; same Divider). Caller controls
    /// whatever belongs in the leading zone — editor uses
    /// `title + dirtyState`; assets bar uses a search field.
    /// Single source of truth for the column-top chrome shape
    /// (= 41-rule audit + §6.2 = no duplicate chrome geometries).
    let customLeading: AnyView?

    init(
        title: String,
        dirtyState: EditorHeaderDirtyState? = nil,
        chrome: [EditorHeaderChrome] = [],
        customLeading: AnyView? = nil
    ) {
        self.title = title
        self.dirtyState = dirtyState
        self.chrome = chrome
        self.customLeading = customLeading
    }

    /// Convenience init that hosts a SwiftUI View via `@ViewBuilder`
    /// (= the caller doesn't pass `AnyView` directly; = matches the
    /// `EditorHeaderChrome.init` shape).
    init<V: View>(
        title: String = "",
        dirtyState: EditorHeaderDirtyState? = nil,
        chrome: [EditorHeaderChrome] = [],
        @ViewBuilder customLeading: () -> V
    ) {
        self.title = title
        self.dirtyState = dirtyState
        self.chrome = chrome
        self.customLeading = AnyView(customLeading())
    }

    var body: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            if let customLeading {
                // Custom leading slot wins (= canonical Apple toolbar
                // pattern: leading zone is either title text OR a custom
                // widget; = the title text is suppressed when customLeading
                // is non-nil; = no double-leading-row visual).
                customLeading
            } else {
                // Title cluster (left)
                HStack(spacing: DesignTokens.spacingIconic) {
                    if let dirtyState {
                        Circle()
                            .fill(dirtyState.color)
                            .frame(
                                width: DesignTokens.tabCloseFrameSize,
                                height: DesignTokens.tabCloseFrameSize
                            )
                            .help(dirtyState.tooltip)
                            .accessibilityLabel(dirtyState.accessibilityLabel)
                    }
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: DesignTokens.spacingStandard)

            // Chrome cluster (right). When empty, the trailing Spacer above
            // already absorbed the slack, so the cluster collapses to
            // (.frame(width: 0)) by SwiftUI's HStack layout (= no visible
            // pixel change when chrome is empty).
            if !chrome.isEmpty {
                HStack(spacing: DesignTokens.spacingCaption) {
                    ForEach(Array(chrome.enumerated()), id: \.offset) { _, item in
                        item.content
                    }
                }
            }
        }
        // 8 PT horizontal padding (= matches Pages' document toolbar rhythm;
        // = matches the editor zone's leading + trailing edge).
        .padding(.horizontal, DesignTokens.spacingStandard)
        // Vertical 0 (= NSTextView's own TextKit 2 insets set the visual
        // baseline; = we don't double-pad).
        .frame(height: DesignTokens.paneTabHotArea)
        // Hairline hairline at the bottom (= the toolbar separator;
        // = Apple's macOS document toolbar pattern; = same Divider used
        // by every other chrome in the column tree).
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

/// Dirty-state marker shape passed into `EditorHeaderView`. The host
/// decides what color (= red for unsaved + external change, gray for
/// autosave-in-progress, nil for clean). Each variant carries its own
/// tooltip + VoiceOver label (= no missing accessibility).
enum EditorHeaderDirtyState {
    case unsaved
    case autosaving
    case externalChangeConflict

    var color: Color {
        switch self {
        case .unsaved:                  return .orange
        case .autosaving:               return .secondary
        case .externalChangeConflict:   return .red
        }
    }

    var tooltip: String {
        switch self {
        case .unsaved:                  return String(localized: "editor.header.dirty.tooltip")
        case .autosaving:               return String(localized: "editor.header.autosaving.tooltip")
        case .externalChangeConflict:   return String(localized: "editor.header.external_change.tooltip")
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .unsaved:                  return String(localized: "editor.header.dirty.a11y")
        case .autosaving:               return String(localized: "editor.header.autosaving.a11y")
        case .externalChangeConflict:   return String(localized: "editor.header.external_change.a11y")
        }
    }
}

/// One widget on the right cluster of the editor header. The host
/// supplies already-built `AnyView`-free SwiftUI content (= e.g. an
/// `Image(systemName:).imageScale(.small)` styled per SFIcon central
/// factory); = EditorHeaderView stays a pure renderer.
struct EditorHeaderChrome {
    let content: AnyView

    init<V: View>(@ViewBuilder _ content: () -> V) {
        self.content = AnyView(content())
    }
}
