//
//  CanvasView.swift · Wenshu · v0.19 ticket 13 (Obsidian replica, 前端做但不接入核心项目)
//  老板 2026-08-19 evening 拍 '前端要做但先不接入核心项目'.
//
//  Standalone SwiftUI View + ViewModel, 不接 LayoutShellView, 等老板验 macOS.
//  现阶段只做 ViewModel 数据通路 + View placeholder (跟 ticket 12 BacklinksPanel 同范式).
//

import Foundation
import SwiftUI

/// CanvasViewModel: @MainActor Observable
@MainActor
@Observable
public final class CanvasViewModel {
    public private(set) var document: CanvasDocument = CanvasDocument()
    public private(set) var isLoading: Bool = false
    public private(set) var error: String? = nil

    public init() {}

    /// 从 .canvas 文件路径加载
    public func load(path: String) async {
        self.isLoading = true
        self.error = nil
        defer { self.isLoading = false }

        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            self.document = try JSONCanvasCodec.decode(data)
        } catch {
            self.error = "\(error)"
            self.document = CanvasDocument()
        }
    }

    /// 从字符串加载 (test 用)
    public func loadFromString(_ content: String) {
        self.error = nil
        do {
            self.document = try JSONCanvasCodec.decode(content)
        } catch {
            self.error = "\(error)"
            self.document = CanvasDocument()
        }
    }
}

/// CanvasView: SwiftUI View, 显示 .canvas 文件 (node + edge placeholder)
/// 现阶段不接 LayoutShellView, 留 standalone 等老板 macOS 验
public struct CanvasView: View {
    @State private var viewModel: CanvasViewModel

    public init(viewModel: CanvasViewModel = CanvasViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("画布")
                .font(.headline)
            if viewModel.isLoading {
                Text("加载中…")
            } else if let error = viewModel.error {
                Text("错误: \(error)")
                    .foregroundStyle(.red)
            } else {
                Text("节点数: \(viewModel.document.nodes.count)")
                Text("边数: \(viewModel.document.edges.count)")
                ForEach(viewModel.document.nodes) { node in
                    Text("[\(node.id)] \(node.type.rawValue) @ (\(Int(node.x)),\(Int(node.y)))")
                        .font(.caption2)
                }
            }
        }
        .padding()
    }
}
