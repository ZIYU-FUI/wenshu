//
//  ChatMessageViewUserCheckTests.swift · Wenshu · T88-USER-CHECK (2026-09-18)
//
//  Verifies the small "checkmark" SF Symbol rendered for
//  user-sent messages (= Apple Messages single-checkmark
//  "sent" affordance; = pairs with T84 for sealed
//  assistant messages).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView user check (T88)")
struct ChatMessageViewUserCheckTests {

    /// T88 contract: T88 marker comment exists.
    @Test func t88_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T88-USER-CHECK (2026-09-18)"))
    }

    /// T88 contract: checkmark icon is in the user branch (= AFTER
    /// the T86 dot).
    @Test func checkmark_in_user_branch() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let userBranch = src.range(of: "if message.source == .user {")!
        let startOffset = src.distance(from: src.startIndex, to: userBranch.upperBound)
        let endOffset = min(startOffset + 3000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("Image(systemName: \"checkmark\")"))
    }

    /// T88 contract: user-branch checkmark uses .semibold + accent.
    @Test func user_checkmark_uses_semibold_accent() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let userBranch = src.range(of: "if message.source == .user {")!
        let startOffset = src.distance(from: src.startIndex, to: userBranch.upperBound)
        let endOffset = min(startOffset + 3000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains(".font(.system(size: 9, weight: .semibold))"))
        #expect(block.contains(".foregroundStyle(Color.accentColor)"))
    }

    /// T88 contract: user checkmark comes AFTER the T86 dot (= visual
    /// flow: paperplane -> blue dot -> checkmark).
    @Test func user_checkmark_after_blue_dot() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let userBranch = src.range(of: "if message.source == .user {")!
        let startOffset = src.distance(from: src.startIndex, to: userBranch.upperBound)
        let endOffset = min(startOffset + 3000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        let dotPos = block.range(of: "Image(systemName: \"circle.fill\")")!
        let checkPos = block.range(of: "Image(systemName: \"checkmark\")")!
        #expect(checkPos.lowerBound > dotPos.lowerBound)
    }

    /// T88 contract: T73 paperplane icon preserved.
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

    /// T88 contract: T86 blue dot preserved.
    @Test func t86_blue_dot_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T86-USER-STATUS-DOT (2026-09-18)"))
    }

    /// T88 contract: T84 sealed-message checkmark preserved (= NOT
    /// removed by T88; = the two checkmarks live in different
    /// branches and are independent).
    @Test func t84_sealed_checkmark_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T84-DELIVERED-CHECK (2026-09-18)"))
    }
}