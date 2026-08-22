//
//  WordCountBadge.swift · Wenshu · v0.19 ticket 20 (Obsidian replica, 前端做但不接入核心项目)
//

import Foundation
import SwiftUI

/// WordCountViewModel: @MainActor Observable
@MainActor
@Observable
public final class WordCountViewModel {
    public private(set) var count: WordCount = WordCount(words: 0, characters: 0, charactersNoSpaces: 0, chineseChars: 0, sentences: 0, paragraphs: 0)

    public init() {}

    /// 统计 content 字数
    public func update(content: String) {
        self.count = WordCounter.count(content)
    }
}

/// WordCountBadge: SwiftUI View, 显示字数 badge placeholder
/// 现阶段不接 LayoutShellView, 留 standalone 等老板 macOS 验
public struct WordCountBadge: View {
    @State private var viewModel: WordCountViewModel

    public init(viewModel: WordCountViewModel = WordCountViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("字数")
                .font(.headline)
            HStack {
                Text("总字符: \(viewModel.count.characters)")
                Text("去空: \(viewModel.count.charactersNoSpaces)")
            }
            HStack {
                Text("中文字: \(viewModel.count.chineseChars)")
                Text("英文词: \(viewModel.count.words)")
            }
            HStack {
                Text("句: \(viewModel.count.sentences)")
                Text("段: \(viewModel.count.paragraphs)")
            }
        }
        .padding()
    }
}

/// WordCountInlineLabel: tiny inline text for toolbar (v0.22 ticket o09).
/// Reads a WordCountViewModel and renders "1.2k 字" or "0 字" compact text.
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
            .font(.system(size: 13))
            .foregroundStyle(.tertiary)
    }
}
