//
//  ChatMessageViewUserStatusDotTests.swift · Wenshu · T86-USER-STATUS-DOT (2026-09-18)
//
//  Verifies the small blue (accent-color) status dot
//  rendered next to the source label on user-sent messages
//  (= Apple HIG outgoing-message affordance; = pairs
//  with T71 green dot for wenshu messages).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView user status dot (T86)")
struct ChatMessageViewUserStatusDotTests {

    /// T86 contract: T86 marker comment exists in the source label area.
    @Test func t86_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T86-USER-STATUS-DOT (2026-09-18)"))
    }

    /// T86 contract: blue accent dot is rendered inside the
    /// user-message branch of the source label row.
    @Test func blue_dot_inside_user_branch() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        // Find the user branch (= L275: appears AFTER both .wenshu
        // branches; = the only branch with `source == .user`)
        let userBranch = src.range(of: "if message.source == .user {")!
        // Use a 1500-char window after the user branch start to
        // extract the block body.
        let startOffset = src.distance(from: src.startIndex, to: userBranch.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("Image(systemName: \"circle.fill\")"))
        #expect(block.contains(".foregroundStyle(Color.accentColor)"))
    }

    /// T86 contract: dot uses .system(size: 6, weight: .bold) (= matches
    /// T71 dot's geometry).
    @Test func dot_uses_size_six_bold() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let userBranch = src.range(of: "if message.source == .user {")!
        let startOffset = src.distance(from: src.startIndex, to: userBranch.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains(".font(.system(size: 6, weight: .bold))"))
    }

    /// T86 contract: T73 paperplane.fill icon preserved for user messages.
    @Test func t73_paperplane_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let userBranch = src.range(of: "if message.source == .user {")!
        let startOffset = src.distance(from: src.startIndex, to: userBranch.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("Image(systemName: \"paperplane.fill\")"))
    }

    /// T86 contract: T71 green dot for wenshu messages preserved (= the
    /// user dot must NOT replace the wenshu dot).
    @Test func t71_wenshu_dot_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("if message.source == .wenshu {"))
        let wenshuBranch = src.range(of: "if message.source == .wenshu {")!
        let branchLimit = min(wenshuBranch.upperBound.utf16Offset(in: src) + 1500, src.utf16.count)
        let limitIdx = src.utf16.index(src.utf16.startIndex, offsetBy: branchLimit)
        let block = String(src[wenshuBranch.upperBound..<limitIdx])
        #expect(block.contains(".foregroundStyle(.green)"))
    }

    /// T86 contract: T75 brain.head.profile icon preserved for wenshu messages.
    @Test func t75_brain_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"brain.head.profile\")"))
    }

    /// T86 contract: T84 checkmark icon preserved in timestamp HStack.
    @Test func t84_checkmark_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"checkmark\")"))
    }
}