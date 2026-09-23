//
//  BookSettingConstraintsOps.swift · Wenshu · v1.75 book-setting-constraints-mvvm T1b
//
//  Per-book setting-constraint business layer, extracted from
//  BookSettingConstraintsView (= the P0 view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9 v1.75 arc).
//
//  Per v1.72 KanbanOps template (= @MainActor enum + Result types +
//  static funcs). Per Q112 1 ticket = 1 file.
//
//  Public surface (= 4 entry points + 4 Result types):
//    1. reload(manager:bookId:) -> LoadResult
//    2. addConstraint(manager:bookId:title:description:severity:scope:appliesToId:forbiddenPatterns:) -> AddResult
//    3. removeConstraint(manager:constraint:) -> WriteResult
//    4. runCheck(manager:bookId:chapterText:) -> CheckResult
//
//  All actor calls nil-guarded (= manager == nil -> didLoad/didSave=false).
//  Scope.parsePatterns(...) is a view-only helper; View keeps it.
//
//  Actor dependency: `BookSettingConstraints` actor lives in
//  Sources/WenshuApp/Core/Agent/Specialized/BookSettingConstraintsTools.swift
//  (= already actor-isolated; = no actor 搬家 per v1.74 standing rule).
//

import Foundation

/// Stateless business layer for BookSettingConstraintsView. Mirrors the
/// shape of KanbanOps / TagManagerOps / CharacterLifecycleOps (= v1.72 +
/// v1.74 + v1.75a precedents).
@MainActor
enum BookSettingConstraintsOps {

    // MARK: - Result types

    /// Outcome of a `reload` (= per-book constraint list snapshot).
    struct LoadResult {
        var constraints: [BookSettingConstraint]
        var didLoad: Bool
        var error: String?
    }

    /// Outcome of an `addConstraint` write.
    struct AddResult {
        var didSave: Bool
        var error: String?
    }

    /// Outcome of a `removeConstraint` write (= or generic write).
    struct WriteResult {
        var didSave: Bool
        var error: String?
    }

    /// Outcome of a `runCheck` (= per-chapter violation list).
    struct CheckResult {
        var violations: [ConstraintViolation]
        var didRun: Bool
        var error: String?
    }

    // MARK: - Entry points

    /// Load all constraints for one book (= the picker + list source).
    static func reload(
        manager: BookSettingConstraints?,
        bookId: UUID?
    ) async -> LoadResult {
        guard let actor = manager,
              let bookId else {
            return LoadResult(constraints: [], didLoad: false, error: nil)
        }
        do {
            let list = try await actor.list(bookId: bookId)
            return LoadResult(constraints: list, didLoad: true, error: nil)
        } catch {
            return LoadResult(constraints: [], didLoad: false, error: error.localizedDescription)
        }
    }

    /// Add one constraint. Pre-validates title (= non-empty after trim);
    /// returns didSave=false (= no actor call) when invalid.
    static func addConstraint(
        manager: BookSettingConstraints?,
        bookId: UUID?,
        title: String,
        description: String,
        severity: ConstraintSeverity,
        scope: ConstraintScope,
        appliesToId: UUID?,
        forbiddenPatterns: [String]
    ) async -> AddResult {
        guard let actor = manager,
              let bookId else {
            return AddResult(didSave: false, error: "manager or bookId is nil")
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return AddResult(didSave: false, error: "title is empty")
        }
        let resolvedAppliesTo: UUID? = scope.supportsAppliesTo ? appliesToId : nil
        let constraint = BookSettingConstraint(
            bookId: bookId,
            title: trimmedTitle,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            severity: severity,
            scope: scope,
            appliesToId: resolvedAppliesTo,
            forbiddenPatterns: forbiddenPatterns
        )
        do {
            try await actor.add(constraint)
            return AddResult(didSave: true, error: nil)
        } catch {
            return AddResult(didSave: false, error: error.localizedDescription)
        }
    }

    /// Remove one constraint by id (= the row's delete button).
    static func removeConstraint(
        manager: BookSettingConstraints?,
        constraint: BookSettingConstraint
    ) async -> WriteResult {
        guard let actor = manager else {
            return WriteResult(didSave: false, error: "manager is nil")
        }
        do {
            try await actor.remove(id: constraint.id)
            return WriteResult(didSave: true, error: nil)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    /// Run the constraint checker for one chapter (= "Run check" button).
    static func runCheck(
        manager: BookSettingConstraints?,
        bookId: UUID?,
        chapterText: String
    ) async -> CheckResult {
        guard let actor = manager,
              let bookId else {
            return CheckResult(violations: [], didRun: false, error: nil)
        }
        do {
            let list = try await actor.check(chapterText: chapterText, bookId: bookId)
            return CheckResult(violations: list, didRun: true, error: nil)
        } catch {
            return CheckResult(violations: [], didRun: false, error: error.localizedDescription)
        }
    }
}