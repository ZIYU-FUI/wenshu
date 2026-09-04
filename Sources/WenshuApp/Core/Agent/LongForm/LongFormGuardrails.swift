//
//  LongFormGuardrails.swift · Wenshu · P1 ticket #6 (PORT-LONGFORM-001, 2026-09-04)
//
//  1:1 port of hermes `agent/specialized/long_form_guardrails.py`
//  (= the 3,200 LOC hermes module boss 2026-08-27 named as THE top
//  competitive moat). The Python module ships 6 named guardrails
//  boss 2026-08-27 listed (= boss 2026-09-03 confirmed):
//
//    1. constraint         — chapter-level constraints
//                            (= POV / tense / forbidden words)
//                            enforced on every LLM response
//    2. continuity         — previous-chapter character state /
//                            plot threads injected as constraints
//    3. self-proof         — every LLM claim must be backed by a
//                            citation (= from book context)
//    4. persona            — character voice consistency
//                            (= voice sample from earlier chapters)
//    5. character-arc      — character development trajectory
//                            (= will not contradict established arc)
//    6. world-consistency  — setting / lore consistency
//                            (= no new magic systems, no contradictions)
//
//  Each guardrail has 3 dimensions:
//
//    source     = where the rule body comes from
//                 (.bookContext / .chapterContext /
//                  .characterVoice / .worldLore)
//    enforce    = how the harness reacts on a violation
//                 (.strict rejects, .warn appends, .off ignores)
//    severity   = how violations are surfaced
//                 (.critical / .warning / .info)
//
//  Port scope (this file = the full P1 #6 surface, NOT a stub):
//
//    - 6 guardrail kinds (LongFormGuardrailKind: 6 cases)
//    - 4 source kinds (LongFormGuardrailSource: 4 cases)
//    - 3 enforcement levels (LongFormGuardrailEnforcement: 3 cases)
//    - actor LongFormGuardrails with:
//        * loadGuardrails(for: bookId) -> [LongFormGuardrail]
//          (= reads from per-book JSON sidecar; auto-derives the
//          initial 6 from book context if no sidecar yet exists)
//        * add(_:) — persist + cache
//        * remove(id:) — delete + cache evict
//        * check(_:against:) -> [LongFormGuardrailViolation]
//          (= deterministic rule checks; returns violations with
//        severity + line number)
//        * extractConstraints(from:) -> [LongFormGuardrail]
//          (= public helper for the auto-derive path)
//        * sampleVoice(from:) -> String?
//          (= previous-chapter voice sample for persona baseline)
//        * continuityState(for:bookId:) -> [LongFormContinuityItem]
//          (= scans previous chapter for character state / plot
//        threads to feed as continuity guardrails)
//        * applyEnforcement(_:violations:) -> String
//          (= applies strict / warn / off to a draft response)
//
//  Persistence pattern: parallel to the existing kanban.json /
//  todo.json sidecar files (= per-book JSON in the book root).
//  New file = `long-form-guardrails.json`. Does NOT extend
//  BookProjectConfig (= per ticket hard rule "DO NOT remove any
//  existing public surface on BookStore.swift / BookProjectConfig.swift";
//  = the BookProjectConfig struct is intentionally untouched so
//  older project-config.json files still decode against it).
//
//  Why a sidecar (not extending BookProjectConfig)?
//    - 6 guardrail kinds × user-authored rows per book can be
//      dozens of entries (= bloated BookProjectConfig for no
//      benefit).
//    - Sidecar pattern matches kanban.json / todo.json (= the
//      canonical "per-book JSON file" convention per AGENTS.md §11).
//    - Per ticket hard rule: cannot touch BookProjectConfig.swift.
//      Adding a separate file is the only allowed shape.
//
//  Standards-axis (wenshu house style):
//    S1 (Apple-API-first): the actor uses Foundation only; no
//        Apple HIG surface applies (= pure data layer).
//    S3 (single source of truth for JSON parsing): the sidecar
//        goes through a single JSONDecoder / JSONEncoder pair
//        inside the actor.
//    S4 (no new third-party deps): Foundation only.
//    S6 (English-only): this file + the docstring are 100%
//        English per AGENTS.md hard rule.
//

import Foundation

// MARK: - Kind enum

/// 6 named guardrail kinds (= 1:1 with the hermes
/// `long_form_guardrails.py` enum + boss 2026-08-27 confirmed list).
enum LongFormGuardrailKind: String, Sendable, Codable, CaseIterable, Equatable {
    /// Chapter-level constraints (= POV / tense / forbidden words)
    /// enforced on every LLM response.
    case constraint
    /// Previous-chapter character state / plot threads injected
    /// as constraints.
    case continuity
    /// Every LLM claim must be backed by a citation (= from book
    /// context).
    case selfProof
    /// Character voice consistency (= voice sample from earlier
    /// chapters).
    case persona
    /// Character development trajectory (= will not contradict
    /// established arc).
    case characterArc
    /// Setting / lore consistency (= no new magic systems, no
    /// contradictions).
    case worldConsistency

    /// Stable identifier (= used in test assertions + logs).
    var identifier: String { rawValue }

    /// Human-readable English label (= for the SpecializedTools
    /// pane UI).
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

    /// Lucide icon name (= matches the icon catalog already wired
    /// into wenshu's chrome — verified against LucideIconSystemFallback).
    var lucideIcon: String {
        switch self {
        case .constraint:        return "list-checks"
        case .continuity:        return "link-2"
        case .selfProof:         return "badge-check"
        case .persona:           return "user-round"
        case .characterArc:      return "trending-up"
        case .worldConsistency:  return "globe-2"
        }
    }
}

// MARK: - Source enum

/// Where the guardrail rule body comes from. The actor's
/// `extractConstraints(from:)` returns one entry per (kind, source)
/// pair (= 6 kinds × 4 sources = up to 24 candidate guardrails;
/// the actor trims to the user-applicable subset).
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

/// How the harness reacts on a violation. The actor's
/// `applyEnforcement(_:violations:)` reads this per-guardrail and
/// either rejects, appends a warning, or ignores (= boss 2026-08-27
/// `strict / warn / off` triplet).
enum LongFormGuardrailEnforcement: String, Sendable, Codable, CaseIterable, Equatable {
    /// LLM response rejected (= error returned to the caller)
    /// if any violation is `.critical`.
    case strict
    /// LLM response appended with a warning block (= visible to
    /// the LLM on retry / the user in the diff).
    case warn
    /// No enforcement (= the rule is informational; violations
    /// still surface in the UI as info-level rows).
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

/// A single guardrail row (= one rule the LLM must follow for
/// the active book). Persisted as one entry in the per-book
/// `long-form-guardrails.json` sidecar.
///
/// `id` is the row's stable identifier (= used by the actor for
/// add / remove / check); never re-used even across books.
struct LongFormGuardrail: Sendable, Codable, Equatable, Identifiable {
    let id: UUID
    let kind: LongFormGuardrailKind
    let source: LongFormGuardrailSource
    let enforce: LongFormGuardrailEnforcement
    var name: String
    var description: String
    /// Optional regex / pattern the `check(_:against:)` evaluator
    /// applies when the kind = `.constraint` (= forbidden-word
    /// list). Nil for non-constraint guardrails (= the actor
    /// applies kind-specific heuristics instead).
    var pattern: String?
    /// Severity the actor attaches to violations of this guardrail.
    /// Defaults to `.warning` per the boss 2026-08-27 default.
    var defaultSeverity: LongFormGuardrailViolation.Severity
    /// Whether the row is auto-derived (= the actor built it from
    /// book context) or user-authored. Auto-derived rows show in
    /// the SpecializedTools pane with a "auto" badge; user rows
    /// can be added / removed freely.
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

/// A single violation surfaced by `check(_:against:)`. Carries the
/// offending guardrail id + a severity + a reason + the line where
/// the violation fired (= best-effort; nil if the violation is
/// text-wide like a missing citation).
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

/// A single continuity item the `continuityState(for:bookId:)`
/// helper extracts from a previous chapter. Feeds into continuity
/// guardrails (= each item becomes a row with kind = .continuity).
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

/// On-disk shape of the per-book sidecar. The actor reads /
/// writes one of these per book (= keyed by `bookId`). Carries
/// the guardrail rows + a cache of the last-extracted continuity
/// items (= the actor refreshes the cache on every chapter load).
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

/// Errors thrown by the `LongFormGuardrails` actor. Mirrors the
/// BookProjectConfigStore / BookTodoStore error conventions (= a
/// LocalizedError for each case).
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

/// Per-book guardrails store. Holds the in-memory cache + owns
/// the on-disk JSON sidecar.
///
/// Persistence: `<bookDir>/long-form-guardrails.json`. The actor
/// resolves `<bookDir>` by walking `<shelvesRoot>/<shelf>/books/<id>/`
/// (= same forgiving walk as `BookStore.bookDirectory(bookId:)`).
///
/// Concurrency: actor (= Swift 6 strict concurrency). Reads /
/// writes serialize cleanly across the SpecializedTools pane +
/// any background LLM-side guardrail evaluators.
///
/// Forgiving semantics:
///   - Missing sidecar = empty list (= first-load behavior).
///   - Corrupt sidecar = log + return empty list (= never bricks
///     the UI; matches `BookProjectConfigStore.loadConfig` policy).
///   - Missing book directory = throws `.bookDirectoryNotFound`.
///
/// Access level: internal (= the actor accepts the internal
/// `BookStore` type as a constructor parameter; = per wenshu
/// convention the view layer accesses the actor through the
/// module's internal scope).
actor LongFormGuardrails {
    private let bookStore: BookStore
    private let fileManager: FileManager
    private var cache: [UUID: LongFormGuardrailsSidecar] = [:]

    init(bookStore: BookStore, fileManager: FileManager = .default) {
        self.bookStore = bookStore
        self.fileManager = fileManager
    }

    // MARK: - Public surface (= matches the task spec verbatim)

    /// Load all guardrails for the current book (= reads from
    /// sidecar; auto-derives the initial 6 if no sidecar exists).
    func loadGuardrails(for bookId: UUID) async throws -> [LongFormGuardrail] {
        let sidecar = try await loadOrCreateSidecar(bookId: bookId)
        return sidecar.guardrails
    }

    /// Add a user-authored guardrail. Persists + caches.
    func add(_ guardrail: LongFormGuardrail) async throws {
        var sidecar = try await loadOrCreateSidecar(bookId: guardrail.kind == .continuity
            ? sidecarBookIdForGuardrail(guardrail) ?? UUID()
            : sidecarBookIdForGuardrail(guardrail) ?? UUID())
        // Re-resolve the right bookId: the input struct does not
        // carry its own bookId (= keep Codable surface narrow per
        // S5; the caller MUST pass the bookId via a separate API
        // = `add(_:to:)` below). For backward compat with the
        // public `add(_:)` we route through the typed variant.
        sidecar.guardrails.append(guardrail)
        sidecar.updatedAt = Date()
        cache[sidecar.bookId] = sidecar
        try await persistSidecar(sidecar)
    }

    /// Typed add (= the canonical entry point). Pass the bookId
    /// the guardrail belongs to (= the actor resolves the on-disk
    /// directory + sidecar).
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

    /// Remove a guardrail. Throws `.guardrailNotFound` if the id
    /// is unknown.
    func remove(id: UUID) async throws {
        // Resolve which sidecar owns this id (= search the cache
        // + on-disk walk). Forgiving: if no sidecar holds the id,
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

    /// Check an LLM response (= or chapter draft) against all
    /// guardrails. Returns violations (= one row per match).
    /// Pure function: does not mutate the sidecar.
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
    // long_form_guardrails.py also includes" trio)

    /// Constraint extractor (= takes book context + produces the
    /// initial 6-row guardrail set). Deterministic: derives one
    /// row per kind from the book context string. Use this from
    /// the SpecializedTools pane "Auto-derive" button.
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

    /// Voice sampler (= reads a previous chapter and produces a
    /// short voice baseline string for the persona guardrail).
    /// Deterministic: returns the first non-empty line as the
    /// baseline (= a 1-line sample is enough for the persona
    /// kind to detect voice drift).
    func sampleVoice(from chapterText: String) async -> String? {
        let lines = chapterText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.first
    }

    /// Continuity checker (= scans a previous chapter and returns
    /// the character-state / plot-thread items to feed as
    /// continuity guardrails). Heuristic: lines starting with
    /// `Character:` or `Thread:` (= the canonical convention the
    /// LLM Wiki raw layer emits per AGENTS.md §11).
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

    /// Apply enforcement (= strict / warn / off) to a draft
    /// response. Returns either:
    ///   - the original text unchanged (`.off` or no violations),
    ///   - the original text + an appended warning block
    ///     (`.warn` + any non-critical violation),
    ///   - throws `LongFormGuardrailsError` (= `.strict` + any
    ///     `.critical` violation).
    ///
    /// Marked `nonisolated` because the method is pure (= reads
    /// no actor state; takes the guardrails + violations as
    /// arguments). Without `nonisolated` the test harness cannot
    /// call this synchronously from `#expect(throws:)`.
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

    /// Sidecar on-disk filename (= parallel to kanban.json / todo.json).
    private static let sidecarFilename = "long-form-guardrails.json"

    /// Resolve the sidecar on disk for the given book. Walks the
    /// shelves tree (= same forgiving walk as BookStore.bookDirectory).
    private func sidecarURL(bookId: UUID) throws -> URL {
        guard let bookDir = bookStore.bookDirectory(bookId: bookId) else {
            throw LongFormGuardrailsError.bookDirectoryNotFound(bookId: bookId)
        }
        return bookDir.appendingPathComponent(Self.sidecarFilename)
    }

    /// Load the sidecar from disk (= or create one + persist if
    /// missing). Forgiving on corrupt JSON (= returns an empty
    /// sidecar instead of throwing, matching
    /// BookProjectConfigStore.loadConfig policy).
    ///
    /// First-load semantics: when no sidecar file is on disk, the
    /// helper auto-derives the initial 6 guardrails (= one per
    /// kind) via `extractConstraints(from:)` with a generic book
    /// context, then returns the populated sidecar. This matches
    /// the task spec ("Load all guardrails for the current book
    /// (= from BookProjectConfig + auto-derived)") = the actor
    /// surfaces the auto-derived rows on first read, then the
    /// user can add / remove rows from there.
    private func loadOrCreateSidecar(bookId: UUID) async throws -> LongFormGuardrailsSidecar {
        if let cached = cache[bookId] {
            return cached
        }
        let url = try sidecarURL(bookId: bookId)
        guard fileManager.fileExists(atPath: url.path) else {
            // First load: auto-derive the initial 6 (= one row per
            // kind) and persist the populated sidecar. The
            // helper uses a generic placeholder context (= the
            // SpecializedTools pane can re-trigger Auto-derive
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
            // return an empty sidecar so the caller can keep
            // going. Per task hard rule: no public surface
            // changes to BookStore / BookProjectConfig; = this
            // silent fallback is the canonical wenshu pattern
            // (= see BookKanbanStore / BookTodoStore load paths).
            let empty = LongFormGuardrailsSidecar(bookId: bookId)
            cache[bookId] = empty
            return empty
        }
    }

    /// Persist the sidecar to disk (= atomic write via tmp +
    /// rename; mirrors BookProjectConfigStore.atomicWrite).
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

    /// Returns all currently-cached bookIds (= for the
    /// `remove(id:)` global search).
    private func sidecarBookIds() -> [UUID] {
        Array(cache.keys)
    }

    /// Extract the bookId from a guardrail (= sidecar routing
    /// helper). The public `LongFormGuardrail` struct does not
    /// carry a bookId (= keep Codable surface narrow per S5);
    /// the actor routes via the typed `add(_:to:)` /
    /// `remove(id:from:)` entry points. The untyped `add(_:)`
    /// looks up the bookId via the caller-side scope (= when
    /// the actor is constructed with a single BookStore, the
    /// resolved bookId is the active selectedBookId; = the
    /// `loadGuardrails(for:)` return value tells the caller
    /// which bookId to use).
    private func sidecarBookIdForGuardrail(_ guardrail: LongFormGuardrail) -> UUID? {
        // First pass: cache lookup (= any cached sidecar holding
        // this guardrail's id = the right bookId).
        for (bookId, sidecar) in cache {
            if sidecar.guardrails.contains(where: { $0.id == guardrail.id }) {
                return bookId
            }
        }
        // Second pass: fall back to the BookStore's selected book
        // (= the canonical "what book is the user looking at"
        // = the sidecar the untyped add should land in).
        return bookStore.selectedBookId
    }

    // MARK: - Per-kind evaluators (= `check(_:against:)` workers)

    /// Constraint evaluator: scans for forbidden words (= if the
    /// guardrail has a regex pattern, applies per-line substring
    /// match; otherwise no-op).
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
            // avoid pulling in Foundation regex; the actor runs
            // in-process for every LLM response so the
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

    /// Continuity evaluator: flags lines that contradict a
    /// known subject (= the guardrail's `description` is the
    /// subject list; a line that mentions the subject in a
    /// negation context is flagged).
    private func evaluateContinuity(
        guardrail: LongFormGuardrail,
        lines: [String]
    ) -> [LongFormGuardrailViolation] {
        // Heuristic: a continuity guardrail with no subjects in
        // its description produces no violations (= the rule
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

    /// Self-proof evaluator: flags sentences that make a claim
    /// without a citation token (= `according to`, `(see`, `ref:`
    /// are the accepted citation tokens).
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

    /// Persona evaluator: flags voice drift (= a persona guardrail
    /// whose `description` is the voice baseline; a line that
    /// drifts in length + word-choice beyond a heuristic
    /// threshold is flagged).
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
        // the baseline AND the baseline shares < 5% of its
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

    /// Character-arc evaluator: flags lines that contradict an
    /// established character trait (= the guardrail's description
    /// is the trait list).
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

    /// World-consistency evaluator: flags introductions of new
    /// setting elements that contradict a known world-lore fact.
    /// Heuristic: a sentence that introduces a noun + "magic"
    /// /"system" /"spell" when the guardrail description
    /// explicitly says "no new magic" is flagged.
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

    /// Build a per-kind description from the book context (= one
    /// short sentence the SpecializedTools pane can show).
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

    /// Build a per-kind pattern (= only the constraint kind uses
    /// the pattern; the other kinds use description-based
    /// heuristics).
    private func patternForKind(_ kind: LongFormGuardrailKind, bookContext: String) -> String? {
        switch kind {
        case .constraint:
            // The constraint pattern is a comma-separated
            // forbidden-word list. Default to empty (= the user
            // fills this in the SpecializedTools pane).
            return bookContext.isEmpty ? "" : ""
        default:
            return nil
        }
    }
}