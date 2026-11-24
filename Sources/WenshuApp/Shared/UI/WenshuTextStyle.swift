//
//  WenshuTextStyle.swift
//
//  The product's named text roles, and the one modifier that applies them.
//  Each case is a SwiftUI text style and nothing more: the case owns the
//  role's name, the size and weight belong to the style, which is why this
//  file states no point size. A role that wants a measured number asks the
//  rendering that produced it.
//

import SwiftUI

// MARK: - wenshuFont

/// Applies one of the product's named roles. `.wenshuFont(.body)` is the
/// same call as `.font(.body)` through the enum, so a role can be passed
/// around as a value instead of re-typed at every site.
///
/// Used by: status bar text, hotkey columns, tab titles.
extension View {
    func wenshuFont(_ style: WenshuTextStyle) -> some View {
        self.font(style.font)
    }
}

// MARK: - WenshuTextStyle

/// The product's named text roles, each one a SwiftUI text style.
enum WenshuTextStyle: Sendable, Equatable, CaseIterable {

    /// system `.largeTitle`. Used by: top-level page hero text.
    case largeTitle

    /// system `.title`. Used by: a section title (= h1).
    case title

    /// system `.title2`. Used by: a secondary section title (= h2).
    case title2

    /// system `.title3`. Used by: a tertiary section title (= h3).
    case title3

    /// system `.headline` — the emphasized role. Used by: a card's own title,
    /// list row emphasis.
    case headline

    /// system `.body`. Used by: status bar text, kanban card body.
    case body

    /// system `.callout`. Used by: hotkey combo label, inline instruction.
    case callout

    /// system `.subheadline`. Used by: secondary metadata.
    case subheadline

    /// system `.caption`. Used by: a footnote line, inline metadata.
    case caption

    /// system `.caption2`. Used by: a caption under an icon, chrome detail
    /// text.
    case caption2

    /// system `.footnote`. Used by: footnote text.
    case footnote

    /// The SwiftUI text style the role names.
    var font: Font {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .caption: .caption
        case .caption2: .caption2
        case .footnote: .footnote
        }
    }
}
