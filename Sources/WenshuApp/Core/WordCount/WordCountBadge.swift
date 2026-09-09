//
// WordCountBadge.swift · Wenshu · v0.19 ticket 20 (Obsidian replica,)
//

import Foundation
import SwiftUI

/// WordCountViewModel: @MainActor Observable
@MainActor
@Observable
public final class WordCountViewModel {
    public private(set) var count: WordCount = WordCount(words: 0, characters: 0, charactersNoSpaces: 0, chineseChars: 0, sentences: 0, paragraphs: 0)

    public init() {}

    /// content
    public func update(content: String) {
        self.count = WordCounter.count(content)
    }
}

/// WordCountBadge: SwiftUI View, show badge placeholder
/// LayoutShellView, standalone wait macOS
public struct WordCountBadge: View {
    @State private var viewModel: WordCountViewModel

    public init(viewModel: WordCountViewModel = WordCountViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("auto.wordcountbadge.l33.h32876713"))
                .font(.headline)
            HStack {
                Text(WenshuI18n.t("auto.wordcountbadge.l36.h53222430"))
                Text(WenshuI18n.t("auto.wordcountbadge.l37.h17621913"))
            }
            HStack {
                Text(WenshuI18n.t("auto.wordcountbadge.l40.h86545847"))
                Text(WenshuI18n.t("auto.wordcountbadge.l41.h72922873"))
            }
            HStack {
                Text(WenshuI18n.t("auto.wordcountbadge.l44.h87324247"))
                Text(WenshuI18n.t("auto.wordcountbadge.l45.h78399135"))
            }
        }
        .padding()
    }
}

/// WordCountInlineLabel: tiny inline text for toolbar (v0.22 ticket o09).
/// Reads a WordCountViewModel and renders "1.2k " or "0 " compact text.
/// Use case: Z-TITLE toolbar always-visible word count badge (Apple HIG compact label).
public struct WordCountInlineLabel: View {
    @Bindable var viewModel: WordCountViewModel

    public init(viewModel: WordCountViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let chars = viewModel.count.characters
        let display: String = chars >= 10000
            ? String(format: "%.1fk 字", Double(chars) / 1000.0)
            : chars >= 1000
            ? String(format: "%.1fk 字", Double(chars) / 1000.0)
            : "\(chars) 字"
        Text(display)
            .font(.body)
            .foregroundStyle(.tertiary)
    }
}
