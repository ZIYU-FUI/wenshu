// 
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
import Foundation
import WenshuAgent

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
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // the domain enum predates the agent tool surface.
        self.layer = Self.wireLayer(reference.layer)
        self.category = reference.category?.rawValue
        // Tags are emitted sorted for stable on-the-wire output (= the
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // depend on sorted form).
        self.tags = reference.tags.sorted()
        self.entityType = reference.entityType.rawValue
        self.summary = reference.summary
        self.source = reference.source
        self.url = reference.url
        self.createdAt = reference.createdAt
        self.updatedAt = reference.updatedAt
    }

    // / ReferenceLayer.wireRawValue: maps the internal layer enum to the
    // / LLM-friendly wire string used in tool input / output.
    static func wireLayer(_ layer: ReferenceLayer) -> String {
        switch layer {
        case .layerRaw:      return "raw"
        case .layerEntities: return "entities"
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
    // / Append a new section to an existing reference's body (= the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / of creating duplicates).
    case extend
}

// MARK: - Errors

enum ReferenceLibraryError: Error, LocalizedError, Sendable, Equatable {
    case emptyTitle
    case entryNotFound(id: UUID)
    /// A document with this title already exists (= the id of the one
    /// that does). The create path refuses the write rather than
    /// adding a second copy of the same document.
    case duplicateTitle(title: String, existingID: UUID)
    case invalidInput(reason: String)
    /// The truth holds text the user wrote in the editor, = and the
    /// agent's write would have replaced it. = **⇒ The user's write
    /// wins, = and the refusal is reported here** (= the LLM reads
    /// this message, = and the user hears about it instead of losing
    /// their text).
    case userEditedReference(id: UUID)
    case underlying(String)

    /// The store's failure, = in the tool's own words.
    ///
    /// **⇒ The second-writer rule reaches the LLM as a NAMED
    /// error**, = not as a stringified enum case. = `String(describing:)`
    /// of the store's error would say `userOwnsTheTruth(id: ...)`,
    /// = which tells the caller nothing about what to do next.
    static func from(_ error: Error) -> ReferenceLibraryError {
        if let storeError = error as? ReferenceStoreError {
            switch storeError {
            case .userOwnsTheTruth(let id):
                return .userEditedReference(id: id)
            default:
                break
            }
        }
        return .underlying(String(describing: error))
    }

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "ReferenceLibraryTool: reference title was empty or whitespace-only."
        case .entryNotFound(let id):
            return "ReferenceLibraryTool: reference \(id.uuidString) not found."
        case .duplicateTitle(let title, let existingID):
            return "ReferenceLibraryTool: a reference titled '\(title)' already exists (id \(existingID.uuidString)). Use upsert to update it, or extend to add a section to it."
        case .invalidInput(let reason):
            return "ReferenceLibraryTool: invalid input — \(reason)."
        case .userEditedReference(let id):
            return "ReferenceLibraryTool: reference \(id.uuidString) holds text the user wrote in the editor, so the write was refused and the user's text was not overwritten. Use extend with a new section title to add to the document, or ask the user what to do with it."
        case .underlying(let msg):
            return "ReferenceLibraryTool: underlying error — \(msg)."
        }
    }
}

// MARK: - Tool-protocol adapter

actor ReferenceLibraryTool: Tool {
    let name = "reference_library"
    let description = "Library-public reference CRUD with self-evolution support. LLM-friendly verbs: create / read / update / delete / list / find / upsert / extend. **Self-evolution protocol (= (see OOB.md #2026-09-25) directive)**: before creating a brand-new entry, ALWAYS `find` by title (= case-insensitive exact) to check whether the noun already exists in `raw` or `entities`. If found, prefer `extend` (id + section_title + section_body) over `create` — extend appends (= or merges if section_title already exists) a new `## <section_title>` section WITHOUT rewriting the prior body. This is the self-evolution mechanism: the first time the user mentions a noun, `create` writes the initial document; subsequent turns that add context (= 'the user later defines the protagonist lives in Ming-dynasty Xi'an' or 'the user mentions a Xi'an water-basin lamb dish') call `extend` so each refinement accumulates in its own section instead of clobbering the base research. Tags are unioned across extends; = summary / source / url only overwrite when explicitly provided."

    private let actor: ReferenceLibraryActor

    /// The library the tool writes to.
    ///
    /// The librarian's `curate` procedure reads the same library the
    /// tool writes to, = and it must be the one the user has open, =
    /// so the procedure goes through the tool's actor rather than
    /// building a second one. (= A second actor with its own store
    /// would analyse a different library than the one the user sees.)
    var libraryActor: ReferenceLibraryActor { actor }

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
                            description: "Reference layer ('entities' or 'raw'). Defaults to 'entities' (= the user-facing layer; = 'raw' is the internal ingestion layer, = the user does not browse it).",
                            enumValues: ["raw", "entities"]
                        ),
                        "category": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Entity category (= required for layer=entities; = a document with no category lands in the unclassified bucket)."
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
            handler: LazyTool { await ReferenceLibraryTool.shared },
            description: "Library-public reference CRUD with dedup-by-title upsert.",
            emoji: "📚"
        )
        }
    }()

    @MainActor
    static let shared: ReferenceLibraryTool = {
        // The fallback for the window between the tool registry's
        // registration and the launch sequence (= the library does
        // not exist yet). Once the launch sequence has bound the
        // library, the tool writes into it.
        let fallbackRoot = URL(fileURLWithPath: "/tmp/wenshu-toolregistry-references-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallbackRoot, withIntermediateDirectories: true)
        let fallbackStore = FileSystemReferenceStore(referenceLibraryRoot: fallbackRoot)
        return ReferenceLibraryTool(
            actor: ReferenceLibraryActor(
                referenceStoreProvider: {
                    ReferenceLibraryLocator.shared.referenceStore ?? fallbackStore
                },
                // The app's own chat model writes the summary of a
                // document that has none (= the routing line the agent
                // reads before it opens the body).
                summaryService: ReferenceSummaryService()
            )
        )
    }()
}