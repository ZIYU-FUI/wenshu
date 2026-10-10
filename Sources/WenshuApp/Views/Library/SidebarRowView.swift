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
// b differs from the reverted v1.68a (= same idea, =
// the user accepted the architecture but rejected the rest of the
// a patch because it leaked changes into LibraryStores /
// BookStore.init / 12 test fixtures — none of those are touched
// here).

import SwiftUI

struct SidebarRowView: View {
    let node: SidebarNode

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
    }

    /// Applies `.tag(node)` to non-divider
    /// rows only (= the v2.7 round-31 fix
    /// for "divider can be selected"
    /// bug). Divider rows are visual
    /// separators (= the gray line between
    /// "长篇网文" and "资料库" sections);
    /// the canonical macOS sidebar pattern
    /// = divider is NOT clickable, NOT
    /// selectable, NOT a context-menu
    /// target.
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

    /// '
    /// ': the row body (= split out so the
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
