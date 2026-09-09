//
// BookmarkPanel.swift · Wenshu · v0.19 ticket 22 (Obsidian replica,)
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

    /// Load all bookmarks
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

/// BookmarkPanel: SwiftUI View, show placeholder
/// LayoutShellView, standalone wait macOS
public struct BookmarkPanel: View {
    @State private var viewModel: BookmarkViewModel

    public init(viewModel: BookmarkViewModel = BookmarkViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("auto.bookmarkpanel.l48.h89923504"))
                .font(.headline)
            Text(WenshuI18n.t("auto.bookmarkpanel.l50.h68931603"))
            ForEach(viewModel.bookmarks) { bookmark in
                Text(bookmark.label).font(.caption)
            }
            if let error = viewModel.error {
                Text(WenshuI18n.t("auto.bookmarkpanel.l55.h42196043"))
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
