// Curator.swift
//
// Background entity curator. Periodically reviews reference-library
// entities to:
//   1. Detect duplicates (= near-identical entities)
//   2. Detect stale entries (= no access in N days)
//   3. Detect orphans (= no cross-references from other entities)
//
// Curator produces a `CurationReport` (= advisory only = no
// destructive actions). The user reviews the report and decides what
// to merge / archive / delete. Per wenshu §11 product-positioning
// rule, wenshu never deletes user data without consent.
//
// ADR-0011 (= no LLM calls in curator path = pure data analysis).
// §11 hard rule (= Apple Foundation only; no external deps).

import Foundation

/// One entry in a CurationReport (= a specific recommendation).
struct CurationFinding: Sendable, Equatable, Codable, Identifiable {
    let id: UUID
    let entityID: String           // = MemoryEntry.id
    let entityTitle: String
    let kind: Kind
    let description: String

    enum Kind: String, Sendable, Equatable, Codable {
        case duplicate   // similar to another entity (= merge candidate)
        case stale       // not accessed in N days (= archive candidate)
        case orphan      // no cross-references (= delete candidate)
    }

    init(
        id: UUID = UUID(),
        entityID: String,
        entityTitle: String,
        kind: Kind,
        description: String
    ) {
        self.id = id
        self.entityID = entityID
        self.entityTitle = entityTitle
        self.kind = kind
        self.description = description
    }
}

/// Full curation report (= advisory only = per-entity findings + metadata).
struct CurationReport: Sendable, Equatable, Codable {
    let id: UUID
    let generatedAt: Date
    let findings: [CurationFinding]
    let totalEntitiesScanned: Int

    init(
        id: UUID = UUID(),
        generatedAt: Date = Date(),
        findings: [CurationFinding],
        totalEntitiesScanned: Int
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.findings = findings
        self.totalEntitiesScanned = totalEntitiesScanned
    }

    var duplicatesCount: Int { findings.filter { $0.kind == .duplicate }.count }
    var staleCount: Int { findings.filter { $0.kind == .stale }.count }
    var orphansCount: Int { findings.filter { $0.kind == .orphan }.count }
}

/// Pure-data curator (= no actor = pure functions over input data).
/// Callers invoke `curate(entities:)` to produce a CurationReport.
/// Per ADR-0011 (= no LLM calls), this is pure data analysis.
enum Curator {

    /// Configuration for the curator (= thresholds for findings).
    struct Config: Sendable, Equatable, Codable {
        let staleThresholdDays: Int       // default 90
        let duplicateSimilarityThreshold: Double  // default 0.85

        init(
            staleThresholdDays: Int = 90,
            duplicateSimilarityThreshold: Double = 0.85
        ) {
            self.staleThresholdDays = staleThresholdDays
            self.duplicateSimilarityThreshold = duplicateSimilarityThreshold
        }
    }

    /// Entity input (= subset of MemoryEntry fields relevant to curation).
    struct Entity: Sendable, Equatable, Codable {
        let id: String
        let title: String
        let snippet: String
        let lastAccessedAt: Date?
        let crossReferenceCount: Int

        init(
            id: String,
            title: String,
            snippet: String,
            lastAccessedAt: Date?,
            crossReferenceCount: Int
        ) {
            self.id = id
            self.title = title
            self.snippet = snippet
            self.lastAccessedAt = lastAccessedAt
            self.crossReferenceCount = crossReferenceCount
        }
    }

    /// Run curation analysis on entities.
    // P2-07 audit (2026-09-24): internal (= Config is internal; =
        // the function's contract is intra-package anyway).
        static func curate(entities: [Entity], config: Config = Config()) -> CurationReport {
        var findings: [CurationFinding] = []
        let now = Date()
        let staleCutoff = now.addingTimeInterval(-Double(config.staleThresholdDays) * 24 * 3600)

        // 1. Detect stale entries
        for entity in entities {
            if let lastAccess = entity.lastAccessedAt, lastAccess < staleCutoff {
                findings.append(CurationFinding(
                    entityID: entity.id,
                    entityTitle: entity.title,
                    kind: .stale,
                    description: "Not accessed in \(config.staleThresholdDays) days (= since \(lastAccess))"
                ))
            }
        }

        // 2. Detect orphans (= no cross-references)
        for entity in entities {
            if entity.crossReferenceCount == 0 {
                findings.append(CurationFinding(
                    entityID: entity.id,
                    entityTitle: entity.title,
                    kind: .orphan,
                    description: "Entity has no cross-references from other entities"
                ))
            }
        }

        // 3. Detect duplicates (= O(n^2) pairwise similarity)
        // For simplicity: compare snippet similarity via character overlap.
        // Real impl could use Sentence-BERT or similar (= future ticket).
        for i in 0..<entities.count {
            for j in (i+1)..<entities.count {
                let a = entities[i]
                let b = entities[j]
                let similarity = snippetSimilarity(a.snippet, b.snippet)
                if similarity >= config.duplicateSimilarityThreshold {
                    findings.append(CurationFinding(
                        entityID: a.id,
                        entityTitle: a.title,
                        kind: .duplicate,
                        description: "Similar to '\(b.title)' (= similarity \(Int(similarity * 100))%)"
                    ))
                }
            }
        }

        return CurationReport(
            findings: findings,
            totalEntitiesScanned: entities.count
        )
    }

    /// Jaccard-like character-set similarity (= simple O(n*m) heuristic).
    /// Real duplicate detection would use semantic embeddings.
    private static func snippetSimilarity(_ a: String, _ b: String) -> Double {
        let setA = Set(a.lowercased().filter { !$0.isWhitespace })
        let setB = Set(b.lowercased().filter { !$0.isWhitespace })
        guard !setA.isEmpty || !setB.isEmpty else { return 0 }
        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count
        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }
}
