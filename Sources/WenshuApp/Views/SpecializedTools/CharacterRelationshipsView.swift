//
//  CharacterRelationshipsView.swift · Wenshu · P1 ticket #12 (WIRE-SPECIALIZEDTOOLS-006, 2026-09-04)
//
//  SpecializedTools pane tab 8: Character Relationships.
//
//  Per the v0.30 boss 2026-08-30 OOB pattern (= ForeshadowingView +
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
//  `books/<bookId>/character-relationships.json`).
//
//  Character picker source: `bookStore.characterStore.loadCharacters()`
//  (= the canonical per-book character list). When the book has
//  no characters yet, the picker rows show "(no characters
//  defined)" and the Add button is disabled.
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
//        live in CharacterRelationshipTools.swift (= public).
//
//  Visual-gate (boss 2026-09-03 auto-pilot rule): this commit
//  ADDS an 8th tab to the specializedTools pane. Boss acceptance
//  required: open SpecializedTools pane, click the new
//  Character-Relationships tab, add an edge between two
//  characters, see the row in the list + (when applicable) the
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

    @State private var relationships: [CharacterRelationship] = []
    @State private var inconsistencies: [RelationshipInconsistency] = []
    @State private var characters: [Character] = []

    // Add-row picker state.
    @State private var draftFromId: UUID?
    @State private var draftToId: UUID?
    @State private var draftKind: RelationshipKind = .ally
    @State private var draftDescription: String = ""

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
            LucideIconSystemFallback("users", size: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Character Relationships")
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
            return "Track how the characters in the active book relate to each other."
        case .loading:
            return "Loading…"
        case .loaded:
            let count = relationships.count
            let issueCount = inconsistencies.count
            if issueCount > 0 {
                return "\(count) relationship\(count == 1 ? "" : "s"), \(issueCount) inconsistency\(issueCount == 1 ? "" : "ies")"
            }
            return "\(count) relationship\(count == 1 ? "" : "s")"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No book selected")
                .font(.callout)
                .foregroundStyle(.primary)
            Text("Pick a book from the sidebar to start tracking character relationships.")
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
            inconsistenciesSection
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
            Text("Add relationship")
                .font(.callout)
                .foregroundStyle(.primary)
            if characters.count < 2 {
                Text("Define at least 2 characters in the Characters pane to add a relationship.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 8) {
                Picker("From", selection: Binding(
                    get: { draftFromId ?? characters.first?.id ?? UUID() },
                    set: { draftFromId = $0 }
                )) {
                    Text("(choose)").tag(UUID())
                    ForEach(characters) { c in
                        Text(c.name).tag(c.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(characters.isEmpty)

                LucideIconSystemFallback("arrow-right", size: 14)
                    .foregroundStyle(.tertiary)

                Picker("To", selection: Binding(
                    get: { draftToId ?? characters.dropFirst().first?.id ?? UUID() },
                    set: { draftToId = $0 }
                )) {
                    Text("(choose)").tag(UUID())
                    ForEach(characters) { c in
                        Text(c.name).tag(c.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(characters.isEmpty)

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
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
                .help("Add a typed edge between the two selected characters.")
            }
            TextField("Optional 1-sentence context", text: $draftDescription, axis: .horizontal)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .disabled(characters.count < 2)
        }
    }

    private var canAdd: Bool {
        guard let from = draftFromId, let to = draftToId else { return false }
        guard from != UUID(), to != UUID() else { return false }
        return from != to
    }

    // MARK: - List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Relationships (\(relationships.count))")
                .font(.callout)
                .foregroundStyle(.primary)
            if relationships.isEmpty {
                Text("(none yet — add the first one above)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(relationships) { row in
                            relationshipRow(row)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func relationshipRow(_ row: CharacterRelationship) -> some View {
        HStack(alignment: .top, spacing: 8) {
            LucideIconSystemFallback(row.kind.lucideIcon, size: 16)
                .foregroundStyle(.tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(characterName(for: row.fromCharacterId))
                        .font(.callout)
                        .foregroundStyle(.primary)
                    LucideIconSystemFallback("arrow-right", size: 10)
                        .foregroundStyle(.tertiary)
                    Text(characterName(for: row.toCharacterId))
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(row.kind.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary)
                        )
                    if row.isMutual {
                        Text("mutual")
                            .font(.caption2)
                            .foregroundStyle(Color(nsColor: .systemBlue))
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
                LucideIconSystemFallback("trash-2", size: 14)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove this relationship.")
        }
        .padding(.vertical, DesignTokens.chromePaddingSmall)
        .padding(.horizontal, DesignTokens.chromePaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary.opacity(0.5))
        )
    }

    // MARK: - Inconsistencies

    private var inconsistenciesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Inconsistencies (\(inconsistencies.count))")
                .font(.callout)
                .foregroundStyle(.primary)
            if inconsistencies.isEmpty {
                Text("(none — every pair has a consistent kind)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(inconsistencies.enumerated()), id: \.offset) { _, issue in
                    HStack(alignment: .top, spacing: 6) {
                        LucideIconSystemFallback("alert-triangle", size: 14)
                            .foregroundStyle(Color(nsColor: .systemOrange))
                            .frame(width: 18)
                        Text(issue.message)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Helpers

    private func characterName(for id: UUID) -> String {
        characters.first { $0.id == id }?.name ?? id.uuidString.prefix(8) + "…"
    }

    // MARK: - Async actions

    private func ensureTracker() -> CharacterRelationshipTracker {
        if let tracker { return tracker }
        let new = CharacterRelationshipTracker(bookStore: bookStore)
        tracker = new
        return new
    }

    private func reload() async {
        guard let bookId = activeBookId else { return }
        status = .loading
        let actor = ensureTracker()
        // Load characters from the per-book character store
        // (= single source of truth for character metadata).
        // Forgiving on missing / corrupt store: empty array.
        characters = (try? bookStore.characterStore.loadCharacters()) ?? []
        // Reset picker defaults to the first / second character
        // (= convenience for empty state).
        if draftFromId == nil { draftFromId = characters.first?.id }
        if draftToId == nil { draftToId = characters.dropFirst().first?.id }
        do {
            relationships = try await actor.list(bookId: bookId)
            inconsistencies = try await actor.inconsistencies(bookId: bookId)
            status = .loaded
        } catch {
            errorText = error.localizedDescription
            status = .failed(error.localizedDescription)
        }
    }

    private func addRelationship() async {
        guard let bookId = activeBookId,
              let from = draftFromId,
              let to = draftToId,
              from != to else { return }
        let actor = ensureTracker()
        let row = CharacterRelationship(
            bookId: bookId,
            fromCharacterId: from,
            toCharacterId: to,
            kind: draftKind,
            description: draftDescription
        )
        do {
            try await actor.add(row)
            draftDescription = ""
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func removeRelationship(_ row: CharacterRelationship) async {
        guard let bookId = activeBookId else { return }
        let actor = ensureTracker()
        do {
            try await actor.remove(id: row.id, from: bookId)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }
}