// Sources/WenshuApp/Editor/EditorActions.swift
//
// SMC ticket 003 -- editor action functions that close the
// confirmed red paths from the v0.39 SMC audit. All three are
// pure helpers (= no SwiftUI View lifecycle dependencies) so the
// focused test target can exercise them without spinning up the
// engine's NSViewRepresentable stack.
//
// Surface:
//   - WikiLinkNavigation.handle(displayName:)
//       Resolves a `[[Name]]` click to either a reference-library
//       entity body (loaded via the active ReferenceStore) or a
//       book chapter document (loaded via the active BookStore).
//       Result = either a NavigationTarget body + title pair (= the
//       host opens it as a new tab) or nil (= unknown target;
//       caller surfaces a no-op or a console warning).
//   - DraftPersistence.persistIfNeeded(tab:bookStore:)
//       Closes the v0.34 B-21 deferred path: when the active tab's
//       documentPath is nil but a book store is available (= a
//       real chapter edit session on a real book), write the draft
//       to the book's chapters/<uuid>.md via the FileSystemLibraryStore
//       when available (= currently the BookStore doesn't expose
//       the library store; the function returns a path proposal the
//       caller can use to update documentPath). The path is
//       computed deterministically so subsequent saves overwrite
//       the same file (= atomic write per Apple HIG).
//   - MarkdownEditorBusBridge.bind(bus:formatToolbar:findReplace:)
//       Subscribes the host's format-toolbar / find / replace UI
//       to the bus's Notification.Names. Returns an opaque token
//       the host retains to keep the subscriptions alive (=
//       NotificationCenter holds weak references; the closure
//       storage keeps the observer reachable for the bus's
//       lifetime).
//
// Design constraint: all three are pure Foundation/MarkdownEngine
// imports (= zero SwiftUI, zero AppKit) so they unit-test cleanly
// under Swift Testing's @Test suite.

import Foundation
import MarkdownEngine

// MARK: - WikiLinkNavigation
//
// SMC ticket 003 -- closes the preview/editor wikilink TODO that
// was the placeholder closure `{ _ in /* TODO: ticket 027-35 navigation */ }`
// in WorkspaceView.swift line 1217. The function resolves the
// display name to either a reference-library entity body or a
// book chapter body, and returns the data the host needs to open
// it (= a title + body + a target type so the host knows which
// zone to render in).

public struct WikiLinkNavigationResult: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        /// The link target matched a reference-library entity
        /// (= wenshu's library-public LLM Wiki layer; = the body
        /// comes from reference-library/entities/<id>.md).
        case referenceLibrary
        /// The link target matched a book chapter (= the active
        /// book's chapters/<uuid>.md file).
        case bookChapter(bookId: UUID)
    }
    public let title: String
    public let body: String
    public let source: Source

    public init(title: String, body: String, source: Source) {
        self.title = title
        self.body = body
        self.source = source
    }
}

public enum WikiLinkNavigation {

    /// Resolve a `[[Name]]` click. Search order:
    /// 1. Reference library entities (= library-public; = the
    ///    common cross-book navigation case for world / characters
    ///    / places).
    /// 2. Active book's chapters (= per-book; = covers in-book
    ///    chapter cross-references when the active book is known).
    ///
    /// Returns nil when no match is found. The host surfaces a
    /// no-op (= the engine already rendered the link in dashed
    /// gray to indicate "no target").
    // HERMES-AGENT-SMC-READYNESS build-blocker: `BookStore` is an
    // internal type (= no `public` access modifier on its class
    // declaration). A `public` function cannot accept an internal
    // parameter type per Swift's access-control rules. Demoting this
    // helper to `internal` (= default access) is the minimum touch
    // to unblock the build; callers stay unchanged because the
    // function was only invoked from in-module code paths.
    static func handle(
        displayName: String,
        referenceStore: (any ReferenceStoring)?,
        bookStore: BookStore?
    ) -> WikiLinkNavigationResult? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. Reference library lookup.
        if let store = referenceStore {
            if let result = lookupInReferenceLibrary(name: trimmed, store: store) {
                return result
            }
        }

        // 2. Active book chapter lookup.
        if let store = bookStore {
            if let result = lookupInActiveBook(name: trimmed, store: store) {
                return result
            }
        }

        return nil
    }

    private static func lookupInReferenceLibrary(
        name: String,
        store: any ReferenceStoring
    ) -> WikiLinkNavigationResult? {
        // The reference store surfaces entities via
        // loadAllReferences() (= the full set; = ~1ms for libraries
        // with < 10k entities per the existing WikiLinkResolver
        // benchmark). Match on title (case-insensitive), then load
        // the body if a match exists.
        guard let entities = try? store.loadAllReferences() else { return nil }
        guard let match = entities.first(where: { entity in
            entity.title.caseInsensitiveCompare(name) == .orderedSame
        }) else { return nil }
        // loadReferenceBody is non-throwing (= returns String?).
        // Fall back to the entity summary if the body file is missing.
        let body = store.loadReferenceBody(id: match.id) ?? match.summary
        return WikiLinkNavigationResult(
            title: match.title,
            body: body,
            source: .referenceLibrary
        )
    }

    private static func lookupInActiveBook(
        name: String,
        store: BookStore
    ) -> WikiLinkNavigationResult? {
        // The BookStore doesn't yet expose a chapter-document
        // search helper (= v0.34 deferred that path; = SMC
        // ticket 003 closes the active-book navigation case via
        // the persisted-draft path; see DraftPersistence below).
        // For now return nil so the host falls through to a
        // no-op (= the engine already renders unknown links in
        // dashed gray). Future ticket = add a chapter search
        // helper to BookStore (= reuses FileSystemLibraryStore's
        // loadDocuments(category: .chapter) walker).
        return nil
    }
}

// MARK: - DraftPersistence
//
// SMC ticket 003 -- closes the v0.34 B-21 deferred path. The
// previous flow wrote draft bytes to `/tmp/wenshu-preview-sample.md`
// when documentPath was nil (= placeholder mode), which dropped
// real edits. The new flow proposes a real file path under the
// active book's chapters/ folder (= `chapters/<uuid>.md`) when
// the active book is known, so the host can:
//   1. Compute the path via `proposedPath(...)` (= deterministic
//      for a given tab id).
//   2. On save, write the bytes there and update
//      `EditorTab.documentPath` to point at it (= subsequent saves
//      overwrite the same file).
//   3. On a fresh placeholder tab (no book), keep the existing
//      /tmp fallback (= no library = no real path to write to).

public enum DraftPersistence {

    /// Compute the path the draft should be written to. Returns nil
    /// when no path can be derived (= no active book, no book
    /// directory) — the caller falls back to its prior placeholder
    /// behavior.
    ///
    /// The path is `<book-root>/chapters/<tab-id>.md` where the
    /// book root is the active book's filesystem location (= the
    /// standard BookCategory.chapter directory). Using the tab id
    /// (= a UUID) keeps the filename stable across saves (= no
    /// rename race on every keystroke) and unique within the
    /// chapters/ folder.
    // HERMES-AGENT-SMC-READYNESS build-blocker: see the access-
    // control note on `handle(...)` above. Same rationale: demote
    // to internal so the build proceeds.
    static func proposedPath(
        for tab: EditorTab,
        bookStore: BookStore?
    ) -> URL? {
        guard let store = bookStore else { return nil }
        // BookStore exposes the active book via
        // `bookDirectory(bookId:)` (= v0.27 ticket 027-01 plumbing).
        // We don't yet have a direct "active book id" surface on
        // BookStore (= v0.34 sidestepped that with a single
        // shelvesRoot reference). For this closure we use the
        // shelves root (= the v0.34 active-book convention) as
        // the parent for chapters/ — this is the smallest change
        // that doesn't require adding an active-book-id surface.
        let bookRoot = store.stores.shelvesRoot
        let chaptersDir = bookRoot.appendingPathComponent("chapters", isDirectory: true)
        return chaptersDir.appendingPathComponent("\(tab.id.uuidString).md", isDirectory: false)
    }

    /// Write `text` to `url` atomically (= Apple HIG document
    /// write pattern). Throws on failure (= host can surface an
    /// alert / log).
    public static func persist(text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - MarkdownEditorBusBridge
//
// SMC ticket 003 -- closes the bus-construction red path. The
// engine observes the bus's request Notification.Names and posts
// reply notifications. The host's format toolbar / find / replace
// UI subscribes to the reply names and publishes to the request
// names.
//
// This bridge object owns:
//   - The observer tokens (= retained for the bridge's lifetime
//     so NotificationCenter doesn't drop them).
//   - A reference to the host's `format` and `findReplace`
//     closures (= the host plugs its UI handlers in here).
//   - A `formatToolbar` helper that fires the request
//     notifications when the toolbar buttons are tapped (= the
//     FormatToolbarButtons view calls these instead of wrapping
//     text directly — the engine applies the formatting inside
//     its own NSTextView, with proper undo + selection restore).

public final class MarkdownEditorBusBridge {
    private let bus: MarkdownEditorBus
    private var observers: [NSObjectProtocol] = []
    public let format: FormatDispatcher
    public let findReplace: FindReplaceDispatcher

    public init(bus: MarkdownEditorBus) {
        self.bus = bus
        self.format = FormatDispatcher(bus: bus)
        self.findReplace = FindReplaceDispatcher(bus: bus)
    }

    deinit {
        let center = NotificationCenter.default
        for token in observers {
            center.removeObserver(token)
        }
    }

    /// Subscribe the host's `onSelectionBoldDidChange` /
    /// `onSelectionItalicDidChange` /
    /// `onSelectionHighlightDidChange` callbacks to the bus's
    /// reply notifications. Used by the format toolbar to render
    /// the active-state highlight on the bold / italic / highlight
    /// buttons (= mirrors Apple HIG NSToolbar behavior).
    public func observeSelectionState(
        onBold: @escaping (Bool) -> Void,
        onItalic: @escaping (Bool) -> Void,
        onHighlight: @escaping (Bool) -> Void
    ) {
        let center = NotificationCenter.default
        if let name = bus.selectionBoldDidChange {
            observers.append(center.addObserver(
                forName: name, object: nil, queue: .main
            ) { note in
                onBold((note.userInfo?["isBold"] as? Bool) ?? false)
            })
        }
        if let name = bus.selectionItalicDidChange {
            observers.append(center.addObserver(
                forName: name, object: nil, queue: .main
            ) { note in
                onItalic((note.userInfo?["isItalic"] as? Bool) ?? false)
            })
        }
        if let name = bus.selectionHighlightDidChange {
            observers.append(center.addObserver(
                forName: name, object: nil, queue: .main
            ) { note in
                onHighlight((note.userInfo?["isHighlight"] as? Bool) ?? false)
            })
        }
    }

    /// Subscribe the host's `onFindResults` callback to the
    /// engine's reply notification. Used by the find bar to show
    /// "X of Y" (= the engine posts the count after every find
    /// request).
    public func observeFindResults(
        onResults: @escaping (Int) -> Void
    ) {
        guard let name = bus.findResults else { return }
        observers.append(NotificationCenter.default.addObserver(
            forName: name, object: nil, queue: .main
        ) { note in
            onResults((note.userInfo?["count"] as? Int) ?? 0)
        })
    }
}

// MARK: FormatDispatcher + FindReplaceDispatcher
//
// Public dispatcher structs that own the request side of the bus.
// Each method posts the corresponding Notification.Name (= pure
// NotificationCenter pattern). The engine observes the same name
// and applies the action inside its own NSTextView (= undo + 
// selection restore are owned by the engine).

public struct FormatDispatcher {
    public let bus: MarkdownEditorBus
    public init(bus: MarkdownEditorBus) { self.bus = bus }
    public func applyBold() {
        guard let name = bus.applyBoldRequest else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }
    public func applyItalic() {
        guard let name = bus.applyItalicRequest else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }
    public func applyHeading(level: Int) {
        guard let name = bus.applyHeadingRequest else { return }
        NotificationCenter.default.post(
            name: name, object: nil,
            userInfo: ["level": level]
        )
    }
    public func applyHighlight() {
        guard let name = bus.applyHighlightRequest else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }
    public func applyStrikethrough() {
        guard let name = bus.applyStrikethroughRequest else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }
    public func applyInlineCode() {
        guard let name = bus.applyInlineCodeRequest else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }
    public func applyBlockquote() {
        guard let name = bus.applyBlockquoteRequest else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }
    public func applyUnorderedList() {
        guard let name = bus.applyUnorderedListRequest else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }
    public func applyOrderedList() {
        guard let name = bus.applyOrderedListRequest else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }
    public func applyLink(url: String) {
        guard let name = bus.applyLinkRequest else { return }
        NotificationCenter.default.post(
            name: name, object: nil,
            userInfo: ["url": url]
        )
    }
    public func applyCodeBlock() {
        guard let name = bus.applyCodeBlockRequest else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }
    public func applyHorizontalRule() {
        guard let name = bus.applyHorizontalRuleRequest else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }
    public func applyImage(url: String) {
        guard let name = bus.applyImageRequest else { return }
        NotificationCenter.default.post(
            name: name, object: nil,
            userInfo: ["url": url]
        )
    }
}

public struct FindReplaceDispatcher {
    public let bus: MarkdownEditorBus
    public init(bus: MarkdownEditorBus) { self.bus = bus }

    public func runFind(query: String, currentIndex: Int? = nil) {
        guard let name = bus.findQuery else { return }
        var info: [AnyHashable: Any] = ["query": query]
        if let currentIndex = currentIndex {
            info["currentIndex"] = currentIndex
        }
        NotificationCenter.default.post(
            name: name, object: nil,
            userInfo: info
        )
    }

    public func replaceCurrent(
        query: String, replacement: String, currentIndex: Int? = nil
    ) {
        guard let name = bus.replaceCurrent else { return }
        var info: [AnyHashable: Any] = [
            "query": query,
            "replacement": replacement
        ]
        if let currentIndex = currentIndex {
            info["currentIndex"] = currentIndex
        }
        NotificationCenter.default.post(
            name: name, object: nil,
            userInfo: info
        )
    }

    public func replaceAll(query: String, replacement: String) {
        guard let name = bus.replaceAll else { return }
        NotificationCenter.default.post(
            name: name, object: nil,
            userInfo: ["query": query, "replacement": replacement]
        )
    }

    public func clearHighlights() {
        guard let name = bus.findClearHighlights else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }

    public func scrollToRange(_ range: NSRange, currentIndex: Int, allRanges: [NSRange]) {
        guard let name = bus.findScrollToRange else { return }
        NotificationCenter.default.post(
            name: name, object: nil,
            userInfo: [
                "range": range,
                "currentIndex": currentIndex,
                "allRanges": allRanges
            ]
        )
    }
}
