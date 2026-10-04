//
// GraphView.swift
// (= v0.19 ticket 14 Obsidian replica, placeholder shell;
//  GraphViewModel deleted in A1.1 = 0 external caller (only internal default-init);
//  View rewritten with inline @State; AnyView(GraphView()) callers in PaneView:163 + WorkspaceView:473 preserved)
//

import Foundation
import SwiftUI

/// GraphView: SwiftUI View, show placeholder
/// LayoutShellView [no longer defined post-v0.72 — see AppRootScene + NavigationSplitView (= per ADR-0011)], standalone wait macOS
struct GraphView: View {
    @State private var isLoading: Bool = false
    @State private var error: String? = nil

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("auto.graphview.l46.h27522022"))
                .font(.headline)
            Text(WenshuI18n.t("graphview.nodes_count"))
            Text(WenshuI18n.t("graphview.edges_count"))
            if let _ = error {
                Text(WenshuI18n.t("auto.graphview.l51.h33390865"))
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
