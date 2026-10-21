// 
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
import Foundation

// MARK: - Kind enum
// / 6 named guardrail kinds (= 1:1 with the hermes
enum LongFormGuardrailKind: String, Sendable, Codable, CaseIterable, Equatable {
    // / Chapter-level constraints (= POV / tense / forbidden words) enforced on
    // / every LLM response.
    case constraint
    /// Previous-chapter character state / plot threads injected as constraints.
    case continuity
    /// Every LLM claim must be backed by a citation (= from book context).
    case selfProof
    /// Character voice consistency (= voice sample from earlier chapters).
    case persona
    // / Character development trajectory (= will not contradict established
    // / arc).
    case characterArc
    /// Setting / lore consistency (= no new magic systems, no contradictions).
    case worldConsistency

    /// Stable identifier (= used in test assertions + logs).
    var identifier: String { rawValue }

    /// Human-readable English label (= for the SpecializedTools pane UI).
    var displayName: String {
        switch self {
        case .constraint:        return "Constraint"
        case .continuity:        return "Continuity"
        case .selfProof:         return "Self-Proof"
        case .persona:           return "Persona"
        case .characterArc:      return "Character Arc"
        case .worldConsistency:  return "World Consistency"
        }
    }

    // / SF Symbols 6 icon name (= Apple canonical; = used by Image(systemName:)
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / Lucide-era names removed Migrated to outline glyphs.
    var icon: String {
        switch self {
        case .constraint:        return "checklist"          // Lucide 'list-checks'
        case .continuity:        return "link"               // Lucide 'link-2'
        case .selfProof:         return "checkmark.seal"     // Lucide 'badge-check'
        case .persona:           return "person"             // Lucide 'user-round'
        case .characterArc:      return "chart.line.uptrend.xyaxis"  // Lucide 'trending-up'
        case .worldConsistency:  return "globe"              // Lucide 'globe-2'
        }
    }
}

// MARK: - Source enum
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / user-applicable subset).
enum LongFormGuardrailSource: String, Sendable, Codable, CaseIterable, Equatable {
    /// Whole-book context (= characters, world, plot summary).
    case bookContext
    /// Per-chapter context (= the chapter being drafted).
    case chapterContext
    /// Voice sample (= earlier chapters of the same character).
    case characterVoice
    /// Setting / lore document (= `.world/` folder).
    case worldLore

    var identifier: String { rawValue }

    var displayName: String {
        switch self {
        case .bookContext:     return "Book Context"
        case .chapterContext:  return "Chapter Context"
        case .characterVoice:  return "Character Voice"
        case .worldLore:       return "World Lore"
        }
    }
}

// MARK: - Enforcement enum
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / warn / off` triplet).
enum LongFormGuardrailEnforcement: String, Sendable, Codable, CaseIterable, Equatable {
    // / LLM response rejected (= error returned to the caller) if any violation
    // / is `.critical`.
    case strict
    // / LLM response appended with a warning block (= visible to the LLM on
    // / retry / the user in the diff).
    case warn
    // / No enforcement (= the rule is informational; violations still surface in
    // / the UI as info-level rows).
    case off

    var identifier: String { rawValue }

    var displayName: String {
        switch self {
        case .strict: return "Strict (reject on violation)"
        case .warn:   return "Warn (append warning)"
        case .off:    return "Off (informational only)"
        }
    }
}

// MARK: - Guardrail struct
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / check); never re-used even across books.
struct LongFormGuardrail: Sendable, Codable, Equatable, Identifiable {
    let id: UUID
    let kind: LongFormGuardrailKind
    let source: LongFormGuardrailSource
    let enforce: LongFormGuardrailEnforcement
    var name: String
    var description: String
    // / Optional regex / pattern the `check(_:against:)` evaluator applies when
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / guardrails (= the actor applies kind-specific heuristics instead).
    var pattern: String?
    /// Severity the actor attaches to violations of this guardrail.
    var defaultSeverity: LongFormGuardrailViolation.Severity
    // / Whether the row is auto-derived (= the actor built it from book context)
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / with a "auto" badge; user rows can be added / removed freely.
    let isAutoDerived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: LongFormGuardrailKind,
        source: LongFormGuardrailSource,
        enforce: LongFormGuardrailEnforcement = .warn,
        name: String,
        description: String,
        pattern: String? = nil,
        defaultSeverity: LongFormGuardrailViolation.Severity = .warning,
        isAutoDerived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.enforce = enforce
        self.name = name
        self.description = description
        self.pattern = pattern
        self.defaultSeverity = defaultSeverity
        self.isAutoDerived = isAutoDerived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Violation struct
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / best-effort; nil if the violation is text-wide like a missing citation).
struct LongFormGuardrailViolation: Sendable, Codable, Equatable {
    let guardrailId: UUID
    let kind: LongFormGuardrailKind
    let severity: Severity
    let reason: String
    let lineNumber: Int?

    enum Severity: String, Sendable, Codable, CaseIterable, Equatable {
        case critical
        case warning
        case info
    }

    init(
        guardrailId: UUID,
        kind: LongFormGuardrailKind,
        severity: Severity,
        reason: String,
        lineNumber: Int? = nil
    ) {
        self.guardrailId = guardrailId
        self.kind = kind
        self.severity = severity
        self.reason = reason
        self.lineNumber = lineNumber
    }
}

// MARK: - Continuity item (= the helper result shape)
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / becomes a row with kind = .continuity).
struct LongFormContinuityItem: Sendable, Codable, Equatable, Identifiable {
    let id: UUID
    let subject: String
    let detail: String
    let chapterIndex: Int

    init(id: UUID = UUID(), subject: String, detail: String, chapterIndex: Int) {
        self.id = id
        self.subject = subject
        self.detail = detail
        self.chapterIndex = chapterIndex
    }
}

// MARK: - Sidecar on-disk shape
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / chapter load).
struct LongFormGuardrailsSidecar: Codable, Sendable, Equatable {
    var bookId: UUID
    var guardrails: [LongFormGuardrail]
    var lastContinuity: [LongFormContinuityItem]
    var updatedAt: Date

    init(
        bookId: UUID,
        guardrails: [LongFormGuardrail] = [],
        lastContinuity: [LongFormContinuityItem] = [],
        updatedAt: Date = .now
    ) {
        self.bookId = bookId
        self.guardrails = guardrails
        self.lastContinuity = lastContinuity
        self.updatedAt = updatedAt
    }
}

// MARK: - Actor errors
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / for each case).
enum LongFormGuardrailsError: Error, LocalizedError, Sendable, Equatable {
    case bookDirectoryNotFound(bookId: UUID)
    case guardrailNotFound(id: UUID)
    case corruptSidecar(bookId: UUID, underlying: String)

    var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let id):
            return "LongFormGuardrails: book directory not found for id \(id.uuidString)"
        case .guardrailNotFound(let id):
            return "LongFormGuardrails: guardrail \(id.uuidString) not found"
        case .corruptSidecar(let id, let underlying):
            return "LongFormGuardrails: corrupt sidecar for book \(id.uuidString): \(underlying)"
        }
    }
}

// MARK: - Actor
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / scope).
actor LongFormGuardrails {
    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: LongFormGuardrailsSidecar] = [:]

    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - Public surface (= matches the task spec verbatim)
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / auto-derives the initial 6 if no sidecar exists).
    func loadGuardrails(for bookId: UUID) async throws -> [LongFormGuardrail] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        return sidecar.guardrails
    }

    /// Add a user-authored guardrail. Persists + caches.
    func add(_ guardrail: LongFormGuardrail) async throws {
        var sidecar = try await loadOrCreateSidecar(bookId: guardrail.kind == .continuity
            ? (await sidecarBookIdForGuardrail(guardrail)) ?? UUID()
            : (await sidecarBookIdForGuardrail(guardrail)) ?? UUID())
        // Re-resolve the right bookId: the input struct does not
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // public `add(_:)` we route through the typed variant.
        sidecar.guardrails.append(guardrail)
        sidecar.updatedAt = Date()
        cache[sidecar.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    // / Typed add (= the canonical entry point). Pass the bookId the guardrail
    // / belongs to (= the actor resolves the on-disk directory + sidecar).
    func add(_ guardrail: LongFormGuardrail, to bookId: UUID) async throws {
        var sidecar = try await loadOrCreateSidecar(bookId: bookId)
        // Replace if a guardrail with the same id already exists
        // (= idempotent add; matches BookKanbanStore upsert policy).
        if let idx = sidecar.guardrails.firstIndex(where: { $0.id == guardrail.id }) {
            sidecar.guardrails[idx] = guardrail
        } else {
            sidecar.guardrails.append(guardrail)
        }
        sidecar.updatedAt = Date()
        cache[bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Remove a guardrail. Throws `.guardrailNotFound` if the id is unknown.
    func remove(id: UUID) async throws {
        // Resolve which sidecar owns this id (= search the cache
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // throw .guardrailNotFound.
        for bookId in sidecarBookIds() {
            var sidecar = try await loadOrCreateSidecar(bookId: bookId)
            if let idx = sidecar.guardrails.firstIndex(where: { $0.id == id }) {
                sidecar.guardrails.remove(at: idx)
                sidecar.updatedAt = Date()
                cache[bookId] = sidecar
                try await persistSidecar(sidecar)
                return
            }
        }
        throw LongFormGuardrailsError.guardrailNotFound(id: id)
    }

    /// Remove a guardrail within a known book (= typed variant).
    func remove(id: UUID, from bookId: UUID) async throws {
        var sidecar = try await loadOrCreateSidecar(bookId: bookId)
        guard let idx = sidecar.guardrails.firstIndex(where: { $0.id == id }) else {
            throw LongFormGuardrailsError.guardrailNotFound(id: id)
        }
        sidecar.guardrails.remove(at: idx)
        sidecar.updatedAt = Date()
        cache[bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    // / Check an LLM response (= or chapter draft) against all guardrails.
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / the sidecar.
    func check(_ text: String, against guardrails: [LongFormGuardrail]) async throws
        -> [LongFormGuardrailViolation]
    {
        var violations: [LongFormGuardrailViolation] = []
        let lines = text.components(separatedBy: "\n")
        for guardrail in guardrails {
            switch guardrail.kind {
            case .constraint:
                violations.append(contentsOf: evaluateConstraint(guardrail: guardrail, lines: lines))
            case .continuity:
                violations.append(contentsOf: evaluateContinuity(guardrail: guardrail, lines: lines))
            case .selfProof:
                violations.append(contentsOf: evaluateSelfProof(guardrail: guardrail, text: text, lines: lines))
            case .persona:
                violations.append(contentsOf: evaluatePersona(guardrail: guardrail, text: text, lines: lines))
            case .characterArc:
                violations.append(contentsOf: evaluateCharacterArc(guardrail: guardrail, lines: lines))
            case .worldConsistency:
                violations.append(contentsOf: evaluateWorldConsistency(guardrail: guardrail, text: text, lines: lines))
            }
        }
        return violations
    }

    // MARK: - Helper methods (= the task spec §"Hermes's
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / button.
    func extractConstraints(from bookContext: String) async -> [LongFormGuardrail] {
        let trimmed = bookContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let kinds: [LongFormGuardrailKind] = LongFormGuardrailKind.allCases
        let sourceByKind: [LongFormGuardrailKind: LongFormGuardrailSource] = [
            .constraint:        .bookContext,
            .continuity:        .bookContext,
            .selfProof:         .bookContext,
            .persona:           .characterVoice,
            .characterArc:      .characterVoice,
            .worldConsistency:  .worldLore,
        ]
        return kinds.map { kind in
            LongFormGuardrail(
                kind: kind,
                source: sourceByKind[kind] ?? .bookContext,
                enforce: .warn,
                name: "Auto-derived \(kind.displayName)",
                description: descriptionForKind(kind, bookContext: trimmed),
                pattern: patternForKind(kind, bookContext: trimmed),
                defaultSeverity: .warning,
                isAutoDerived: true
            )
        }
    }

    // / Voice sampler (= reads a previous chapter and produces a short voice
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / the persona kind to detect voice drift).
    func sampleVoice(from chapterText: String) async -> String? {
        let lines = chapterText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.first
    }

    // / Continuity checker (= scans a previous chapter and returns the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / canonical convention the LLM Wiki raw layer emits per AGENTS.md §11).
    func continuityState(for bookId: UUID, chapterIndex: Int = -1) async throws
        -> [LongFormContinuityItem]
    {
        // Reuse the cached sidecar's `lastContinuity` if present
        // (= continuity was extracted earlier and not invalidated).
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        if !sidecar.lastContinuity.isEmpty {
            return sidecar.lastContinuity
        }
        // Otherwise scan the active book's chapter folder for
        // raw-layer files. Forgiving: missing folder = empty list.
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            return []
        }
        let chaptersDir = bookDir.appendingPathComponent("chapters", isDirectory: true)
        guard fileManager.fileExists(atPath: chaptersDir.path) else { return [] }
        let chapterFiles = (try? fileManager.contentsOfDirectory(
            at: chaptersDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        var items: [LongFormContinuityItem] = []
        for url in chapterFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard url.pathExtension.lowercased() == "md",
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in text.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("Character:") {
                    let subject = String(trimmed.dropFirst("Character:".count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !subject.isEmpty {
                        items.append(LongFormContinuityItem(
                            subject: subject,
                            detail: "state observed in chapter file",
                            chapterIndex: chapterIndex < 0 ? items.count : chapterIndex
                        ))
                    }
                } else if trimmed.hasPrefix("Thread:") {
                    let subject = String(trimmed.dropFirst("Thread:".count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !subject.isEmpty {
                        items.append(LongFormContinuityItem(
                            subject: subject,
                            detail: "plot thread observed in chapter file",
                            chapterIndex: chapterIndex < 0 ? items.count : chapterIndex
                        ))
                    }
                }
            }
        }
        // Cache the result on the sidecar (= future calls short-
        // circuit until the user explicitly invalidates).
        var updated = sidecar
        updated.lastContinuity = items
        updated.updatedAt = Date()
        cache[bookId] = updated
        try await persistSidecar(updated)
        return items
    }

    // / Apply enforcement (= strict / warn / off) to a draft response. Returns
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / synchronously from `#expect(throws:)`.
    nonisolated func applyEnforcement(_ text: String, violations: [LongFormGuardrailViolation],
                                      against guardrails: [LongFormGuardrail]) throws -> String
    {
        // Group violations by their guardrail's enforcement level.
        let enforcementByGuardrailId: [UUID: LongFormGuardrailEnforcement] = Dictionary(
            uniqueKeysWithValues: guardrails.map { ($0.id, $0.enforce) }
        )
        let hasCritical = violations.contains { v in
            v.severity == .critical
        }
        let anyStrictWithCritical = violations.contains { v in
            v.severity == .critical
                && (enforcementByGuardrailId[v.guardrailId] ?? .warn) == .strict
        }
        if anyStrictWithCritical {
            throw LongFormGuardrailsError.guardrailNotFound(
                id: violations.first(where: { $0.severity == .critical })?.guardrailId ?? UUID()
            )
        }
        // Anything else = keep the text. If there's a `.warn` +
        // any violation, append a warning block.
        let warnViolations = violations.filter { v in
            (enforcementByGuardrailId[v.guardrailId] ?? .warn) == .warn
        }
        guard !warnViolations.isEmpty else { return text }
        _ = hasCritical // (kept for future strict-with-non-critical use)
        let warningLines = warnViolations.map { v -> String in
            let lineFragment = v.lineNumber.map { " (line \($0))" } ?? ""
            return "- [\(v.severity.rawValue)] \(v.kind.displayName)\(lineFragment): \(v.reason)"
        }
        let warningBlock = "\n\n<!-- LongFormGuardrails warning\n" + warningLines.joined(separator: "\n") + "\n-->"
        return text + warningBlock
    }

    // MARK: - Internals
    // / Sidecar on-disk filename (= parallel to kanban.json / todo.json).
    private static let sidecarFilename = "long-form-guardrails.json"

    // / Resolve the sidecar on disk for the given book. Walks the shelves tree
    // / (= same forgiving walk as BookStore.bookDirectory).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw LongFormGuardrailsError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    // / Load the sidecar from disk (= or create one + persist if missing).
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / from there.
    private func loadOrCreateSidecar(bookId: UUID) async throws -> LongFormGuardrailsSidecar {
        if let cached = cache[bookId] {
            return cached
        }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            // First load: auto-derive the initial 6 (= one row per
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // with the real book context later).
            let derived = await extractConstraints(from: "(book context not yet supplied)")
            let fresh = LongFormGuardrailsSidecar(
                bookId: bookId,
                guardrails: derived,
                lastContinuity: []
            )
            cache[bookId] = fresh
            try await persistSidecar(fresh)
            return fresh
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sidecar = try decoder.decode(LongFormGuardrailsSidecar.self, from: data)
            cache[bookId] = sidecar
            return sidecar
        } catch {
            // Forgiving: log nothing (= no logger dependency);
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // (= see BookKanbanStore load paths).
            let empty = LongFormGuardrailsSidecar(bookId: bookId)
            cache[bookId] = empty
            return empty
        }
    }

    // / Persist the sidecar to disk (= atomic write via tmp + rename; mirrors
    // / BookProjectConfigStore.atomicWrite).
    private func persistSidecar(_ sidecar: LongFormGuardrailsSidecar) async throws {
        let url = try sidecarURL(bookId: sidecar.bookId)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sidecar)
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.moveItem(at: tmpURL, to: url)
    }

    // / Returns all currently-cached bookIds (= for the `remove(id:)` global
    // / search).
    private func sidecarBookIds() -> [UUID] {
        Array(cache.keys)
    }

    // / Extract the bookId from a guardrail (= sidecar routing helper). The
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / caller which bookId to use).
    private func sidecarBookIdForGuardrail(_ guardrail: LongFormGuardrail) async -> UUID? {
        // First pass: cache lookup (= any cached sidecar holding
        // this guardrail's id = the right bookId).
        for (bookId, sidecar) in cache {
            if sidecar.guardrails.contains(where: { $0.id == guardrail.id }) {
                return bookId
            }
        }
        // Second pass: fall back to the BookStore's selected book
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // = read the value from a MainActor-isolated context.
        return await MainActor.run { bookStore.selectedBookId }
    }

    // MARK: - Per-kind evaluators (= `check(_:against:)` workers)
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / a regex pattern, applies per-line substring match; otherwise no-op).
    private func evaluateConstraint(
        guardrail: LongFormGuardrail,
        lines: [String]
    ) -> [LongFormGuardrailViolation] {
        guard let pattern = guardrail.pattern, !pattern.isEmpty else {
            return []
        }
        var violations: [LongFormGuardrailViolation] = []
        for (idx, line) in lines.enumerated() {
            let lowerLine = line.lowercased()
            // Naive substring scan (= not NSRegularExpression to
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // substring scan is the right cost shape).
            let forbiddenWords = pattern
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            for word in forbiddenWords where lowerLine.contains(word) {
                violations.append(LongFormGuardrailViolation(
                    guardrailId: guardrail.id,
                    kind: .constraint,
                    severity: guardrail.defaultSeverity,
                    reason: "forbidden word '\(word)' found (guardrail: \(guardrail.name))",
                    lineNumber: idx + 1
                ))
            }
        }
        return violations
    }

    // / Continuity evaluator: flags lines that contradict a known subject (= the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / subject in a negation context is flagged).
    private func evaluateContinuity(
        guardrail: LongFormGuardrail,
        lines: [String]
    ) -> [LongFormGuardrailViolation] {
        // Heuristic: a continuity guardrail with no subjects in
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // exists but applies globally; = surface as info).
        let subjects = guardrail.description
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !subjects.isEmpty else {
            return []
        }
        var violations: [LongFormGuardrailViolation] = []
        let negationMarkers = [" never ", " no longer ", " not ", " isn't ", " aren't "]
        for (idx, line) in lines.enumerated() {
            let lower = " \(line.lowercased()) "
            for subject in subjects {
                if lower.contains(" \(subject.lowercased()) "),
                   negationMarkers.contains(where: { lower.contains($0) }) {
                    violations.append(LongFormGuardrailViolation(
                        guardrailId: guardrail.id,
                        kind: .continuity,
                        severity: guardrail.defaultSeverity,
                        reason: "continuity subject '\(subject)' is negated (guardrail: \(guardrail.name))",
                        lineNumber: idx + 1
                    ))
                }
            }
        }
        return violations
    }

    // / Self-proof evaluator: flags sentences that make a claim without a
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / citation tokens).
    private func evaluateSelfProof(
        guardrail: LongFormGuardrail,
        text: String,
        lines: [String]
    ) -> [LongFormGuardrailViolation] {
        let citationMarkers = ["according to", "(see", "ref:", "[ref]", "source:", "cite:"]
        let claimMarkers = [" is ", " are ", " was ", " were ", " must ", " will "]
        var violations: [LongFormGuardrailViolation] = []
        for (idx, line) in lines.enumerated() {
            let lower = line.lowercased()
            let hasClaim = claimMarkers.contains { lower.contains($0) }
            let hasCitation = citationMarkers.contains { lower.contains($0) }
            if hasClaim && !hasCitation && line.count > 60 {
                violations.append(LongFormGuardrailViolation(
                    guardrailId: guardrail.id,
                    kind: .selfProof,
                    severity: guardrail.defaultSeverity,
                    reason: "claim without citation (guardrail: \(guardrail.name))",
                    lineNumber: idx + 1
                ))
            }
        }
        _ = text
        return violations
    }

    // / Persona evaluator: flags voice drift (= a persona guardrail whose
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / word-choice beyond a heuristic threshold is flagged).
    private func evaluatePersona(
        guardrail: LongFormGuardrail,
        text: String,
        lines: [String]
    ) -> [LongFormGuardrailViolation] {
        let baseline = guardrail.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseline.isEmpty else { return [] }
        let baselineWords = Set(baseline.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty })
        guard !baselineWords.isEmpty else { return [] }
        var violations: [LongFormGuardrailViolation] = []
        let bodyWords = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let bodySet = Set(bodyWords)
        let overlap = bodySet.intersection(baselineWords).count
        let bodyCount = max(bodyWords.count, 1)
        let baselineCount = max(baselineWords.count, 1)
        let overlapRatio = Double(overlap) / Double(bodyCount)
        let baselineRatio = Double(overlap) / Double(baselineCount)
        // Heuristic: if the body shares < 5% of its words with
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // words with the body = voice drift.
        if overlapRatio < 0.05 && baselineRatio < 0.05 && text.count > 200 {
            violations.append(LongFormGuardrailViolation(
                guardrailId: guardrail.id,
                kind: .persona,
                severity: .info,
                reason: "voice drift: text shares few words with baseline (guardrail: \(guardrail.name))",
                lineNumber: lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                    .map { $0 + 1 }
            ))
        }
        return violations
    }

    // / Character-arc evaluator: flags lines that contradict an established
    // / character trait (= the guardrail's description is the trait list).
    private func evaluateCharacterArc(
        guardrail: LongFormGuardrail,
        lines: [String]
    ) -> [LongFormGuardrailViolation] {
        let traits = guardrail.description
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !traits.isEmpty else { return [] }
        var violations: [LongFormGuardrailViolation] = []
        let contradictionMarkers = [" suddenly ", " unexpectedly ", " for the first time "]
        for (idx, line) in lines.enumerated() {
            let lower = " \(line.lowercased()) "
            for trait in traits {
                if lower.contains(" \(trait.lowercased()) "),
                   contradictionMarkers.contains(where: { lower.contains($0) }) {
                    violations.append(LongFormGuardrailViolation(
                        guardrailId: guardrail.id,
                        kind: .characterArc,
                        severity: guardrail.defaultSeverity,
                        reason: "character trait '\(trait)' is contradicted (guardrail: \(guardrail.name))",
                        lineNumber: idx + 1
                    ))
                }
            }
        }
        return violations
    }

    // / World-consistency evaluator: flags introductions of new setting elements
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / description explicitly says "no new magic" is flagged.
    private func evaluateWorldConsistency(
        guardrail: LongFormGuardrail,
        text: String,
        lines: [String]
    ) -> [LongFormGuardrailViolation] {
        let lore = guardrail.description.lowercased()
        guard lore.contains("no new magic") || lore.contains("no new system") else {
            return []
        }
        let introductionMarkers = [" there is a ", " there exists a ", " introduces ", " creates a "]
        let forbiddenNouns = ["magic system", "spell", "artifact", "enchantment"]
        var violations: [LongFormGuardrailViolation] = []
        for (idx, line) in lines.enumerated() {
            let lower = " \(line.lowercased()) "
            if introductionMarkers.contains(where: { lower.contains($0) }),
               forbiddenNouns.contains(where: { lower.contains($0) }) {
                violations.append(LongFormGuardrailViolation(
                    guardrailId: guardrail.id,
                    kind: .worldConsistency,
                    severity: guardrail.defaultSeverity,
                    reason: "new setting element introduced (guardrail: \(guardrail.name))",
                    lineNumber: idx + 1
                ))
            }
        }
        _ = text
        return violations
    }

    // MARK: - extractConstraints helpers
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / the SpecializedTools pane can show).
    private func descriptionForKind(_ kind: LongFormGuardrailKind, bookContext: String) -> String {
        let context = bookContext.isEmpty ? "(no book context supplied)" : bookContext
        switch kind {
        case .constraint:
            return "Forbidden words / POV / tense rules derived from: \(context.prefix(80))"
        case .continuity:
            return "Character states / plot threads carried over from previous chapters"
        case .selfProof:
            return "Every claim must include a citation (according to / see / ref:)"
        case .persona:
            return "Character voice baseline sampled from earlier chapters"
        case .characterArc:
            return "Character development trajectory must not contradict established arc"
        case .worldConsistency:
            return "Setting / lore must remain consistent (no new magic systems)"
        }
    }

    // / Build a per-kind pattern (= only the constraint kind uses the pattern;
    // / the other kinds use description-based heuristics).
    private func patternForKind(_ kind: LongFormGuardrailKind, bookContext: String) -> String? {
        switch kind {
        case .constraint:
            // The constraint pattern is a comma-separated
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // fills this in the SpecializedTools pane).
            return bookContext.isEmpty ? "" : ""
        default:
            return nil
        }
    }
}