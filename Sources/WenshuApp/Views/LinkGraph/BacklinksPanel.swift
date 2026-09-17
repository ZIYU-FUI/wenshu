//
// BacklinksPanel.swift · Wenshu · migrated from Core/LinkGraph/BacklinksPanel.swift in v1.28 A1.1
// (= v0.19 ticket 12 Obsidian replica; View separated from ViewModel)
//

import Foundation
import SwiftUI

/// BacklinksPanel: SwiftUI View, show note backlinks
/// LayoutShellView, standalone wait macOS
public struct BacklinksPanel: View {
    @State private var viewModel: BacklinksViewModel

    public init(viewModel: BacklinksViewModel = BacklinksViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        // placeholder: macOS
        // show docId + backlinks, verify ViewModel
        //
        // v0.40 POLISH-LIQUIDGLASS-005 (= 9/5 boss OOB 'apply Liquid
        // Glass to menu popovers + dropdown panels + context menus'):
        // .background { Color.clear.glassEffect(.regular) } applied
        // AFTER .padding() so the canonical Apple Liquid Glass material
        // (= semitransparent, blurs content behind, dark/light adaptive,
        // adapts to Reduce Transparency + Increase Contrast per Apple HIG)
        // fills the BacklinksPanel's outer content rect (= the VStack +
        // its inner padding). Identical pattern to POLISH-LIQUIDGLASS-
        // 001/002/003/004 (= 950e46423 / 74b22f73a / be2bfc62d /
        // dfd97d0e7) per the boss 2026-09-02 hard rule 'every color
        // comes from an Apple API; .glassEffect IS the Apple Liquid
        // Glass primitive; adding a separate RoundedRectangle
        // strokeBorder or .shadow would duplicate what .glassEffect
        // already supplies'.
        //
        // BacklinksPanel IS the only custom popover root view in the
        // wenshu codebase. All other popover-like surfaces (= SwiftUI
        // native Menu { } label: { } blocks + Picker(...).pickerStyle
        // (.menu) blocks + .contextMenu { } blocks + .alert(...) +
        // .confirmationDialog(...)) are Apple system-rendered with the
        // native Liquid Glass treatment on macOS 27 Tahoe (= no custom
        // view body exists to apply .background to; Apple owns the
        // styling per HIG). Same Apple-API-first rationale documented
        // in dfd97d0e7 (= POLISH-LIQUIDGLASS-004 modal sheets commit
        // body for .alert / .confirmationDialog).
        VStack(alignment: .leading, spacing: 8) {
            Text(WenshuI18n.t("auto.backlinkspanel.l95.h69157839"))
                .font(.headline)
            if viewModel.isLoading {
                Text(WenshuI18n.t("auto.backlinkspanel.l98.h65489296"))
            } else if let _ = viewModel.error {
                Text(WenshuI18n.t("auto.backlinkspanel.l100.h25269061"))
                    .foregroundStyle(.red)
            } else {
                Text(WenshuI18n.t("backlinks.document_id"))
                    .font(.caption)
                Text(WenshuI18n.t("backlinks.links_count"))
                ForEach(viewModel.backlinks, id: \.offset) { link in
                    Text(WenshuI18n.t("b5.backlinkspanel.l107.h31356346"))
                        .font(.caption2)
                }
            }
        }
        .padding()
        // v0.40 boss real-device test 2026-09-07: removed
        // .glassEffect(.regular) (= Liquid Glass panel background);
        // now uses Color.clear.
        .background { Color.clear }
    }
}
