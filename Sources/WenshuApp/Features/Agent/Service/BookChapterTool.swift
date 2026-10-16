// BookChapterTool.swift Per-book chapter CRUD tool (= wraps FileSystemChapterStore).
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// Document struct with category=.chapter (= the canonical wenshu-side metadata shape).
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
    // / Closure returning the book directory for the current chat session's
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / holding a stale root.
    private let bookDirectoryProvider: @Sendable () -> URL?

    // / Closure returning the chat session's currently-bound book. See
    // / BookWorldActor's matching field for the contract.
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
        // Per boss 2026-10-05 (see OOB.md #2026-10-05) → SwiftData migration commit 1):
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // layer migrates to a Sendable protocol.
        return FileSystemChapterStore.loadChapterBodyFromFileSystem(
            id: id,
            chaptersDirectory: dir.appendingPathComponent("chapters", isDirectory: true)
        )
    }

    // / Resolve the current book directory (= raises `invalidInput` if the chat
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / FileSystem fallback methods).
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
        // wt/path-guard-v2-2026-09-25: PathGuard.assertInsideLibrary is the second line
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // body still refuses to write.
        try PathGuard.assertInsideLibrary(path: LibraryPath(rawValue: dir.path))
        let chaptersDirectory = dir.appendingPathComponent("chapters", isDirectory: true)
        let indexURL = dir.appendingPathComponent("chapters.json")
        return (dir, chaptersDirectory, indexURL)
    }

    // MARK: - Agent gate
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / `chapters/<id>.md` and updating `chapters.json`).
    private func resolveDraftsPaths() throws -> (
        bookDirectory: URL,
        draftsDirectory: URL,
        indexURL: URL
    ) {
        guard let dir = bookDirectoryProvider() else {
            throw BookChapterError.invalidInput(
                reason: "no chat session book bound (= scope guard should have caught this earlier)"
            )
        }
        try PathGuard.assertInsideLibrary(path: LibraryPath(rawValue: dir.path))
        let draftsDirectory = dir.appendingPathComponent("drafts", isDirectory: true)
        let indexURL = dir.appendingPathComponent("drafts.json")
        return (dir, draftsDirectory, indexURL)
    }

    // MARK: - CRUD
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / (= the caller can read back the file path or update the UI).
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

        // the dedup check now looks in `drafts/` (= the agent's canonical staging area).
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // but prefer drafts/ for agent writes.
        if let existing = try await findDraftChapter(bookId: bookId, title: trimmed) {
            return try await updateDraftChapter(
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
            let (bookDirectory, draftsDirectory, indexURL) = try resolveDraftsPaths()
            try Self.saveFileSystemChapter(
                chapter: document,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: bookDirectory,
                chaptersDirectory: draftsDirectory,
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
        // the agent gate (= boss 2026-10-10 "提升为 正文的内容，成 为下阶段的约 束，Agent 在 没有用户允许 的情况下，不
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // disk; if its parent directory ends in 'chapters', reject".
        let (bookDirectory, draftsDirectory, _) = try resolveDraftsPaths()
        let fileOnDisk = bookDirectory
            .appendingPathComponent("chapters", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: fileOnDisk.path) {
            throw BookChapterError.underlying(
                "agent gate: this chapter is confirmed (= the user promoted it from drafts/ to chapters/). Agent 写正文一律先写草稿. The user must explicitly approve edits to confirmed chapters. Tell the user: 'I want to edit chapter `<title>` (id `<id>`). It's currently in `chapters/`, not `drafts/`. Please confirm the edit or move it back to `drafts/`.'"
            )
        }
        // Otherwise the file is in `drafts/` (or doesn't exist = a new draft; = we
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // chapter's editor tab focused.
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
            documents = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
                bookDirectory: draftsDirectory,
                chaptersDirectory: draftsDirectory,
                indexURL: draftsDirectory.deletingLastPathComponent().appendingPathComponent("drafts.json")
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
            let (_, draftsDir, indexURL) = try resolveDraftsPaths()
            try Self.writeFileSystemChapter(
                chapter: updated,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: bookDirectory,
                chaptersDirectory: draftsDir,
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

    // / drafts/ counterpart of `findChapter` (= looks in `drafts/` only; = used
    // / by `createChapter`'s dedup so the agent can't create duplicate drafts).
    private func findDraftChapter(bookId: UUID, title: String) async throws -> ChapterDescriptor? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let (_, draftsDirectory, indexURL) = try resolveDraftsPaths()
        let documents: [Document]
        do {
            documents = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
                bookDirectory: draftsDirectory,
                chaptersDirectory: draftsDirectory,
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

    // / drafts/ counterpart of `updateChapter` (= re-edits an existing draft in
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / duplicate).
    private func updateDraftChapter(
        id: UUID,
        title: String,
        bodyMarkdown: String,
        summary: String?
    ) async throws -> ChapterDescriptor {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // Mirror `updateChapter`'s scope guard (= the chapter focus lock = the user is
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // reviewing a draft).
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
            let (_, draftsDirectory, indexURL) = try resolveDraftsPaths()
            documents = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
                bookDirectory: draftsDirectory,
                chaptersDirectory: draftsDirectory,
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
            let (bookDirectory, draftsDirectory, indexURL) = try resolveDraftsPaths()
            try Self.writeFileSystemChapter(
                chapter: updated,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: bookDirectory,
                chaptersDirectory: draftsDirectory,
                indexURL: indexURL
            )
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
        return ChapterDescriptor(updated)
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
                // Read the existing body before the update so the success envelope can
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // `new_text` for the in-chat preview card.
                let oldBody: String
                do {
                    let (_, existing) = try await readChapter(id: id)
                    oldBody = existing ?? ""
                } catch {
                    // If the chapter didn't exist (= treat as create-flavored update), we
                    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                    // body means the entire new body is "+" lines.
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

    // / Variant for the `update` action — enriches the envelope with a
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / reads `diff.stats`).
    private static func encodeSuccessUpdate(
        action: BookChapterAction,
        chapter: ChapterDescriptor,
        oldBody: String,
        newBody: String
    ) -> String {
        let diff = computeUnifiedDiff(old: oldBody, new: newBody)
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

    // / Plain unified-diff product (= text + line / char counts). Pure function
    // / so it's reachable from unit tests without an actor.

    // / Compute a minimal unified diff between two strings (= the form hermes
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / new\n@@\n-removed line\n+added line\n context\n"




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

    // / Encode a BookScopeViolation into the standard failure envelope. See
    // / BookWorldTool.encodeFailureScopeViolation for the matching contract.
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
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
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

