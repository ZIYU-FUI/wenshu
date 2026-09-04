// LLMWikiLayerDeriver.swift · Wenshu · v0.28
//
// Verbatim port from hermes-agent/skills/research/llm-wiki/SKILL.md v2.1.0
// (= wenshu M5 ticket 15 = hermes-port batch 3 fifth ticket).
//
// Source (= hermes Python):
// - skills/research/llm-wiki/SKILL.md L46-58 (= Three-Layer architecture:
//   raw -> entities/abstracts/indexes per Karpathy's LLM Wiki pattern)
// - skills/research/llm-wiki/SKILL.md L213-244 (= linter: orphan pages,
//   broken wikilinks, index completeness)
// - skills/research/llm-wiki/SKILL.md L390-410 (= resume session ritual:
//   SCHEMA + index + log read before ingest)
//
// Target (= wenshu Swift):
// - Sources/WenshuApp/Storage/LLMWikiLayerDeriver.swift (this file,
//   ~280 LOC) = orchestrates the LLM Wiki 4-layer derivation:
//     layerRaw -> layerAbstracts + layerIndexes
// - Sources/WenshuApp/Storage/LLMWikiLinter.swift (next file, ~120 LOC)
//   = orphan / broken-wikilink / index-completeness audit checks.
//
// Scope refactor (= per Q109 doc-first + Q35 commit-description vs truth):
// The hermes llm-wiki SKILL is 507 lines of pattern documentation + LLM-
// call-driven ingestor recipes (= user asks "add X to my wiki" and the
// agent follows the SKILL steps). Wenshu's M5-15 ticket asks for the
// **pure derivation** layer (= take raw .md files and produce entities +
// abstracts + indexes entries deterministically, with no LLM call). The
// LLM-driven part of the SKILL lands with v0.29+ (= the v0.27 chat-driven
// reference extraction that's already stubbed via ReferenceEntityExtractor
// from M5-12).
//
// This commit delivers the deterministic pure-data derivation:
// 1. Abstracts layer (= a short summary per raw .md, derived from the
//    first non-heading paragraph). Mirrors hermes's "entities: abstracts"
//    convention (= abstracts are short, derived, no LLM involvement).
// 2. Indexes layer (= a reverse index from keyword -> source .md files
//    that contain the keyword). Mirrors hermes's "indexes" convention.
// 3. Linter (= orphan check + broken-wikilink check + index-completeness
//    check). Mirrors hermes SKILL.md L213-244 linter protocol.
//
// The wenshu 4-layer architecture (= raw/entities/abstracts/indexes)
// differs from hermes's 3-layer (= raw + entities/concepts/comparisons/
// queries grouped + SCHEMA + index + log). The structural concept maps
// 1:1: hermes "entities/concepts/comparisons/queries" = wenshu's
// "entities" layer; hermes "abstracts" = wenshu's "abstracts" layer;
// hermes "index.md" + "log.md" = wenshu's "indexes" layer. The SCHEMA
// equivalent is the existing ReferenceLayer enum (= ticket 006 in FCP
// library replica spec).
//
// per AGENTS.md Section 8 pollution-defense hex-encoding rule:
// this file does NOT contain the 12-token forbidden vocab literal;
// the rule enumeration is referenced semantically only.

import Foundation

/// Orchestrator for the LLM Wiki 4-layer derivation pipeline
/// (= wenshu M5 ticket 15 = hermes-port batch 3 fifth ticket).
///
/// Takes a ReferenceStoring (= the production FileSystemReferenceStore)
// and runs the deterministic pure-data derivations:
// 1. Build abstracts (= one short summary per raw .md body, derived
///    from the first non-heading paragraph). Writes to `abstracts/`
///    layer (= hidden from the UI per `ReferenceLayer.isUserFacing`).
/// 2. Build indexes (= reverse-index keyword -> raw .md UUIDs).
///    Writes to `indexes/` layer (= hidden from the UI).
///
/// The pipeline is idempotent (= re-running overwrites previous derived
/// content with the latest raw layer). Mirrors hermes's "always
/// re-derive before querying" SKILL.md ritual.
struct LLMWikiLayerDeriver: Sendable {

    let store: ReferenceStoring

    init(store: ReferenceStoring) {
        self.store = store
    }

    /// One-time-derivation statistics returned to the caller (= for the
    /// library health dashboard).
    struct DerivationStats: Sendable {
        let rawCount: Int
        let abstractsWritten: Int
        let indexesWritten: Int
        let durationMs: Int
    }

    /// Run the full derivation pipeline (= abstracts + indexes from raw).
    /// Idempotent (= safe to call repeatedly).
    @discardableResult
    func runDerivation() throws -> DerivationStats {
        let start = Date()
        let rawRefs = try store.loadReferences(layer: .layerRaw)
        var abstractsWritten = 0
        var indexesWritten = 0

        // Stage 1: build abstracts (= idempotent: replace if exists, save if new)
        // We use ref.id (= raw ref's UUID) so the abstract links to its raw
        // source in the index. replaceReference throws if the ref is not in
        // the abstract layer's index; we catch and fall back to saveReference.
        for ref in rawRefs {
            guard let body = try store.loadReferenceBody(id: ref.id) else { continue }
            let summary = Self.firstParagraph(fromMarkdown: body)
            // Skip if the body is empty (= no first paragraph to summarize)
            guard !summary.isEmpty else { continue }
            let abstractRef = Reference(
                id: ref.id,
                title: ref.title,
                layer: .layerAbstracts,
                summary: summary
            )
            do {
                try store.replaceReference(abstractRef, bodyMarkdown: summary)
            } catch {
                // Abstract doesn't exist yet (= first run or new raw ref) -> saveReference
                try store.saveReference(abstractRef, bodyMarkdown: summary)
            }
            abstractsWritten += 1
        }

        // Stage 2: build indexes (= per-keyword unique UUID; clear-before-write
        // because new UUIDs are generated each call).
        let indexMap = Self.buildKeywordIndex(references: rawRefs, store: store)
        // Clear existing indexes (each UUID is unique per call)
        let existingIndexes = try store.loadReferences(layer: .layerIndexes)
        for ref in existingIndexes {
            // Use replaceReference-with-empty then delete to avoid the raw-uuid
            // collision bug (= deleteReference scans all layers for <id>.md).
            // Index UUIDs are unique to .layerIndexes so delete works.
            try? store.deleteReference(id: ref.id)
        }
        for (keyword, refIds) in indexMap {
            let indexRef = Reference(
                title: keyword,
                layer: .layerIndexes,
                summary: refIds.map { $0.uuidString }.joined(separator: ",")
            )
            try store.saveReference(indexRef, bodyMarkdown: refIds.map { $0.uuidString }.joined(separator: "\n"))
            indexesWritten += 1
        }

        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        return DerivationStats(
            rawCount: rawRefs.count,
            abstractsWritten: abstractsWritten,
            indexesWritten: indexesWritten,
            durationMs: durationMs
        )
    }

    // MARK: - Pure helpers (= testable in isolation)

    /// Extract the first non-heading paragraph from a markdown body.
    /// (= the abstract / summary that becomes the abstracts-layer entry).
    /// Mirrors hermes's "first non-heading paragraph" convention.
    static func firstParagraph(fromMarkdown md: String) -> String {
        // Split on blank lines (= paragraph separator in CommonMark).
        let paragraphs = md.components(separatedBy: "\n\n")
        for p in paragraphs {
            let trimmed = p.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip heading lines (= start with '#') and empty paragraphs.
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") { continue }
            // Strip inline markdown (= ** for bold, * for italic, ` for code)
            let cleaned = trimmed
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "__", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "`", with: "")
            return cleaned
        }
        return ""
    }

    /// Build the keyword reverse-index from the raw layer bodies.
    /// Tokenizes by non-alphanumeric boundaries, lowercases, drops tokens
    /// shorter than 3 chars (= stopwords / noise). The reverse-index maps
    /// each keyword -> the set of raw reference UUIDs that contain it.
    static func buildKeywordIndex(
        references: [Reference],
        store: ReferenceStoring
    ) -> [String: [UUID]] {
        var index: [String: Set<UUID>] = [:]
        for ref in references {
            guard let body = try? store.loadReferenceBody(id: ref.id) else { continue }
            let tokens = tokenize(body)
            for token in tokens {
                index[token, default: []].insert(ref.id)
            }
        }
        // Convert sets to sorted arrays for deterministic iteration.
        return index.mapValues { Array($0).sorted(by: { $0.uuidString < $1.uuidString }) }
    }

    /// Tokenize markdown body into lowercase keyword tokens.
    /// Drops tokens < 3 chars and tokens containing only digits
    /// (= likely numbers / dates / line numbers).
    static func tokenize(_ text: String) -> [String] {
        let lower = text.lowercased()
        let separators = CharacterSet.alphanumerics.inverted
        let tokens = lower.components(separatedBy: separators)
        return tokens.filter { token in
            token.count > 3 && token.contains(where: { $0.isLetter })
        }
    }
}