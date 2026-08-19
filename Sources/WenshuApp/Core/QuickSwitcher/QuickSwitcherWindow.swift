//
//  QuickSwitcherWindow.swift · Wenshu · v0.19 ticket 19 (Obsidian replica, 前端做但不接入核心项目)
//

import Foundation
import SwiftUI

/// QuickSwitcherViewModel: @MainActor Observable
@MainActor
@Observable
public final class QuickSwitcherViewModel {
    public private(set) var query: String = ""
    public private(set) var results: [SwitcherItem] = []

    private var allItems: [SwitcherItem]

    public init(items: [SwitcherItem] = []) {
        self.allItems = items
    }

    /// 设置 query
    public func setQuery(_ q: String) {
        self.query = q
        self.results = QuickSwitcherIndex.search(query: q, in: allItems)
    }

    /// 添加 note 进索引
    public func addItem(_ item: SwitcherItem) {
        allItems.append(item)
    }
}

/// QuickSwitcherWindow: SwiftUI View, ⌘O 弹出式搜索
/// 现阶段不接 LayoutShellView, 留 standalone 等老板 macOS 验
public struct QuickSwitcherWindow: View {
    @State private var viewModel: QuickSwitcherViewModel
    @State private var queryText: String = ""

    public init(viewModel: QuickSwitcherViewModel = QuickSwitcherViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quick Switcher")
                .font(.headline)
            TextField("搜索 note...", text: $queryText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.setQuery(queryText)
                }
            Text("结果数: \(viewModel.results.count)")
            ForEach(viewModel.results) { item in
                VStack(alignment: .leading) {
                    Text(item.title).font(.caption.bold())
                    if let subtitle = item.subtitle {
                        Text(subtitle).font(.caption2)
                    }
                }
            }
        }
        .padding()
    }
}
