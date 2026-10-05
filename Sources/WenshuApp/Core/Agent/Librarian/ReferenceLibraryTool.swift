//
//  ReferenceLibraryTool.swift
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
//  title = same document, edited in place; (see OOB.md #2026-09-25) directive).
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
    let displayTitle: String?
    let layer: String
    let category: String?
    let tags: [String]
    let entityType: String
    let summary: String
    let source: String?
    let url: String?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        title: String,
        displayTitle: String? = nil,
        layer: String,
        category: String?,
        tags: [String],
        entityType: String,
        summary: String,
        source: String?,
        url: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.displayTitle = displayTitle
        self.layer = layer
        self.category = category
        self.tags = tags
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
        self.displayTitle = reference.displayTitle
        // Map ReferenceLayer.wire_internal raw values (= "layerRaw" /
        // "layerEntities") to the LLM-friendly wire names (= "raw" /
        // "entities"). The internal case names are verbose because
        // the domain enum predates the agent tool surface.
        self.layer = Self.wireLayer(reference.layer)
        self.category = reference.category?.rawValue
        // Tags are emitted sorted for stable on-the-wire output (= the
        // LLM emits them in any order; = the agent UI / tests can
        // depend on sorted form).
        self.tags = reference.tags.sorted()
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
    /// Append a new section to an existing reference's body (= the
    /// self-evolution mechanism). When the user prompt adds more
    /// context to a noun (= e.g. 'protagonist born in Xi'an'
    /// → 'protagonist lives in the Ming dynasty' → 'protagonist
    /// ate a bowl of Yangrou Paomo in Xi'an'), the agent extends
    /// the existing reference with new sections rather than
    /// rewriting the body from scratch. Sections whose
    /// `section_title` already exists are merged (= later
    /// occurrences update the older section instead of creating
    /// duplicates).
    case extend
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
        tags: Set<String> = [],
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
            tags: tags,
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

    /// Append a new section to an existing reference's body (= the
    /// self-evolution mechanism). When the user prompt adds more
    /// context to a noun (= e.g. 'protagonist born in Xi'an'
    /// → 'protagonist lives in the Ming dynasty' → 'protagonist
    /// ate a bowl of Yangrou Paomo in Xi'an'), the agent extends
    /// the existing reference with new sections rather than
    /// rewriting the body from scratch. Sections whose
    /// `section_title` already exists are merged (= later
    /// occurrences update the older section content instead of
    /// creating duplicates).
    ///
    /// Wire-format:
    ///   - id (UUID, required): the reference to extend (= the agent
    ///     should `find` the existing reference by title first, then
    ///     call extend with that id).
    ///   - section_title (string, required): the section heading to
    ///     add or merge. Prepended with `## ` (= h2) in the body.
    ///   - section_body (string, required): the new content for the
    ///     section. Markdown is preserved.
    ///   - tags (array of strings, optional): tags to add (= unioned
    ///     with existing tags; = never replaces).
    ///   - summary (string, optional): if non-empty, replaces the
    ///     existing summary (the latest high-level blurb wins).
    ///   - source / url (strings, optional): if non-empty, replaces
    ///     existing source / url.
    ///
    /// Returns the updated `ReferenceDescriptor`. Throws
    /// `entryNotFound` if the id doesn't exist.
    func extendReference(
        id: UUID,
        sectionTitle: String,
        sectionBody: String,
        tags: Set<String> = [],
        summary: String? = nil,
        source: String? = nil,
        url: String? = nil
    ) async throws -> ReferenceDescriptor {
        let trimmedTitle = sectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw ReferenceLibraryError.invalidInput(
                reason: "extend: section_title was empty"
            )
        }
        let references = (try? referenceStore.loadAllReferences()) ?? []
        guard let existing = references.first(where: { $0.id == id }) else {
            throw ReferenceLibraryError.entryNotFound(id: id)
        }
        // Load existing body (may be nil for legacy entries without
        // a .md file — fall back to empty string).
        let existingBody = referenceStore.loadReferenceBody(id: id) ?? ""
        let mergedBody = Self.mergeSection(
            into: existingBody,
            sectionTitle: trimmedTitle,
            sectionBody: sectionBody
        )
        // Tag merge: union (= never replace).
        let mergedTags = existing.tags.union(tags)
        // Field updates: only overwrite summary / source / url when
        // the caller explicitly provides non-empty values. Optional
        // nil keeps the existing value (= (see OOB.md #2026-09-25) directive:
        // the latest high-level blurb wins; = don't drop a known-good
        // summary just because the extend call didn't pass one).
        do {
            let updated = try referenceStore.upsertReference(
                title: existing.title,
                bodyMarkdown: mergedBody,
                layer: existing.layer,
                category: existing.category,
                tags: mergedTags,
                source: source ?? existing.source,
                url: url ?? existing.url,
                entityType: existing.entityType,
                summary: summary ?? existing.summary
            )
            return ReferenceDescriptor(updated)
        } catch {
            throw ReferenceLibraryError.underlying(String(describing: error))
        }
    }

    /// Merge `## <sectionTitle>` into `existingBody`. If a section
    /// with that title already exists, its content is replaced with
    /// the new body (= the most recent research wins; = no duplicate
    /// sections). If no section with that title exists, the section
    /// is appended at the end of the body.
    ///
    /// Markdown section parser: splits on lines that start with
    /// exactly `## ` (= h2 sections; = we don't merge into h1 titles
    /// or h3+ subsections because the reference body's top-level
    /// structure is h2 per the writer convention).
    static func mergeSection(
        into existingBody: String,
        sectionTitle: String,
        sectionBody: String
    ) -> String {
        let heading = "## \(sectionTitle)"
        let newSection = "\(heading)\n\n\(sectionBody.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        // Look for an existing `## <sectionTitle>` heading line.
        // We match the heading line prefix only (= the section ends
        // at the next `## ` heading or at end-of-body).
        var lines = existingBody.components(separatedBy: "\n")
        var headingLineIndex: Int?
        for (idx, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == heading {
                headingLineIndex = idx
                break
            }
        }
        if let start = headingLineIndex {
            // Find the next `## ` heading after `start`, or end-of-
            // body, to bound the existing section's content.
            var endIndex = lines.count
            for idx in (start + 1)..<lines.count {
                let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("## ") {
                    endIndex = idx
                    break
                }
            }
            // Replace lines[start..<end] with the new section (= the
            // heading + body, plus a trailing newline separator).
            let replacementLines = newSection.components(separatedBy: "\n")
            lines.replaceSubrange(start..<endIndex, with: replacementLines)
        } else {
            // No existing section — append. Insert a blank-line
            // separator if the body is non-empty and doesn't end
            // with one.
            if !existingBody.isEmpty,
               !existingBody.hasSuffix("\n\n") {
                if existingBody.hasSuffix("\n") {
                    lines.append("")
                } else {
                    lines.append("")
                    lines.append("")
                }
            }
            lines.append(contentsOf: newSection.components(separatedBy: "\n"))
        }
        return lines.joined(separator: "\n")
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
    /// url + tags + updatedAt are refreshed in place (= tags from
    /// the new payload are merged with existing tags, not replaced,
    /// so the cross-cutting facet is monotonically growing);
    /// otherwise a new reference is created with a fresh UUID.
    func upsertReference(
        title: String,
        bodyMarkdown: String,
        layer: String = "raw",
        category: String? = nil,
        tags: Set<String> = [],
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
            // Tag merge strategy: for an existing entry, the new tags
            // are unioned with the existing tags (= the user/LLM can
            // add tags over time without losing previously-classified
            // ones). For a fresh entry, the tags land as-is.
            let existingRefs = (try? referenceStore.loadReferences(layer: parsedLayer)) ?? []
            let normalizedTitle = trimmed.lowercased()
            let existingMatch = existingRefs.first { ref in
                ref.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle
            }
            let mergedTags: Set<String>
            if let existingTags = existingMatch?.tags {
                mergedTags = existingTags.union(tags)
            } else {
                mergedTags = tags
            }
            let result = try referenceStore.upsertReference(
                title: trimmed,
                bodyMarkdown: bodyMarkdown,
                layer: parsedLayer,
                category: parsedLayer == .layerEntities ? parsedCategory : nil,
                tags: mergedTags,
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
                // Tags is an optional [String] in the envelope. Accept
                // both `["a","b"]` (= canonical) and `nil` (= LLM didn't
                // provide any tags).
                let tagsArray = envelope["tags"] as? [String] ?? []
                let tags = Set(tagsArray)
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
                    tags: tags,
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
                let tagsArray = envelope["tags"] as? [String] ?? []
                let tags = Set(tagsArray)
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
                    tags: tags,
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

            case .extend:
                // Self-evolution mechanism. The agent finds an
                // existing reference via `find` first, then calls
                // extend with the id + a `section_title` + the new
                // section body. We append (= or merge if the section
                // already exists) rather than rewriting the body.
                let id = envelope["id"] as? String
                    ?? (envelope["id"] as? [String: Any])?["value"] as? String
                let sectionTitle = envelope["section_title"] as? String ?? ""
                let sectionBody = envelope["section_body"] as? String
                    ?? envelope["markdown"] as? String
                    ?? envelope["body"] as? String
                    ?? ""
                let tagsArray = envelope["tags"] as? [String] ?? []
                let tags = Set(tagsArray)
                let summary = envelope["summary"] as? String
                let source = envelope["source"] as? String
                let url = envelope["url"] as? String
                guard let idRaw = id, let parsed = UUID(uuidString: idRaw) else {
                    return Self.encodeFailure(
                        action: action,
                        error: .invalidInput(
                            reason: "extend: id is required and must be a UUID (= use `find` first to get it)"
                        )
                    )
                }
                guard !sectionTitle.isEmpty else {
                    return Self.encodeFailure(
                        action: action,
                        error: .invalidInput(
                            reason: "extend: section_title is required (= the heading for the new section)"
                        )
                    )
                }
                let reference = try await extendReference(
                    id: parsed,
                    sectionTitle: sectionTitle,
                    sectionBody: sectionBody,
                    tags: tags,
                    summary: summary,
                    source: source,
                    url: url
                )
                return Self.encodeSuccess(action: action, reference: reference, created: false)
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
                var dict: [String: Any] = [
            "id": d.id.uuidString,
            "title": d.title,
            "displayTitle": d.displayTitle ?? d.title,
            "layer": d.layer,
            "entity_type": d.entityType,
            "summary": d.summary,
            "createdAt": d.createdAt.formatted(.iso8601),
            "updatedAt": d.updatedAt.formatted(.iso8601)
        ]
        if let category = d.category { dict["category"] = category }
        if let source = d.source { dict["source"] = source }
        if let url = d.url { dict["url"] = url }
        // Tags are emitted sorted (= the LLM / agent UI sees a
        // deterministic ordering regardless of insertion order). Even
        // when the set is empty, the key is present (= forward-compat
        // — consumers don't need to handle missing-key vs nil).
        dict["tags"] = d.tags
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
    let description = "Library-public reference CRUD with self-evolution support. LLM-friendly verbs: create / read / update / delete / list / find / upsert / extend. **Self-evolution protocol (= (see OOB.md #2026-09-25) directive)**: before creating a brand-new entry, ALWAYS `find` by title (= case-insensitive exact) to check whether the noun already exists in `raw` or `entities`. If found, prefer `extend` (id + section_title + section_body) over `create` — extend appends (= or merges if section_title already exists) a new `## <section_title>` section WITHOUT rewriting the prior body. This is the self-evolution mechanism: the first time the user mentions a noun, `create` writes the initial document; subsequent turns that add context (= 'the user later defines the protagonist lives in Ming-dynasty Xi'an' or 'the user mentions a Xi'an water-basin lamb dish') call `extend` so each refinement accumulates in its own section instead of clobbering the base research. Tags are unioned across extends; = summary / source / url only overwrite when explicitly provided."

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
                    description: "Library-public reference CRUD with self-evolution support (= wraps FileSystemReferenceStore). Same-title research edits the existing document instead of creating a new one (= (see OOB.md #2026-09-25) directive). **Self-evolution protocol**: before creating a new entry, ALWAYS `find` by title; = if found, prefer `extend` (id + section_title + section_body) over `create` — extend appends a new `## <section_title>` section without rewriting the prior body. Tags are unioned across extends.",
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The reference operation to perform. Self-evolution pattern: use `find` first (= returns the existing id), then `extend` (= id + section_title + section_body) instead of `create`/`upsert`. Use `create` only when `find` returns no match (= first time we hear the noun).",
                            enumValues: ["create", "read", "update", "delete", "list", "find", "upsert", "extend"]
                        ),
                        "id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Reference id (UUID). Required for read / update / delete / extend. Get it via `find` first when extending (= the self-evolution pattern)."
                        ),
                        "title": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Reference title. Required for create / find / upsert. For upsert, same-title = edit-in-place (= full body rewrite). Prefer `extend` instead (= section append)."
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
                            description: "1-line summary. For extend: only replaces when explicitly non-empty."
                        ),
                        "markdown": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Full .md body. Alias: 'body'. For extend, prefer `section_title` + `section_body` (= append-mode)."
                        ),
                        "section_title": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "extend-only. The `## <section_title>` heading to add or merge into the existing body. If a section with this title already exists, its content is replaced (most recent research wins). Required when action='extend'."
                        ),
                        "section_body": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "extend-only. The markdown body for the new section. Required when action='extend'."
                        ),
                        "tags": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Tags to attach (string OR JSON array of strings). For create / upsert: replaces existing tags. For extend: unioned with existing tags (= never replaces).",
                            enumValues: []  // open set; = LLM supplies
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