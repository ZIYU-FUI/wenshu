//
//  Core/Agent/Librarian/BookChapterToolDiffTests.swift · chat-diff-preview 2026-09-28 T2
//
//  carries a `kind:"diff"` block so ChatToolResultPartView can route
//  the result into ChatToolDiffPreview. Mirrors hermes 0.21.5
//  tool-fallback.tsx augmenting the diff metadata for file-edit tools
//  (write_file / edit_file / patch).
//
//  Async Swift Testing — drives the actor directly via its async API.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("BookChapterTool.update diff envelope (chat-diff-preview 2026-09-28 T2)")
struct BookChapterToolDiffEnvelopeTests {


    // Reset the global library override to nil at suite entry. Suite
    // bodies then re-set it to the canonical test root (e.g. `/tmp`
    // or the makeBookDirectory) inside individual test functions. The
    // nil reset prevents prior-suite leakage across the
    // .nonisolated(unsafe) override seam (= tests are .serialized but
    // the static var is process-wide; = without this reset a prior
    // suite's /Users/.../test.ws would still be bound when this suite
    // starts and PathGuard would reject paths from the new
    // makeBookDirectory).
    init() {
        ActiveLibrary.overrideForTesting = nil
    }
    @Test("update envelope carries kind='diff' with diff text and +/- char counts")
    func updateEnvelopeHasDiff() async throws {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-diff-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        ActiveLibrary.overrideForTesting = nil; ActiveLibrary.overrideForTesting = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path

        let bookId = UUID()
        ActiveLibrary.overrideForTesting = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path
        defer { ActiveLibrary.overrideForTesting = nil }
        let actor = BookChapterActor(
            bookDirectoryProvider: { tmpRoot },
            currentChatBookIDProvider: { bookId }
        )

        let createInput = """
        {"action":"create","title":"第一章 测试","summary":"测试用","book_id":"\(bookId.uuidString)","markdown":"第一行原文。\\n第二行原文。\\n"}
        """
        let createOutput = try await actor.execute(input: createInput)
        let createPayload = try jsonObject(createOutput)
        guard let chapter = createPayload["chapter"] as? [String: Any] else {
            Issue.record("create did not return a chapter object: \(createPayload)")
            return
        }
        guard let idString = chapter["id"] as? String else {
            Issue.record("chapter object missing id: \(chapter)")
            return
        }

        let updateInput = """
        {"action":"update","id":"\(idString)","title":"第一章 测试","book_id":"\(bookId.uuidString)","markdown":"第一行原文改成新增。\\n第二行原文。\\n第三行全新。\\n"}
        """
        let updateOutput = try await actor.execute(input: updateInput)
        let updatePayload = try jsonObject(updateOutput)

        // 1. Kind marker.
        let kind = updatePayload["kind"] as? String
        #expect(kind == "diff")

        // 2. Diff block.
        guard let diffPayload = updatePayload["diff"] as? [String: Any] else {
            Issue.record("update envelope must carry a diff block")
            return
        }

        // 3. Diff stats.
        guard let stats = diffPayload["stats"] as? [String: Any] else {
            Issue.record("diff block must carry stats")
            return
        }
        let addedChars = stats["added_chars"] as? Int ?? -1
        let removedChars = stats["removed_chars"] as? Int ?? -1
        #expect(addedChars > 0)
        #expect(removedChars > 0)
    }

    @Test("update envelope diff block's old_text and new_text mirror the chapter body")
    func updateEnvelopeCarriesOldAndNew() async throws {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-diff-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        ActiveLibrary.overrideForTesting = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path

        let bookId = UUID()
        ActiveLibrary.overrideForTesting = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path
        defer { ActiveLibrary.overrideForTesting = nil }
        let actor = BookChapterActor(
            bookDirectoryProvider: { tmpRoot },
            currentChatBookIDProvider: { bookId }
        )

        let createInput = "{\"action\":\"create\",\"title\":\"T\",\"book_id\":\"\(bookId.uuidString)\",\"markdown\":\"before\\n\"}"
        let createOutput = try await actor.execute(input: createInput)
        let createPayload = try jsonObject(createOutput)
        guard let chapter = createPayload["chapter"] as? [String: Any],
              let idString = chapter["id"] as? String else {
            Issue.record("create failed")
            return
        }
        let updateInput = "{\"action\":\"update\",\"id\":\"\(idString)\",\"title\":\"T\",\"book_id\":\"\(bookId.uuidString)\",\"markdown\":\"after\\n\"}"
        let updateOutput = try await actor.execute(input: updateInput)
        let updatePayload = try jsonObject(updateOutput)
        guard let diff = updatePayload["diff"] as? [String: Any] else {
            Issue.record("update envelope missing diff block")
            return
        }
        let oldText = diff["old_text"] as? String
        let newText = diff["new_text"] as? String
        #expect(oldText == "before\n")
        #expect(newText == "after\n")
    }
}

private func jsonObject(_ raw: String) throws -> [String: Any] {
    let data = Data(raw.utf8)
    guard let obj = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "not a JSON object: \(raw)"])
    }
    return obj
}