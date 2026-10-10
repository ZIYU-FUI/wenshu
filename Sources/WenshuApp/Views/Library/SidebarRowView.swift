// SidebarRowView.swift
//
// One row in the macOS 27 Apple HIG sidebar. Used by
// AppleSidebarView's List(.sidebar) — Apple takes care of the
// disclosure indicator (= children property of the row's data)
// + the selection tint (= List(selection:) binding) + the hover
// highlight (= macOS 14+ default on List(.sidebar)) + the indent
// (= per-level indent from the data tree's depth). The row itself
// just renders the icon + title + subtitle (= the Apple HIG
// sidebar row content).
//
// v2.7 round-33 (= boss 2026-10-10 "如果当前
// 选中是别的，但鼠标直接在十二地仙
// 处右键，点导入，就不能带入" directive):
// SidebarRowView now carries a per-row
// `.contextMenu(menuItems:)` (= the
// right-click hit target IS the row that
// hosts the menu; = the menu closure
// captures the row's `node` directly;
// = the user's right-click on row X
// ALWAYS fires the menu for row X,
// regardless of the List's current
// `selectedNode` value). The previous
// design used `.contextMenu(forSelectionType:
// menu:)` on the List (= the menu
// closure got the List's `selectedNode`
// set, NOT the right-click hit target;
// = right-clicking a different row
// while another was selected routed
// the menu to the SELECTED row, not
// the right-clicked one).
//
// Apple canonical pattern (= macOS 14+
// Finder / Mail / Notes sidebar):
//   - per-row .contextMenu(menuItems:)
//     = right-click row X → menu for X
//   - list-level .contextMenu(forSelectionType:
//     menu:) = multi-select batch action
//     (= cmd+click 2+ rows + right-click
//     → batch delete; = the right-click
//     target IS one of the selected
//     rows, so the batch menu is
//     semantically correct).
// Wenshu uses both: per-row for
// single-click UX (= the canonical
// macOS Finder behavior), list-level
// for multi-select batch delete (= the
// v2.6 sidebar feedback bundle).

import SwiftUI

struct SidebarRowView: View {
    let node: SidebarNode
    /// Callbacks for the per-row context menu (= all
    /// the actions a single row may surface; = passed
    /// down from `AppleSidebarView` via the
    /// `SidebarRowCallbacks` bag; = the menu closure
    /// captures the row's `node` directly, so the
    /// right-click target is always the row that
    /// hosts the menu).
    var callbacks: SidebarRowCallbacks?

    /// v2.7 round-33 = drag source context (= the
    /// per-row `.contextMenu(menuItems:)` doesn't
    /// support drag-and-drop directly; = the canonical
    /// wenshu drag pattern uses the per-row
    /// `.onDrag` to expose the node id; = the drag
    /// destination is the editor's tab strip; = the
    /// drag payload is a SidebarItem enum).
    /// Currently no-op (= the editor's drag-drop
    /// support is a separate ticket; = this hook
    /// is reserved for the future per-row drag).
    // var onDragNode: (() -> NSItemProvider)?

    var body: some View {
        // sidebar fix (= (see OOB.md #2026-09-22) OOB
        // ''): the macOS sidebar List bundled
        // with the `List(data, children:selection:rowContent:)`
        // init (= the OutlineGroup-backed one) does NOT bind
        // selection back to the binding purely via
        // Data.Element.Identifiable.id — Apple HIG sidebar
        // selection requires each row to ALSO carry an explicit
        // `.tag(value)` so the OutlineGroup's selection bridge
        // (= `Binding<SelectionValue?>` ↔ `OutlineGroup` row
        // identity) can find the right row id.
        //
        // Without this .tag, macOS 14+ sidebar List selection
        // silently fails to update the bound selection when the
        // user clicks ANY row (= including top-level shelves,
        // books, AND folder leaves). Symptom: right side cards
        // never change (= persist from last launch); sidebar
        // rows show no selection tint; click → no effect.
        //
        // Reference: Apple Stack Overflow + the macOS 14
        // SwiftUI List(.sidebar) + selection 2-click bug =
        // documented at
        // https://stackoverflow.com/questions/58785044/swiftui-sidebar-list-does-not-register-first-click
        // (= the same class of bug; the .tag fix here is the
        // canonical workaround).
        //
        // for divider rows, override
        // .listRowInsets to zero (= remove the default 16 PT
        // horizontal padding that List(.sidebar) applies to
        // every row) + wrap the Divider in a frame with 10 PT
        // left/right padding (= the standard sidebar inner
        // padding; = the same 10 PT gutter PreviewPane's section
        // header uses). Net result: divider spans from sidebar
        // left edge + 10 PT to sidebar right edge − 10 PT (= full
        // visible width minus the standard inset, NOT flush to
        // the column edge; = the user's ''
        // requirement).
        rowContent
            .listRowInsets(node.kind == .divider
                            ? EdgeInsets(top: DesignTokens.spacingIconic, leading: 0, bottom: DesignTokens.spacingIconic, trailing: 0)
                            : EdgeInsets())
            // v2.7 round-31 (= boss 2026-10-10
            // "分割线也能点选了，分割线
            // 不可点中" directive): divider
            // rows are visual separators, not
            // content rows. The previous code
            // (rounded 1.68f) attached
            // `.tag(node)` to EVERY row
            // (including divider) because the
            // v1.68 era macOS 14+ sidebar
            // List selection bridge needed
            // every row to be addressable;
            // the side-effect was that the
            // divider was selectable (= the
            // user could click the gray line
            // between "长篇网文" and "资料
            // 库" and the row would highlight
            // + the bound `selectedNode`
            // would update to the divider).
            // The fix: only attach
            // `.tag(node)` to NON-divider
            // rows. The OutlineGroup selection
            // bridge (= the `List(_:children:
            // selection:rowContent:)` form
            // used in `AppleSidebarView.swift`)
            // still works because the bridge
            // resolves the selection via
            // `Data.Element.Identifiable.id`
            // for the row; = the divider
            // without a tag simply has no
            // selection value (= clicking
            // divider = no selection update
            // = no highlight; = the divider
            // stays inert).
            .modifier(DividerTagIfNeeded(node: node))
            // v2.7 round-33: per-row context menu (= the
            // right-click hit target IS the row that
            // hosts this menu; = the menu closure
            // captures the row's `node` directly; =
            // the right-click target is always the
            // row the user clicked, regardless of the
            // List's current `selectedNode` value;
            // = boss round-33 "如果当前选中是别
            // 的，但鼠标直接在十二地仙处右
            // 键，点导入，就不能带入" directive).
            // The per-row menu overrides the
            // list-level `forSelectionType:` for
            // single-click right-click; = the list-
            // level forSelectionType still fires for
            // multi-select batch delete (= Apple
            // canonical macOS 14+ sidebar pattern).
            .modifier(PerRowContextMenu(
                node: node,
                callbacks: callbacks
            ))
    }

    /// Applies `.tag(node)` to non-divider rows only
    /// (= the v2.7 round-31 fix for "divider can be
    /// selected" bug). Divider rows are visual
    /// separators (= the gray line between "长篇网
    /// 文" and "资料库" sections); the canonical
    /// macOS sidebar pattern = divider is NOT
    /// clickable, NOT selectable, NOT a context-
    /// menu target.
    private struct DividerTagIfNeeded: ViewModifier {
        let node: SidebarNode
        func body(content: Content) -> some View {
            if node.kind == .divider {
                content
                    // No .tag (= no selection
                    // bridge; = the divider is
                    // invisible to the List's
                    // selection mechanism).
                    .contentShape(Rectangle())
            } else {
                content.tag(node)
            }
        }
    }

    /// Per-row context menu (= the v2.7 round-33
    /// fix for "right-click another row while
    /// another is selected routes the menu to the
    /// SELECTED row"). The closure body captures
    /// the row's `node` directly (= the right-
    /// click hit target IS the row that hosts the
    /// menu).
    private struct PerRowContextMenu: ViewModifier {
        let node: SidebarNode
        let callbacks: SidebarRowCallbacks?
        func body(content: Content) -> some View {
            // Divider rows: NO menu (= Apple HIG
            // = divider is a visual separator; =
            // no selection, no menu, no hover-
            // tint, no right-click action).
            if node.kind == .divider {
                return AnyView(content)
            }
            // Leaf / content rows: per-row menu.
            // The menu closure captures `node`
            // directly (= the right-click target
            // IS this row; = no list-level
            // selection routing). The menu
            // body inlines the buttons
            // directly (= the wenshu canonical
            // sidebar menu has at most 3 rows
            // per right-click target; = the
            // menu shape is small enough that
            // inlining is simpler than a
            // builder helper).
            //
            // macOS 14+ SwiftUI known limitation
            // (= round-35 diagnostic confirmed):
            // \`List(_:children:selection:)\`
            // (= OutlineGroup-backed) does NOT
            // mount the per-row
            // \`.contextMenu(menuItems:)\` until
            // the user has right-clicked ANOTHER
            // row first (= the first right-click
            // on a fresh List's row is silently
            // ignored; = Apple Stack Overflow
            // "macOS List per-row contextMenu
            // first-click ignored"). The boss
            // round-35 accepted this limitation
            // ("那就先放弃，commit 现有能力");
            // the per-row menu IS the canonical
            // path for the second-and-later
            // right-click (= the v2.6 sidebar
            // feedback bundle canonical = the
            // per-row single-click menu is the
            // wenshu UX after the first
            // warm-up). The List-level
            // \`forSelectionType:\` modifier was
            // removed in this commit (= its
            // presence made the first-click
            // bug worse).
            if let callbacks {
                switch node.kind {
                case .shelf:
                    if let shelf = callbacks.resolveShelf(node.id) {
                        return AnyView(content.contextMenu {
                            Button(String(localized: "sidebar_context_menu_new_book_here")) {
                                callbacks.onNewBookHere(shelf.id)
                            }
                            Button(String(localized: "sidebar_context_menu_rename")) {
                                callbacks.onRenameShelf(shelf.id, shelf.name)
                            }
                            Button(
                                String(localized: "sidebar_context_menu_delete"),
                                role: .destructive
                            ) {
                                callbacks.onDeleteShelf(shelf.id, shelf.name)
                            }
                        })
                    }
                case .book:
                    if let book = callbacks.resolveBook(node.id) {
                        return AnyView(content.contextMenu {
                            Button("导入") {
                                callbacks.onImportToBook(book.id)
                            }
                            Button(String(localized: "sidebar_context_menu_rename")) {
                                callbacks.onRenameBook(book.id, book.name)
                            }
                            Button(
                                String(localized: "sidebar_context_menu_delete"),
                                role: .destructive
                            ) {
                                callbacks.onDeleteBook(book.id, book.name)
                            }
                        })
                    }
                case .reference, .referenceCategory, .divider, .tag:
                    return AnyView(content.contextMenu {
                        Button("导入") {
                            callbacks.onImportToReferenceLibrary()
                        }
                    })
                }
            }
            // No callbacks (= dev / preview path;
            // = no menu).
            return AnyView(content)
        }
    }

    /// '\n    /// ': the row body (= split out so the
    /// `.divider` kind can return a different View type without
    /// breaking the `.tag(node)` modifier chain on the parent
    /// View). The `.tag(node)` modifier is applied on the result
    /// in `body` (= uniform regardless of node kind; = the
    /// divider row is still selectable on id so the OutlineGroup
    /// selection bridge stays consistent).
    @ViewBuilder
    private var rowContent: some View {
        // The `.divider` kind renders as a pure horizontal line
        // (= no icon, no title, no subtitle; = just a Divider +
        // small vertical breathing room). Apple HIG section
        // separator idiom.
        //
        // the divider
        // has `.listRowInsets(EdgeInsets(top: 4, leading: 0,
        // bottom: 4, trailing: 0))` applied at the body level
        // (= no horizontal inset from the List); = the Divider
        // here renders flush to the sidebar column edge (= the
        // raw maximum width the List gives to a row = the user
        // asked to remove the .padding(.horizontal, 10) to
        // measure the List's natural divider width before
        // adding the standard inner gutter).
        if node.kind == .divider {
            Divider()
        } else {
            SFLabelRow(
                title: node.title,
                systemImage: node.systemImage,
                subtitle: node.subtitle
            )
        }
    }
}

/// The bag of callbacks that the per-row context
/// menu needs (= the `SidebarRowView` doesn't
/// have access to `AppleSidebarView` directly; =
/// the parent View passes the callbacks down via
/// this struct; = the menu closure captures each
/// callback by value; = the menu always reflects
/// the current AppleSidebarView state without
/// retaining the parent view).
struct SidebarRowCallbacks {
    let onNewBookHere: (UUID) -> Void
    let onRenameShelf: (UUID, String) -> Void
    let onRenameBook: (UUID, String) -> Void
    let onDeleteShelf: (UUID, String) -> Void
    let onDeleteBook: (UUID, String) -> Void
    let resolveShelf: (UUID) -> (id: UUID, name: String)?
    let resolveBook: (UUID) -> (id: UUID, name: String)?
    /// v2.7 (= boss 2026-10-09 round-18 "右键
    /// 点资料库，点导入，进到弹窗后，目标
    /// 自动选好资料库。右键点书的时候目
    /// 标自动选好对应的书" directive).
    let onImportToReferenceLibrary: () -> Void
    let onImportToBook: (UUID) -> Void
}
