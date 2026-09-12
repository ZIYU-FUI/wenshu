//
// ComposerPanel.swift · Wenshu · v0.19 ticket 16 (Obsidian replica,)
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

    /// execute rename
    public func rename(oldName: String, newName: String, content: String) {
        self.lastOperation = "rename '\(oldName)' → '\(newName)'"
        self.lastResult = NoteComposer.rename(oldName: oldName, newName: newName, content: content)
    }

    /// execute merge
    public func merge(targetName: String, sources: [(name: String, content: String)]) {
        self.lastOperation = "merge \(sources.count) sources → '\(targetName)'"
        self.lastResult = NoteComposer.merge(targetName: targetName, sourceContents: sources)
    }
}

/// ComposerPanel: SwiftUI View, show Composer placeholder
/// LayoutShellView, standalone wait macOS
public struct ComposerPanel: View {
    @State private var viewModel: ComposerViewModel

    public init(viewModel: ComposerViewModel = ComposerViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("auto.composerpanel.l41.h81532393"))
                .font(.headline)
            Text(WenshuI18n.t("auto.composerpanel.l43.h51994109"))
            Text(WenshuI18n.t("auto.composerpanel.l44.h7571830"))
        }
        .padding()
    }
}
