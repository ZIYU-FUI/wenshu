//
//  GraphView.swift · Wenshu · v0.19 ticket 14 (Obsidian replica, 前端做但不接入核心项目)
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

    /// 从 link + documentIndex 构建图 + 布局
    public func update(links: [Link], documentIndex: DocumentIndexing) async {
        self.isLoading = true
        self.error = nil
        defer { self.isLoading = false }
        do {
            let fullGraph = await GraphBuilder.build(links: links, documentIndex: documentIndex)
            self.graph = GraphBuilder.layout(fullGraph)
        }
    }

    /// 测试 / 直接设置图
    public func setGraph(_ graph: Graph) {
        self.graph = graph
    }
}

/// GraphView: SwiftUI View, 显示图 placeholder
/// 现阶段不接 LayoutShellView, 留 standalone 等老板 macOS 验
public struct GraphView: View {
    @State private var viewModel: GraphViewModel

    public init(viewModel: GraphViewModel = GraphViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("关系图")
                .font(.headline)
            Text("节点数: \(viewModel.graph.nodes.count)")
            Text("边数: \(viewModel.graph.edges.count)")
            if let error = viewModel.error {
                Text("错误: \(error)")
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
