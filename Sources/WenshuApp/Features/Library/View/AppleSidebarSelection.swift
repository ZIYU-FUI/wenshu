//
//  AppleSidebarSelection.swift
//
//  Sidebar selection forwarder extracted from AppleSidebarView.swift
//  in A108 (= §6.6 600-LOC cap god-class split; = also §6.6
//  60-LOC function-level cap; = `forwardSelection` was 166 LOC =
//  2.77x the cap).
//
//  Why a separate file (= and not in AppleSidebarView.swift): the
//  `forwardSelection(_:)` function is the sidebar's "click to scope"
//  handler (= 1 single concern = update `WorkspaceUIState.sidebarSelection`
//  based on the clicked `SidebarNode`); = it's a sibling of the
//  `SidebarRowView` + `SidebarRowCallbacks` system (= all sidebar
//  click logic lives in `Features/Library/View/`); = the function
//  uses 2 private state slots (`workspaceUI` + `service`) that are
//  now `var` (= internal scope) so this extension can reach them
//  per the §6.6 cross-file extension pattern (= see A82-A83 for
//  PreviewPane precedents; = A100 for BookChapter precedents).
//
//  Per the §6.2 4-slot spec: this is a SwiftUI sub-view helper
//  (= a function on the view) = belongs in View/ (= already is;
//  = sibling of SidebarRowView.swift + SidebarRowCallbacks.swift
//  in the same View/ dir).
//
//  The function was moved verbatim in A108 (= 1:1 move; = no logic
//  change). = It has since been SPLIT IN TWO, = and the split is the
//  point: = `writes(for:in:)` is the row→value decision (= pure, = so a
//  test can name what a click chooses), = and `forwardSelection` is that
//  decision plus the two writes it decides (= the §6.6 60-LOC
//  function-level cap violation inherited from AppleSidebarView's
//  A14-A38 era is gone with the split).
//

import SwiftUI

/// The pair `AppleSidebarView.writes(for:in:)` decides for one clicked
/// row (= two fields, = one decision, = so a test can assert both the
/// selection and the store write without a running window).
struct SidebarClickWrites {
    var selection: SidebarItem?
    var selectedBookId: UUID?
}

extension AppleSidebarView {
    // MARK: Reference-row right-click helpers

    // (= the rename
    // sheet needs the
    // reference's
    // current title +
    // the list of all
    // other reference
    // titles for the
    // duplicate check).

    /// Resolve the `otherNames` list for the rename sheet based on the target's
    /// `Kind` (= shelf / book / reference). The reference case uses
    /// `SidebarService. otherReferenceTitles` (= the v2.7 [archived-round] addition).
    func otherNamesForRename(target: SidebarRenamingTarget) -> [String] {
        switch target.kind {
        case .shelf:
            return service?.otherShelfNames(excluding: target.itemId) ?? []
        case .book:
            return service?.otherBookTitles(excluding: target.itemId) ?? []
        case .reference:
            return service?.otherReferenceTitles(excluding: target.itemId) ?? []
        case .bookDoc:
            // the
            // sidebar's
            // own
            // otherNames
            // dispatch
            // also
            // gains a
            // `.bookDoc`
            // case
            // (= same
            // SidebarService
            // method
            // used by
            // PreviewPane's
            // rename
            // sheet).
            return service?.otherBookDocTitles(excluding: target.itemId) ?? []
        }
    }
    /// ', ': context-menu builder (= extracted from the inline body of
    /// `.contextMenu(forSelectionType:menuItems:)` above; = the inline closure
    /// body was so large the Swift type checker gave up; = extracting it to a
    /// focused method gives the type-checker room to work). The handler
    /// forwards to `SidebarContextMenuBuilder.build(...)` with closures that
    /// flip `renaming` / `pendingDelete` / `appState.*RequestCount` (= the
    /// sidebar's local `@State` and the AppState shared counter; = the .sheet +
    /// .alert modifiers elsewhere on this body observe + present). context-menu
    /// builder (= extracted from the inline body of
    /// `.contextMenu(forSelectionType:menuItems:)` above; = the inline closure
    /// body was so large the Swift type checker gave up; = extracting it to a
    /// focused method gives the type-checker room to work). The handler
    /// forwards to `SidebarContextMenuBuilder.build(...)` with closures that
    /// flip `renaming` / `pendingDelete` / `appState.*RequestCount` (= the
    /// sidebar's local `@State` and the AppState shared counter; = the .sheet +
    /// .alert modifiers elsewhere on this body observe + present). Apple HIG
    /// canonical: the closure passed to `.contextMenu(forSelectionType:menu:)`
    /// must return a @ViewBuilder block (= no `AnyView` wrapper, no explicit
    /// Group, no Divider between buttons). The `AnyView` wrapper collapses the
    /// @ContentBuilder tuple type and the menu item extractor drops trailing
    /// items (= the v1.69y symptom: the menu only renders the "create new"
    /// item). The `?` shorthand below ensures both return paths produce the
    /// same @ContentBuilder tuple (= Apple HIG canonical shape). Map the
    /// user-clicked sidebar row to the corresponding AppState.sidebarSelection
    /// discriminator (= so the rest of wenshu continues to read the same value
    /// it did before the v1.69 MVVM split (= when SidebarItem still lived
    /// inline inside NewLibraryOutlineView)). ' ，' (= the 5 standard folders
    /// under each book are now visible in the sidebar; = the folder rows
    /// forward their selection to AppState.sidebarSelection AND open the folder
    /// in the editor's tab strip).
    ///
    /// THE STORE'S SELECTED BOOK IS WRITTEN HERE
    ///
    /// `BookStore.selectedBookId` is the app's one record of WHICH BOOK
    /// IS THE ACTIVE ONE, = and the style sheet's page and the editor
    /// both read it (= the sheet is keyed by book id). = It had NO
    /// writer in production (= `BookStore.reload(bookId:)` has no
    /// caller, = and the write that used to live here is gone), = so
    /// the field stayed nil and every reader fell back to the print
    /// baseline. = So the selection writes it.
    ///
    /// A FOLDER ROW writes the book that OWNS the folder (= the same
    /// book the `.folder` selection resolves to), = so the store and
    /// the selection always name ONE book.
    /// WHAT A CLICKED ROW WRITES, = as ONE decision a test can call.
    ///
    /// ⇒ WHY IT IS NOT INLINE: = the header above names this the only
    /// seam left for selection, = and a claim nobody can observe is not
    /// a guard (= the review's R2 finding: = the row→selection mapping
    /// lived inside `forwardSelection`, = which is a mutation path on a
    /// view, = so a test could only read it back by asserting on SOURCE
    /// TEXT). = Extracted, = a test names what a click chooses.
    ///
    /// `selection` = the value `workspaceUI.sidebarSelection` takes, =
    /// nil for a divider row (= pure chrome, = the previous selection
    /// stays put). = `selectedBookId` = the value
    /// `BookStore.selectedBookId` takes, = nil when the row names no
    /// book (= the field keeps what it had: = a tag row is not a book).
    ///
    /// ⇒ THE INVARIANT THE TWO SHARES: = when a row names a book, = the
    /// selection and the store name THE SAME one.
    static func writes(
        for node: SidebarNode,
        in nodes: [SidebarNode]
    ) -> SidebarClickWrites {
        switch node.kind {
        case .shelf:
            return SidebarClickWrites(selection: .shelf(node.id), selectedBookId: nil)
        case .book:
            // A book row with a parent is a FOLDER row (= the 5 standard
            // folders under each book), = and it selects the folder it
            // names; = a real book row selects the book.
            if let parent = parentBookInfo(for: node.id, in: nodes) {
                return SidebarClickWrites(
                    selection: .folder(bookId: parent.bookId, folderName: parent.folderName),
                    selectedBookId: parent.bookId
                )
            }
            return SidebarClickWrites(selection: .book(node.id), selectedBookId: node.id)
        case .reference:
            // THE LIBRARY ROOT NAMES ITSELF. = The row is the container
            // the tag rows hang under, = and the value the click writes
            // is what the highlight and the reveal read back, = so it
            // has to be an id the tree can resolve. = The value this
            // case used to write (= a category-shaped key built from the
            // row's TITLE) matched no row at all, = so clicking the root
            // selected nothing.
            return SidebarClickWrites(selection: .referenceLibraryRoot, selectedBookId: nil)
        case .tag:
            // A tag leaf routes by the tag string (= the material zone's
            // grid filters on it). = It was routed through the
            // category-shaped key once, = and the filter was silently
            // unreachable.
            return SidebarClickWrites(selection: .tag(node.title), selectedBookId: nil)
        case .divider:
            // Divider rows are non-interactive (= see OOB.md
            // #2026-09-23): = forwarding a selection here would corrupt
            // the discriminator, = so nothing is written.
            return SidebarClickWrites(selection: nil, selectedBookId: nil)
        }
    }

    /// The click handler (= the sidebar's "click to scope"). = It is
    /// `writes(for:in:)` and NOTHING BUT the two writes that function
    /// decides (= the store's selected book is written HERE, = and the
    /// book a FOLDER row writes is the book that OWNS the folder, = so
    /// the store and the selection always name ONE book).
    func forwardSelection(_ node: SidebarNode?) {
        // RATIONALE: the sidebar click is a scope filter only (= NOT a
        // tab-opener; = `openFolderInEditor` / `openBookInEditor` fired
        // on every click, = which mutated `appState.openTabs`; = the
        // wenshu 1:1 macOS Finder canonical is "click to scope,
        // double-click to open"). = The selection is still recorded, =
        // so the middle column re-scopes to the cards inside the row.
        guard let node else { return }
        let writes = Self.writes(for: node, in: service?.nodes ?? [])
        if let selection = writes.selection {
            workspaceUI.sidebarSelection = selection
        }
        if let bookId = writes.selectedBookId {
            bookStore.selectedBookId = bookId
        }
    }
}
