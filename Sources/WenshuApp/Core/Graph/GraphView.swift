//
// GraphView.swift · Wenshu · v0.19 ticket 14 (Obsidian replica,)
//

import Foundation
import SwiftUI

/// GraphViewModel: @MainActor Observable
@MainActor
@Observable
public final class GraphViewModel {
    public private(set) var graph: Graph = Graph()
    public private(set) var isLoading: Bool = false
    public private(set) var error: String? = nil

    public init() {}

    /// link + documentIndex build + layout
    public func update(links: [Link], documentIndex: DocumentIndexing) async {
        self.isLoading = true
        self.error = nil
        defer { self.isLoading = false }
        do {
            let fullGraph = await GraphBuilder.build(links: links, documentIndex: documentIndex)
            self.graph = GraphBuilder.layout(fullGraph)
        }
    }

    /// Test / Direct Settings
    public func setGraph(_ graph: Graph) {
        self.graph = graph
    }
}

/// GraphView: SwiftUI View, show placeholder
/// LayoutShellView, standalone wait macOS
public struct GraphView: View {
    @State private var viewModel: GraphViewModel

    public init(viewModel: GraphViewModel = GraphViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("auto.graphview.l46.h27522022"))
                .font(.headline)
            Text(WenshuI18n.t("graphview.nodes_count"))
            Text(WenshuI18n.t("graphview.edges_count"))
            if let error = viewModel.error {
                Text(WenshuI18n.t("auto.graphview.l51.h33390865"))
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
