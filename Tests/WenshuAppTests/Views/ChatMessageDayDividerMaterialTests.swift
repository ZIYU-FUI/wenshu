//
//  ChatMessageDayDividerMaterialTests.swift · Wenshu · T39-DIVIDER-MATERIAL (2026-09-18)
//
//  Verifies the new .ultraThinMaterial background capsule on
//  ChatMessageDayDivider (= the visual upgrade from bare text
//  to a Material-anchored pill, = matches Apple HIG sidebar /
//  toolbar chrome).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageDayDivider material (T39)")
struct ChatMessageDayDividerMaterialTests {

    /// T39 contract: source uses .ultraThinMaterial (= the
    /// standard Apple HIG sidebar / toolbar material).
    @Test func source_uses_ultraThinMaterial() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains(".fill(.ultraThinMaterial)"))
    }

    /// T39 contract: source uses Capsule shape (= rounded ends
    /// matching Apple HIG date-pill affordance).
    @Test func source_uses_capsule_shape() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Capsule()"))
    }

    /// T39 contract: the divider still renders the localized label
    /// (= the existing T36 label logic is preserved).
    @Test func existing_label_logic_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.today\")"))
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.yesterday\")"))
    }

    /// T39 contract: the accessibility label is preserved
    /// (= screen readers still announce the divider text).
    @Test func accessibility_label_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains(".accessibilityLabel(\"Chat day separator: \\(label)\")"))
    }

    /// T39 contract: HStack invariant preserved (= this change is
    /// inside ChatMessageDayDivider only; = no ChatView changes).
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        // The divider view is a standalone SwiftUI View (= no HStack
        // inside the chat input is touched).
        #expect(src.contains("public struct ChatMessageDayDivider: View {"))
    }
}