//
// GraphView.swift
// (= v0.19 ticket 14 Obsidian replica, placeholder shell;
//  GraphViewModel deleted in A1.1 = 0 external caller (only internal default-init);
//  View rewritten with inline @State; AnyView(GraphView()) callers preserved)
//

import Foundation
import SwiftUI

/// GraphView: SwiftUI View, show placeholder
/// AppRootScene, standalone wait macOS
struct GraphView: View {
    @State private var errorMessage: String? = nil

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "auto.graphview.l46.h27522022"))
                .font(.headline)
            Text(String(localized: "graphview.nodes_count"))
            Text(String(localized: "graphview.edges_count"))
            if let _ = errorMessage {
                Text(String(localized: "auto.graphview.l51.h33390865"))
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
