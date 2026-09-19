//
//  ChatMessageViewLinkIconTests.swift · Wenshu · T90-LINK-ICON (2026-09-18)
//
//  Verifies the small "link" SF Symbol rendered next
//  to the T75 brain icon for wenshu messages (= Apple
//  HIG "contains links" affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView link icon (T90)")
struct ChatMessageViewLinkIconTests {

    /// T90 contract: T90 marker comment exists.
    @Test func t90_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T90-LINK-ICON (2026-09-18)"))
    }

    /// T90 contract: "link" SF Symbol present in wenshu branch.
    @Test func link_icon_in_wenshu_branch() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        // Find the FIRST wenshu branch in the source label
        // area (= L263-ish).
        let brainPos = src.range(of: "Image(systemName: \"brain.head.profile\")")!
        let startOffset = src.distance(from: src.startIndex, to: brainPos.upperBound)
        let endOffset = min(startOffset + 3000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("Image(systemName: \"link\")"))
    }

    /// T90 contract: link uses .system(size: 9) + .tertiary.
    @Test func link_uses_size_9_tertiary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let linkPos = src.range(of: "Image(systemName: \"link\")")!
        let after = src[linkPos.upperBound...]
        #expect(after.contains(".font(.system(size: 9, weight: .regular))"))
        #expect(after.contains(".foregroundStyle(.tertiary)"))
    }

    /// T90 contract: link icon is INSIDE the wenshu branch (= the
    /// IF that gates it).
    @Test func link_in_wenshu_branch() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        // Find the SECOND .wenshu branch (= L263 = the one
        // with the brain + link icons).
        let firstWenshu = src.range(of: "if message.source == .wenshu {")!
        let secondWenshu = src.range(of: "if message.source == .wenshu {", range: firstWenshu.upperBound..<src.endIndex)!
        let startOffset = src.distance(from: src.startIndex, to: secondWenshu.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("Image(systemName: \"link\")"))
    }

    /// T90 contract: T75 brain icon preserved.
    @Test func t75_brain_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"brain.head.profile\")"))
    }

    /// T90 contract: T71 green dot preserved.
    @Test func t71_green_dot_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".foregroundStyle(.green)"))
    }

    /// T90 contract: T88 user check preserved.
    @Test func t88_user_check_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T88-USER-CHECK (2026-09-18)"))
    }
}