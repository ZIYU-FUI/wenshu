//
// GraphView.swift · Wenshu · migrated from Core/Graph/GraphView.swift in v1.28 A1.1
// (= v0.19 ticket 14 Obsidian replica, placeholder shell;
//  GraphViewModel deleted in A1.1 = 0 external caller (only internal default-init);
//  View rewritten with inline @State; AnyView(GraphView()) callers in PaneView:163 + WorkspaceView:473 preserved)
//

import Foundation
import SwiftUI

/// GraphView: SwiftUI View, show placeholder
/// LayoutShellView [no longer defined post-v0.72 — AppRootScene + NavigationSplitView; = ADR-0007 pending ADR-0010; = type references kept as historical landmarks pending 老板 拍], standalone wait macOS
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
