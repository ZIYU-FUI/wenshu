//
//  CharacterRelationshipsView.swift
//
//  SpecializedTools pane tab 8: Character Relationships.
//
//  PlaceholderView + LongFormGuardrailsView + ReaderExperienceView +
//  PlotThreadView + GenreFitView + EmotionCurveView = 7 tabs in
//  the specializedTools pane), this view is the REAL
//  implementation for the Character Relationships tab (= the
//  8th tab). Renders:
//
//    - Top header (= icon + tab title + book + character count)
//    - "Add relationship" row (= from-picker + to-picker +
//      kind-picker + description field + add button)
//    - Relationships list (= one row per edge; shows the kind
//      badge + description + mutual flag + remove button)
//    - Inconsistencies section (= the tracker emits one row per
//      pair with conflicting kinds; = the writer-facing gap list)
//
//  State source: `CharacterRelationshipTracker` actor (= owned
//  per-book, persisted via per-book JSON sidecar at
//  `books/<bookId>/character-state.relationships.json`).
//
//  Character picker source: `bookStore.characterStore.loadCharacters()`
//  (= the canonical per-book character list). When the book has
//  no state.characters yet, the picker rows show "(no state.characters
//  defined)" and the Add button is disabled.
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
//        live in CharacterRelationshipTools.swift (= public).
//
//  Visual-gate ((see OOB.md #2026-09-03) auto-pilot rule): this commit
//  ADDS an 8th tab to the specializedTools pane. The acceptance
//  required: open SpecializedTools pane, click the new
//  Character-Relationships tab, add an edge between two
//  state.characters, see the row in the list + (when applicable) the
//  inconsistency warning.
//

import SwiftUI

/// SpecializedTools pane tab 8: Character Relationships.
///
/// Reads the active bookId from `BookStore.selectedBookId`. If
/// no book is selected, renders the empty-state (= "no book
/// selected" hint, matching the ForeshadowingView no-content
/// pattern).
@MainActor
struct CharacterRelationshipsView: View {

    @Environment(BookStore.self) private var bookStore

    /// Active book id (= drives the actor's per-book scope).
    private var activeBookId: UUID? { bookStore.selectedBookId }

    /// Actor (= created lazily for the current book; held as
    /// @State so SwiftUI keeps the identity across re-renders).
    @State private var tracker: CharacterRelationshipTracker?

    /// Business state mirror (= state.relationships + state.inconsistencies +
    /// state.characters + status + errorText). Form picker + input
    /// drafts stay on the View per §11.3.
    @State private var state = CharacterRelationshipsViewState()

    // Add-row picker state.
    @State private var draftFromId: UUID?
    @State private var draftToId: UUID?
    @State private var draftKind: RelationshipKind = .ally
    @State private var draftDescription: String = ""



    init() {}

    var body: some View {
        // C3.7.3: migrate to specializedToolBody modifier
        // (= same modifier adoption as CharacterLifecycleView above).
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
            icon: "person.2",
            title: String(localized: "b5.characterrelationshipsview.l148.h14968122"),
            body: String(localized: "b5.characterrelationshipsview.l151.h23755386")
        )
    }


    // MARK: - Body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            addRow
            Divider()
            listSection
            inconsistenciesSection
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
            Text(String(localized: "b5.characterrelationshipsview.l179.h77944637"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.characters.count < 2 {
                Text(String(localized: "b5.characterrelationshipsview.l183.h86534805"))
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.statusForeground)
            }
            HStack(spacing: DesignTokens.spacingStandard) {
                Picker("From", selection: Binding(
                    get: { draftFromId ?? state.characters.first?.id ?? UUID() },
                    set: { draftFromId = $0 }
                )) {
                    Text(String(localized: "b5.characterrelationshipsview.l192.h15212550")).tag(UUID())
                    ForEach(state.characters) { c in
                        Text(c.name).tag(c.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(state.characters.isEmpty)

                SFIcon("arrow.right", style: .inlineSmall, color: IconColor.tertiary)

                Picker("To", selection: Binding(
                    get: { draftToId ?? state.characters.dropFirst().first?.id ?? UUID() },
                    set: { draftToId = $0 }
                )) {
                    Text(String(localized: "b5.characterrelationshipsview.l208.h39347010")).tag(UUID())
                    ForEach(state.characters) { c in
                        Text(c.name).tag(c.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(state.characters.isEmpty)

                Picker("Kind", selection: $draftKind) {
                    ForEach(RelationshipKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Spacer(minLength: 0)

                Button {
                    Task { await addRelationship() }
                } label: {
                    Label { Text(String(localized: "b5.characterrelationshipsview.l230.h80913925")) } icon: { SFIcon("plus", style: .inlineSmall, color: IconColor.tint) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
                .help(String(localized: "b5.characterrelationshipsview.l234.h8880758"))
            }
            TextField(String(localized: "b5.characterrelationshipsview.l236.h75459793"), text: $draftDescription, axis: .horizontal)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .disabled(state.characters.count < 2)
        }
    }

    private var canAdd: Bool {
        guard let from = draftFromId, let to = draftToId else { return false }
        guard from != UUID(), to != UUID() else { return false }
        return from != to
    }

    // MARK: - List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(String(localized: "b5.characterrelationshipsview.l253.h68099009"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.relationships.isEmpty {
                Text(String(localized: "b5.characterrelationshipsview.l257.h87596331"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                        ForEach(state.relationships) { row in
                            relationshipRow(row)
                        }
                    }
                }
                .frame(maxHeight: DesignTokens.panelLargeMaxHeight)
            }
        }
    }

    private func relationshipRow(_ row: CharacterRelationship) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingStandard) {
            SFIcon(row.kind.icon, style: .inlineSmall, color: IconColor.tint)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.spacingTight) {
                    Text(characterName(for: row.fromCharacterId))
                        .font(.callout)
                        .foregroundStyle(.primary)
                    SFIcon("arrow.right", style: .inlineSmall, color: IconColor.tertiary)
                    Text(characterName(for: row.toCharacterId))
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(row.kind.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.spacingTight)
                        .padding(.vertical, DesignTokens.spacingHairline)
                        
                    if row.isMutual {
                        Text(String(localized: "b5.characterrelationshipsview.l299.h17838183"))
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                if !row.description.isEmpty {
                    Text(row.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                Task { await removeRelationship(row) }
            } label: {
                SFIcon("trash", style: .inlineSmall, color: IconColor.secondary)
            }
            .buttonStyle(.borderless)
            .help(String(localized: "b5.characterrelationshipsview.l319.h19379525"))
        }
        .padding(.vertical, DesignTokens.spacingTight)
        .padding(.horizontal, DesignTokens.spacingStandard)
        .frame(maxWidth: .infinity, alignment: .leading)
        
    }

    // MARK: - Inconsistencies

    private var inconsistenciesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(String(localized: "b5.characterrelationshipsview.l334.h68375167"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.inconsistencies.isEmpty {
                Text(String(localized: "b5.characterrelationshipsview.l338.h51048722"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(state.inconsistencies.enumerated()), id: \.offset) { _, issue in
                    HStack(alignment: .top, spacing: DesignTokens.spacingTight) {
                        SFIcon("exclamationmark.triangle", style: .inlineSmall, color: IconColor.orange)
                        Text(issue.message)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, DesignTokens.spacingCaption)
                }
            }
        }
    }

    // MARK: - Helpers

    private func characterName(for id: UUID) -> String {
        state.characters.first { $0.id == id }?.name ?? id.uuidString.prefix(8) + "…"
    }

    // MARK: - Async actions

    private func ensureTracker() -> CharacterRelationshipTracker {
        if let tracker { return tracker }
        let new = CharacterRelationshipTracker(bookStore: bookStore)
        tracker = new
        return new
    }

    private func reload() async {
        guard activeBookId != nil else { return }
        state.status = .loading
        let actor = ensureTracker()
        // Load state.characters from the per-book character store
        // (= single source of truth for character metadata).
        // Forgiving on missing / corrupt store: empty array.
        state.characters = (try? bookStore.loadCharacters()) ?? []
        // Reset picker defaults to the first / second character
        // (= convenience for empty state).
        if draftFromId == nil { draftFromId = state.characters.first?.id }
        if draftToId == nil { draftToId = state.characters.dropFirst().first?.id }
        let result = await CharacterRelationshipsOps.reload(
            manager: actor,
            bookId: activeBookId
        )
        state.relationships = result.relationships
        state.inconsistencies = result.inconsistencies
        if let err = result.error {
            state.errorText = err
            state.status = .failed(err)
        } else if result.didLoad {
            state.status = .loaded
        }
    }

    private func addRelationship() async {
        let actor = ensureTracker()
        let result = await CharacterRelationshipsOps.addRelationship(
            manager: actor,
            bookId: activeBookId,
            fromCharacterId: draftFromId,
            toCharacterId: draftToId,
            kind: draftKind,
            description: draftDescription
        )
        if result.didSave {
            draftDescription = ""
            await reload()
        } else if let err = result.error {
            state.errorText = err
        }
    }

    private func removeRelationship(_ row: CharacterRelationship) async {
        let actor = ensureTracker()
        let result = await CharacterRelationshipsOps.removeRelationship(
            manager: actor,
            bookId: activeBookId,
            row: row
        )
        if result.didSave {
            await reload()
        } else if let err = result.error {
            state.errorText = err
        }
    }
}
