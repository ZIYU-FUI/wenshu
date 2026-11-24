//
//  Round6StandaloneSweepTests.swift · Wenshu
//
//  A symbol that sits directly in an `HStack`, a `VStack` or a button's
//  label, with an `imageScale` chain on it, is a glyph the call site
//  sized by hand. Those sites come through `SFIcon`; the `Label` icon
//  slot is the other sweep's subject.
//
//  Three shapes are preserved deliberately: a self-implemented animation
//  chain whose hook the factory does not own; a hero card that sizes its
//  own thumbnail; and Apple's `ContentUnavailableView`, which draws its
//  glyph at the system default.
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Standalone Image(systemName:) sites outside the Label icon slot")
struct Round6StandaloneSweepTests {

    static let exceptionSites: [String] = [
        "Sources/WenshuApp/Features/Chat/View/ChatToolUsePartView.swift:57", // pulse animation chain
        "Sources/WenshuApp/Workspace/PreviewPane.swift:1570", // the hero card's glyph: a hero surface, not a toolbar or an inline row
    ]
}
