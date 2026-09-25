// Reference.swift · Wenshu () · v0.26 (FCP library replica — reference-library entity)
//
// Domain model for a single reference (= one piece of research material
// inside the library's ReferenceLibrary). Library-public (= shelf-shared,
// reusable across all books; a single research source can back many
// books).
//
// Each reference is stored as a `.md` file under
// `<.ws>/reference-library/<layer>/<ref-uuid>.md` where <layer> is one of
// the 4 LLM Wiki layers (raw / entities / abstracts / indexes).
//
// ships only `raw/` (user imports) + `entities/` (user-facing, the
// only visible layer). `abstracts/` + `indexes/` are LLM-derived layers
// (= LLM-driven entity extraction from chat).
//
// ReferenceStore protocol handles the read / write of the `.md` body +
// JSON sidecar per layer.

import Foundation

/// LLM Wiki layer (= where in the 4-layer ReferenceLibrary hierarchy this
/// reference lives). v0.26 supports raw + entities; abstracts + indexes
/// are LLM-derived.
enum ReferenceLayer: String, CaseIterable, Codable, Sendable {
    case layerRaw
    case layerEntities
    case layerAbstracts
    case layerIndexes

    /// Filesystem directory name (= the layer's subdirectory under
    /// `reference-library/`).
    var directoryName: String {
        switch self {
        case .layerRaw:       return "raw"
        case .layerEntities:  return "entities"
        case .layerAbstracts: return "abstracts"
        case .layerIndexes:   return "indexes"
        }
    }

    /// Chinese display label.
    var displayName: String {
        switch self {
        case .layerRaw:       return "原始资料"
        case .layerEntities:  return "实体"
        case .layerAbstracts: return "抽象"
        case .layerIndexes:   return "索引"
        }
    }

    /// Whether this layer is user-facing (= visible in the UI).
    ///
    /// `.layerRaw` (= original source files = user doesn't need to
    /// browse these directly = they're for LLM ingestion) is NOT
    /// user-facing. `.layerEntities` remains user-facing.
    /// `.layerAbstracts` + `.layerIndexes` are LLM-derived (= hidden
    /// per their semantic nature).
    var isUserFacing: Bool {
        switch self {
        case .layerEntities: return true
        case .layerRaw, .layerAbstracts, .layerIndexes: return false
        }
    }

    /// SF Symbols 6 icon name (= for direct SF Symbol lookup via
    /// Image(systemName:)). All layers return outline (= non-.fill)
    /// icons.
    var icon: String {
        switch self {
        case .layerRaw:       return "tray.and.arrow.down"   // = raw inbox
        case .layerEntities:  return "person.crop.circle"    // = entities (= people)
        case .layerAbstracts: return "sparkles"              // = LLM-extracted abstractions
        case .layerIndexes:   return "magnifyingglass"       // = searchable indexes
        }
    }
}

/// A single reference (= one piece of research material inside the
/// ReferenceLibrary). Library-public (= any book can `@reference.<name>`
/// this entry in its markdown).
///
/// The full reference body lives in the .md body (= free-form markdown
/// the user writes or imports). This struct holds the structured
/// metadata used for the second-column card grid.
struct Reference: Identifiable, Hashable, Codable, Sendable {
    let id: UUID

    /// Title shown in the card. Falls back to the first H1 of the MD
    /// body, or the filename without extension (= per Document.title
    /// convention).
    var title: String

    /// Optional bibliographic source (= e.g. ', 'Smith 2020').
    /// Display-only (= does not affect search or cross-ref matching).
    var source: String?

    /// Optional URL for web sources.
    var url: String?

    /// LLM Wiki layer this reference lives in. Drives the
    /// subdirectory under `reference-library/`.
    var layer: ReferenceLayer

    /// Library-taxonomy category (= optional primary CLC bucket for
    /// users who want library-style browsing). Assigned at save time
    /// by `EntityClassifier.classify()`. Optional for backward
    /// compatibility (= legacy raw materials may not have a category).
    ///
    /// In the v2.6 facet model: `category` is ONE facet among several
    /// (= `tags` + `entityType` are cross-cutting facets). A document
    /// can be browsed by category, by entity type, OR by tag filter;
    /// = the physical file is metadata-flat (= entities/<uuid>.md).
    /// See AGENTS.md §11.16 for the full design rationale.
    var category: EntityCategory?

    /// Free-form tags (= the cross-cutting facet in the v2.6 facet
    /// model). A document may carry any number of tags (= multi-tag),
    /// enabling queries like "all references tagged 唐朝" or
    /// "all references tagged 文学 AND 唐朝". Tags are populated by
    /// `EntityClassifier.classify()` (= LLM-suggested or keyword-derived)
    /// and editable by the user.
    ///
    /// Tags are **orthogonal** to `category` and `entityType`. A
    /// single reference can have:
    /// - 0 or 1 `category` (= primary CLC bucket)
    /// - 1 `entityType` (= character / location / event / etc.)
    /// - 0..N `tags` (= any string, CJK + EN)
    var tags: Set<String>

    /// Entity-type (= orthogonal facet, unchanged from previous).
    /// 9 cases: character / location / event / concept / artifact /
    /// organization / era / work / other.
    ///
    /// Custom Codable: accepts BOTH string ("character") AND integer
    /// representations on decode. The seed-script writes integers
    /// (= matches `EntityType.promptNumber` for LLM output). String
    /// form remains supported for human-readable JSON files.
    var entityType: EntityType

    // MARK: - entityType Codable migration: fallback to .other

    // Legacy entities.json (pre-entityType) doesn't have the field.
    // Strict Codable would fail decoding (= "Key 'entityType' not found").
    // Custom init(from:) provides a graceful migration path: missing
    // entityType → .other (= safe default; user can re-classify later
    // via LLM classifier once v1 ships).
    //
    // Also handles both string and integer representations of entityType
    // (= string = "character" / integer = 1). Seed scripts use integers
    // (= matches LLM promptNumber), human-readable exports use strings.

    private enum CodingKeys: String, CodingKey {
        case id, title, source, url, layer, category
        case tags
        case entityType, summary, characterRefIds, worldRefIds
        case bookRefIds, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        layer = try c.decode(ReferenceLayer.self, forKey: .layer)
        category = try c.decodeIfPresent(EntityCategory.self, forKey: .category)
        // tags is new in v2.6 facet model. Legacy entities.json files
        // (= written before this commit) lack the field; = default to
        // empty set. Forward-compatible: future saves will round-trip.
        tags = try c.decodeIfPresent(Set<String>.self, forKey: .tags) ?? []
        // entityType may be encoded as String ("character") OR Int (1).
        // Try Int first (= matches seed-script + LLM prompt format), fall
        // back to String (= matches human-readable format).
        if let intVal = try? c.decodeIfPresent(Int.self, forKey: .entityType) {
            entityType = EntityType.fromPromptNumber(intVal)
        } else if let strVal = try? c.decodeIfPresent(String.self, forKey: .entityType),
                  let parsed = EntityType(rawValue: strVal) {
            entityType = parsed
        } else {
            entityType = .other
        }
        summary = try c.decode(String.self, forKey: .summary)
        characterRefIds = try c.decodeIfPresent([UUID].self, forKey: .characterRefIds) ?? []
        worldRefIds = try c.decodeIfPresent([UUID].self, forKey: .worldRefIds) ?? []
        bookRefIds = try c.decodeIfPresent([UUID].self, forKey: .bookRefIds) ?? []
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(source, forKey: .source)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encode(layer, forKey: .layer)
        try c.encodeIfPresent(category, forKey: .category)
        // Encode tags sorted for stable on-disk output (= idempotent
        // writes; = easier diff inspection).
        try c.encode(tags.sorted(), forKey: .tags)
        // Encode as string (= human-readable; readers without EntityType
        // knowledge can still interpret "character" / "location" / etc.).
        try c.encode(entityType.rawValue, forKey: .entityType)
        try c.encode(summary, forKey: .summary)
        try c.encode(characterRefIds, forKey: .characterRefIds)
        try c.encode(worldRefIds, forKey: .worldRefIds)
        try c.encode(bookRefIds, forKey: .bookRefIds)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    /// One-line summary shown on the card.
    var summary: String

    /// Optional cross-references to other entities (= where this
    /// reference is used / connected to):
    /// - characterRefIds: which characters this reference informs
    /// - worldRefIds: which world entries this reference backs
    /// - bookRefIds: which books reference this material (= many-to-many;
    ///   a single 'Ming dynasty tax record' reference can be used by
    ///   multiple Book A, Book B, Book C)
    var characterRefIds: [UUID]
    var worldRefIds: [UUID]
    var bookRefIds: [UUID]

    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        source: String? = nil,
        url: String? = nil,
        layer: ReferenceLayer = .layerRaw,
        category: EntityCategory? = nil,
        tags: Set<String> = [],
        entityType: EntityType = .other,
        summary: String = "",
        characterRefIds: [UUID] = [],
        worldRefIds: [UUID] = [],
        bookRefIds: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.url = url
        self.layer = layer
        self.category = category
        self.tags = tags
        self.entityType = entityType
        self.summary = summary
        self.characterRefIds = characterRefIds
        self.worldRefIds = worldRefIds
        self.bookRefIds = bookRefIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Filename on disk. v2.6 facet model: file path uses the reference
    /// title (= e.g. `entities/李白.md`) so the user can locate a
    /// reference by its on-disk name. The opaque id is preserved as
    /// a suffix to guarantee uniqueness (= two references sharing a
    /// title = e.g. `李白` vs `李白 (poet)` don't collide):
    /// `<title>--<uuid-prefix>.md`. The title is sanitized for
    /// filesystems (= forbidden characters `<>:"/\|?*` stripped,
    /// internal whitespace collapsed to `-`, = leading/trailing
    /// whitespace trimmed) before being joined with the id.
    var filename: String {
        let sanitized = Self.sanitizeFilename(title)
        let idSuffix = String(id.uuidString.prefix(8))
        if sanitized.isEmpty {
            return "\(idSuffix).md"
        }
        return "\(sanitized)--\(idSuffix).md"
    }

    /// Replace filesystem-unsafe characters in a reference title.
    /// Keeps CJK + Latin letters + digits + a small set of safe
    /// punctuation (`- _ . ( )`). Whitespace collapses to `-`.
    /// Empty input returns "".
    static func sanitizeFilename(_ raw: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\<>:\"|?*")
        let cleaned = raw.unicodeScalars
            .filter { !forbidden.contains($0) }
            .reduce(into: "") { acc, scalar in
                if scalar == " " {
                    acc.append("-")
                } else {
                    acc.unicodeScalars.append(scalar)
                }
            }
        // Collapse runs of dashes (= from collapsed whitespace).
        var collapsed = ""
        var lastWasDash = false
        for ch in cleaned {
            if ch == "-" {
                if !lastWasDash && !collapsed.isEmpty {
                    collapsed.append(ch)
                }
                lastWasDash = true
            } else {
                collapsed.append(ch)
                lastWasDash = false
            }
        }
        // Trim leading/trailing dashes.
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Full on-disk path. v2.6 facet model: file path is metadata-flat
    /// (= `entities/<uuid>.md`). The `category` field is preserved as
    /// metadata in entities.json (= sidebar browsing uses the index, not
    /// the directory tree). Multi-tag references live in 1 folder; =
    /// tag-filtered views are produced by SwiftData queries, not by
    /// file location.
    ///
    /// Older reference libraries may still have files at
    /// `entities/<category>/<uuid>.md` (= pre-v2.6 layout); =
    /// `FileSystemReferenceStore.loadReferences` performs a one-shot
    /// migration to the flat path on first load (= see issue 002).
    func onDiskPath(under referenceLibraryRoot: URL) -> URL {
        return referenceLibraryRoot
            .appendingPathComponent(layer.directoryName)
            .appendingPathComponent(filename)
    }

    // id-based identity (= Apple HIG document-based convention).
    static func == (lhs: Reference, rhs: Reference) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
