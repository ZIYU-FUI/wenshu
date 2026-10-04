//
//  BookSettingConstraintsView.swift
//  FINAL specialized-tools tab.
//
//  SpecializedTools pane tab 12: Book Setting Constraints.
//
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
//      state.violations list)
//
//  State source: `BookSettingConstraints` actor (= owned
//  per-book, persisted via per-book JSON sidecar at
//  `books/<bookId>/setting-state.constraints.json`).
//
//  Standards-axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6 icon
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
//  Visual-gate ((see OOB.md #2026-09-03) auto-pilot rule): this commit
//  ADDS a 12th (= FINAL) tab to the specializedTools pane. The
//  acceptance required: open SpecializedTools pane, click the
//  new Book-Setting-Constraints tab, add a constraint, see the
//  row in the list, then paste chapter text and run the check to
//  see the state.violations.
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

    /// Business state mirror (= state.constraints + state.violations + status +
    /// errorText). Form drafts stay on the View per §11.3.
    @State private var state = BookSettingConstraintsViewState()

    // Add-constraint picker state.
    @State private var draftTitle: String = ""
    @State private var draftDescription: String = ""
    @State private var draftSeverity: ConstraintSeverity = .hard
    @State private var draftScope: ConstraintScope = .world
    @State private var draftAppliesToText: String = ""
    @State private var draftPatternsText: String = ""

    // Scan input.
    @State private var chapterText: String = ""
    @State private var hasChecked: Bool = false



    init() {}

    var body: some View {
        // C3.7.4: migrate to specializedToolBody modifier
        // (= TagManagerView, CharacterLifecycleView, CharacterRelationshipsView
        // already migrated in C3.7.2 + C3.7.3; = BookSettingConstraintsView is
        // the 4th of 6 SpecializedTools to adopt the modifier).
        specializedToolBody(
            activeBookId: activeBookId,
            emptyContent: { emptyState },
            mainContent: { contentBody }
        )
        .task(id: activeBookId) {
            await reload()
        }
    }

    private var emptyState: some View {
        // -m1-shell (see OOB.md #2026-09-12) OOB 'the current empty state isn't
        // a single component — can you abstract a UI component? While you're at it, on the
        // empty-state icon: double the size and use the thinnest strokes. The goal is to unify all
        // empty-state styles. The right column has 12 tabs and many are missing an empty state': use
        // the unified EmptyStateView component (= 76 PT SF Symbols 6 icon + .regular weight = the canonical macOS 27 inspector icon weight; = standard
        // title/body hierarchy). Same visual treatment as every
        // other empty state in the workspace.
        EmptyStateView(
            icon: "book.closed",
            title: WenshuI18n.t("b5.booksettingconstraintsview.l153.h29425451"),
            body: WenshuI18n.t("b5.booksettingconstraintsview.l156.h45808897")
        )
    }


    // MARK: - Body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            addRow
            Divider()
            listSection
            Divider()
            checkSection
            Spacer(minLength: 0)
            if let errorText = state.errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Add row

    private var addRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            Text(WenshuI18n.t("b5.booksettingconstraintsview.l185.h87583031"))
                .font(.callout)
                .foregroundStyle(.primary)
            TextField(WenshuI18n.t("b5.booksettingconstraintsview.l188.h10634385"), text: $draftTitle, axis: .horizontal)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .help(WenshuI18n.t("b5.booksettingconstraintsview.l191.h24829594"))
            TextField(
                "Description (2-3 sentences)",
                text: $draftDescription,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .lineLimit(2...4)
            .help(WenshuI18n.t("b5.booksettingconstraintsview.l200.h58963992"))
            HStack(spacing: DesignTokens.spacingStandard) {
                Picker("Severity", selection: $draftSeverity) {
                    ForEach(ConstraintSeverity.allCases) { severity in
                        Label(severity.displayName, systemImage: severity.icon).tag(severity)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .help(WenshuI18n.t("b5.booksettingconstraintsview.l209.h3955671"))
                Picker("Scope", selection: $draftScope) {
                    ForEach(ConstraintScope.allCases) { scope in
                        Label(scope.displayName, systemImage: scope.icon).tag(scope)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .help(WenshuI18n.t("b5.booksettingconstraintsview.l217.h78462056"))
                TextField(
                    draftScope.supportsAppliesTo ? "Applies-to UUID (character or plot)" : "Applies-to (not used)",
                    text: $draftAppliesToText
                )
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .disabled(!draftScope.supportsAppliesTo)
                .help(WenshuI18n.t("b5.booksettingconstraintsview.l225.h9125068"))
                Spacer(minLength: 0)
                Button {
                    Task { await addConstraint() }
                } label: {
                    Label { Text(WenshuI18n.t("b5.booksettingconstraintsview.l230.h25158042")) } icon: { SFIcon("plus", style: .inlineSmall, color: IconColor.tint) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
                .help(WenshuI18n.t("b5.booksettingconstraintsview.l234.h50733767"))
            }
            TextField(
                "Forbidden patterns (comma-separated, e.g. cast from behind, came back from the dead)",
                text: $draftPatternsText,
                axis: .horizontal
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .help(WenshuI18n.t("b5.booksettingconstraintsview.l243.h5804737"))
        }
    }

    private var canAdd: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(WenshuI18n.t("b5.booksettingconstraintsview.l255.h54115638"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.constraints.isEmpty {
                Text(WenshuI18n.t("b5.booksettingconstraintsview.l259.h46205528"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                        ForEach(state.constraints) { constraint in
                            constraintRow(constraint)
                        }
                    }
                }
                .frame(maxHeight: DesignTokens.panelMediumMaxHeight)
            }
        }
    }

    private func constraintRow(_ constraint: BookSettingConstraint) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            HStack(alignment: .top, spacing: DesignTokens.spacingStandard) {
                SFIcon(constraint.severity.icon, style: .inlineSmall, color: constraint.severity == .hard ? IconColor.red : IconColor.tint)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DesignTokens.spacingTight) {
                        Text(constraint.title)
                            .font(.callout)
                            .foregroundStyle(.primary)
                        Text(constraint.severity.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DesignTokens.spacingTight)
                            .padding(.vertical, DesignTokens.spacingHairline)
                            
                        Text(constraint.scope.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DesignTokens.spacingTight)
                            .padding(.vertical, DesignTokens.spacingHairline)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip)
                                    .fill(.tint.opacity(0.15))
                            )
                        if let _ = constraint.appliesToId {
                            Text(WenshuI18n.t("b5.booksettingconstraintsview.l306.h56657996"))
                                .font(.caption2)
                                .foregroundStyle(DesignTokens.statusForeground)
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
                            HStack(spacing: DesignTokens.spacingIconic) {
                                ForEach(constraint.forbiddenPatterns, id: \.self) { pattern in
                                    Text(pattern)
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, DesignTokens.spacingIconic)
                                        .padding(.vertical, DesignTokens.spacingHairline)
                                        .background(
                                            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip)
                                                .fill(.red.opacity(0.15))
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
                    SFIcon("trash", style: .inlineSmall, color: IconColor.secondary)
                }
                .buttonStyle(.borderless)
                .help(WenshuI18n.t("b5.booksettingconstraintsview.l343.h49822929"))
            }
        }
        .padding(.vertical, DesignTokens.spacingTight)
        .padding(.horizontal, DesignTokens.spacingStandard)
        .frame(maxWidth: .infinity, alignment: .leading)
        
    }

    // MARK: - Check section

    private var checkSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            Text(WenshuI18n.t("b5.booksettingconstraintsview.l359.h58742514"))
                .font(.callout)
                .foregroundStyle(.primary)
            HStack(alignment: .top, spacing: DesignTokens.spacingStandard) {
                TextEditor(text: $chapterText)
                    .font(.caption)
                    .frame(minHeight: DesignTokens.textEditorMediumMinHeight, maxHeight: DesignTokens.textEditorMediumMaxHeight)
                    .padding(DesignTokens.spacingIconic)
                    
                    .help(WenshuI18n.t("b5.booksettingconstraintsview.l371.h65632517"))
                VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                    Button {
                        Task { await runCheck() }
                    } label: {
                        Label { Text(WenshuI18n.t("b5.booksettingconstraintsview.l376.h23587784")) } icon: { SFIcon("magnifyingglass", style: .inlineSmall, color: IconColor.tint) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(chapterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.constraints.isEmpty)
                    .help(WenshuI18n.t("b5.booksettingconstraintsview.l380.h7773239"))
                    if hasChecked {
                        Text("\(state.violations.count) violation\(state.violations.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(state.violations.isEmpty ? .green : .orange)
                    }
                }
            }
            if hasChecked {
                if state.violations.isEmpty {
                    Text(WenshuI18n.t("b5.booksettingconstraintsview.l390.h74566260"))
                        .font(.caption)
                        .foregroundStyle(DesignTokens.statusForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(state.violations) { violation in
                        violationRow(violation)
                    }
                }
            }
        }
    }

    private func violationRow(_ violation: ConstraintViolation) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingTight) {
            SFIcon(violation.severity == .hard ? "octagon" : "exclamationmark.triangle",
                   style: .inlineSmall,
                   color: violation.severity == .hard ? IconColor.red : IconColor.orange)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: DesignTokens.spacingIconic) {
                    Text(violation.title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Text(WenshuI18n.t("b5.booksettingconstraintsview.l416.h60886424"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let _ = violation.lineNumber {
                        Text(WenshuI18n.t("b5.booksettingconstraintsview.l420.h37146244"))
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.statusForeground)
                    }
                }
                Text("matched \"\"\" \(violation.matchedText) \"\"\"")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(violation.suggestion)
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.statusForeground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, DesignTokens.spacingCaption)
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
        guard activeBookId != nil else { return }
        state.status = .loading
        let actor = ensureTracker()
        let result = await BookSettingConstraintsOps.reload(
            manager: actor,
            bookId: activeBookId
        )
        state.constraints = result.constraints
        if let err = result.error {
            state.errorText = err
            state.status = .failed(err)
        } else if result.didLoad {
            state.status = .loaded
        } else {
            state.status = .idle
        }
    }

    private func addConstraint() async {
        guard activeBookId != nil else { return }
        let actor = ensureTracker()
        let resolvedAppliesTo: UUID? = draftScope.supportsAppliesTo ? resolveAppliesToUUID() : nil
        let result = await BookSettingConstraintsOps.addConstraint(
            manager: actor,
            bookId: activeBookId,
            title: draftTitle,
            description: draftDescription,
            severity: draftSeverity,
            scope: draftScope,
            appliesToId: resolvedAppliesTo,
            forbiddenPatterns: parsePatterns()
        )
        if result.didSave {
            draftTitle = ""
            draftDescription = ""
            draftAppliesToText = ""
            draftPatternsText = ""
            await reload()
        } else if let err = result.error {
            state.errorText = err
        }
    }

    private func removeConstraint(_ constraint: BookSettingConstraint) async {
        let actor = ensureTracker()
        let result = await BookSettingConstraintsOps.removeConstraint(
            manager: actor,
            constraint: constraint
        )
        if result.didSave {
            await reload()
        } else if let err = result.error {
            state.errorText = err
        }
    }

    private func runCheck() async {
        guard activeBookId != nil else { return }
        let actor = ensureTracker()
        let result = await BookSettingConstraintsOps.runCheck(
            manager: actor,
            bookId: activeBookId,
            chapterText: chapterText
        )
        state.violations = result.violations
        hasChecked = result.didRun
        if let err = result.error {
            state.errorText = err
        }
    }
}
