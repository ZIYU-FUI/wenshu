//
// OutlinePanel.swift · Wenshu · v0.19 ticket 21 (Obsidian replica,)
//

import Foundation
import SwiftUI

/// OutlineViewModel: @MainActor Observable
@MainActor
@Observable
public final class OutlineViewModel {
    public private(set) var items: [OutlineItem] = []
    public private(set) var tree: [OutlineNode] = []

    public init() {}

    /// markdown content, update outline
    public func update(content: String) {
        self.items = OutlineExtractor.extract(content)
        self.tree = OutlineExtractor.tree(from: items)
    }
}

/// OutlinePanel: SwiftUI View, show placeholder
/// LayoutShellView, standalone wait macOS
public struct OutlinePanel: View {
    @State private var viewModel: OutlineViewModel

    public init(viewModel: OutlineViewModel = OutlineViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("auto.outlinepanel.l35.h85687200"))
                .font(.headline)
            Text(WenshuI18n.t("outlinepanel.items_count"))
            ForEach(viewModel.items) { item in
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
