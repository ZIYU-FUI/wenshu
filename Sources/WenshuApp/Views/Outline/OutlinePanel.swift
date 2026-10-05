//
// OutlinePanel.swift
// (= v0.19 ticket 21 Obsidian replica, placeholder shell;
//  OutlineViewModel deleted in A1.1 = 0 external caller (only internal default-init);
//  View rewritten with inline @State; AnyView(OutlinePanel()) caller in PaneView:212 preserved)
//

import Foundation
import SwiftUI

/// OutlinePanel: SwiftUI View, show placeholder
/// AppRootScene, standalone wait macOS
struct OutlinePanel: View {
    @State private var items: [OutlineItem] = []

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "auto.outlinepanel.l35.h85687200"))
                .font(.headline)
            Text(String(localized: "outlinepanel.items_count"))
            ForEach(items) { item in
                HStack {
                    Text(String(repeating: "  ", count: item.level - 1))
                    Text(String(localized: "b5.outlinepanel.l41.h2194654"))
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}
