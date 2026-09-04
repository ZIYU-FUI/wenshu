//
//  BacklinksPanel.swift · Wenshu · v0.19 ticket 12 (Obsidian replica, 前端做但不接入核心项目)
//  老板 2026-08-19 evening 拍 '前端要做但先不接入核心项目'.
//
//  Standalone SwiftUI View + ViewModel, 不接 LayoutShellView, 等老板验 macOS.
//  ViewModel 跟 v0.18 ticket 04 AgentRuntime 同范式: @MainActor + Observable (苹果 Swift 6 strict concurrency).
//
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
//  业务语言描述 (老板懂):
//  - BacklinksPanel 是 SwiftUI View, 给一个 docId 显示所有引用它的 source 链接
//  - 现阶段只做 ViewModel 渲染逻辑, View 体留 placeholder (老板 macOS 验后再补 .body 接入)
//

import Foundation
import SwiftUI

/// BacklinksViewModel: @MainActor Observable, 给 SwiftUI View 用的渲染数据源
@MainActor
@Observable
public final class BacklinksViewModel {
    public private(set) var docId: String = ""
    public private(set) var backlinks: [Link] = []
    public private(set) var isLoading: Bool = false
    public private(set) var error: String? = nil

    private let resolver: BacklinkResolver?
    private let documentIndex: DocumentIndexing?

    public init(resolver: BacklinkResolver? = nil, documentIndex: DocumentIndexing? = nil) {
        self.resolver = resolver
        self.documentIndex = documentIndex
    }

    /// 加载指定 docId 的 backlinks
    public func load(docId: String) async {
        self.docId = docId
        self.isLoading = true
        self.error = nil
        defer { self.isLoading = false }

        guard let resolver else {
            // 老板 macOS 验后再接 resolver. 现阶段返回空数组
            self.backlinks = []
            return
        }
        do {
            let result = try await resolver.backlinks(forDocId: docId)
            self.backlinks = result
        } catch {
            self.error = "\(error)"
            self.backlinks = []
        }
    }
}

/// BacklinksPanel: SwiftUI View, 右栏显示当前 note 的 backlinks
/// 现阶段不接 LayoutShellView, 留 standalone 等老板 macOS 验
public struct BacklinksPanel: View {
    @State private var viewModel: BacklinksViewModel

    public init(viewModel: BacklinksViewModel = BacklinksViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        // placeholder: 老板 macOS 验后再补实际渲染
        // 现阶段只显示 docId + backlinks 数量, 验证 ViewModel 数据通路
        VStack(alignment: .leading, spacing: 8) {
            Text("反链")
                .font(.headline)
            if viewModel.isLoading {
                Text("加载中…")
            } else if let error = viewModel.error {
                Text("错误: \(error)")
                    .foregroundStyle(.red)
            } else {
                Text("文档 ID: \(viewModel.docId)")
                    .font(.caption)
                Text("链接数: \(viewModel.backlinks.count)")
                ForEach(viewModel.backlinks, id: \.offset) { link in
                    Text("→ \(link.sourceDocId) @ \(link.line):\(link.offset)")
                        .font(.caption2)
                }
            }
        }
        .padding()
    }
}
