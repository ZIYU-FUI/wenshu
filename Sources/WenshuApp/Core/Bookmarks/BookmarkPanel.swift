//
//  BookmarkPanel.swift · Wenshu · v0.19 ticket 22 (Obsidian replica, 前端做但不接入核心项目)
//

import Foundation
import SwiftUI

/// BookmarkViewModel: @MainActor Observable
@MainActor
@Observable
public final class BookmarkViewModel {
    public private(set) var bookmarks: [Bookmark] = []
    public private(set) var error: String? = nil

    private let store: BookmarkStore?

    public init(store: BookmarkStore? = nil) {
        self.store = store
    }

    /// 加载所有书签
    public func load() async {
        guard let store else {
            self.bookmarks = []
            return
        }
        do {
            self.bookmarks = try await store.list()
            self.error = nil
        } catch {
            self.error = "\(error)"
            self.bookmarks = []
        }
    }
}

/// BookmarkPanel: SwiftUI View, 显示书签 placeholder
/// 现阶段不接 LayoutShellView, 留 standalone 等老板 macOS 验
public struct BookmarkPanel: View {
    @State private var viewModel: BookmarkViewModel

    public init(viewModel: BookmarkViewModel = BookmarkViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("收藏")
                .font(.headline)
            Text("书签数: \(viewModel.bookmarks.count)")
            ForEach(viewModel.bookmarks) { bookmark in
                Text(bookmark.label).font(.caption)
            }
            if let error = viewModel.error {
                Text("错误: \(error)")
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
