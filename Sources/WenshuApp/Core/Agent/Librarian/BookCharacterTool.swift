//
//  BookCharacterTool.swift · Wenshu · v2.0 (2026-09-25)
//
//  Per-book character CRUD tool (= wraps FileSystemCharacterStore).
//  Mirrors BookManagerTool + BookWorldTool patterns.
//
//  LLM-friendly verbs: create / read / update / delete / list / find.
//
//  Standard-axis S3: actor owns JSON parsing (single source of truth);
//  the Tool struct is a thin adapter.
//

import Foundation

// MARK: - CharacterDescriptor

struct CharacterDescriptor: Sendable, Codable, Equatable, Identifiable {
    let id: UUID
    let bookId: UUID
    let name: String
    let role: String
    let age: Int?
    let arc: String?
    let summary: String
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        bookId: UUID,
        name: String,
        role: String,
        age: Int?,
        arc: String?,
        summary: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.bookId = bookId
        self.name = name
        self.role = role
        self.age = age
        self.arc = arc
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(_ character: Character) {
        self.id = character.id
        self.bookId = character.bookId
        self.name = character.name
        self.role = character.role.rawValue
        self.age = character.age
        self.arc = character.arc
        self.summary = character.summary
        self.createdAt = character.createdAt
        self.updatedAt = character.updatedAt
    }
}

// MARK: - Action enum

enum BookCharacterAction: String, Sendable, Codable, CaseIterable, Equatable {
    case create
    case read
    case update
    case delete
    case list
    case find
}

// MARK: - Errors

enum BookCharacterError: Error, LocalizedError, Sendable, Equatable {
    case emptyName
    case entryNotFound(id: UUID)
    case invalidInput(reason: String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "BookCharacterTool: character name was empty or whitespace-only."
        case .entryNotFound(let id):
            return "BookCharacterTool: character \(id.uuidString) not found."
        case .invalidInput(let reason):
            return "BookCharacterTool: invalid input — \(reason)."
        case .underlying(let msg):
            return "BookCharacterTool: underlying error — \(msg)."
        }
    }
}

// MARK: - Actor

actor BookCharacterActor {
    private let characterStore: any CharacterStoring

    /// Closure returning the chat session's currently-bound book
    /// (= nil when the chat session has no bound book). See
    /// BookWorldActor's matching field for the contract.
    private let currentChatBookIDProvider: @Sendable () -> UUID?

    init(
        characterStore: any CharacterStoring,
        currentChatBookIDProvider: @escaping @Sendable () -> UUID? = { nil }
    ) {
        self.characterStore = characterStore
        self.currentChatBookIDProvider = currentChatBookIDProvider
    }

    var bookDirectory: URL {
        characterStore.bookDirectory
    }

    /// Test-only body accessor (mirrors BookWorldActor.readBodyForTest).
    func readBodyForTest(id: UUID) async -> String? {
        let store = FileSystemCharacterStore(bookDirectory: characterStore.bookDirectory)
        return store.loadCharacterBody(id: id)
    }

    // MARK: - CRUD

    func createCharacter(
        bookId: UUID,
        name: String,
        bodyMarkdown: String,
        role: String = "other",
        age: Int? = nil,
        arc: String? = nil,
        summary: String = ""
    ) async throws -> CharacterDescriptor {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookCharacterError.emptyName
        }
        let parsedRole = CharacterRole(rawValue: role) ?? .other
        let character = Character(
            bookId: bookId,
            name: trimmed,
            age: age,
            role: parsedRole,
            arc: arc,
            summary: summary
        )
        do {
            try characterStore.saveCharacter(character, bodyMarkdown: bodyMarkdown)
        } catch {
            throw BookCharacterError.underlying(String(describing: error))
        }
        return CharacterDescriptor(character)
    }

    func readCharacter(id: UUID) async throws -> (CharacterDescriptor, String?) {
        do {
            let characters = try characterStore.loadCharacters()
            guard let character = characters.first(where: { $0.id == id }) else {
                throw BookCharacterError.entryNotFound(id: id)
            }
            let body = characterStore.loadCharacterBody(id: id)
            return (CharacterDescriptor(character), body)
        } catch let err as BookCharacterError {
            throw err
        } catch {
            throw BookCharacterError.underlying(String(describing: error))
        }
    }

    func updateCharacter(
        id: UUID,
        name: String,
        bodyMarkdown: String,
        role: String? = nil,
        age: Int? = nil,
        arc: String? = nil,
        summary: String? = nil
    ) async throws -> CharacterDescriptor {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookCharacterError.emptyName
        }
        let characters: [Character]
        do {
            characters = try characterStore.loadCharacters()
        } catch {
            throw BookCharacterError.underlying(String(describing: error))
        }
        guard let existing = characters.first(where: { $0.id == id }) else {
            throw BookCharacterError.entryNotFound(id: id)
        }
        let updatedRole: CharacterRole
        if let role, let parsed = CharacterRole(rawValue: role) {
            updatedRole = parsed
        } else {
            updatedRole = existing.role
        }
        var updated = existing
        updated.name = trimmed
        updated.role = updatedRole
        if let age { updated.age = age }
        if let arc { updated.arc = arc }
        if let summary { updated.summary = summary }
        updated.updatedAt = Date()
        do {
            try characterStore.replaceCharacter(updated, bodyMarkdown: bodyMarkdown)
        } catch {
            throw BookCharacterError.underlying(String(describing: error))
        }
        return CharacterDescriptor(updated)
    }

    func deleteCharacter(id: UUID) async throws {
        do {
            try characterStore.deleteCharacter(id: id)
        } catch {
            throw BookCharacterError.underlying(String(describing: error))
        }
    }

    func listCharacters(bookId: UUID) async throws -> [CharacterDescriptor] {
        let characters: [Character]
        do {
            characters = try characterStore.loadCharacters()
        } catch {
            throw BookCharacterError.underlying(String(describing: error))
        }
        let filtered = characters.filter { $0.bookId == bookId }
        let sorted = filtered.sorted { $0.updatedAt > $1.updatedAt }
        return sorted.map { CharacterDescriptor($0) }
    }

    func findCharacter(bookId: UUID, name: String) async throws -> CharacterDescriptor? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let characters: [Character]
        do {
            characters = try characterStore.loadCharacters()
        } catch {
            throw BookCharacterError.underlying(String(describing: error))
        }
        let match = characters.first { character in
            character.bookId == bookId &&
            character.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed
        }
        return match.map { CharacterDescriptor($0) }
    }

    // MARK: - Tool-protocol entry-point (LLM-facing dispatcher)

    func execute(input: String) async throws -> String {
        let envelope: [String: Any]
        do {
            guard let data = input.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw BookCharacterError.invalidInput(reason: "input must be a JSON object")
            }
            envelope = parsed
        } catch let error as BookCharacterError {
            return Self.encodeFailure(action: nil, error: error)
        } catch {
            return Self.encodeFailure(
                action: nil,
                error: BookCharacterError.invalidInput(
                    reason: "input JSON parse failed: \(error.localizedDescription)"
                )
            )
        }

        guard let actionRaw = envelope["action"] as? String,
              let action = BookCharacterAction(rawValue: actionRaw)
        else {
            return Self.encodeFailure(
                action: nil,
                error: BookCharacterError.invalidInput(
                    reason: "missing or unknown 'action' (expected: create / read / update / delete / list / find)"
                )
            )
        }

        // Scope guard: every action MUST carry a `book_id` that matches
        // the chat session's currently-bound book. See BookWorldActor
        // (= identical contract).
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
                error: BookCharacterError.invalidInput(
                    reason: "scope guard failed: \(error.localizedDescription)"
                )
            )
        }

        do {
            switch action {
            case .create:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookCharacterError.invalidInput(reason: "create requires 'book_id' (UUID string)")
                }
                let name = envelope["name"] as? String ?? ""
                let role = envelope["role"] as? String ?? "other"
                let age = (envelope["age"] as? Int)
                let arc = envelope["arc"] as? String
                let summary = envelope["summary"] as? String ?? ""
                let body = Self.extractMarkdown(envelope)
                let character = try await createCharacter(
                    bookId: bookId,
                    name: name,
                    bodyMarkdown: body,
                    role: role,
                    age: age,
                    arc: arc,
                    summary: summary
                )
                return Self.encodeSuccess(action: action, character: character)

            case .read:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookCharacterError.invalidInput(reason: "read requires 'id' (UUID string)")
                }
                let (character, body) = try await readCharacter(id: id)
                return Self.encodeSuccessRead(action: action, character: character, body: body)

            case .update:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookCharacterError.invalidInput(reason: "update requires 'id' (UUID string)")
                }
                let name = envelope["name"] as? String ?? ""
                let role = envelope["role"] as? String
                let age = envelope["age"] as? Int
                let arc = envelope["arc"] as? String
                let summary = envelope["summary"] as? String
                let body = Self.extractMarkdown(envelope)
                let character = try await updateCharacter(
                    id: id,
                    name: name,
                    bodyMarkdown: body,
                    role: role,
                    age: age,
                    arc: arc,
                    summary: summary
                )
                return Self.encodeSuccess(action: action, character: character)

            case .delete:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw BookCharacterError.invalidInput(reason: "delete requires 'id' (UUID string)")
                }
                try await deleteCharacter(id: id)
                return Self.encodeSuccess(action: action)

            case .list:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookCharacterError.invalidInput(reason: "list requires 'book_id' (UUID string)")
                }
                let characters = try await listCharacters(bookId: bookId)
                return Self.encodeSuccessList(action: action, characters: characters)

            case .find:
                guard let bookId = Self.parseUUID(envelope["book_id"]) else {
                    throw BookCharacterError.invalidInput(reason: "find requires 'book_id' (UUID string)")
                }
                let name = envelope["name"] as? String ?? ""
                let character = try await findCharacter(bookId: bookId, name: name)
                return Self.encodeSuccessFind(action: action, character: character)
            }
        } catch let error as BookCharacterError {
            return Self.encodeFailure(action: action, error: error)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: BookCharacterError.underlying(String(describing: error))
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
        action: BookCharacterAction,
        character: CharacterDescriptor? = nil
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        if let character {
            payload["character"] = descriptorToJSON(character)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessRead(
        action: BookCharacterAction,
        character: CharacterDescriptor,
        body: String?
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "character": descriptorToJSON(character),
            "body": body ?? ""
        ]
        return encodeJSON(payload)
    }

    private static func encodeSuccessFind(
        action: BookCharacterAction,
        character: CharacterDescriptor?
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue, "found": character != nil]
        if let character {
            payload["character"] = descriptorToJSON(character)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessList(
        action: BookCharacterAction,
        characters: [CharacterDescriptor]
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "characters": characters.map { descriptorToJSON($0) }
        ]
        return encodeJSON(payload)
    }

    private static func encodeFailure(
        action: BookCharacterAction?,
        error: BookCharacterError
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
    /// See BookWorldTool.encodeFailureScopeViolation for the
    /// matching contract (= identical shape across the 4 book_X
    /// tools).
    private static func encodeFailureScopeViolation(
        action: BookCharacterAction,
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

    private static func descriptorToJSON(_ d: CharacterDescriptor) -> [String: Any] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        var dict: [String: Any] = [
            "id": d.id.uuidString,
            "book_id": d.bookId.uuidString,
            "name": d.name,
            "role": d.role,
            "summary": d.summary,
            "createdAt": iso.string(from: d.createdAt),
            "updatedAt": iso.string(from: d.updatedAt)
        ]
        if let age = d.age { dict["age"] = age }
        if let arc = d.arc { dict["arc"] = arc }
        return dict
    }

    private static func encodeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"BookCharacterTool: JSON encode failed\"}"
        }
        return s
    }
}

// MARK: - Tool-protocol adapter

actor BookCharacterTool: Tool {
    let name = "book_character"
    let description = "Create / read / update / delete / list / find characters under a book (= protagonist / antagonist / supporting / narrator / other)."

    private let actor: BookCharacterActor

    init(actor: BookCharacterActor) {
        self.actor = actor
    }

    func execute(input: String) async throws -> String {
        try await actor.execute(input: input)
    }
}

// MARK: - ToolRegistry bootstrap

extension BookCharacterTool {
    /// Module-load registration with `ToolRegistry.shared`.
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "book_character",
                toolset: "library",
                schema: ToolRegistrySchema(
                    name: "book_character",
                    description: "Per-book character CRUD (= wraps FileSystemCharacterStore). LLM-friendly verbs: create / read / update / delete / list / find.",
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The character operation to perform.",
                            enumValues: ["create", "read", "update", "delete", "list", "find"]
                        ),
                        "book_id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Owning book id (UUID). Required for create / list / find."
                        ),
                        "id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Character id (UUID). Required for read / update / delete."
                        ),
                        "name": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Character name. Required for create / find."
                        ),
                        "role": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "CharacterRole (protagonist / antagonist / supporting / narrator / other)."
                        ),
                        "age": ToolRegistrySchemaProperty(
                            type: "integer",
                            description: "Optional age."
                        ),
                        "arc": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Optional narrative arc summary."
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
            handler: BookCharacterTool.shared,
            description: "Per-book character CRUD.",
            emoji: "👤"
        )
        }
    }()

    nonisolated static let shared: BookCharacterTool = {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-toolregistry-character-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let store = FileSystemCharacterStore(bookDirectory: tmpRoot)
        return BookCharacterTool(actor: BookCharacterActor(characterStore: store))
    }()
}