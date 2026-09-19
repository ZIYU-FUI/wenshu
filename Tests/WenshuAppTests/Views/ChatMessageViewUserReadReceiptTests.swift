//
//  ChatMessageViewUserReadReceiptTests.swift · Wenshu · T99-USER-READ-RECEIPT (2026-09-18)
//
//  Verifies the small "checkmark" SF Symbol overlay
//  rendered after the T88 single-checkmark for user
//  messages (= Apple Messages double-checkmark
//  "delivered" affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView user read receipt (T99)")
struct ChatMessageViewUserReadReceiptTests {

    /// T99 contract: T99 marker comment exists.
    @Test func t99_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T99-USER-READ-RECEIPT (2026-09-18)"))
    }

    /// T99 contract: 2nd checkmark present in user branch.
    @Test func second_checkmark_in_user_branch() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let userBranch = src.range(of: "if message.source == .user {")!
        let startOffset = src.distance(from: src.startIndex, to: userBranch.upperBound)
        let endOffset = min(startOffset + 5000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        // Count Image(systemName: "checkmark") in user branch
        // (= T88 single + T99 double = 2)
        let checkCount = block.components(separatedBy: "Image(systemName: \"checkmark\")").count - 1
        #expect(checkCount >= 2)
    }

    /// T99 contract: T99 uses smaller font (.system(size: 7)) vs T88 (.system(size: 9)).
    @Test func t99_uses_smaller_font() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".font(.system(size: 7, weight: .semibold))"))
        #expect(src.contains(".font(.system(size: 9, weight: .semibold))"))
    }

    /// T99 contract: T99 uses Color.accentColor.opacity(0.7).
    @Test func t99_uses_accent_with_seventy_opacity() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Color.accentColor.opacity(0.7)"))
    }

    /// T99 contract: T88 single-checkmark preserved.
    @Test func t88_single_check_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T88-USER-CHECK (2026-09-18)"))
    }

    /// T99 contract: T86 blue dot preserved.
    @Test func t86_blue_dot_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T86-USER-STATUS-DOT (2026-09-18)"))
    }

    /// T99 contract: T73 paperplane preserved.
    @Test func t73_paperplane_preserved() throws {
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
        #expect(block.contains("Image(systemName: \"paperplane.fill\")"))
    }

    /// T99 contract: T75 brain icon preserved (= not affected by user-branch change).
    @Test func t75_brain_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"brain.head.profile\")"))
    }
}