//
// QuickSwitcherWindow.swift · Wenshu · v0.19 ticket 19 (Obsidian replica,)
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

    /// Settings query
    public func setQuery(_ q: String) {
        self.query = q
        self.results = QuickSwitcherIndex.search(query: q, in: allItems)
    }

    /// add note
    public func addItem(_ item: SwitcherItem) {
        allItems.append(item)
    }
}

/// QuickSwitcherWindow: SwiftUI View, ⌘O popupsearch
/// LayoutShellView, standalone wait macOS
public struct QuickSwitcherWindow: View {
    @State private var viewModel: QuickSwitcherViewModel
    @State private var queryText: String = ""

    public init(viewModel: QuickSwitcherViewModel = QuickSwitcherViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("b5.quickswitcherwindow.l45.h21094551"))
                .font(.headline)
            TextField(WenshuI18n.t("auto2.quickswitcherwindow.l47.h24962090"), text: $queryText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.setQuery(queryText)
                }
            Text(WenshuI18n.t("auto.quickswitcherwindow.l52.h4024573"))
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
