//
//  LongFormGuardrailsOps.swift · Wenshu · v1.75 longform-guardrails-mvvm T1b
//
//  Per-book long-form-guardrails business layer, extracted from
//  LongFormGuardrailsView (= the P0 view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9 v1.75 arc).
//
//  Per v1.72 KanbanOps template (= @MainActor enum + Result types +
//  static funcs). Per Q112 1 ticket = 1 file.
//
//  Public surface (= 5 entry points + 4 Result types):
//    1. reload(manager:bookId:) -> LoadResult
//    2. autoDerive(manager:bookId:existingRows:) -> WriteResult
//    3. removeRow(manager:bookId:row:) -> WriteResult
//    4. saveDraft(manager:bookId:kind:enforcement:name:description:) -> AddResult
//    5. runCheck(manager:guardrails:checkText:) -> CheckResult
//
//  All actor calls nil-guarded (= manager == nil -> didLoad/didSave=false).
//  Per Q112, no actor 搬家: actor stays in
//  Sources/WenshuApp/Core/Agent/LongForm/LongFormGuardrails.swift.
//

import Foundation

/// Stateless business layer for LongFormGuardrailsView. Mirrors
/// KanbanOps / TagManagerOps / CharacterLifecycleOps / BookSettingConstraintsOps
/// (= v1.72 + v1.74 + v1.75a/b precedents).
@MainActor
enum LongFormGuardrailsOps {

    // MARK: - Result types

    /// Outcome of a `reload` (= per-book guardrail list snapshot).
    struct LoadResult {
        var rows: [LongFormGuardrail]
        var didLoad: Bool
        var error: String?
    }

    /// Outcome of an `add` write (= saveDraft + autoDerive internals).
    struct AddResult {
        var didSave: Bool
        var error: String?
    }

    /// Outcome of a `remove` write (= or generic write).
    struct WriteResult {
        var didSave: Bool
        var error: String?
    }

    /// Outcome of `runCheck` (= the per-chapter enforcement scan).
    struct CheckResult {
        var violations: [LongFormGuardrailViolation]
        var hasCritical: Bool
        var didRun: Bool
        var error: String?
    }

    // MARK: - Entry points

    /// Load all guardrails for one book (= the picker + list source).
    static func reload(
        manager: LongFormGuardrails?,
        bookId: UUID?
    ) async -> LoadResult {
        guard let actor = manager,
              let bookId else {
            return LoadResult(rows: [], didLoad: false, error: nil)
        }
        do {
            let list = try await actor.loadGuardrails(for: bookId)
            return LoadResult(rows: list, didLoad: true, error: nil)
        } catch {
            return LoadResult(rows: [], didLoad: false, error: error.localizedDescription)
        }
    }

    /// Auto-derive guardrails from book context (= replaces existing
    /// rows; = the "Auto-derive" button).
    static func autoDerive(
        manager: LongFormGuardrails?,
        bookId: UUID?
    ) async -> WriteResult {
        guard let actor = manager,
              let bookId else {
            return WriteResult(didSave: false, error: "manager or bookId is nil")
        }
        do {
            // Step 1: read current rows (we need their ids to wipe).
            let existing = try await actor.loadGuardrails(for: bookId)
            for row in existing {
                try await actor.remove(id: row.id, from: bookId)
            }
            // Step 2: extract new rows from a (no book context supplied) stub.
            let derived = await actor.extractConstraints(from: "(no book context supplied)")
            for row in derived {
                try await actor.add(row, to: bookId)
            }
            return WriteResult(didSave: true, error: nil)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    /// Remove one guardrail row (= the row's delete button).
    static func removeRow(
        manager: LongFormGuardrails?,
        bookId: UUID?,
        row: LongFormGuardrail
    ) async -> WriteResult {
        guard let actor = manager,
              let bookId else {
            return WriteResult(didSave: false, error: "manager or bookId is nil")
        }
        do {
            try await actor.remove(id: row.id, from: bookId)
            return WriteResult(didSave: true, error: nil)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    /// Add a new guardrail from the draft sheet.
    static func saveDraft(
        manager: LongFormGuardrails?,
        bookId: UUID?,
        kind: LongFormGuardrailKind,
        enforcement: LongFormGuardrailEnforcement,
        name: String,
        description: String
    ) async -> AddResult {
        guard let actor = manager,
              let bookId else {
            return AddResult(didSave: false, error: "manager or bookId is nil")
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return AddResult(didSave: false, error: "name is empty")
        }
        let row = LongFormGuardrail(
            kind: kind,
            source: .bookContext,
            enforce: enforcement,
            name: trimmedName,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            isAutoDerived: false
        )
        do {
            try await actor.add(row, to: bookId)
            return AddResult(didSave: true, error: nil)
        } catch {
            return AddResult(didSave: false, error: error.localizedDescription)
        }
    }

    /// Run the guardrail enforcement scan for one chapter text.
    static func runCheck(
        manager: LongFormGuardrails?,
        guardrails: [LongFormGuardrail],
        checkText: String
    ) async -> CheckResult {
        guard let actor = manager else {
            return CheckResult(violations: [], hasCritical: false, didRun: false, error: nil)
        }
        do {
            let violations = try await actor.check(checkText, against: guardrails)
            let hasCritical = violations.contains { $0.severity == .critical }
            return CheckResult(violations: violations, hasCritical: hasCritical, didRun: true, error: nil)
        } catch {
            return CheckResult(violations: [], hasCritical: false, didRun: false, error: error.localizedDescription)
        }
    }
}