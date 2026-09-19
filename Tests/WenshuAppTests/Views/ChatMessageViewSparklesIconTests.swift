//
//  ChatMessageViewSparklesIconTests.swift · Wenshu · T117-SPARKLES-ICON (2026-09-18)
//
//  Verifies the small "sparkles" SF Symbol rendered
//  next to the T116 magnifyingglass icon for wenshu
//  messages (= Apple HIG "AI-powered insight"
//  affordance; = wenshu's brand icon for AI content).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView sparkles icon (T117)")
struct ChatMessageViewSparklesIconTests {

    /// T117 contract: T117 marker comment exists.
    @Test func t117_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T117-SPARKLES-ICON (2026-09-18)"))
    }

    /// T117 contract: sparkles SF Symbol present.
    @Test func sparkles_icon_present() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"sparkles\")"))
    }

    /// T117 contract: sparkles uses .system(size: 9, weight: .regular).
    @Test func sparkles_uses_size_9_regular() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let sparkPos = src.range(of: "Image(systemName: \"sparkles\")")!
        let after = src[sparkPos.upperBound...]
        #expect(after.contains(".font(.system(size: 9, weight: .regular))"))
    }

    /// T117 contract: sparkles uses .tertiary tone.
    @Test func sparkles_uses_tertiary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let sparkPos = src.range(of: "Image(systemName: \"sparkles\")")!
        let after = src[sparkPos.upperBound...]
        #expect(after.contains(".foregroundStyle(.tertiary)"))
    }

    /// T117 contract: sparkles AFTER magnifyingglass icon (= correct visual order).
    @Test func sparkles_after_magnifyingglass() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        // Find the FIRST magnifyingglass (= T116).
        let mgPos = src.range(of: "Image(systemName: \"magnifyingglass\")")!
        // Find the magnifyingglass + the sparkles
        // after it (= the sparkles in the same HStack
        // block = the T117 one). The earlier `sparkles`
        // (= the streaming placeholder at L222) is
        // BEFORE the magnifyingglass and is NOT the
        // T117 sparkles we care about.
        let startIdx = mgPos.upperBound
        guard let sparkPos = src.range(of: "Image(systemName: \"sparkles\")", range: startIdx..<src.endIndex) else {
            #expect(Bool(false), "expected sparkles after magnifyingglass")
            return
        }
        #expect(sparkPos.lowerBound > mgPos.lowerBound)
    }

    /// T117 contract: T116 magnifyingglass icon preserved.
    @Test func t116_magnifyingglass_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T116-MICROSCOPE-ICON (2026-09-18)"))
    }

    /// T117 contract: T111 flask icon preserved.
    @Test func t111_flask_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T111-FLASK-ICON (2026-09-18)"))
    }

    /// T117 contract: T75 brain icon preserved.
    @Test func t75_brain_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"brain.head.profile\")"))
    }
}