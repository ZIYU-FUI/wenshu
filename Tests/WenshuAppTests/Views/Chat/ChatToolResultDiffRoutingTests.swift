//
//  ChatToolResultDiffRoutingTests.swift · wenshu · chat-diff-preview 2026-09-28 T3
//
//  RED tests for Phase 3: ChatToolResultPartView routes a tool result
//  whose content is a JSON envelope with `kind:"diff"` into the
//  ChatToolDiffPreview (= the hermes 0.21.5 file-edit preview card
//  surface, 1:1 mirrored here). Plain-text / non-diff envelopes fall
//  through to the existing markdown render path.
//
//  Pure parser test (= no SwiftUI render host needed).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatToolResult diff routing (chat-diff-preview 2026-09-28 T3)")
struct ChatToolResultDiffRoutingTests {

    @Test("extracts a chat-tool diff payload from a kind:'diff' JSON envelope")
    func extractsDiffFromEnvelope() throws {
        let envelope = """
        {
          "ok": true,
          "action": "update",
          "kind": "diff",
          "diff": {
            "path": "chapters/abc.md",
            "old_text": "before",
            "new_text": "after",
            "stats": {
              "added_chars": 5,
              "removed_chars": 6,
              "added_lines": 1,
              "removed_lines": 1
            }
          },
          "diff_text": "--- old\\n+++ new\\n@@\\n-before\\n+after\\n"
        }
        """
        let parsed = ChatToolResultPartView.extractDiffPayload(from: envelope)
        #expect(parsed != nil, "kind:'diff' envelope must surface the diff payload")
        #expect(parsed?.path == "chapters/abc.md")
        #expect(parsed?.oldText == "before")
        #expect(parsed?.newText == "after")
        #expect(parsed?.addedChars == 5)
        #expect(parsed?.removedChars == 6)
        #expect(parsed?.body.contains("-before") == true)
        #expect(parsed?.body.contains("+after") == true)
    }

    @Test("non-diff JSON envelope returns nil (= fall through to markdown render)")
    func nonDiffEnvelopeReturnsNil() throws {
        let envelope = "{\"ok\": true, \"action\": \"create\", \"chapter\": {\"id\": \"abc\"}}"
        let parsed = ChatToolResultPartView.extractDiffPayload(from: envelope)
        #expect(parsed == nil)
    }

    @Test("plain-text tool result returns nil (= markdown render path unchanged)")
    func plainTextResultReturnsNil() throws {
        let parsed = ChatToolResultPartView.extractDiffPayload(
            from: "chapter #1 created at /books/abc/chapters/xyz.md"
        )
        #expect(parsed == nil)
    }

    @Test("malformed JSON returns nil (= parser never crashes)")
    func malformedJsonReturnsNil() throws {
        let parsed = ChatToolResultPartView.extractDiffPayload(from: "not json")
        #expect(parsed == nil)
    }
}