//
//  BookChapterTool.swift · Wenshu · v2.0 (2026-09-25)
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
    private let chapterStore: any ChapterStoring

    /// Closure returning the chat session's currently-bound book.
    /// See BookWorldActor's matching field for the contract.
    private let currentChatBookIDProvider: @Sendable () -> UUID?

    init(
        chapterStore: any ChapterStoring,
        currentChatBookIDProvider: @escaping @Sendable () -> UUID? = { nil }
    ) {
        self.chapterStore = chapterStore
        self.currentChatBookIDProvider = currentChatBookIDProvider
    }

    var bookDirectory: URL {
        chapterStore.bookDirectory
    }

    /// Test-only body accessor.
    func readBodyForTest(id: UUID) async -> String? {
        let store = FileSystemChapterStore(bookDirectory: chapterStore.bookDirectory)
        return store.loadChapterBody(id: id)
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
        let document = Document(
            bookId: bookId,
            category: .chapter,
            title: trimmed,
            byteSize: bodyMarkdown.utf8.count,
            summary: summary
        )
        do {
            try chapterStore.saveChapter(document, bodyMarkdown: bodyMarkdown)
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
        return ChapterDescriptor(document)
    }

    func readChapter(id: UUID) async throws -> (ChapterDescriptor, String?) {
        do {
            let documents = try chapterStore.loadChapters()
            guard let document = documents.first(where: { $0.id == id }) else {
                throw BookChapterError.entryNotFound(id: id)
            }
            let body = chapterStore.loadChapterBody(id: id)
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
        let documents: [Document]
        do {
            documents = try chapterStore.loadChapters()
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
            try chapterStore.replaceChapter(updated, bodyMarkdown: bodyMarkdown)
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
        return ChapterDescriptor(updated)
    }

    func deleteChapter(id: UUID) async throws {
        do {
            try chapterStore.deleteChapter(id: id)
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
    }

    func listChapters(bookId: UUID) async throws -> [ChapterDescriptor] {
        let documents: [Document]
        do {
            documents = try chapterStore.loadChapters()
        } catch {
            throw BookChapterError.underlying(String(describing: error))
        }
        let filtered = documents.filter { $0.bookId == bookId }
        let sorted = filtered.sorted { $0.updatedAt > $1.updatedAt }
        return sorted.map { ChapterDescriptor($0) }
    }

    func findChapter(bookId: UUID, title: String) async throws -> ChapterDescriptor? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let documents: [Document]
        do {
            documents = try chapterStore.loadChapters()
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
                let chapter = try await updateChapter(
                    id: id,
                    title: title,
                    bodyMarkdown: body,
                    summary: summary
                )
                return Self.encodeSuccess(action: action, chapter: chapter)

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
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return [
            "id": d.id.uuidString,
            "book_id": d.bookId.uuidString,
            "title": d.title,
            "summary": d.summary,
            "createdAt": iso.string(from: d.createdAt),
            "updatedAt": iso.string(from: d.updatedAt)
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
        let store = FileSystemChapterStore(bookDirectory: tmpRoot)
        return BookChapterTool(actor: BookChapterActor(chapterStore: store))
    }()
}