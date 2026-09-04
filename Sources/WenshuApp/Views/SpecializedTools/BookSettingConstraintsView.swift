//
//  BookSettingConstraintsView.swift · Wenshu · P1 ticket #16 (WIRE-SPECIALIZEDTOOLS-010, 2026-09-04)
//  FINAL specialized-tools tab.
//
//  SpecializedTools pane tab 12: Book Setting Constraints.
//
//  Per the v0.30 boss 2026-08-30 OOB pattern (= ForeshadowingView +
//  PlaceholderView + LongFormGuardrailsView + ReaderExperienceView +
//  PlotThreadView + GenreFitView + EmotionCurveView +
//  CharacterRelationshipsView + CharacterLifecycleView +
//  TagManagerView + IdeaLibraryView = 11 tabs in the specializedTools
//  pane), this view is the REAL implementation for the Book
//  Setting Constraints tab (= the 12th and final tab). Renders:
//
//    - Top header (= icon + tab title + book + constraint count)
//    - "Add constraint" row (= title + description + severity +
//      scope + appliesToId + forbidden-patterns fields + add
//      button)
//    - Constraints list (= one row per constraint; shows the
//      severity badge + title + scope + appliesToId fragment +
//      pattern chips + remove button)
//    - Check section (= chapter-text TextEditor + check button +
//      violations list)
//
//  State source: `BookSettingConstraints` actor (= owned
//  per-book, persisted via per-book JSON sidecar at
//  `books/<bookId>/setting-constraints.json`).
//
//  Standards-axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + Lucide icon
//        helper (= already wired into wenshu). No custom hover /
//        click handlers; Apple `.buttonStyle` .borderless +
//        .borderedProminent per the macOS 27 Liquid Glass
//        defaults.
//    S3 (single source of truth for JSON parsing): the actor
//        owns the JSONDecoder / JSONEncoder pair; the view
//        reads / mutates the actor and never touches the file
//        system.
//    S5 (no private types the rest of the app needs): all types
//        live in BookSettingConstraintsTools.swift (= public).
//
//  Visual-gate (boss 2026-09-03 auto-pilot rule): this commit
//  ADDS a 12th (= FINAL) tab to the specializedTools pane. Boss
//  acceptance required: open SpecializedTools pane, click the
//  new Book-Setting-Constraints tab, add a constraint, see the
//  row in the list, then paste chapter text and run the check to
//  see the violations.
//

import SwiftUI

/// SpecializedTools pane tab 12: Book Setting Constraints (= the
/// FINAL specialized tab per P1 stage completion).
///
/// Reads the active bookId from `BookStore.selectedBookId`. If
/// no book is selected, renders the empty-state (= "no book
/// selected" hint, matching the ForeshadowingView no-content
/// pattern).
@MainActor
struct BookSettingConstraintsView: View {

    @Environment(BookStore.self) private var bookStore

    /// Active book id (= drives the actor's per-book scope).
    private var activeBookId: UUID? { bookStore.selectedBookId }

    /// Actor (= created lazily for the current book; held as
    /// @State so SwiftUI keeps the identity across re-renders).
    @State private var tracker: BookSettingConstraints?

    @State private var constraints: [BookSettingConstraint] = []
    @State private var violations: [ConstraintViolation] = []

    // Add-row picker state.
    @State private var draftTitle: String = ""
    @State private var draftDescription: String = ""
    @State private var draftSeverity: ConstraintSeverity = .hard
    @State private var draftScope: ConstraintScope = .world
    @State private var draftAppliesToText: String = ""
    @State private var draftPatternsText: String = ""

    // Check-section state.
    @State private var chapterText: String = ""
    @State private var hasChecked: Bool = false

    @State private var status: LoadStatus = .idle
    @State private var errorText: String?

    private enum LoadStatus: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if activeBookId == nil {
                emptyState
            } else {
                contentBody
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: activeBookId) {
            await reload()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            LucideIconSystemFallback("book-lock", size: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Book Setting Constraints")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitleText: String {
        switch status {
        case .idle:
            return "Hard worldbuilding rules: hard / soft / preference severities across 4 scopes."
        case .loading:
            return "Loading…"
        case .loaded:
            let count = constraints.count
            let hardCount = constraints.filter { $0.severity == .hard }.count
            if hardCount > 0 {
                return "\(count) constraint\(count == 1 ? "" : "s") (\(hardCount) hard)"
            }
            return "\(count) constraint\(count == 1 ? "" : "s")"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No book selected")
                .font(.callout)
                .foregroundStyle(.primary)
            Text("Pick a book from the sidebar to start tracking setting constraints.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            addRow
            Divider()
            listSection
            Divider()
            checkSection
            Spacer(minLength: 0)
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
        }
    }

    // MARK: - Add row

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add constraint")
                .font(.callout)
                .foregroundStyle(.primary)
            TextField("Title (e.g. Magic requires eye contact)", text: $draftTitle, axis: .horizontal)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .help("Short, human-readable title for the constraint. Whitespace is trimmed.")
            TextField(
                "Description (2-3 sentences)",
                text: $draftDescription,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .lineLimit(2...4)
            .help("Short description of the rule.")
            HStack(spacing: 8) {
                Picker("Severity", selection: $draftSeverity) {
                    ForEach(ConstraintSeverity.allCases) { severity in
                        Label(severity.displayName, systemImage: severity.lucideIcon).tag(severity)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .help("Severity: hard (cannot be violated), soft (advisory), preference (style target).")
                Picker("Scope", selection: $draftScope) {
                    ForEach(ConstraintScope.allCases) { scope in
                        Label(scope.displayName, systemImage: scope.lucideIcon).tag(scope)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .help("Scope: world / character / plot / style.")
                TextField(
                    draftScope.supportsAppliesTo ? "Applies-to UUID (character or plot)" : "Applies-to (not used)",
                    text: $draftAppliesToText
                )
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .disabled(!draftScope.supportsAppliesTo)
                .help("Optional UUID of the character or plot this rule applies to.")
                Spacer(minLength: 0)
                Button {
                    Task { await addConstraint() }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
                .help("Add a new setting constraint with the supplied fields.")
            }
            TextField(
                "Forbidden patterns (comma-separated, e.g. cast from behind, came back from the dead)",
                text: $draftPatternsText,
                axis: .horizontal
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .help("Comma-separated phrases or regex patterns that violate this constraint. Trimmed at save time.")
        }
    }

    private var canAdd: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Constraints (\(constraints.count))")
                .font(.callout)
                .foregroundStyle(.primary)
            if constraints.isEmpty {
                Text("(none yet — add the first one above)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(constraints) { constraint in
                            constraintRow(constraint)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private func constraintRow(_ constraint: BookSettingConstraint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                LucideIconSystemFallback(constraint.severity.lucideIcon, size: 16)
                    .foregroundStyle(constraint.severity == .hard ? AnyShapeStyle(Color(nsColor: .systemRed)) : AnyShapeStyle(.tint))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(constraint.title)
                            .font(.callout)
                            .foregroundStyle(.primary)
                        Text(constraint.severity.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.quaternary)
                            )
                        Text(constraint.scope.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.tint.opacity(0.15))
                            )
                        if let appliesTo = constraint.appliesToId {
                            Text("→ \(appliesTo.uuidString.prefix(8))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if !constraint.description.isEmpty {
                        Text(constraint.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if !constraint.forbiddenPatterns.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(constraint.forbiddenPatterns, id: \.self) { pattern in
                                    Text(pattern)
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(nsColor: .systemRed).opacity(0.15))
                                        )
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    Task { await removeConstraint(constraint) }
                } label: {
                    LucideIconSystemFallback("trash-2", size: 14)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove this constraint.")
            }
        }
        .padding(.vertical, DesignTokens.chromePaddingSmall)
        .padding(.horizontal, DesignTokens.chromePaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary.opacity(0.5))
        )
    }

    // MARK: - Check section

    private var checkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Check chapter against constraints")
                .font(.callout)
                .foregroundStyle(.primary)
            HStack(alignment: .top, spacing: 8) {
                TextEditor(text: $chapterText)
                    .font(.caption)
                    .frame(minHeight: 100, maxHeight: 160)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary.opacity(0.3))
                    )
                    .help("Paste the chapter draft text. The checker scans every line for the forbidden patterns of every active constraint.")
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        Task { await runCheck() }
                    } label: {
                        Label("Check", systemImage: "search-check")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(chapterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || constraints.isEmpty)
                    .help("Scan the chapter text against every constraint's forbidden patterns.")
                    if hasChecked {
                        Text("\(violations.count) violation\(violations.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(violations.isEmpty ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange))
                    }
                }
            }
            if hasChecked {
                if violations.isEmpty {
                    Text("(no violations — chapter text is clean)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(violations) { violation in
                        violationRow(violation)
                    }
                }
            }
        }
    }

    private func violationRow(_ violation: ConstraintViolation) -> some View {
        HStack(alignment: .top, spacing: 6) {
            LucideIconSystemFallback(
                violation.severity == .hard ? "alert-octagon" : "alert-triangle",
                size: 14
            )
            .foregroundStyle(violation.severity == .hard ? AnyShapeStyle(Color(nsColor: .systemRed)) : AnyShapeStyle(Color(nsColor: .systemOrange)))
            .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(violation.title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Text("· \(violation.severity.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let line = violation.lineNumber {
                        Text("· line \(line)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text("matched \"\"\" \(violation.matchedText) \"\"\"")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(violation.suggestion)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    /// Resolve the appliesTo UUID from the draft text. Returns nil
    /// when the text is empty (= applies universally) or malformed
    /// (= invalid UUID = treated as nil; the writer can see the row
    /// without an applies-to anchor rather than getting an error).
    private func resolveAppliesToUUID() -> UUID? {
        let trimmed = draftAppliesToText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return UUID(uuidString: trimmed)
    }

    /// Parse the comma-separated patterns text into a clean list.
    private func parsePatterns() -> [String] {
        draftPatternsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Async actions

    private func ensureTracker() -> BookSettingConstraints {
        if let tracker { return tracker }
        let new = BookSettingConstraints(bookStore: bookStore)
        tracker = new
        return new
    }

    private func reload() async {
        guard let bookId = activeBookId else { return }
        status = .loading
        let actor = ensureTracker()
        do {
            constraints = try await actor.list(bookId: bookId)
            status = .loaded
        } catch {
            errorText = error.localizedDescription
            status = .failed(error.localizedDescription)
        }
    }

    private func addConstraint() async {
        guard let bookId = activeBookId else { return }
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let actor = ensureTracker()
        let resolvedAppliesTo: UUID?
        if draftScope.supportsAppliesTo {
            resolvedAppliesTo = resolveAppliesToUUID()
        } else {
            resolvedAppliesTo = nil
        }
        let constraint = BookSettingConstraint(
            bookId: bookId,
            title: title,
            description: draftDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            severity: draftSeverity,
            scope: draftScope,
            appliesToId: resolvedAppliesTo,
            forbiddenPatterns: parsePatterns()
        )
        do {
            try await actor.add(constraint)
            // Reset draft state.
            draftTitle = ""
            draftDescription = ""
            draftAppliesToText = ""
            draftPatternsText = ""
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func removeConstraint(_ constraint: BookSettingConstraint) async {
        let actor = ensureTracker()
        do {
            try await actor.remove(id: constraint.id)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func runCheck() async {
        guard let bookId = activeBookId else { return }
        let actor = ensureTracker()
        do {
            violations = try await actor.check(chapterText: chapterText, bookId: bookId)
            hasChecked = true
        } catch {
            errorText = error.localizedDescription
            violations = []
        }
    }
}