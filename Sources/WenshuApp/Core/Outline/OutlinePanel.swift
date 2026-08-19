//
//  OutlinePanel.swift · Wenshu · v0.19 ticket 21 (Obsidian replica, 前端做但不接入核心项目)
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

    /// 解析 markdown content, 更新 outline
    public func update(content: String) {
        self.items = OutlineExtractor.extract(content)
        self.tree = OutlineExtractor.tree(from: items)
    }
}

/// OutlinePanel: SwiftUI View, 显示大纲 placeholder
/// 现阶段不接 LayoutShellView, 留 standalone 等老板 macOS 验
public struct OutlinePanel: View {
    @State private var viewModel: OutlineViewModel

    public init(viewModel: OutlineViewModel = OutlineViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Outline")
                .font(.headline)
            Text("条目数: \(viewModel.items.count)")
            ForEach(viewModel.items) { item in
                HStack {
                    Text(String(repeating: "  ", count: item.level - 1))
                    Text("#\(item.level) \(item.title)")
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}
