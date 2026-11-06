//
//  ReferenceLibraryActor.swift
//
//  The actor the reference library's tool runs on.
//
//  Why: the actor's own state and its CRUD cluster stayed together (= the layer parsing is used only by the CRUD cluster, so it stays with it), and the LLM-facing dispatcher moved to its own file (= the actor was over the file-size cap).
//

import Foundation
import WenshuAgent

// MARK: - Actor

@MainActor
final class ReferenceLibraryActor {
    /// The store the actor reads and writes.
    ///
    /// It is resolved at CALL time, not at construction time: the
    /// agent's tool is built by the tool registry before the user's
    /// library exists, and the documents the agent writes have to
    /// land in the library that is open now (= the locator binds it
    /// at launch).
    private let referenceStoreProvider: @MainActor () -> any ReferenceStoring

    /// The store the actor writes to (= the bound library, or the
    /// store it was built with).
    private var referenceStore: any ReferenceStoring {
        referenceStoreProvider()
    }

    /// The service that writes the semantic summary of a document
    /// (= nil = no model is wired, = the document keeps whatever
    /// summary the caller gave it).
    let summaryService: ReferenceSummaryService?

    init(
        referenceStore: any ReferenceStoring,
        summaryService: ReferenceSummaryService? = nil
    ) {
        referenceStoreProvider = { referenceStore }
        self.summaryService = summaryService
    }

    /// The variant that resolves the store at call time (= the agent's
    /// tool).
    init(
        referenceStoreProvider: @escaping @MainActor () -> any ReferenceStoring,
        summaryService: ReferenceSummaryService? = nil
    ) {
        self.referenceStoreProvider = referenceStoreProvider
        self.summaryService = summaryService
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
        // A create must not produce a second copy of a document that
        // already exists.
        //
        // The upsert path matched on the title, the import path
        // matched on the title, and only this path did not: = the same
        // noun written twice by two callers ended up in the library
        // twice, = and neither copy knew about the other. The tool's
        // description told the model to `find` before it created;
        // = that is a request, = this is the mechanism. A caller that
        // means to refine an existing document uses `upsert` (or
        // `extend`), which is what the protocol asks for anyway.
        if let existing = try referenceStore.loadReferences(layer: parsedLayer)
            .first(where: { Self.titlesMatch($0.title, trimmed) }) {
            throw ReferenceLibraryError.duplicateTitle(
                title: trimmed,
                existingID: existing.id
            )
        }
        // A document without a summary cannot be routed (= the agent
        // cannot tell whether it constrains the chapter it is
        // writing), so the model writes one when the caller did not.
        // The call happens BEFORE the save: a document is never
        // stored with a blank summary, and a model failure surfaces
        // instead of passing for a saved document.
        let resolvedSummary = try await summaryOrThrow(
            requested: summary,
            title: trimmed,
            bodyMarkdown: bodyMarkdown
        )
        let reference = Reference(
            title: trimmed,
            source: source,
            url: url,
            layer: parsedLayer,
            category: parsedLayer == .layerEntities ? parsedCategory : nil,
            tags: tags,
            entityType: parsedType,
            summary: resolvedSummary
        )
        do {
            try referenceStore.saveReference(reference, bodyMarkdown: bodyMarkdown)
        } catch {
            throw ReferenceLibraryError.from(error)
        }
        // The library changed, so the app says so: the sidebar reloads
        // the tree and the material zone re-reads the documents. A
        // reference the agent wrote is otherwise invisible until the
        // user clicks something else.
        LibraryChangeNotifier.notifyLibraryChanged(source: .agentReference)
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
            throw ReferenceLibraryError.from(error)
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
        if let summary {
            updated.summary = summary
        }
        if let source {
            updated.source = source
        }
        if let url {
            updated.url = url
        }
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
            throw ReferenceLibraryError.from(error)
        }
        LibraryChangeNotifier.notifyLibraryChanged(source: .agentReference)
        return ReferenceDescriptor(updated)
    }

    func deleteReference(id: UUID) async throws {
        do {
            try referenceStore.deleteReference(id: id)
        } catch {
            throw ReferenceLibraryError.from(error)
        }
        LibraryChangeNotifier.notifyLibraryChanged(source: .agentReference)
    }

    /// / Append a new section to an existing reference's body (= the
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / `ReferenceDescriptor`. Throws `entryNotFound` if the id doesn't exist.
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
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
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
            LibraryChangeNotifier.notifyLibraryChanged(source: .agentReference)
            return ReferenceDescriptor(updated)
        } catch {
            throw ReferenceLibraryError.from(error)
        }
    }

    // MARK: - Identity

    /// Whether two titles name the same document.
    ///
    /// The comparison is the one the upsert path and the import path
    /// already used: = trimmed, = case-insensitive, = exact. It lives
    /// on the model (= `Reference.titlesMatch`), because the caller
    /// that owns the rule is not the only one that needs it: = three
    /// copies of the same rule is how the corpus ended up with three
    /// identities.
    static func titlesMatch(_ lhs: String, _ rhs: String) -> Bool {
        Reference.titlesMatch(lhs, rhs)
    }

    /// / Merge `## <sectionTitle>` into `existingBody`. If a section with that
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / convention).
    static func mergeSection(
        into existingBody: String,
        sectionTitle: String,
        sectionBody: String
    ) -> String {
        let heading = "## \(sectionTitle)"
        let newSection = "\(heading)\n\n\(sectionBody.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        // Look for an existing `## <sectionTitle>` heading line.
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
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
            for idx in (start + 1) ..< lines.count {
                let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("## ") {
                    endIndex = idx
                    break
                }
            }
            // Replace lines[start..<end] with the new section (= the
            // heading + body, plus a trailing newline separator).
            let replacementLines = newSection.components(separatedBy: "\n")
            lines.replaceSubrange(start ..< endIndex, with: replacementLines)
        } else {
            // No existing section — append. Insert a blank-line
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // with one.
            if !existingBody.isEmpty,
               !existingBody.hasSuffix("\n\n")
            {
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
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // rather than silently falling back to user-managed.
            guard let parsedLayer = parseLayerIfUserFacing(layer) else {
                return []
            }
            filtered = all.filter { $0.layer == parsedLayer }
        } else {
            // Default: user-managed layers (= raw + entities; =
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // which stay hidden per the spec v5 convention).
            filtered = all.filter { $0.layer == .layerRaw || $0.layer == .layerEntities }
        }
        let sorted = filtered.sorted { $0.updatedAt > $1.updatedAt }
        return sorted.map { ReferenceDescriptor($0) }
    }

    /// Every reference in the user-managed layers, = whole.
    ///
    /// `listReferences` returns a descriptor (= the light view the
    /// tool shows), = and a descriptor does not carry the
    /// cross-references. The curator needs them: = an entity with no
    /// cross-reference is an orphan, = and "orphan" is one of the
    /// three findings a curation run reports. = So this returns the
    /// full references, = for the one caller that needs the whole
    /// thing.
    func allReferencesForCuration() async throws -> [Reference] {
        let all = (try? referenceStore.loadAllReferences()) ?? []
        return all.filter { $0.layer == .layerRaw || $0.layer == .layerEntities }
    }

    func findReference(title: String, layer: String? = nil) async throws -> ReferenceDescriptor? {
        let all = (try? referenceStore.loadAllReferences()) ?? []
        let candidates: [Reference]
        if let layer {
            // Explicit layer requested. Reject the layers the agent
            // may not read (= the derived ones) by returning nil.
            guard let parsedLayer = parseLayerIfUserFacing(layer) else {
                return nil
            }
            candidates = all.filter { $0.layer == parsedLayer }
        } else {
            // Default: search across both raw + entities (= user-managed).
            candidates = all.filter { $0.layer == .layerRaw || $0.layer == .layerEntities }
        }
        // The SAME rule `create` uses. = The two must agree, = or the
        // tool's own protocol (= find before you create) traps the
        // caller: = `find` says the title is absent, = and `create`
        // then refuses the write as a duplicate, = and the caller has
        // no way out. = The rule lives in `Reference.titlesMatch`, =
        // so every reader is on the one rule.
        let match = candidates.first { ref in
            Reference.titlesMatch(ref.title, title)
        }
        return match.map { ReferenceDescriptor($0) }
    }

    /// / Upsert by title within a layer (= the recurring-research path). If an
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / growing); otherwise a new reference is created with a fresh UUID.
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
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // ones). For a fresh entry, the tags land as-is.
            let existingRefs = (try? referenceStore.loadReferences(layer: parsedLayer)) ?? []
            let existingMatch = existingRefs.first { ref in
                Self.titlesMatch(ref.title, trimmed)
            }
            let mergedTags: Set<String>
            if let existingTags = existingMatch?.tags {
                mergedTags = existingTags.union(tags)
            } else {
                mergedTags = tags
            }
            // The summary is written ONCE per document (= one model
            // call): a document that already carries one keeps it, and
            // a document without one gets one.
            let resolvedSummary = try await summaryOrThrow(
                requested: summary,
                title: trimmed,
                bodyMarkdown: bodyMarkdown,
                keeping: existingMatch?.summary ?? ""
            )
            let result = try referenceStore.upsertReference(
                title: trimmed,
                bodyMarkdown: bodyMarkdown,
                layer: parsedLayer,
                category: parsedLayer == .layerEntities ? parsedCategory : nil,
                tags: mergedTags,
                source: source,
                url: url,
                entityType: parsedType,
                summary: resolvedSummary
            )
            LibraryChangeNotifier.notifyLibraryChanged(source: .agentReference)
            return ReferenceDescriptor(result)
        } catch {
            throw ReferenceLibraryError.from(error)
        }
    }

    // MARK: - Layer parsing

    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / the derived layers) are explicitly rejected.
    private func parseLayer(_ raw: String) -> ReferenceLayer {
        switch raw.lowercased() {
        case "raw", "sourcematerial":
            return .layerRaw
        case "entities", "entity":
            return .layerEntities
        default:
            return .layerRaw
        }
    }

    /// / Same as parseLayer, but used by list / find (= returns nil if the LLM
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// / results rather than crashing).
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
}
