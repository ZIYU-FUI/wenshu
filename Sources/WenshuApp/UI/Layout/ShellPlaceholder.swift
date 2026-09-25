// ShellPlaceholder.swift · Wenshu
//
// Extracted from `NavigationSplitShell.swift`. Canonical icon
// layer = Apple SF Symbols 6 built into macOS 27 (= zero SPM
// dependency). This extracted file uses the SF Symbols version
// via `Image(systemName:)`.

import SwiftUI

struct ShellPlaceholder: View {
    let name: String
    let icon: String
    let hint: String

    var body: some View {
        // Canonical SF Symbols 6 icon layer.
        ContentUnavailableView {
            // 38 PT matches the glyph height Apple's own
            // ContentUnavailableView renders, measured on this machine.
            Label { Text(name) } icon: { Image(systemName: icon).imageScale(.large) }
        } description: {
            Text(hint)
        }
    }
}

