// LLMWikiLinter.swift · Wenshu · v0.28
//
// Linter for the LLM Wiki 4-layer reference-library
// (= wenshu M5 ticket 15 second file).
//
// Source (= hermes Python):
// - skills/research/llm-wiki/SKILL.md L213-244 (= the linter checks:
//   orphan pages, broken wikilinks, index completeness, schema drift).
//
// Target (= wenshu Swift):
// - Sources/WenshuApp/Storage/LLMWikiLinter.swift (this file,
//   ~150 LOC) = static analysis of the reference-library 4-layer
//   structure. Returns a list of `LintFinding` records; no I/O
//   mutation (= the deriver is the writer, the linter is the reader).
//
// Per AGENTS.md Section 8 pollution-defense hex-encoding rule:
// this file does NOT contain the 12-token forbidden vocab literal;
// the rule enumeration is referenced semantically only.

import Foundation

/// Linter for the LLM Wiki 4-layer reference-library.
/// Mirrors hermes SKILL.md L213-244 linter protocol (= orphan pages,
/// broken wikilinks, index completeness, schema drift).
struct LLMWikiLinter: Sendable {

    let store: ReferenceStoring

    init(store: ReferenceStoring) {
        self.store = store
    }

    // MARK: - Public surface

    /// One lint finding (= one issue detected across the wiki).
    struct LintFinding: Sendable {
        let severity: Severity
        let code: String
        let message: String
        enum Severity: String, Sendable {
            case info, warning, error
        }
    }

    /// Run all linter checks. Returns ALL findings (= the caller can
    /// filter by severity for display vs CI gating).
    func lint() throws -> [LintFinding] {
        var findings: [LintFinding] = []
        findings.append(contentsOf: try checkOrphanPages())
        findings.append(contentsOf: try checkBrokenWikilinks())
        findings.append(contentsOf: try checkIndexCompleteness())
        findings.append(contentsOf: try checkAbstractsRecency())
        return findings
    }

    // MARK: - Individual checks (= mirror hermes SKILL.md checks)

    /// Check 1: orphan pages in the entities layer.
    /// An orphan = a reference in the entities layer that no raw
    /// reference mentions (= no provenance link back to source material).
    private func checkOrphanPages() throws -> [LintFinding] {
        let entities = try store.loadReferences(layer: .layerEntities)
        guard !entities.isEmpty else { return [] }
        var findings: [LintFinding] = []
        for entity in entities {
            let hasProvenance = (entity.characterRefIds.count + entity.worldRefIds.count) > 0
            if !hasProvenance {
                findings.append(LintFinding(
                    severity: .warning,
                    code: "LLM-ORPHAN-ENTITY",
                    message: "Entity '\(entity.title)' has no provenance link (= no characterRefIds/worldRefIds)"
                ))
            }
        }
        return findings
    }

    /// Check 2: broken wikilinks.
    /// A wikilink is a markdown `[text](wiki:<uuid>)` reference.
    /// Broken = the referenced UUID does not exist in any layer.
    private func checkBrokenWikilinks() throws -> [LintFinding] {
        let allRefs = try store.loadAllReferences()
        let knownIDs = Set(allRefs.map { $0.id })
        var findings: [LintFinding] = []
        for ref in allRefs {
            guard let body = store.loadReferenceBody(id: ref.id) else { continue }
            let links = Self.extractWikilinks(fromMarkdown: body)
            for link in links where !knownIDs.contains(link) {
                findings.append(LintFinding(
                    severity: .error,
                    code: "LLM-BROKEN-WIKILINK",
                    message: "Reference '\(ref.title)' has wikilink to unknown UUID \(link.uuidString)"
                ))
            }
        }
        return findings
    }

    /// Check 3: index completeness.
    /// Verifies that every raw reference is mentioned in the indexes layer
    /// (= has at least one keyword -> UUID mapping).
    private func checkIndexCompleteness() throws -> [LintFinding] {
        let rawRefs = try store.loadReferences(layer: .layerRaw)
        let indexes = try store.loadReferences(layer: .layerIndexes)
        let indexedUUIDs = Set(indexes.flatMap { ref -> [UUID] in
            ref.summary.split(separator: "\n").compactMap { UUID(uuidString: String($0)) }
        })
        var findings: [LintFinding] = []
        for raw in rawRefs where !indexedUUIDs.contains(raw.id) {
            findings.append(LintFinding(
                severity: .info,
                code: "LLM-MISSING-IN-INDEX",
                message: "Raw reference '\(raw.title)' is not present in any indexes keyword"
            ))
        }
        return findings
    }

    /// Check 4: abstracts recency (= a soft drift check).
    /// Verifies that the abstracts layer was updated more recently than
    /// the raw layer (= i.e., the user ran the deriver at least once
    /// after the last raw update).
    private func checkAbstractsRecency() throws -> [LintFinding] {
        let rawRefs = try store.loadReferences(layer: .layerRaw)
        let abstractRefs = try store.loadReferences(layer: .layerAbstracts)
        let abstractByID = Dictionary(uniqueKeysWithValues: abstractRefs.map { ($0.id, $0) })
        var findings: [LintFinding] = []
        for raw in rawRefs {
            guard let abstract = abstractByID[raw.id] else {
                findings.append(LintFinding(
                    severity: .warning,
                    code: "LLM-NO-ABSTRACT",
                    message: "Raw reference '\(raw.title)' has no abstract (= run LLMWikiLayerDeriver.runDerivation)"
                ))
                continue
            }
            // Abstract's updatedAt should be >= raw's updatedAt (= deriver
            // ran after the last raw update).
            if abstract.updatedAt < raw.updatedAt {
                findings.append(LintFinding(
                    severity: .info,
                    code: "LLM-ABSTRACT-STALE",
                    message: "Abstract for '\(raw.title)' is older than the raw source (= re-run deriver)"
                ))
            }
        }
        return findings
    }

    // MARK: - Pure helpers (= testable in isolation)

    /// Extract all `wiki:<uuid>` references from a markdown body.
    static func extractWikilinks(fromMarkdown md: String) -> [UUID] {
        let pattern = #"wiki:([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = md as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        var uuids: [UUID] = []
        regex.enumerateMatches(in: md, range: fullRange) { match, _, _ in
            guard let match = match,
                  match.numberOfRanges >= 2,
                  let strRange = Range(match.range(at: 1), in: md)
            else { return }
            let uuidString = String(md[strRange])
            if let uuid = UUID(uuidString: uuidString) {
                uuids.append(uuid)
            }
        }
        return uuids
    }
}