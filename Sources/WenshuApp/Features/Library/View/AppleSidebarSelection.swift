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
//  The function is preserved verbatim (= 1:1 move; = no logic
//  change; = the §6.6 60-LOC function-level cap violation is
//  inherited from AppleSidebarView's A14-A38 era; = a future
//  ticket may split the 4 `node.kind` switch cases into 4
//  separate per-kind handlers).
//

import SwiftUI

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
    /// `SidebarService. otherReferenceTitles` (= the v2.7 round-63 addition).
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

    /// Resolve the current title of a reference by id (= the rename sheet's
    /// `originalName` field; = the existing `renameShelf` / `renameBook`
    /// callbacks look up the name from `service.shelves` / `service.books`
    /// synchronously; = the reference equivalent reads from `bookStore.
    /// loadAllReferences()`). Returns nil if the reference is missing (= the
    /// rename sheet opens with an empty name; = the user can still type a new
    /// one; = the save fails with `bookNotFound`).
    func referenceTitle(for id: UUID) -> String? {
    guard let references = try? bookStore.loadAllReferences() else {
        return nil
    }
    return references.first(where: { $0.id == id })?.title
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
    func forwardSelection(_ node: SidebarNode?) {
    // RATIONALE: the sidebar click
    // is a scope filter only (= NOT
    // a tab-opener; = the previous
    // behavior fired
    // `openFolderInEditor` /
    // `openBookInEditor` on every
    // click; = that mutates
    // `appState.openTabs`; = the
    // wenshu 1:1 macOS Finder
    // canonical = "click to scope,
    // double-click to open"). The
    // sidebar selection is still
    // recorded in
    // `workspaceUI.sidebarSelection`
    // (= the middle column re-scopes
    // to show the cards inside the
    // selected folder / book; = the
    // user can see what's inside the
    // folder without the editor
    // automatically opening a tab).
    guard let node else { return }
    switch node.kind {
    case .shelf:
        workspaceUI.sidebarSelection = .shelf(node.id)
    case .book:
        // Determine if this is a real book (top-level row) or a
        // folder row (child of a book). Folder rows have a
        // parent in the sidebar tree (= the v1.68f folder
        // children, = 5 standard folders per book); real books
        // are children of a shelf. Walk the tree to disambiguate.
        if let parent = Self.parentBookInfo(for: node.id, in: service?.nodes ?? []) {
            // Folder row.
            // RATIONALE 2026-10-13: the
            // `openFolderInEditor(...)` call
            // is removed (= the boss asked
            // the sidebar click to NOT
            // open a tab; = the sidebar
            // click only records the
            // selection in
            // `workspaceUI.sidebarSelection`;
            // = the middle column re-scopes
            // to show the cards inside the
            // folder; = the user can
            // double-click a card to open
            // a tab if they want to edit).
            workspaceUI.sidebarSelection = .folder(bookId: parent.bookId, folderName: parent.folderName)
        } else {
            // Real book row. RATIONALE 2026-10-13:
            // the `openBookInEditor(...)` call
            // is removed (= same reason as
            // the folder row above).
            workspaceUI.sidebarSelection = .book(node.id)
        }
    case .reference:
        // reference-library leaf (= a single Reference
        // document). node.title carries the reference's
        // display title, not its category, so writing
        // `.referenceCategory(node.title)` here is incorrect;
        // the correct route is `.referenceCategory(<ref's
        // category directoryName>)` — but the SidebarNode
        // doesn't carry the Reference struct (= only id +
        // title + subtitle), so we resolve the reference's
        // category downstream by storing a structured
        // selection. Without that plumbing (= v1.69 ticket
        // scope = expand the CLC category tree only; =
        // single-reference selection lands on a future
        // ticket), the leaf row falls through to
        // .referenceScope(nil) in the preview pane via
        // ShellMiddleColumn's case-mismatch fallback (= =
        // the user sees the full overview; = the leaf can
        // be opened via the existing double-click pipeline
        // on the middle-column card).
        workspaceUI.sidebarSelection = .referenceCategory(node.title)
    case .referenceCategory:
        // :
        // a category parent row (= one of the 22 CLC
        // top-level categories under the Reference-Library
        // root). Selecting it scopes the middle-column card
        // grid to that category.
        //
        // p (see OOB.md #2026-09-22) OOB: read the routing key
        // (= the EntityCategory.directoryName, stored in
        // SidebarNode.routingKey during the v1.69j projection;
        // = lowercase letter for the official 22 cases,
        // "" for .z, "" for pre-v0.29 nil-category
        // references). The routing key is what
        // ShellMiddleColumn.previewScope's case-insensitive
        // EntityCategory(rawValue:) lookup resolves back to
        // a category — the user-visible title (= "") can't
        // be used directly because no EntityCategory rawValue
        // is "". Falling back to node.title (= the previous
        // m behaviour) leaves the routing key in the
        // user-visible slot (= the user's ', 
        // ' complaint).
        workspaceUI.sidebarSelection = .referenceCategory(node.routingKey ?? node.title)
    case .tag:
        // tag row (= SidebarNode.Kind.tag,
        // populated by SidebarService from the union of
        // Reference.tags across all references). Routing
        // uses the node title (= the tag string) directly;
        // AssetsPane.previewScope() maps .tag(let tagString)
        // to .referenceScope(nil) AND sets
        // workspaceUI.activeTag = tagString (= PreviewPane
        // applies the tag filter on top of the reference
        // scope). This case must be its own branch
        // (= NOT a .referenceCategory fallback; = the
        // previous code used .referenceCategory here and
        // the tag filter was silently unreachable).
        workspaceUI.sidebarSelection = .tag(node.title)
    case .divider:
        // bb (see OOB.md #2026-09-23) OOB '
        // ': divider rows are non-interactive;
        // = the user can never select a divider (= it's
        // pure chrome between sections). Forwarding a
        // sidebarSelection here would corrupt the
        // .referenceCategory discriminator (= the divider
        // sentinel has no EntityCategory mapping). Simply
        // no-op so the previous selection stays put.
        break
    }
    }
}
