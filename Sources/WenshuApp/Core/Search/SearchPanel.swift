//
//  SearchPanel.swift · Wenshu · v0.19 ticket 17 (Obsidian replica, 前端做但不接入核心项目)
//

import Foundation
import SwiftUI

/// SearchViewModel: @MainActor Observable
@MainActor
@Observable
public final class SearchViewModel {
    public private(set) var query: String = ""
    public private(set) var results: [SearchResult] = []
    public private(set) var isLoading: Bool = false
    public private(set) var error: String? = nil

    private let search: FullTextSearch?

    public init(search: FullTextSearch? = nil) {
        self.search = search
    }

    /// 设置 query (debounce 留给 View 层)
    public func setQuery(_ q: String) {
        self.query = q
    }

    /// 跑搜索
    public func runSearch() async {
        guard let search else {
            self.results = []
            return
        }
        guard !query.isEmpty else {
            self.results = []
            return
        }
        self.isLoading = true
        self.error = nil
        defer { self.isLoading = false }
        do {
            self.results = try await search.search(query: query)
        } catch {
            self.error = "\(error)"
            self.results = []
        }
    }
}

/// SearchPanel: SwiftUI View, 全文搜索结果列表
/// 现阶段不接 LayoutShellView, 留 standalone 等老板 macOS 验
public struct SearchPanel: View {
    @State private var viewModel: SearchViewModel
    @State private var queryText: String = ""

    public init(viewModel: SearchViewModel = SearchViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("搜索")
                .font(.headline)
            TextField("搜索…", text: $queryText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.setQuery(queryText)
                    Task { await viewModel.runSearch() }
                }
            if viewModel.isLoading {
                Text("搜索中…")
            } else if let error = viewModel.error {
                Text("错误: \(error)")
                    .foregroundStyle(.red)
            } else {
                Text("结果数: \(viewModel.results.count)")
                ForEach(viewModel.results, id: \.docId) { result in
                    VStack(alignment: .leading) {
                        Text(result.docId).font(.caption.bold())
                        Text(result.snippet).font(.caption2)
                    }
                }
            }
        }
        .padding()
    }
}
