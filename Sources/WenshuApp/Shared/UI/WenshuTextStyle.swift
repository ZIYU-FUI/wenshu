//
//  WenshuTextStyle.swift
//
//  Text style enum + View extension extracted from IconStyles.swift (= §6.6
//  god-class split: 88 LOC of text-related code moved out). The
//  `WenshuTextStyle` enum is the canonical source for wenshu's text
//  styles (= 9 cases spanning Apple HIG canonical sizes + a few wenshu-
//  specific tuning knobs). The `View.wenshuFont(...)` modifier is the
//  presentational helper (= wraps `SwiftUI.View.font(_:)` with the
//  WenshuTextStyle).
//

import SwiftUI

// MARK: - wenshuFont

/// Convenience modifier that applies a `WenshuTextStyle` (= the HIG
/// text-style API). Production code that previously did
/// `.font(DesignTokens.statusFont)` (= 13 PT ad-hoc) moves to
/// `.wenshuFont(.body)` (= HIG body, same 13 PT default, same
/// Dynamic Type semantics).
///
/// Used by: status bar text, hotkey columns, tab titles.
extension View {
    func wenshuFont(_ style: WenshuTextStyle) -> some View {
        self.font(style.font)
    }
}// MARK: - WenshuTextStyle

/// Apple HIG text-style enum. Each case carries the SwiftUI text-style
/// API (= `.body` / `.callout` / `.caption` / `.title2` / `.footnote`)
/// + the point size (= SwiftUI default; = Apple HIG default).
///
/// The case names walk Apple HIG text-style terminology (= the 2026-09-15
/// 2026-10-01 = "  HIG "; =  case  = Apple
/// Text Style ).
enum WenshuTextStyle: Sendable, Equatable, CaseIterable {

    /// HIG `.largeTitle` (= SwiftUI `.font(.largeTitle)`, default 26 PT).
    /// Used by: top-level page hero text.
    case largeTitle

    /// HIG `.title` (= SwiftUI `.font(.title)`, default 22 PT).
    /// Used by: section titles (= h1).
    case title

    /// HIG `.title2` (= SwiftUI `.font(.title2)`, default 17 PT).
    /// Used by: secondary section titles (= h2).
    case title2

    /// HIG `.title3` (= SwiftUI `.font(.title3)`, default 15 PT).
    /// Used by: tertiary section titles (= h3).
    case title3

    /// HIG `.headline` (= SwiftUI `.font(.headline)`, default 13 PT
    /// semibold). Used by: list row emphasis.
    case headline

    /// HIG `.body` (= SwiftUI `.font(.body)`, default 13 PT regular).
    /// Apple-shipped Mail / Notes body text.
    /// Used by: status bar text (= former `statusFont` 13 PT),
    /// kanban card body.
    case body

    /// HIG `.callout` (= SwiftUI `.font(.callout)`, default 12 PT).
    /// Apple-shipped inline button label.
    /// Used by: hotkey combo label (= former `hotkeyComboFont` 12 PT),
    /// pane tab title (= former `tabTitleFont` 12 PT).
    case callout

    /// HIG `.subheadline` (= SwiftUI `.font(.subheadline)`, default 11 PT).
    /// Used by: secondary metadata.
    case subheadline

    /// HIG `.caption` (= SwiftUI `.font(.caption)`, default 11 PT regular).
    /// Apple-shipped inline footnote.
    /// Used by: runtime CWD display chip (= former `runtimeCwdChipFont`
    /// 11 PT), inline metadata captions.
    case caption

    /// HIG `.caption2` (= SwiftUI `.font(.caption2)`, default 11 PT).
    /// Used by: very small captions.
    case caption2

    /// HIG `.footnote` (= SwiftUI `.font(.footnote)`, default 10 PT).
    /// Used by: footnote text.
    case footnote

    /// SwiftUI text-style API (= the canonical HIG text style).
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

    /// HIG default point size (= SwiftUI text-style default).
    var pointSize: CGFloat {
        switch self {
        case .largeTitle: 26
        case .title: 22
        case .title2: 17
        case .title3: 15
        case .headline, .body: 13
        case .callout: 12
        case .subheadline, .caption, .caption2: 11
        case .footnote: 10
        }
    }
}
