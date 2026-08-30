// Reference.swift · Wenshu (文枢) · v0.26 (FCP library replica — reference-library entity)
//
// Domain model for a single reference (= one piece of research material
// inside the library's ReferenceLibrary). Library-public (= shelf-shared,
// reusable across all books; boss 2026-08-26 OOB clarification:
// '明代调研可以跨书复用' = a single research source can back many books).
//
// Each reference is stored as a `.md` file under
// `<.ws>/reference-library/<layer>/<ref-uuid>.md` where <layer> is one of
// the 4 LLM Wiki layers (raw / entities / abstracts / indexes).
//
// v0.26 ships only `raw/` (user imports) + `entities/` (user-facing, the
// only visible layer). `abstracts/` + `indexes/` are LLM-derived layers
// for v0.27+ (= LLM-driven entity extraction).
//
// ReferenceStore protocol (ticket 006) handles the read / write of the
// `.md` body + JSON sidecar per layer.

import Foundation

/// LLM Wiki layer (= where in the 4-layer ReferenceLibrary hierarchy this
/// reference lives). v0.26 supports raw + entities; abstracts + indexes
/// land in v0.27+ (= LLM-driven extraction from chat).
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

    /// Chinese display label (= boss 8/25 'UI 全中文').
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
    /// v0.29 boss 2026-08-30 OOB '资料库的原始文件目录也是, 用户不需要
    /// 看到. 实体保留': `.layerRaw` (= original source files = user
    /// doesn't need to browse these directly = they're for LLM ingestion)
    /// is now NOT user-facing. `.layerEntities` remains user-facing.
    /// `.layerAbstracts` + `.layerIndexes` are LLM-derived (= already
    /// hidden per their semantic nature).
    ///
    /// v0.26 historical: only `.layerRaw` + `.layerEntities` were
    /// user-facing; `.layerAbstracts` + `.layerIndexes` LLM-derived.
    /// v0.29: `.layerRaw` also LLM-only (= user browses entities instead).
    var isUserFacing: Bool {
        switch self {
        case .layerEntities: return true
        case .layerRaw, .layerAbstracts, .layerIndexes: return false
        }
    }

    /// Lucide icon name (= for direct Lucide lookup via Lucide("name")).
    /// v0.27 boss 8/27 OOB: was SF Symbol name ('tray.full.fill' / etc.);
    /// Lucide doesn't have those names (= returned nil → sidebar rows
    /// rendered empty per boss 8/27 '资料库下面的两个文件夹没有
    /// ICON'). Boss 8/27 '你查一下 lucide 的文档' = use the closest
    /// Lucide equivalent that exists.
    var icon: String {
        switch self {
        case .layerRaw:       return "inbox"
        case .layerEntities:  return "user-round"
        case .layerAbstracts: return "sparkles"
        case .layerIndexes:   return "search"
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

    /// Optional bibliographic source (= e.g. '万历十五年', 'Smith 2020').
    /// Display-only (= does not affect search or cross-ref matching).
    var source: String?

    /// Optional URL for web sources.
    var url: String?

    /// LLM Wiki layer this reference lives in. Drives the
    /// subdirectory under `reference-library/`.
    var layer: ReferenceLayer

    /// One-line summary shown on the card (= boss 8/26 '卡片样式就是
    /// 展示文档的重点摘要').
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
        self.summary = summary
        self.characterRefIds = characterRefIds
        self.worldRefIds = worldRefIds
        self.bookRefIds = bookRefIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Filename on disk (= `<uuid>.md`).
    var filename: String {
        "\(id.uuidString).md"
    }

    /// Full on-disk path (= the ReferenceLibrary root + the layer
    /// directory + the filename). Storage layer uses this.
    func onDiskPath(under referenceLibraryRoot: URL) -> URL {
        referenceLibraryRoot
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
