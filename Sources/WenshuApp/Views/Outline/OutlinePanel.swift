//
// OutlinePanel.swift · Wenshu · migrated from Core/Outline/OutlinePanel.swift in v1.28 A1.1
// (= v0.19 ticket 21 Obsidian replica, placeholder shell;
//  OutlineViewModel deleted in A1.1 = 0 external caller (only internal default-init);
//  View rewritten with inline @State; AnyView(OutlinePanel()) caller in ZoneModuleView:212 preserved)
//

import Foundation
import SwiftUI

/// OutlinePanel: SwiftUI View, show placeholder
/// LayoutShellView, standalone wait macOS
public struct OutlinePanel: View {
    @State private var items: [OutlineItem] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("auto.outlinepanel.l35.h85687200"))
                .font(.headline)
            Text(WenshuI18n.t("outlinepanel.items_count"))
            ForEach(items) { item in
                HStack {
                    Text(String(repeating: "  ", count: item.level - 1))
                    Text(WenshuI18n.t("b5.outlinepanel.l41.h2194654"))
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}
