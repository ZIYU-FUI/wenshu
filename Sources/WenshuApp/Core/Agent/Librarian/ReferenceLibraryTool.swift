//
//  ReferenceLibraryTool.swift · Wenshu · v2.0 (2026-09-25)
//
//  Per-library reference CRUD tool (= wraps FileSystemReferenceStore).
//
//  Mirrors BookWorldTool / BookCharacterTool / BookChapterTool /
//  BookOutlineTool patterns. The library-public scope differs from
//  the per-book scope (= references are library-wide, not per-book;
//  = every reference is reusable across all books in the library).
//
//  LLM-friendly verbs: create / read / update / delete / list / find /
//  upsert (= upsert is the primary "research recurring" verb: same
//  title = same document, edited in place; boss 2026-09-25 directive).
//
//  Layer model:
//    - .layerRaw       = the original source the user imports
//    - .layerEntities  = user-facing entity layer (= character /
//                        location / concept / artifact / etc.)
//    - .layerAbstracts = LLM-derived (= NOT exposed to LLM via tool)
//    - .layerIndexes   = LLM-derived (= NOT exposed to LLM via tool)
//
//  The Tool accepts `layer: "raw" | "entities"` (= only the user-
//  facing layers; LLM-derived layers stay hidden per the spec v5
//  ReferenceLayer.isUserFacing convention).
//

import Foundation

// MARK: - ReferenceDescriptor

struct ReferenceDescriptor: Sendable, Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let layer: String
    let category: String?
    let entityType: String
    let summary: String
    let source: String?
    let url: String?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        title: String,
        layer: String,
        category: String?,
        entityType: String,
        summary: String,
        source: String?,
        url: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.layer = layer
        self.category = category
        self.entityType = entityType
        self.summary = summary
        self.source = source
        self.url = url
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(_ reference: Reference) {
        self.id = reference.id
        self.title = reference.title
        // Map ReferenceLayer.wire_internal raw values (= "layerRaw" /
        // "layerEntities") to the LLM-friendly wire names (= "raw" /
        // "entities"). The internal case names are verbose because
        // the domain enum predates the agent tool surface.
        self.layer = Self.wireLayer(reference.layer)
        self.category = reference.category?.rawValue
        self.entityType = reference.entityType.rawValue
        self.summary = reference.summary
        self.source = reference.source
        self.url = reference.url
        self.createdAt = reference.createdAt
        self.updatedAt = reference.updatedAt
    }

    /// ReferenceLayer.wireRawValue: maps the internal layer enum to
    /// the LLM-friendly wire string used in tool input / output.
    static func wireLayer(_ layer: ReferenceLayer) -> String {
        switch layer {
        case .layerRaw:       return "raw"
        case .layerEntities:  return "entities"
        case .layerAbstracts: return "abstracts"
        case .layerIndexes:   return "indexes"
        }
    }
}

// MARK: - Action enum

enum ReferenceLibraryAction: String, Sendable, Codable, CaseIterable, Equatable {
    case create
    case read
    case update
    case delete
    case list
    case find
    case upsert
}

// MARK: - Errors

enum ReferenceLibraryError: Error, LocalizedError, Sendable, Equatable {
    case emptyTitle
    case entryNotFound(id: UUID)
    case invalidInput(reason: String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "ReferenceLibraryTool: reference title was empty or whitespace-only."
        case .entryNotFound(let id):
            return "ReferenceLibraryTool: reference \(id.uuidString) not found."
        case .invalidInput(let reason):
            return "ReferenceLibraryTool: invalid input — \(reason)."
        case .underlying(let msg):
            return "ReferenceLibraryTool: underlying error — \(msg)."
        }
    }
}

// MARK: - Actor

actor ReferenceLibraryActor {
    private let referenceStore: any ReferenceStoring

    init(referenceStore: any ReferenceStoring) {
        self.referenceStore = referenceStore
    }

    var referenceLibraryRoot: URL {
        referenceStore.referenceLibraryRoot
    }

    /// Test-only body accessor.
    func readBodyForTest(id: UUID) async -> String? {
        referenceStore.loadReferenceBody(id: id)
    }

    // MARK: - CRUD

    func createReference(
        title: String,
        bodyMarkdown: String,
        layer: String = "raw",
        category: String? = nil,
        entityType: String = "other",
        source: String? = nil,
        url: String? = nil,
        summary: String = ""
    ) async throws -> ReferenceDescriptor {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ReferenceLibraryError.emptyTitle
        }
        let parsedLayer = parseLayer(layer)
        let parsedCategory = category.flatMap { EntityCategory(rawValue: $0) }
        let parsedType = EntityType(rawValue: entityType) ?? .other
        let reference = Reference(
            title: trimmed,
            source: source,
            url: url,
            layer: parsedLayer,
            category: parsedLayer == .layerEntities ? parsedCategory : nil,
            entityType: parsedType,
            summary: summary
        )
        do {
            try referenceStore.saveReference(reference, bodyMarkdown: bodyMarkdown)
        } catch {
            throw ReferenceLibraryError.underlying(String(describing: error))
        }
        return ReferenceDescriptor(reference)
    }

    func readReference(id: UUID) async throws -> (ReferenceDescriptor, String?) {
        do {
            let references = try referenceStore.loadAllReferences()
            guard let reference = references.first(where: { $0.id == id }) else {
                throw ReferenceLibraryError.entryNotFound(id: id)
            }
            let body = referenceStore.loadReferenceBody(id: id)
            return (ReferenceDescriptor(reference), body)
        } catch let err as ReferenceLibraryError {
            throw err
        } catch {
            throw ReferenceLibraryError.underlying(String(describing: error))
        }
    }

    func updateReference(
        id: UUID,
        title: String,
        bodyMarkdown: String,
        category: String? = nil,
        entityType: String? = nil,
        source: String? = nil,
        url: String? = nil,
        summary: String? = nil
    ) async throws -> ReferenceDescriptor {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ReferenceLibraryError.emptyTitle
        }
        let references = (try? referenceStore.loadAllReferences()) ?? []
        guard let existing = references.first(where: { $0.id == id }) else {
            throw ReferenceLibraryError.entryNotFound(id: id)
        }
        var updated = existing
        updated.title = trimmed
        if let summary { updated.summary = summary }
        if let source { updated.source = source }
        if let url { updated.url = url }
        if let entityType, let parsed = EntityType(rawValue: entityType) {
            updated.entityType = parsed
        }
        if existing.layer == .layerEntities {
            updated.category = category.flatMap { EntityCategory(rawValue: $0) } ?? existing.category
        }
        updated.updatedAt = Date()
        do {
            try referenceStore.replaceReference(updated, bodyMarkdown: bodyMarkdown)
        } catch {
            throw ReferenceLibraryError.underlying(String(describing: error))
        }
        return ReferenceDescriptor(updated)
    }

    func deleteReference(id: UUID) async throws {
        do {
            try referenceStore.deleteReference(id: id)
        } catch {
            throw ReferenceLibraryError.underlying(String(describing: error))
        }
    }

    func listReferences(layer: String? = nil) async throws -> [ReferenceDescriptor] {
        let all = (try? referenceStore.loadAllReferences()) ?? []
        let filtered: [Reference]
        if let layer {
            // Explicit layer requested. Reject LLM-derived layers
            // (= .layerAbstracts / .layerIndexes) by returning empty
            // rather than silently falling back to user-managed.
            guard let parsedLayer = parseLayerIfUserFacing(layer) else {
                return []
            }
            filtered = all.filter { $0.layer == parsedLayer }
        } else {
            // Default: user-managed layers (= raw + entities; =
            // excludes the LLM-derived .layerAbstracts / .layerIndexes
            // which stay hidden per the spec v5 convention).
            filtered = all.filter { $0.layer == .layerRaw || $0.layer == .layerEntities }
        }
        let sorted = filtered.sorted { $0.updatedAt > $1.updatedAt }
        return sorted.map { ReferenceDescriptor($0) }
    }

    func findReference(title: String, layer: String? = nil) async throws -> ReferenceDescriptor? {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = (try? referenceStore.loadAllReferences()) ?? []
        let candidates: [Reference]
        if let layer {
            // Explicit layer requested. Reject LLM-derived layers
            // (= .layerAbstracts / .layerIndexes) by returning nil.
            guard let parsedLayer = parseLayerIfUserFacing(layer) else {
                return nil
            }
            candidates = all.filter { $0.layer == parsedLayer }
        } else {
            // Default: search across both raw + entities (= user-managed).
            candidates = all.filter { $0.layer == .layerRaw || $0.layer == .layerEntities }
        }
        let match = candidates.first { ref in
            ref.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
        return match.map { ReferenceDescriptor($0) }
    }

    /// Upsert by title within a layer (= the recurring-research path).
    /// If an entry with the same case-insensitive trimmed title
    /// already exists in the layer, its body + summary + source +
    /// url + updatedAt are refreshed in place; otherwise a new
    /// reference is created with a fresh UUID.
    func upsertReference(
        title: String,
        bodyMarkdown: String,
        layer: String = "raw",
        category: String? = nil,
        entityType: String = "other",
        source: String? = nil,
        url: String? = nil,
        summary: String = ""
    ) async throws -> ReferenceDescriptor {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ReferenceLibraryError.emptyTitle
        }
        let parsedLayer = parseLayer(layer)
        let parsedCategory = category.flatMap { EntityCategory(rawValue: $0) }
        let parsedType = EntityType(rawValue: entityType) ?? .other
        do {
            let result = try referenceStore.upsertReference(
                title: trimmed,
                bodyMarkdown: bodyMarkdown,
                layer: parsedLayer,
                category: parsedLayer == .layerEntities ? parsedCategory : nil,
                source: source,
                url: url,
                entityType: parsedType,
                summary: summary
            )
            return ReferenceDescriptor(result)
        } catch {
            throw ReferenceLibraryError.underlying(String(describing: error))
        }
    }

    // MARK: - Layer parsing

    /// Map LLM-facing string to ReferenceLayer. Defaults to .layerRaw
    /// (= the most common research target). LLM-derived layers
    /// (.layerAbstracts / .layerIndexes) are explicitly rejected.
    private func parseLayer(_ raw: String) -> ReferenceLayer {
        switch raw.lowercased() {
        case "raw", "sourcematerial":
            return .layerRaw
        case "entities", "entity":
            return .layerEntities
        case "abstracts":
            // LLM-derived: silently fall back to raw (= the LLM should
            // not be writing abstracts; = the tool rejects gracefully
            // by routing to .layerRaw and the user can re-classify).
            return .layerRaw
        case "indexes":
            return .layerRaw
        default:
            return .layerRaw
        }
    }

    /// Same as parseLayer, but used by list / find (= returns nil if
    /// the LLM asked for an LLM-derived layer = the operation
    /// silently returns no results rather than crashing).
    private func parseLayerIfUserFacing(_ raw: String) -> ReferenceLayer? {
        switch raw.lowercased() {
        case "raw", "sourcematerial":
            return .layerRaw
        case "entities", "entity":
            return .layerEntities
        default:
            return nil
        }
    }

    // MARK: - Tool-protocol entry-point (LLM-facing dispatcher)

    func execute(input: String) async throws -> String {
        let envelope: [String: Any]
        do {
            guard let data = input.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw ReferenceLibraryError.invalidInput(reason: "input must be a JSON object")
            }
            envelope = parsed
        } catch let error as ReferenceLibraryError {
            return Self.encodeFailure(action: nil, error: error)
        } catch {
            return Self.encodeFailure(
                action: nil,
                error: ReferenceLibraryError.invalidInput(
                    reason: "input JSON parse failed: \(error.localizedDescription)"
                )
            )
        }

        guard let actionRaw = envelope["action"] as? String,
              let action = ReferenceLibraryAction(rawValue: actionRaw)
        else {
            return Self.encodeFailure(
                action: nil,
                error: ReferenceLibraryError.invalidInput(
                    reason: "missing or unknown 'action' (expected: create / read / update / delete / list / find / upsert)"
                )
            )
        }

        do {
            switch action {
            case .create:
                let title = envelope["title"] as? String ?? ""
                let layer = envelope["layer"] as? String ?? "raw"
                let category = envelope["category"] as? String
                let entityType = envelope["entity_type"] as? String ?? "other"
                let source = envelope["source"] as? String
                let url = envelope["url"] as? String
                let summary = envelope["summary"] as? String ?? ""
                let body = Self.extractMarkdown(envelope)
                let reference = try await createReference(
                    title: title,
                    bodyMarkdown: body,
                    layer: layer,
                    category: category,
                    entityType: entityType,
                    source: source,
                    url: url,
                    summary: summary
                )
                return Self.encodeSuccess(action: action, reference: reference, created: true)

            case .read:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw ReferenceLibraryError.invalidInput(reason: "read requires 'id' (UUID string)")
                }
                let (reference, body) = try await readReference(id: id)
                return Self.encodeSuccessRead(action: action, reference: reference, body: body)

            case .update:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw ReferenceLibraryError.invalidInput(reason: "update requires 'id' (UUID string)")
                }
                let title = envelope["title"] as? String ?? ""
                let category = envelope["category"] as? String
                let entityType = envelope["entity_type"] as? String
                let source = envelope["source"] as? String
                let url = envelope["url"] as? String
                let summary = envelope["summary"] as? String
                let body = Self.extractMarkdown(envelope)
                let reference = try await updateReference(
                    id: id,
                    title: title,
                    bodyMarkdown: body,
                    category: category,
                    entityType: entityType,
                    source: source,
                    url: url,
                    summary: summary
                )
                return Self.encodeSuccess(action: action, reference: reference, created: false)

            case .delete:
                guard let id = Self.parseUUID(envelope["id"]) else {
                    throw ReferenceLibraryError.invalidInput(reason: "delete requires 'id' (UUID string)")
                }
                try await deleteReference(id: id)
                return Self.encodeSuccess(action: action)

            case .list:
                let layer = envelope["layer"] as? String
                let references = try await listReferences(layer: layer)
                return Self.encodeSuccessList(action: action, references: references)

            case .find:
                let title = envelope["title"] as? String ?? ""
                let layer = envelope["layer"] as? String
                let reference = try await findReference(title: title, layer: layer)
                return Self.encodeSuccessFind(action: action, reference: reference)

            case .upsert:
                let title = envelope["title"] as? String ?? ""
                let layer = envelope["layer"] as? String ?? "raw"
                let category = envelope["category"] as? String
                let entityType = envelope["entity_type"] as? String ?? "other"
                let source = envelope["source"] as? String
                let url = envelope["url"] as? String
                let summary = envelope["summary"] as? String ?? ""
                let body = Self.extractMarkdown(envelope)
                let reference = try await upsertReference(
                    title: title,
                    bodyMarkdown: body,
                    layer: layer,
                    category: category,
                    entityType: entityType,
                    source: source,
                    url: url,
                    summary: summary
                )
                // The "created" flag in the JSON envelope tells the
                // LLM whether this upsert hit the create branch or
                // the update branch.
                let wasCreated = Date().timeIntervalSince(reference.createdAt) < 1.0
                return Self.encodeSuccess(action: action, reference: reference, created: wasCreated)
            }
        } catch let error as ReferenceLibraryError {
            return Self.encodeFailure(action: action, error: error)
        } catch {
            return Self.encodeFailure(
                action: action,
                error: ReferenceLibraryError.underlying(String(describing: error))
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
        action: ReferenceLibraryAction,
        reference: ReferenceDescriptor? = nil,
        created: Bool? = nil
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue]
        if let reference {
            payload["reference"] = descriptorToJSON(reference)
        }
        if let created {
            payload["created"] = created
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessRead(
        action: ReferenceLibraryAction,
        reference: ReferenceDescriptor,
        body: String?
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "reference": descriptorToJSON(reference),
            "body": body ?? ""
        ]
        return encodeJSON(payload)
    }

    private static func encodeSuccessFind(
        action: ReferenceLibraryAction,
        reference: ReferenceDescriptor?
    ) -> String {
        var payload: [String: Any] = ["ok": true, "action": action.rawValue, "found": reference != nil]
        if let reference {
            payload["reference"] = descriptorToJSON(reference)
        }
        return encodeJSON(payload)
    }

    private static func encodeSuccessList(
        action: ReferenceLibraryAction,
        references: [ReferenceDescriptor]
    ) -> String {
        let payload: [String: Any] = [
            "ok": true,
            "action": action.rawValue,
            "references": references.map { descriptorToJSON($0) }
        ]
        return encodeJSON(payload)
    }

    private static func encodeFailure(
        action: ReferenceLibraryAction?,
        error: ReferenceLibraryError
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

    private static func descriptorToJSON(_ d: ReferenceDescriptor) -> [String: Any] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        var dict: [String: Any] = [
            "id": d.id.uuidString,
            "title": d.title,
            "layer": d.layer,
            "entity_type": d.entityType,
            "summary": d.summary,
            "createdAt": iso.string(from: d.createdAt),
            "updatedAt": iso.string(from: d.updatedAt)
        ]
        if let category = d.category { dict["category"] = category }
        if let source = d.source { dict["source"] = source }
        if let url = d.url { dict["url"] = url }
        return dict
    }

    private static func encodeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let s = String(data: data, encoding: .utf8)
        else {
            return "{\"ok\":false,\"error\":\"ReferenceLibraryTool: JSON encode failed\"}"
        }
        return s
    }
}

// MARK: - Tool-protocol adapter

actor ReferenceLibraryTool: Tool {
    let name = "reference_library"
    let description = "Library-public reference CRUD with dedup-by-title upsert (= wraps FileSystemReferenceStore). LLM-friendly verbs: create / read / update / delete / list / find / upsert."

    private let actor: ReferenceLibraryActor

    init(actor: ReferenceLibraryActor) {
        self.actor = actor
    }

    func execute(input: String) async throws -> String {
        try await actor.execute(input: input)
    }
}

// MARK: - ToolRegistry bootstrap

extension ReferenceLibraryTool {
    /// Module-load registration with `ToolRegistry.shared`.
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "reference_library",
                toolset: "library",
                schema: ToolRegistrySchema(
                    name: "reference_library",
                    description: "Library-public reference CRUD with dedup-by-title upsert (= wraps FileSystemReferenceStore). Same-title research edits the existing document instead of creating a new one (= boss 2026-09-25 directive).",
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The reference operation to perform.",
                            enumValues: ["create", "read", "update", "delete", "list", "find", "upsert"]
                        ),
                        "id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Reference id (UUID). Required for read / update / delete."
                        ),
                        "title": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Reference title. Required for create / find / upsert. For upsert, same-title = edit-in-place."
                        ),
                        "layer": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Reference layer ('raw' or 'entities'). Defaults to 'raw'.",
                            enumValues: ["raw", "entities"]
                        ),
                        "category": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Entity category (for layer=entities)."
                        ),
                        "entity_type": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "EntityType (character / location / event / concept / artifact / organization / era / work / other)."
                        ),
                        "source": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Bibliographic source string."
                        ),
                        "url": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Source URL (web sources)."
                        ),
                        "summary": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "1-line summary."
                        ),
                        "markdown": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Full .md body. Alias: 'body'."
                        )
                    ],
                    required: ["action"]
            ),
            handler: ReferenceLibraryTool.shared,
            description: "Library-public reference CRUD with dedup-by-title upsert.",
            emoji: "📚"
        )
        }
    }()

    nonisolated static let shared: ReferenceLibraryTool = {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-toolregistry-references-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmpRoot)
        return ReferenceLibraryTool(actor: ReferenceLibraryActor(referenceStore: store))
    }()
}