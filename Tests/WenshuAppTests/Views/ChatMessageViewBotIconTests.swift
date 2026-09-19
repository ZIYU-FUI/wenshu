//
//  ChatMessageViewBotIconTests.swift · Wenshu · T75-BOT-ICON (2026-09-18)
//
//  Verifies the small "brain.head.profile" SF Symbol rendered
//  for wenshu messages in the source label row (= Apple HIG
//  AI/assistant identity affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView bot icon (T75)")
struct ChatMessageViewBotIconTests {

    /// T75 contract: source uses Image(systemName: "brain.head.profile").
    @Test func source_uses_brain_head_profile() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"brain.head.profile\")"))
    }

    /// T75 contract: icon uses .system(size: 10, weight: .regular)
    /// + .secondary foregroundStyle.
    @Test func icon_uses_system_size_10_secondary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let iconPos = src.range(of: "Image(systemName: \"brain.head.profile\")")!
        let endOffset = src.distance(from: src.startIndex, to: iconPos.upperBound) + 200
        let startOffset = src.distance(from: src.startIndex, to: iconPos.lowerBound)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let iconBlock = String(src[startIdx..<endIdx])
        #expect(iconBlock.contains(".font(.system(size: 10, weight: .regular))"))
        #expect(iconBlock.contains(".foregroundStyle(.secondary)"))
    }

    /// T75 contract: icon gated on source == .wenshu (= only
    /// assistant messages get the brain icon).
    @Test func icon_gated_on_wenshu_source() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        // Source has TWO `if message.source == .wenshu` blocks now
        // (= T71 dot + T75 brain icon = both gated by same condition).
        let count = src.components(separatedBy: "if message.source == .wenshu {").count - 1
        #expect(count >= 2, "expected at least 2 .wenshu source gates (T71 dot + T75 brain); got \(count)")
    }

    /// T75 contract: T71 status dot preserved.
    @Test func t71_status_dot_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"circle.fill\")"))
    }

    /// T75 contract: T73 user paperplane icon preserved.
    @Test func t73_user_paperplane_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"paperplane.fill\")"))
    }

    /// T75 contract: T17 reasoning pulse preserved (= brain icon
    /// is the same family as the T17 reasoning icon).
    @Test func t17_reasoning_pulse_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".opacity(isRunning ? runningOpacity : 1.0)"))
    }
}