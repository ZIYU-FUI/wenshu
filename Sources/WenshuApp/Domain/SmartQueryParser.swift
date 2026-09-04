// SmartQueryParser.swift · Wenshu (文枢) · v0.27 (FCP library replica)
//
// Search predicate parser + evaluator (= ticket 027-02 = v0.27
// placeholder for SmartQuery engine; v0.26 only had schema + UI).
//
// SmartQuery.queryJSON is a JSON-encoded predicate of one of 4 kinds:
// 1. namePattern — substring match against entity name (= name contains X)
// 2. entityType — filter by entity type (= .character / .world / .reference)
// 3. refIds — match entities linked to any of the given UUIDs
// 4. layer — filter Reference entities by layer
//
// Queries are evaluated against a `SmartQueryIndex` (= a snapshot of
// the library's entities: [Character] + [WorldEntry] + [Reference]).
// The evaluator is pure (= no side effects; suitable for SwiftUI
// background thread use).

import Foundation

// MARK: - Entity type

enum SmartQueryEntityType: String, Codable, CaseIterable, Sendable {
    case character
    case world
    case reference
}

// MARK: - Predicate envelope (= the SmartQuery.queryJSON shape)

/// Envelope that encodes/decodes the SmartQuery.queryJSON string.
/// The `kind` discriminates which predicate variant is in use.
struct SmartQueryEnvelope: Codable, Sendable {
    let kind: String
    let value: StringOrList

    enum StringOrList: Codable, Sendable {
        case text(String)
        case list([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) {
                self = .text(s)
            } else if let l = try? container.decode([String].self) {
                self = .list(l)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "SmartQueryEnvelope value must be String or [String]"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let s): try container.encode(s)
            case .list(let l): try container.encode(l)
            }
        }

        var textValue: String? { if case .text(let s) = self { return s } else { return nil } }
        var listValue: [String]? { if case .list(let l) = self { return l } else { return nil } }
    }
}

// MARK: - Predicate + JSON roundtrip

enum SmartQueryPredicate: Hashable, Sendable {
    case namePattern(String)
    case entityType(SmartQueryEntityType)
    case refIds([UUID])
    case layer(ReferenceLayer)

    /// JSON encoding (= the SmartQuery.queryJSON string).
    func encodedJSON() throws -> String {
        let envelope: SmartQueryEnvelope
        switch self {
        case .namePattern(let s):
            envelope = SmartQueryEnvelope(kind: "namePattern", value: .text(s))
        case .entityType(let t):
            envelope = SmartQueryEnvelope(kind: "entityType", value: .text(t.rawValue))
        case .refIds(let ids):
            envelope = SmartQueryEnvelope(kind: "refIds", value: .list(ids.map(\.uuidString)))
        case .layer(let l):
            envelope = SmartQueryEnvelope(kind: "layer", value: .text(l.rawValue))
        }
        let data = try JSONEncoder().encode(envelope)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Decode from JSON (= the SmartQuery.queryJSON string).
    static func decode(json: String) -> SmartQueryPredicate? {
        guard let data = json.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(SmartQueryEnvelope.self, from: data) else {
            return nil
        }
        switch envelope.kind {
        case "namePattern":
            return .namePattern(envelope.value.textValue ?? "")
        case "entityType":
            guard let raw = envelope.value.textValue,
                  let t = SmartQueryEntityType(rawValue: raw) else { return nil }
            return .entityType(t)
        case "refIds":
            return .refIds(envelope.value.listValue?.compactMap(UUID.init(uuidString:)) ?? [])
        case "layer":
            guard let raw = envelope.value.textValue,
                  let l = ReferenceLayer(rawValue: raw) else { return nil }
            return .layer(l)
        default:
            return nil
        }
    }
}

// MARK: - Index + Evaluator

/// Snapshot of the library's searchable entities (= constructed by
/// SmartQueryEngine and passed to the evaluator).
struct SmartQueryIndex: Sendable {
    var characters: [Character]
    var worldEntries: [WorldEntry]
    var references: [Reference]
}

/// Single-predicate evaluator. Returns the matching entities.
struct SmartQueryEvaluator: Sendable {
    let predicate: SmartQueryPredicate

    func evaluate(against index: SmartQueryIndex) -> [SmartQueryResult] {
        switch predicate {
        case .namePattern(let pattern):
            return matchByName(pattern: pattern, index: index)
        case .entityType(let type):
            return matchByType(type: type, index: index)
        case .refIds(let ids):
            return matchByRefIds(ids: ids, index: index)
        case .layer(let layer):
            return matchByLayer(layer: layer, index: index)
        }
    }

    private func matchByName(pattern: String, index: SmartQueryIndex) -> [SmartQueryResult] {
        guard !pattern.isEmpty else {
            return matchAll(index)
        }
        var results: [SmartQueryResult] = []
        for character in index.characters where character.name.contains(pattern) {
            results.append(.character(character))
        }
        for entry in index.worldEntries where entry.name.contains(pattern) {
            results.append(.world(entry))
        }
        for reference in index.references where reference.title.contains(pattern) {
            results.append(.reference(reference))
        }
        return results
    }

    private func matchByType(type: SmartQueryEntityType, index: SmartQueryIndex) -> [SmartQueryResult] {
        switch type {
        case .character:
            return index.characters.map(SmartQueryResult.character)
        case .world:
            return index.worldEntries.map(SmartQueryResult.world)
        case .reference:
            return index.references.map(SmartQueryResult.reference)
        }
    }

    private func matchByRefIds(ids: [UUID], index: SmartQueryIndex) -> [SmartQueryResult] {
        let idSet = Set(ids)
        var results: [SmartQueryResult] = []
        for character in index.characters {
            if idSet.contains(character.id)
                || !Set(character.characterRefIds).isDisjoint(with: idSet)
                || !Set(character.worldRefIds).isDisjoint(with: idSet)
                || !Set(character.referenceRefIds).isDisjoint(with: idSet) {
                results.append(.character(character))
            }
        }
        for entry in index.worldEntries {
            if idSet.contains(entry.id)
                || !Set(entry.characterRefIds).isDisjoint(with: idSet) {
                results.append(.world(entry))
            }
        }
        for reference in index.references {
            if idSet.contains(reference.id)
                || !Set(reference.characterRefIds).isDisjoint(with: idSet)
                || !Set(reference.worldRefIds).isDisjoint(with: idSet)
                || !Set(reference.bookRefIds).isDisjoint(with: idSet) {
                results.append(.reference(reference))
            }
        }
        return results
    }

    private func matchByLayer(layer: ReferenceLayer, index: SmartQueryIndex) -> [SmartQueryResult] {
        index.references
            .filter { $0.layer == layer }
            .map(SmartQueryResult.reference)
    }

    private func matchAll(_ index: SmartQueryIndex) -> [SmartQueryResult] {
        var results: [SmartQueryResult] = []
        results.append(contentsOf: index.characters.map(SmartQueryResult.character))
        results.append(contentsOf: index.worldEntries.map(SmartQueryResult.world))
        results.append(contentsOf: index.references.map(SmartQueryResult.reference))
        return results
    }
}

enum SmartQueryResult: Hashable, Sendable {
    case character(Character)
    case world(WorldEntry)
    case reference(Reference)

    var id: UUID {
        switch self {
        case .character(let c): return c.id
        case .world(let w): return w.id
        case .reference(let r): return r.id
        }
    }

    var name: String {
        switch self {
        case .character(let c): return c.name
        case .world(let w): return w.name
        case .reference(let r): return r.title
        }
    }
}

// MARK: - Engine (composes index + evaluator)

/// High-level SmartQuery engine (= constructs the index from stores
/// + evaluates a SmartQuery).
struct SmartQueryEngine: Sendable {
    let worldStore: WorldStoring
    let characterStore: CharacterStoring
    let referenceStore: ReferenceStoring

    /// Build a SmartQueryIndex from the current store contents.
    func buildIndex() throws -> SmartQueryIndex {
        let characters = (try? characterStore.loadCharacters()) ?? []
        let worldEntries = (try? worldStore.loadWorld()) ?? []
        let references = (try? referenceStore.loadAllReferences()) ?? []
        return SmartQueryIndex(
            characters: characters,
            worldEntries: worldEntries,
            references: references
        )
    }

    /// Run a saved query (= returns matching entities + the index used).
    func run(query: SmartQuery) throws -> SmartQueryRunResult {
        guard let predicate = SmartQueryPredicate.decode(json: query.queryJSON) else {
            return SmartQueryRunResult(query: query, results: [], error: .invalidPredicateJSON)
        }
        let index = try buildIndex()
        let results = SmartQueryEvaluator(predicate: predicate).evaluate(against: index)
        return SmartQueryRunResult(query: query, results: results, error: nil)
    }
}

struct SmartQueryRunResult: Sendable {
    let query: SmartQuery
    let results: [SmartQueryResult]
    let error: SmartQueryError?
}

enum SmartQueryError: Error, LocalizedError, Sendable {
    case invalidPredicateJSON

    var errorDescription: String? {
        switch self {
        case .invalidPredicateJSON: return "Smart query JSON is malformed."
        }
    }
}