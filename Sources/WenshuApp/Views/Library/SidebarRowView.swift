// SidebarRowView.swift · Wenshu · v1.68b
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
// v1.68b differs from the reverted v1.68a (= same idea, =
// the boss accepted the architecture but rejected the rest of the
// v1.68a patch because it leaked changes into LibraryStores /
// BookStore.init / 12 test fixtures — none of those are touched
// here).

import SwiftUI

struct SidebarRowView: View {
    let node: SidebarNode

    var body: some View {
        // v1.69 sidebar fix (= boss 2026-09-22 OOB
        // '现在目录树还是点不了'): the macOS sidebar List bundled
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
        rowContent.tag(node)
    }

    /// v1.69bb boss 2026-09-23 OOB '现在把资料库上面也加一条
    /// 分割线': the row body (= split out so the
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
        if node.kind == .divider {
            Divider()
                .padding(.vertical, 4)
        } else {
            HStack(spacing: 6) {
                Image(systemName: node.systemImage)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text(node.title)
                        .font(.body)
                        .lineLimit(1)
                    if let subtitle = node.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
            }
            // macOS 27 standard sidebar row height (= 30 PT
            // chrome row; = the same value the v1.67
            // LazySidebarView used pre-MVVM-split).
            .frame(height: DesignTokens.chromeHeight)
        }
    }
}