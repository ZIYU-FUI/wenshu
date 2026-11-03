// BookChapterTool.swift Per-book chapter CRUD tool (= wraps FileSystemChapterStore).
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// Document struct with category=.chapter (= the canonical wenshu-side metadata shape).
import Foundation
import WenshuAgent

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
    let currentChatBookIDProvider: @Sendable () -> UUID?

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
        let chapters = dir.appendingPathComponent("chapters", isDirectory: true)
        if let body = FileSystemChapterStore.loadChapterBodyFromFileSystem(
            id: id,
            chaptersDirectory: chapters
        ) {
            return body
        }
        return FileSystemChapterStore.loadChapterBodyFromFileSystem(
            id: id,
            chaptersDirectory: dir.appendingPathComponent("drafts", isDirectory: true)
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

    /// The chapter tiers to read from, in resolution order.
    /// `chapters/` = confirmed body; `drafts/` = the agent's staging area.
    func readTiers() throws -> [ChapterTier] {
        let (bookDirectory, chaptersDirectory, indexURL) = try resolvePaths()
        let (_, draftsDirectory, draftsIndexURL) = try resolveDraftsPaths()
        return [
            ChapterTier(
                name: "chapters",
                bookDirectory: bookDirectory,
                directory: chaptersDirectory,
                indexURL: indexURL
            ),
            ChapterTier(
                name: "drafts",
                bookDirectory: bookDirectory,
                directory: draftsDirectory,
                indexURL: draftsIndexURL
            )
        ]
    }

    func readChapter(id: UUID) async throws -> (ChapterDescriptor, String?) {
        do {
            let tiers = try readTiers()
            guard let located = Self.locateChapter(id: id, across: tiers) else {
                throw BookChapterError.entryNotFound(id: id)
            }
            return (ChapterDescriptor(located.document), located.tier.body(id: id))
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
        documents = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: draftsDirectory,
            chaptersDirectory: draftsDirectory,
            indexURL: draftsDirectory.deletingLastPathComponent().appendingPathComponent("drafts.json")
        )) ?? []
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
            let tiers = try readTiers()
            guard let located = Self.locateChapter(id: id, across: tiers) else {
                throw BookChapterError.entryNotFound(id: id)
            }
            try Self.deleteFileSystemChapter(
                id: id,
                bookDirectory: located.tier.bookDirectory,
                chaptersDirectory: located.tier.directory,
                indexURL: located.tier.indexURL
            )
            // A cover is a CHILD of its document: the .md file is
            // gone, so the cover that depicted it goes with it.
            //
            // The removal is TOLERANT: the document delete is the
            // important operation, and a cover that cannot be
            // removed must not stop it.
            await CoverCascade.live().removeCoverTolerantly(
                forBookDocFileAt: located.tier.directory
                    .appendingPathComponent("\(id.uuidString).md")
            )
        } catch let err as BookChapterError {
            throw err
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
    }

    func listChapters(bookId: UUID) async throws -> [ChapterDescriptor] {
        let tiers = try readTiers()
        let documents = Self.chapterDocuments(across: tiers)
        let filtered = documents.filter { $0.bookId == bookId }
        let sorted = filtered.sorted { $0.updatedAt > $1.updatedAt }
        return sorted.map { ChapterDescriptor($0) }
    }

    func findChapter(bookId: UUID, title: String) async throws -> ChapterDescriptor? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tiers = try readTiers()
        let documents = Self.chapterDocuments(across: tiers)
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
        documents = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: draftsDirectory,
            chaptersDirectory: draftsDirectory,
            indexURL: indexURL
        )) ?? []
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

