//
//  Core/Agent/Librarian/BookChapterToolDiffTests.swift · chat-diff-preview 2026-09-28 T2
//
//  RED tests for Phase 2: BookChapterTool.update's success envelope
//  carries a `kind:"diff"` block (= {diff, old_text, new_text,
//  added_chars, removed_chars}) so ChatToolResultPartView can route
//  the result into ChatToolDiffPreview. Mirrors hermes 0.21.5
//  `tool-fallback.tsx` augmenting the diff metadata for file-edit
//  tools (= write_file, edit_file, patch).
//
//  The test runs against an in-memory chapter store (= on-disk
//  fixture pattern used elsewhere in BookChapterTool tests).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("BookChapterTool.update diff envelope (chat-diff-preview 2026-09-28 T2)")
struct BookChapterToolDiffEnvelopeTests {

    @Test("update envelope carries kind='diff' with diff text and +/- char counts")
    func updateEnvelopeHasDiff() throws {
        // Drive the actor with a fresh on-disk chapter = real BookChapterTool
        // path. We point its bookDirectoryProvider at a tmp dir; = chapter
        // ID is generated, body is written, then update with new body
        // should produce a diff envelope.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookChapterToolDiffEnvelopeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let actor = BookChapterActor(
            bookDirectoryProvider: { tmp },
            currentChatBookIDProvider: { nil }
        )
        // Use the structured execute API (= same as ToolExecutor.invokeTool).
        let createdEnvelope: [String: Any] = [
            "action": "create",
            "title": "第一章 测试",
            "summary": "测试用",
            "markdown": "第一行原文。\n第二行原文。\n"
        ]
        guard let createdJSON = try JSONSerialization.data(
            withJSONObject: createdEnvelope,
            options: []
        ).toJSONString() else {
            Issue.record("JSONSerialization failed"); return
        }
        let createdResult = try awaitDirect(actor: actor, input: createdJSON)
        // createdResult.ok == true + id present
        guard case .success(let payload) = createdResult,
              let chapter = payload["chapter"] as? [String: Any],
              let idString = chapter["id"] as? String,
              let id = UUID(uuidString: idString) else {
            Issue.record("create did not return a chapter id"); return
        }

        // Now update with a different body.
        let updateEnvelope: [String: Any] = [
            "action": "update",
            "id": idString,
            "title": "第一章 测试",
            "markdown": "第一行原文改成新增。\n第二行原文。\n第三行全新。\n"
        ]
        guard let updateJSON = try JSONSerialization.data(
            withJSONObject: updateEnvelope,
            options: []
        ).toJSONString() else {
            Issue.record("JSONSerialization failed"); return
        }
        let updateResult = try awaitDirect(actor: actor, input: updateJSON)
        guard case .success(let updatePayload) = updateResult else {
            Issue.record("update did not succeed"); return
        }
        // The envelope must carry the diff-friendly block.
        #expect(updatePayload["kind"] as? String == "diff")
        let diffPayload = updatePayload["diff"] as? [String: Any]
        #expect(diffPayload != nil, "update envelope must carry a diff block")
        #expect(diffPayload?["path"] as? String == "chapters/<id>.md" || diffPayload?["path"] is String)
        let stats = diffPayload?["stats"] as? [String: Any]
        #expect(stats?["added_chars"] is Int)
        #expect(stats?["removed_chars"] is Int)
        let addedChars = stats?["added_chars"] as? Int ?? 0
        let removedChars = stats?["removed_chars"] as? Int ?? 0
        // The new text added ~10 chars on the first changed line + new line 3.
        #expect(addedChars > 0)
        #expect(removedChars > 0)
    }
}

// Local helpers (= avoid spreading JSON wrappers across the suite).

enum BookChapterTestToolResult {
    case success([String: Any])
    case failure(String)
}

private func awaitDirect(actor: BookChapterActor, input: String) throws -> BookChapterTestToolResult {
    // BookChapterActor.execute is async — wrap synchronously via a semaphore
    // so the @Test bodies stay non-async.
    let sema = DispatchSemaphore(value: 0)
    var captured: BookChapterTestToolResult = .failure("did-not-run")
    Task.detached {
        let text = try await actor.execute(input: input)
        let data = Data(text.utf8)
        if let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if obj["ok"] as? Bool == true {
                captured = .success(obj)
            } else {
                captured = .failure(obj["error"] as? String ?? "unknown")
            }
        } else {
            captured = .failure("not-json: \(text)")
        }
        sema.signal()
    }
    sema.wait()
    return captured
}

private extension Data {
    /// Wrap Data -> JSON string for the input pipeline.
    func toJSONString() -> String? {
        guard let s = String(data: self, encoding: .utf8) else { return nil }
        return s
    }
}
