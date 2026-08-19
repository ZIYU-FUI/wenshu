//
//  ComposerPanel.swift · Wenshu · v0.19 ticket 16 (Obsidian replica, 前端做但不接入核心项目)
//

import Foundation
import SwiftUI

/// ComposerViewModel: @MainActor Observable
@MainActor
@Observable
public final class ComposerViewModel {
    public private(set) var lastOperation: String = ""
    public private(set) var lastResult: String = ""

    public init() {}

    /// 执行 rename
    public func rename(oldName: String, newName: String, content: String) {
        self.lastOperation = "rename '\(oldName)' → '\(newName)'"
        self.lastResult = NoteComposer.rename(oldName: oldName, newName: newName, content: content)
    }

    /// 执行 merge
    public func merge(targetName: String, sources: [(name: String, content: String)]) {
        self.lastOperation = "merge \(sources.count) sources → '\(targetName)'"
        self.lastResult = NoteComposer.merge(targetName: targetName, sourceContents: sources)
    }
}

/// ComposerPanel: SwiftUI View, 显示 Composer 操作 placeholder
/// 现阶段不接 LayoutShellView, 留 standalone 等老板 macOS 验
public struct ComposerPanel: View {
    @State private var viewModel: ComposerViewModel

    public init(viewModel: ComposerViewModel = ComposerViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Composer")
                .font(.headline)
            Text("上次操作: \(viewModel.lastOperation)")
            Text("结果字符数: \(viewModel.lastResult.count)")
        }
        .padding()
    }
}
