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
        // chapter-focus-lock (= single-focus model): throws when the user's
        // editor tab is focused on this chapter. The conductor
        // (= WenshuConductor.executeIfUnlocked) catches this and
        // presents an Allow / Deny dialog; = the user can override
        // the lock by approving the agent's edit. Until then, the
        // chapter is read-only on the agent side too.
        let chapterPath = ChapterFocusLockGuard.resolveChapterPath(
            chapterId: chapterId,
            bookDirectoryProvider: bookDirectoryProvider
        )
        try await ChapterFocusLockGuard.assertNotLocked(
            documentPath: chapterPath,
            focusedChapterPathProvider: { @Sendable in
                await ChapterFocusLockGuard.currentFocusedChapterPath()
            }
        )
        guard let dir = bookDirectoryProvider() else {
            throw EditChapterError.chapterNotFound
        }
        // Per boss 2026-10-05 OOB '做 8' (= the #8 FileSystem*Store
        // → SwiftData migration commit 1): actor-based callers
        // can't instantiate the @MainActor-isolated
        // FileSystemChapterStore struct (= SwiftData's ModelContext
        // is MainActor-isolated; = the struct's init requires
        // MainActor). Use the static FileSystem fallback methods
        // (= the legacy .md file path) until the actor is migrated
        // to a non-isolated form or the storage layer migrates to
        // a Sendable protocol.
        let chaptersDirectory = dir.appendingPathComponent("chapters", isDirectory: true)
        let indexURL = dir.appendingPathComponent("chapters.json")

        // 1. Read the existing chapter + body (= via the FileSystem
        // fallback; = the SwiftData path will be wired once the
        // actor boundary is fixed in commit 2 of #8).
        let documents = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: dir,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        guard let document = documents.first(where: { $0.id == chapterId }) else {
            throw EditChapterError.chapterNotFound
        }
        guard let oldBody = FileSystemChapterStore.loadChapterBodyFromFileSystem(
            id: chapterId,
            chaptersDirectory: chaptersDirectory
        ) else {
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

        // 4. Persist the patched body. NOTE: writeFileSystemChapter
        // is the legacy .md writer (= actor can write to the file
        // system directly; = the SwiftData write path is gated on
        // MainActor and will be wired in commit 2 of #8).
        var updated = document
        updated.updatedAt = Date()
        if let summary { updated.summary = summary }
        try Self.writeFileSystemChapter(
            chapter: updated,
            bodyMarkdown: newBody,
            bookDirectory: dir,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )

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

    /// Write a chapter to the legacy FileSystem .md + chapters.json
    /// path (= actor-safe helper; = FileManager + JSONEncoder are
    /// thread-safe).
    static func writeFileSystemChapter(
        chapter: Document,
        bodyMarkdown: String,
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws {
        NSLog("[edit-chapter] writeFileSystemChapter bookDirectory=%@ chaptersDirectory=%@ indexURL=%@", bookDirectory.path, chaptersDirectory.path, indexURL.path)
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            NSLog("[edit-chapter] writeFileSystemChapter FAIL: bookDirectory missing")
            throw EditChapterError.chapterNotFound
        }
        try Self.ensureChaptersDirectoryExists(at: chaptersDirectory)
        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(chapter.id.uuidString).md")
        NSLog("[edit-chapter] writeFileSystemChapter chapterURL=%@ exists=%d", chapterURL.path, FileManager.default.fileExists(atPath: chapterURL.path) ? 1 : 0)
        guard FileManager.default.fileExists(atPath: chapterURL.path) else {
            NSLog("[edit-chapter] writeFileSystemChapter FAIL: chapterURL missing")
            throw EditChapterError.chapterNotFound
        }
        try Self.atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)

        var current = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        guard let idx = current.firstIndex(where: { $0.id == chapter.id }) else {
            throw EditChapterError.chapterNotFound
        }
        current[idx] = chapter
        try Self.writeIndex(current, to: indexURL)
    }

    /// Static FileSystem load (= actor-safe; = no instance state).
    private static func loadChaptersFromFileSystemStatic(
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws -> [Document] {
        try FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )
    }

    private static func ensureChaptersDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private static func atomicWrite(_ data: Data, to url: URL) throws {
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmpURL, to: url)
        let fd = open(url.path, O_RDONLY)
        if fd >= 0 {
            fsync(fd)
            close(fd)
        }
    }

    private static func writeIndex(_ chapters: [Document], to indexURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(chapters)
        try atomicWrite(data, to: indexURL)
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

/// chapter-dialog 2026-09-28 T2: thrown when the user denies the
/// chapter-edit dialog (= chose Deny in the Allow/Deny alert).
/// The LLM receives this error and decides what to do next
/// (= try a different chapter, ask for clarification, etc).
struct DatasetLockDeniedByBoss: Error, Equatable {
    let chapterPath: String?
}

/// chapter-focus-lock 2026-09-28: thrown when the user has the
/// editor focused on the chapter an agent tool call is targeting.
/// The conductor (= WenshuConductor) catches this and presents
/// an Allow / Deny dialog so the focus can be released before the
/// agent retries. Surfacing the chapter path lets the dialog
/// name the chapter (= e.g. "Agent wants to edit 'Chapter 3'.").
struct ChapterFocusLockedError: Error, Equatable {
    let chapterPath: String?
}

/// chapter-focus-lock 2026-09-28: helpers used by both EditChapterActor
/// (= this file) and BookChapterActor (= sibling file) to gate the
/// single-focus lock. Resolves the canonical chapter file path from
/// the book directory provider + chapter UUID, then queries
/// AppState.focusedChapterPath via MainActor.
enum ChapterFocusLockGuard {
    /// Canonical wenshu chapter path (= <bookDir>/chapters/<id>.md).
    /// Static so callers don't have to construct the URL themselves.
    static func resolveChapterPath(
        chapterId: UUID,
        bookDirectoryProvider: @escaping @Sendable () -> URL?
    ) -> String? {
        guard let dir = bookDirectoryProvider() else { return nil }
        return dir
            .appendingPathComponent("chapters", isDirectory: true)
            .appendingPathComponent("\(chapterId.uuidString).md", isDirectory: false)
            .path
    }

    /// Throws `ChapterFocusLockedError` when the user has this
    /// chapter's editor tab focused. Async because AppState lives
    /// on the MainActor; = actors crossing isolation must await.
    static func assertNotLocked(
        documentPath: String?,
        focusedChapterPathProvider: @escaping @Sendable () async -> String?
    ) async throws {
        let focused = await focusedChapterPathProvider()
        guard let documentPath, focused == documentPath else { return }
        throw ChapterFocusLockedError(chapterPath: documentPath)
    }

    /// Snapshot reader for AppState.focusedChapterPath. Crosses
    /// into the MainActor where AppState lives (= @MainActor
    /// isolation rule); = callers from background actors can
    /// `await` this without dealing with MainActor directly.
    /// Returns nil when no AppState exists (= unit test fixtures
    /// don't construct one) so the lock never trips spuriously.
    @MainActor
    static func currentFocusedChapterPath() -> String? {
        AppStateLocator.shared.appState?.focusedChapterPath
    }
}