// LLMWikiLayerDeriver.swift
//
// Pure-data derivation layer for the LLM Wiki 4-layer architecture
// (= raw + entities + abstracts + indexes). Mirrors hermes's
// "entities: abstracts" + "indexes" conventions from
// skills/research/llm-wiki/SKILL.md.
//
// The wenshu 4-layer architecture differs from hermes's 3-layer:
// hermes "entities/concepts/comparisons/queries" = wenshu's
// "entities"; hermes "abstracts" = wenshu's "abstracts"; hermes
// "index.md" + "log.md" = wenshu's "indexes". The SCHEMA equivalent
// is the existing ReferenceLayer enum.

import Foundation

/// Orchestrator for the LLM Wiki 4-layer derivation pipeline.
///
/// Takes a `ReferenceStoring` (= the production
/// `FileSystemReferenceStore`) and runs the deterministic pure-data
/// derivations:
/// 1. Build abstracts (= one short summary per raw .md body, derived
///    from the first non-heading paragraph). Writes to `abstracts/`
///    layer (= hidden from the UI per `ReferenceLayer.isUserFacing`).
/// 2. Build indexes (= reverse-index keyword -> raw .md UUIDs).
///    Writes to `indexes/` layer (= hidden from the UI).
///
/// The pipeline is idempotent (= re-running overwrites previous derived
/// content with the latest raw layer).
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

        // Stage 1: build abstracts (= idempotent: replace if exists,
        // save if new). The abstract id equals the raw ref's UUID so
        // the abstract links to its raw source in the index.
        // replaceReference throws if the abstract isn't in the layer's
        // index yet; = fall back to saveReference on the catch path.
        for ref in rawRefs {
            guard let body = store.loadReferenceBody(id: ref.id) else { continue }
            let summary = Self.firstParagraph(fromMarkdown: body)
            // Skip if the body is empty (= no first paragraph to summarize).
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
                // First run or new raw ref: the abstract doesn't
                // exist in the layer's index yet.
                try store.saveReference(abstractRef, bodyMarkdown: summary)
            }
            abstractsWritten += 1
        }

        // Stage 2: build indexes (= per-keyword unique UUID; clear-
        // before-write because new UUIDs are generated each call).
        // deleteReference scans all layers for <id>.md; index UUIDs
        // are unique to .layerIndexes so the scan only finds the
        // index entries (= safe).
        let indexMap = Self.buildKeywordIndex(references: rawRefs, store: store)
        let existingIndexes = try store.loadReferences(layer: .layerIndexes)
        for ref in existingIndexes {
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
            guard let body = store.loadReferenceBody(id: ref.id) else { continue }
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