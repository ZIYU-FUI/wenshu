//
//  BookChapterTool.swift
//
//  Per-book chapter CRUD tool (= wraps FileSystemChapterStore).
//  Mirrors BookWorldTool + BookCharacterTool patterns.
//
//  LLM-friendly verbs: create / read / update / delete / list / find.
//
//  Note: chapter identity uses the canonical Document struct with
//  category=.chapter (= the canonical wenshu-side metadata shape).
//

import Foundation

// MARK: - ChapterDescriptor

struct ChapterDescriptor: Sendable, Codable, Equatable, Identifiable {
    let id: UUID
    let bookId: UUID
    let title: String
    let summary: String
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        bookId: UUID,
        title: String,
        summary: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.bookId = bookId
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(_ document: Document) {
        self.id = document.id
        self.bookId = document.bookId
        self.title = document.title
        self.summary = document.summary
        self.createdAt = document.createdAt
        self.updatedAt = document.updatedAt
    }
}

// MARK: - Action enum

enum BookChapterAction: String, Sendable, Codable, CaseIterable, Equatable {
    case create
    case read
    case update
    case delete
    case list
    case find
}

// MARK: - Errors

enum BookChapterError: Error, LocalizedError, Sendable, Equatable {
    case emptyTitle
    case entryNotFound(id: UUID)
    case invalidInput(reason: String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "BookChapterTool: chapter title was empty or whitespace-only."
        case .entryNotFound(let id):
            return "BookChapterTool: chapter \(id.uuidString) not found."
        case .invalidInput(let reason):
            return "BookChapterTool: invalid input — \(reason)."
        case .underlying(let msg):
            return "BookChapterTool: underlying error — \(msg)."
        }
    }
}

// MARK: - Actor

actor BookChapterActor {
    /// Closure returning the book directory for the current chat
    /// session's bound book (= nil when no chat book is bound).
    /// Resolved on every CRUD call so the user can switch books
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

    /// Test-only body accessor.
    func readBodyForTest(id: UUID) async -> String? {
        guard let dir = bookDirectoryProvider() else { return nil }
        // Per boss 2026-10-05 OOB '做 8' (= the #8 FileSystem*Store
        // → SwiftData migration commit 1): actor-based callers
        // can't instantiate the @MainActor-isolated
        // FileSystemChapterStore struct (= SwiftData's ModelContext
        // is MainActor-isolated; = the struct's init requires
        // MainActor). Use the static FileSystem fallback methods
        // (= the legacy .md file path) until the actor is migrated
        // to a non-isolated form or the storage layer migrates to
        // a Sendable protocol.
        return FileSystemChapterStore.loadChapterBodyFromFileSystem(
            id: id,
            chaptersDirectory: dir.appendingPathComponent("chapters", isDirectory: true)
        )
    }

    /// Resolve the current book directory (= raises `invalidInput`
    /// if the chat session has no bound book, which the scope guard
    /// should already have rejected). Then return the FileSystem
    /// chapter paths that the static methods need (= the actor
    /// can't instantiate the @MainActor struct, so the CRUD
    /// methods now take the paths directly and call the static
    /// FileSystem fallback methods).
    private func resolvePaths() throws -> (
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) {
        guard let dir = bookDirectoryProvider() else {
            throw BookChapterError.invalidInput(
                reason: "no chat session book bound (= scope guard should have caught this earlier)"
            )
        }
        // wt/path-guard-v2-2026-09-25: PathGuard.assertInsideLibrary
        // is the second line of defense (= the first is
        // WenshuConductor.wireBookScopeGuard, which only protects
        // against a wrong book_id in the JSON envelope). If a
        // future caller wires bookDirectoryProvider to return a
        // directory outside .ws/ (= e.g. a misconfigured library
        // override), the tool body still refuses to write.
        try PathGuard.assertInsideLibrary(path: LibraryPath(rawValue: dir.path))
        let chaptersDirectory = dir.appendingPathComponent("chapters", isDirectory: true)
        let indexURL = dir.appendingPathComponent("chapters.json")
        return (dir, chaptersDirectory, indexURL)
    }

    // MARK: - CRUD

    func createChapter(
        bookId: UUID,
        title: String,
        bodyMarkdown: String,
        summary: String = ""
    ) async throws -> ChapterDescriptor {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookChapterError.emptyTitle
        }

        // Silent dedup (= v2.2, 2026-09-25): if a chapter with
        // the same title already exists in this book, fall back to
        // an in-place update (= preserves id / createdAt). LLM
        // never sees an error.
        if let existing = try await findChapter(bookId: bookId, title: trimmed) {
            return try await updateChapter(
                id: existing.id,
                title: trimmed,
                bodyMarkdown: bodyMarkdown,
                summary: summary.isEmpty ? nil : summary
            )
        }

        let document = Document(
            bookId: bookId,
            category: .chapter,
            title: trimmed,
            byteSize: bodyMarkdown.utf8.count,
            summary: summary
        )
        do {
            let (bookDirectory, chaptersDirectory, indexURL) = try resolvePaths()
            try Self.saveFileSystemChapter(
                chapter: document,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: bookDirectory,
                chaptersDirectory: chaptersDirectory,
                indexURL: indexURL
            )
        } catch let err as BookChapterError {
            throw err
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
        return ChapterDescriptor(document)
    }

    func readChapter(id: UUID) async throws -> (ChapterDescriptor, String?) {
        do {
            let (_, chaptersDirectory, indexURL) = try resolvePaths()
            let documents = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
                bookDirectory: chaptersDirectory,
                chaptersDirectory: chaptersDirectory,
                indexURL: indexURL
            )) ?? []
            guard let document = documents.first(where: { $0.id == id }) else {
                throw BookChapterError.entryNotFound(id: id)
            }
            let body = FileSystemChapterStore.loadChapterBodyFromFileSystem(
                id: id,
                chaptersDirectory: chaptersDirectory
            )
            return (ChapterDescriptor(document), body)
        } catch let err as BookChapterError {
            throw err
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
    }

    func updateChapter(
        id: UUID,
        title: String,
        bodyMarkdown: String,
        summary: String? = nil
    ) async throws -> ChapterDescriptor {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookChapterError.emptyTitle
        }
        let (_, chaptersDirectory, _) = try resolvePaths()
        // chapter-focus-lock 2026-09-28: gate the update path on
        // the single-focus lock. Same shape as EditChapterActor:
        // resolve the canonical chapter path (= <bookDir>/chapters/<id>.md)
        // and throw ChapterFocusLockedError when the user has
        // this chapter's editor tab focused. WenshuConductor
        // catches this and offers an Allow / Deny dialog.
        let chapterPath = ChapterFocusLockGuard.resolveChapterPath(
            chapterId: id,
            bookDirectoryProvider: bookDirectoryProvider
        )
        try await ChapterFocusLockGuard.assertNotLocked(
            documentPath: chapterPath,
            focusedChapterPathProvider: { @Sendable in
                await ChapterFocusLockGuard.currentFocusedChapterPath()
            }
        )
        let documents: [Document]
        do {
            let (_, chaptersDirectory, indexURL) = try resolvePaths()
            documents = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
                bookDirectory: chaptersDirectory,
                chaptersDirectory: chaptersDirectory,
                indexURL: indexURL
            )) ?? []
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
        guard let existing = documents.first(where: { $0.id == id }) else {
            throw BookChapterError.entryNotFound(id: id)
        }
        var updated = existing
        updated.title = trimmed
        if let summary { updated.summary = summary }
        updated.byteSize = bodyMarkdown.utf8.count
        updated.updatedAt = Date()
        do {
            let (bookDirectory, chaptersDirectory, indexURL) = try resolvePaths()
            try Self.writeFileSystemChapter(
                chapter: updated,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: bookDirectory,
                chaptersDirectory: chaptersDirectory,
                indexURL: indexURL
            )
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
        return ChapterDescriptor(updated)
    }

    func deleteChapter(id: UUID) async throws {
        do {
            let (bookDirectory, chaptersDirectory, indexURL) = try resolvePaths()
            try Self.deleteFileSystemChapter(
                id: id,
                bookDirectory: bookDirectory,
                chaptersDirectory: chaptersDirectory,
                indexURL: indexURL
            )
        } catch let err as BookChapterError {
            throw err
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
    }

    func listChapters(bookId: UUID) async throws -> [ChapterDescriptor] {
        let (_, chaptersDirectory, indexURL) = try resolvePaths()
        let documents: [Document]
        do {
            documents = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
                bookDirectory: chaptersDirectory,
                chaptersDirectory: chaptersDirectory,
                indexURL: indexURL
            )) ?? []
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
        let filtered = documents.filter { $0.bookId == bookId }
        let sorted = filtered.sorted { $0.updatedAt > $1.updatedAt }
        return sorted.map { ChapterDescriptor($0) }
    }

    func findChapter(bookId: UUID, title: String) async throws -> ChapterDescriptor? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let (_, chaptersDirectory, indexURL) = try resolvePaths()
        let documents: [Document]
        do {
            documents = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
                bookDirectory: chaptersDirectory,
                chaptersDirectory: chaptersDirectory,
                indexURL: indexURL
            )) ?? []
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
        let match = documents.first { document in
            document.bookId == bookId &&
            document.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed
        }
        return match.map { ChapterDescriptor($0) }
    }

    // MARK: - Tool-protocol entry-point (LLM-facing dispatcher)

    func execute(input: String) async throws -> String {
        let envelope: [String: Any]
        do {
            guard let data = input.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw BookChapterError.invalidInput(reason: "input must be a JSON object")
            }
            envelope = parsed
        } catch let error as BookChapterError {
            return Self.encodeFailure(action: nil, error: error)
        } catch {
            return Self.encodeFailure(
                action: nil,
                error: BookChapterError.invalidInput(
                    reason: "input JSON parse failed: \(error.localizedDescription)"
                )
            )
        }

        guard let actionRaw = envelope["action"] as? String,
              let action = BookChapterAction(rawValue: actionRaw)
        else {
            return Self.encodeFailure(
                action: nil,
                error: BookChapterError.invalidInput(
                    reason: "missing or unknown 'action' (expected: create / read / update / delete / list / find)"
                )
            )
        }

        // Scope guard: see BookWorldActor (= identical contract).
        do {
            try BookScopeGuard.validate(
                providedBookID: Self.parseUUID(envelope["book_id"]),
                currentChatBookIDProvider: currentChatBookIDProvider
            )
        } catch let violation as BookScopeViolation {
            return Self.encodeFailureScopeViolation(action: action, error: violation)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookChapterError.invalidInput(
                    reason: "scope guard failed: \(error.localizedDescription)"
                )
            )
        }

        do {
            switch action {
            case .create:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookChapterError.invalidInput(reason: "create requires 'book_id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let summary = envelope["summary"] as? String ?? ""
                let body = Self.extractMarkdown(envelope)
                let chapter = try await createChapter(
                    bookId: bookId,
                    title: title,
                    bodyMarkdown: body,
                    summary: summary
                )
                return Self.encodeSuccess(action: action, chapter: chapter)

            case .read:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookChapterError.invalidInput(reason: "read requires 'id' (UUID string)")
                }
                let (chapter, body) = try await readChapter(id: id)
                return Self.encodeSuccessRead(action: action, chapter: chapter, body: body)

            case .update:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookChapterError.invalidInput(reason: "update requires 'id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let summary = envelope["summary"] as? String
                let body = Self.extractMarkdown(envelope)
                // Read the existing body before the update so the success
                // envelope can carry a unified-diff block (= the chat
                // tool-result preview surfaces the change to the human).
                // Mirrors hermes 0.21.5 tool-fallback.tsx, which augments
                // file-edit tool results with `diff` + `old_text` +
                // `new_text` for the in-chat preview card.
                let oldBody: String
                do {
                    let (_, existing) = try await readChapter(id: id)
                    oldBody = existing ?? ""
                } catch {
                    // If the chapter didn't exist (= treat as create-flavored
                    // update), we still want to surface the diff; = empty
                    // old body means the entire new body is "+" lines.
                    oldBody = ""
                }
                let chapter = try await updateChapter(
                    id: id,
                    title: title,
                    bodyMarkdown: body,
                    summary: summary
                )
                return Self.encodeSuccessUpdate(
                    action: action,
                    chapter: chapter,
                    oldBody: oldBody,
                    newBody: body
                )

            case .delete:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookChapterError.invalidInput(reason: "delete requires 'id' (UUID string)")
                }
                try await deleteChapter(id: id)
                return Self.encodeSuccess(action: action)

            case .list:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookChapterError.invalidInput(reason: "list requires 'book_id' (UUID string)")
                }
                let chapters = try await listChapters(bookId: bookId)
                return Self.encodeSuccessList(action: action, chapters: chapters)

            case .find:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookChapterError.invalidInput(reason: "find requires 'book_id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let chapter = try await findChapter(bookId: bookId, title: title)
                return Self.encodeSuccessFind(action: action, chapter: chapter)
            }
        } catch let error as BookChapterError {
            return Self.encodeFailure(action: action, error: error)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookChapterError.underlying(String(describing: error))
            )
        }
    }

    // MARK: - JSON helpers

    private static func extractMarkdown(_ envelope: [String: Any]) -> String {
        if let m = envelope["markdown"] as? String, !m.isEmpty { return m }
        if let b = envelope["body"] as? String { return b }
        return ""
    }

    private static func parseUUID(_ any: Any?) -> UUID? {
        if let s = any as? String {
            return UUID(uuidString: s.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let dict = any as? [String: Any], let s = dict["value"] as? String {
            return UUID(uuidString: s.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func encodeSuccess(
        action: BookChapterAction,
        chapter: ChapterDescriptor? = nil
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        if let chapter {
            payload["chapter"] = descriptorToJSON(chapter)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessRead(
        action: BookChapterAction,
        chapter: ChapterDescriptor,
        body: String?
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "chapter": descriptorToJSON(chapter),
            "body": body ?? ""
        ]
        return encodeJSON(payload)
    }

    /// Variant for the `update` action — enriches the envelope with a
    /// unified-diff block so `ChatToolResultPartView` can route the
    /// result into `ChatToolDiffPreview` (= the hermes 0.21.5
    /// file-edit preview card surface, 1:1 mirrored here).
    ///
    /// Schema:
    ///   kind    = "diff"
    ///   diff    = { path, old_text, new_text, stats: { added_chars,
    ///               removed_chars, added_lines, removed_lines } }
    ///   diff_stats_canonical = same stats block at the top level for
    ///         tooling that already routes on `kind:"diff"` (= our chat
    ///         layer reads `diff.stats`).
    private static func encodeSuccessUpdate(
        action: BookChapterAction,
        chapter: ChapterDescriptor,
        oldBody: String,
        newBody: String
    ) -> String {
        let diff = Self.computeUnifiedDiff(old: oldBody, new: newBody)
        let stats = ChatToolDiffPreview.LineStats(
            addedLines: diff.addedLines,
            removedLines: diff.removedLines,
            addedChars: diff.addedChars,
            removedChars: diff.removedChars
        )
        let diffBlock: [String: Any] = [
            "path": "chapters/\(chapter.id.uuidString).md",
            "old_text": oldBody,
            "new_text": newBody,
            "stats": [
                "added_chars": stats.addedChars,
                "removed_chars": stats.removedChars,
                "added_lines": stats.addedLines,
                "removed_lines": stats.removedLines
            ] as [String: Int]
        ]
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "chapter": descriptorToJSON(chapter),
            "kind": "diff",
            "diff": diffBlock,
            "diff_text": diff.text
        ]
        return encodeJSON(payload)
    }

    /// Plain unified-diff product (= text + line / char counts). Pure
    /// function so it's reachable from unit tests without an actor.
    struct UnifiedDiff: Equatable, Sendable {
        let text: String
        let addedLines: Int
        let removedLines: Int
        let addedChars: Int
        let removedChars: Int
    }

    /// Compute a minimal unified diff between two strings (= the
    /// form hermes `tool-fallback.tsx` renders). This is NOT a full
    /// Myers diff; = it's the `diff` algorithm's "intraline + line
    /// block" variant (= same lines → kept, changed → +/- lines).
    /// The body split is line-by-line, so trailing-newline-only edits
    /// surface as expected by the user-facing metric.
    ///
    /// Schema (one hunk, no header noise):
    ///   "--- old\n+++ new\n@@\n-removed line\n+added line\n context\n"
    static func computeUnifiedDiff(old: String, new: String) -> UnifiedDiff {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        // Trailing-newline guard: split(separator:) drops empty trailing
        // element. Bring it back so the diff stays newline-faithful.
        var oldSplit = oldLines
        var newSplit = newLines
        if old.hasSuffix("\n") && oldSplit.last == "" { oldSplit.removeLast() }
        if new.hasSuffix("\n") && newSplit.last == "" { newSplit.removeLast() }

        // Two-pointer LCS walk (= the canonical intraline diff surface).
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

    private static func encodeSuccessFind(
        action: BookChapterAction,
        chapter: ChapterDescriptor?
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue, "found": chapter != nil]
        if let chapter {
            payload["chapter"] = descriptorToJSON(chapter)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessList(
        action: BookChapterAction,
        chapters: [ChapterDescriptor]
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "chapters": chapters.map { descriptorToJSON($0) }
        ]
        return encodeJSON(payload)
    }

    private static func encodeFailure(
        action: BookChapterAction?,
        error: BookChapterError
    ) -> String {
        var payload: [String: Any] = [
            "ok": false,
            "error": error.errorDescription ?? "unknown error"
        ]
        if let action {
            payload["action"] = action.rawValue
        }
        return encodeJSON(payload)
    }

    /// Encode a BookScopeViolation into the standard failure envelope.
    /// See BookWorldTool.encodeFailureScopeViolation for the matching
    /// contract.
    private static func encodeFailureScopeViolation(
        action: BookChapterAction,
        error: BookScopeViolation
    ) -> String {
        let payload: [String: Any] = [
            "ok": false,
            "action": action.rawValue,
            "error": error.errorDescription ?? "unknown error",
            "error_kind": "book_scope_violation"
        ]
        return encodeJSON(payload)
    }

    private static func descriptorToJSON(_ d: ChapterDescriptor) -> [String: Any] {
                return [
            "id": d.id.uuidString,
            "book_id": d.bookId.uuidString,
            "title": d.title,
            "summary": d.summary,
            "createdAt": d.createdAt.formatted(.iso8601),
            "updatedAt": d.updatedAt.formatted(.iso8601)
        ]
    }

    private static func encodeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"BookChapterTool: JSON encode failed\"}"
        }
        return s
    }
}

// MARK: - BookChapterActor static FileSystem helpers
//
// The actor-based callers (= BookChapterActor) can't call instance
// methods on the @MainActor-isolated FileSystemChapterStore struct;
// = they use these static helpers (= FileManager + JSONEncoder are
// thread-safe; = the actor's isolation is fine). This file hosts
// the helpers here (= duplicates the storage layer) so the actor
// doesn't need a separate extension file.
extension BookChapterActor {
    /// Write a NEW chapter to the legacy FileSystem path (.md file +
    /// chapters.json index update).
    static func saveFileSystemChapter(
        chapter: Document,
        bodyMarkdown: String,
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws {
        try ensureChaptersDirectoryExists(at: chaptersDirectory)
        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(chapter.id.uuidString).md")
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            throw BookChapterError.entryNotFound(id: chapter.id)
        }
        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)

        // Append to the chapters.json index (= the legacy list
        // path callers read via loadChaptersFromFileSystem).
        var current = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        current.append(chapter)
        try writeIndex(current, to: indexURL)
    }

    /// Replace an EXISTING chapter (.md body + index row update).
    static func writeFileSystemChapter(
        chapter: Document,
        bodyMarkdown: String,
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws {
        try ensureChaptersDirectoryExists(at: chaptersDirectory)
        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(chapter.id.uuidString).md")
        guard FileManager.default.fileExists(atPath: chapterURL.path) else {
            throw BookChapterError.entryNotFound(id: chapter.id)
        }
        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)

        // Update the chapters.json index row.
        var current = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        guard let idx = current.firstIndex(where: { $0.id == chapter.id }) else {
            throw BookChapterError.entryNotFound(id: chapter.id)
        }
        current[idx] = chapter
        try writeIndex(current, to: indexURL)
    }

    /// Delete a chapter (.md body + index row remove).
    static func deleteFileSystemChapter(
        id: UUID,
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws {
        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            try FileManager.default.removeItem(at: chapterURL)
        }

        // Remove from chapters.json index.
        var current = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        let before = current.count
        current.removeAll { $0.id == id }
        if current.count != before {
            try writeIndex(current, to: indexURL)
        }
    }

    fileprivate static func writeIndex(_ chapters: [Document], to indexURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(chapters)
        try atomicWrite(data, to: indexURL)
    }

    fileprivate static func ensureChaptersDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    fileprivate static func atomicWrite(_ data: Data, to url: URL) throws {
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
}

// MARK: - Tool-protocol adapter

actor BookChapterTool: Tool {
    let name = "book_chapter"
    let description = "Create / read / update / delete / list / find chapters under a book."

    private let actor: BookChapterActor

    init(actor: BookChapterActor) {
        self.actor = actor
    }

    func execute(input: String) async throws -> String {
        try await actor.execute(input: input)
    }
}

// MARK: - ToolRegistry bootstrap

extension BookChapterTool {
    /// Module-load registration with `ToolRegistry.shared`.
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "book_chapter",
                toolset: "library",
                schema: ToolRegistrySchema(
                    name: "book_chapter",
                    description: "Per-book chapter CRUD (= wraps FileSystemChapterStore). LLM-friendly verbs: create / read / update / delete / list / find.",
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The chapter operation to perform.",
                            enumValues: ["create", "read", "update", "delete", "list", "find"]
                        ),
                        "book_id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Owning book id (UUID). Required for create / list / find."
                        ),
                        "id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Chapter id (UUID). Required for read / update / delete."
                        ),
                        "title": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Chapter title. Required for create / find; for update replaces the chapter title."
                        ),
                        "summary": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional 1-line summary."
                        ),
                        "markdown": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Full .md body. Alias: 'body'."
                        )
                    ],
                    required: ["action"]
            ),
            handler: BookChapterTool.shared,
            description: "Per-book chapter CRUD.",
            emoji: "📖"
        )
        }
    }()

    nonisolated static let shared: BookChapterTool = {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-toolregistry-chapter-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return BookChapterTool(
            actor: BookChapterActor(
                bookDirectoryProvider: { tmpRoot },
                currentChatBookIDProvider: { nil }
            )
        )
    }()

    // MARK: - Static FileSystem helpers (actor-safe; = the actor
    // can't instantiate the @MainActor-isolated FileSystemChapterStore
    // struct, so the CRUD methods above call these static helpers
    // (= FileManager + JSONEncoder are thread-safe).

    /// Write a NEW chapter to the legacy FileSystem path (.md file +
    /// chapters.json index update).
    static func saveFileSystemChapter(
        chapter: Document,
        bodyMarkdown: String,
        chaptersDirectory: URL
    ) throws {
        try Self.ensureChaptersDirectoryExists(at: chaptersDirectory)
        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(chapter.id.uuidString).md")
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            throw BookChapterError.entryNotFound(id: chapter.id)
        }
        try Self.atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)
    }

    /// Replace an EXISTING chapter (.md body + index row update).
    static func writeFileSystemChapter(
        chapter: Document,
        bodyMarkdown: String,
        chaptersDirectory: URL
    ) throws {
        try Self.ensureChaptersDirectoryExists(at: chaptersDirectory)
        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(chapter.id.uuidString).md")
        guard FileManager.default.fileExists(atPath: chapterURL.path) else {
            throw BookChapterError.entryNotFound(id: chapter.id)
        }
        try Self.atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)
    }

    /// Delete a chapter (.md body remove).
    static func deleteFileSystemChapter(
        id: UUID,
        chaptersDirectory: URL
    ) throws {
        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            try FileManager.default.removeItem(at: chapterURL)
        }
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
}