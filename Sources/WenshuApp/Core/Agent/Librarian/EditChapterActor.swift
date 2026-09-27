//
//  EditChapterActor.swift · wenshu · edit-chapter-tool 2026-09-28
//
//  Actor + domain types for hermes 0.21.5 `edit_file` 1:1 —
//  patch-style chapter edits: replace `old_text` with `new_text`
//  inside the chapter's body markdown. Returns the same
//  `kind:"diff"` envelope shape that BookChapterTool.update
//  emits (= ChatToolDiffPreview's input is stable across both
//  surfaces; = hermes tool-fallback.tsx schema, 1:1).
//
//  Why a separate actor (= not just another action on BookChapterActor):
//    - hermes splits write_file / edit_file / patch into separate
//      tools (= each with its own dispatcher surface + tool schema).
//      wenshu mirrors that for clarity (= future WenshuConductor
//      wiring treats EditChapterTool as a sibling of BookChapterTool).
//    - the edit semantics are different from update (= find substring
//      vs. replace whole body). Keeping them in separate actors
//      preserves the SSOT of each surface.
//

import Foundation

/// Patch-style chapter edit (= hermes edit_file 1:1).
actor EditChapterActor {
    /// Closure returning the book directory for the current chat
    /// session's bound book (= nil when no chat book is bound).
    /// Resolved on every call so the user can switch books
    /// mid-conversation without the actor holding a stale root.
    private let bookDirectoryProvider: @Sendable () -> URL?

    /// Closure returning the chat session's currently-bound book.
    /// See BookWorldActor's matching field for the contract.
    private let currentChatBookIDProvider: @Sendable () -> UUID?

    init(
        bookDirectoryProvider: @escaping @Sendable () -> URL?,
        currentChatBookIDProvider: @escaping @Sendable () -> UUID? = { nil }
    ) {
        self.bookDirectoryProvider = bookDirectoryProvider
        self.currentChatBookIDProvider = currentChatBookIDProvider
    }

    struct EditResult: Equatable, Sendable {
        let envelope: EditDiffEnvelope
    }

    /// Replace `oldText` with `newText` inside the chapter body.
    /// Throws `EditChapterError.oldTextNotFound` when `oldText` is
    /// not a substring of the body.
    func editChapter(
        chapterId: UUID,
        bookId: UUID,
        oldText: String,
        newText: String,
        summary: String?
    ) async throws -> EditResult {
        guard let dir = bookDirectoryProvider() else {
            throw EditChapterError.chapterNotFound
        }
        let store = FileSystemChapterStore(bookDirectory: dir)

        // 1. Read the existing chapter + body.
        let documents = try store.loadChapters()
        guard let document = documents.first(where: { $0.id == chapterId }) else {
            throw EditChapterError.chapterNotFound
        }
        guard let oldBody = store.loadChapterBody(id: chapterId) else {
            throw EditChapterError.chapterNotFound
        }

        // 2. Find `oldText` and replace once (= hermes semantics —
        //    ambiguous matches throw so the LLM re-issues with
        //    tighter context).
        guard let range = oldBody.range(of: oldText) else {
            throw EditChapterError.oldTextNotFound
        }
        let newBody = oldBody.replacingOccurrences(of: oldText, with: newText, options: [], range: range)

        // 3. Compute the unified-diff stats (= same algorithm as
        //    BookChapterTool.computeUnifiedDiff; = LCS-based).
        let diff = Self.computeUnifiedDiff(old: oldBody, new: newBody)

        // 4. Persist the patched body.
        var updated = document
        updated.updatedAt = Date()
        if let summary { updated.summary = summary }
        try store.replaceChapter(updated, bodyMarkdown: newBody)

        let envelope = EditDiffEnvelope(
            kind: "diff",
            path: "chapters/\(chapterId.uuidString).md",
            oldText: oldBody,
            newText: newBody,
            addedChars: diff.addedChars,
            removedChars: diff.removedChars,
            addedLines: diff.addedLines,
            removedLines: diff.removedLines
        )
        return EditResult(envelope: envelope)
    }

    /// Tool-call dispatch entry point (= hermes-style tool-call
    /// envelope). Parses the JSON input, calls `editChapter(...)`,
    /// and serializes the result back as a JSON envelope so the
    /// `EditChapterTool` wrapper (= which forwards here) returns
    /// the canonical wire shape to the LLM dispatcher.
    func execute(input: String) async throws -> String {
        guard let envelope = try? JSONSerialization.jsonObject(
            with: Data(input.utf8),
            options: []
        ) as? [String: Any] else {
            return Self.encodeFailure(reason: "input is not a JSON object")
        }
        guard let idString = envelope["id"] as? String,
              let id = UUID(uuidString: idString) else {
            return Self.encodeFailure(reason: "edit requires 'id' (UUID string)")
        }
        guard let bookIdString = envelope["book_id"] as? String,
              let bookId = UUID(uuidString: bookIdString) else {
            return Self.encodeFailure(reason: "edit requires 'book_id' (UUID string)")
        }
        guard let oldText = envelope["old_text"] as? String else {
            return Self.encodeFailure(reason: "edit requires 'old_text'")
        }
        guard let newText = envelope["new_text"] as? String else {
            return Self.encodeFailure(reason: "edit requires 'new_text'")
        }
        let summary = envelope["summary"] as? String

        let result: EditResult
        do {
            result = try await editChapter(
                chapterId: id,
                bookId: bookId,
                oldText: oldText,
                newText: newText,
                summary: summary
            )
        } catch let error as EditChapterError {
            switch error {
            case .chapterNotFound:
                return Self.encodeFailure(reason: "chapter not found", errorKind: "chapter_not_found")
            case .oldTextNotFound:
                return Self.encodeFailure(reason: "old_text not found in chapter body", errorKind: "old_text_not_found")
            }
        } catch {
            return Self.encodeFailure(reason: String(describing: error))
        }
        return Self.encodeSuccess(result: result)
    }

    // MARK: - JSON envelope (= same shape as BookChapterTool.update)

    private static func encodeSuccess(result: EditResult) -> String {
        let diff = result.envelope
        let payload: [String: Any] = [
            "ok": true,
            "action": "edit",
            "kind": diff.kind,
            "diff": [
                "path": diff.path,
                "old_text": diff.oldText,
                "new_text": diff.newText,
                "stats": [
                    "added_chars": diff.addedChars,
                    "removed_chars": diff.removedChars,
                    "added_lines": diff.addedLines,
                    "removed_lines": diff.removedLines
                ] as [String: Int]
            ] as [String: Any]
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: []
        ), let text = String(data: data, encoding: .utf8) else {
            return "{\"ok\":false,\"error\":\"json-encode-failed\"}"
        }
        return text
    }

    private static func encodeFailure(
        reason: String,
        errorKind: String? = nil
    ) -> String {
        var payload: [String: Any] = ["ok": false, "error": reason]
        if let errorKind { payload["error_kind"] = errorKind }
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: []
        ), let text = String(data: data, encoding: .utf8) else {
            return "{\"ok\":false,\"error\":\"json-encode-failed\"}"
        }
        return text
    }

    // MARK: - Diff (= shared algorithm with BookChapterTool)

    struct UnifiedDiff: Equatable, Sendable {
        let text: String
        let addedLines: Int
        let removedLines: Int
        let addedChars: Int
        let removedChars: Int
    }

    /// LCS-based unified diff (= mirrors hermes tool-fallback.tsx).
    /// Plain function so it's reachable from unit tests.
    static func computeUnifiedDiff(old: String, new: String) -> UnifiedDiff {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        var oldSplit = oldLines
        var newSplit = newLines
        if old.hasSuffix("\n") && oldSplit.last == "" { oldSplit.removeLast() }
        if new.hasSuffix("\n") && newSplit.last == "" { newSplit.removeLast() }
        let lcs = lcsTable(oldSplit, newSplit)
        let lines = backtrackDiff(old: oldSplit, new: newSplit, lcs: lcs)
        var addedLines = 0
        var removedLines = 0
        var addedChars = 0
        var removedChars = 0
        for entry in lines {
            switch entry {
            case .added(let body):
                addedLines += 1
                addedChars += body.count
            case .removed(let body):
                removedLines += 1
                removedChars += body.count
            case .context: continue
            }
        }
        var text = "--- old\n+++ new\n@@\n"
        for entry in lines {
            switch entry {
            case .added(let body): text += "+\(body)\n"
            case .removed(let body): text += "-\(body)\n"
            case .context(let body): text += " \(body)\n"
            }
        }
        return UnifiedDiff(
            text: text,
            addedLines: addedLines,
            removedLines: removedLines,
            addedChars: addedChars,
            removedChars: removedChars
        )
    }

    private enum DiffEntry: Equatable, Sendable {
        case added(String)
        case removed(String)
        case context(String)
    }

    private static func lcsTable(_ a: [String], _ b: [String]) -> [[Int]] {
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    table[i][j] = table[i - 1][j - 1] + 1
                } else {
                    table[i][j] = max(table[i - 1][j], table[i][j - 1])
                }
            }
        }
        return table
    }

    private static func backtrackDiff(
        old: [String],
        new: [String],
        lcs: [[Int]]
    ) -> [DiffEntry] {
        var entries: [DiffEntry] = []
        var i = old.count
        var j = new.count
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && old[i - 1] == new[j - 1] {
                entries.append(.context(old[i - 1]))
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || lcs[i][j - 1] >= lcs[i - 1][j]) {
                entries.append(.added(new[j - 1]))
                j -= 1
            } else if i > 0 {
                entries.append(.removed(old[i - 1]))
                i -= 1
            }
        }
        return entries.reversed()
    }
}

// MARK: - Diff envelope (= chat-diff-preview wire shape)

/// Canonical diff envelope emitted by both EditChapterActor and
/// BookChapterActor.update (= ChatToolResultPartView routes any
/// envelope carrying this shape into ChatToolDiffPreview).
struct EditDiffEnvelope: Equatable, Sendable {
    let kind: String                // always "diff"
    let path: String                // "chapters/<UUID>.md"
    let oldText: String
    let newText: String
    let addedChars: Int
    let removedChars: Int
    let addedLines: Int
    let removedLines: Int

    var stats: Stats {
        Stats(addedChars: addedChars, removedChars: removedChars)
    }

    struct Stats: Equatable, Sendable {
        let addedChars: Int
        let removedChars: Int
    }
}

/// Errors surfaced by EditChapterActor (= hermes edit_file semantics).
enum EditChapterError: Error, Equatable {
    /// The chapter id doesn't exist (= the LLM is wrong about the
    /// id; = same envelope as `BookChapterError.entryNotFound`).
    case chapterNotFound
    /// `oldText` is not a substring of the chapter body (= hermes
    /// edit_file throws so the LLM re-issues with tighter context).
    case oldTextNotFound
}