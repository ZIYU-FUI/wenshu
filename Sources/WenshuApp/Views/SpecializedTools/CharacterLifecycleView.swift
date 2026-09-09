//
//  CharacterLifecycleView.swift · Wenshu · P1 ticket #13 (WIRE-SPECIALIZEDTOOLS-007, 2026-09-04)
//
//  SpecializedTools pane tab 9: Character Lifecycle.
//
//  Per the v0.30 boss 2026-08-30 OOB pattern (= ForeshadowingView +
//  PlaceholderView + LongFormGuardrailsView + ReaderExperienceView +
//  PlotThreadView + GenreFitView + EmotionCurveView +
//  CharacterRelationshipsView = 8 tabs in the specializedTools
//  pane), this view is the REAL implementation for the Character
//  Lifecycle tab (= the 9th tab). Renders:
//
//    - Top header (= icon + tab title + book + event count +
//      contradiction count)
//    - "Add lifecycle event" row (= character picker + stage
//      picker + chapter UUID field + excerpt field + add button)
//    - Events list (= one row per event; shows the stage badge +
//      character label + chapter fragment + excerpt + remove
//      button)
//    - Timeline section (= the chronological event order for
//      the selected character)
//    - Contradictions section (= the tracker emits one row per
//      character with a terminal-stage-then-non-resurrected
//      sequence)
//
//  State source: `CharacterLifecycleTracker` actor (= owned
//  per-book, persisted via per-book JSON sidecar at
//  `books/<bookId>/character-lifecycle.json`).
//
//  Character picker source: `bookStore.characterStore.loadCharacters()`
//  (= the canonical per-book character list). When the book has
//  no characters yet, the picker rows show "(no characters
//  defined)" and the Add button is disabled.
//
//  Chapter picker source: a TextField for an optional chapter
//  UUID (= the wenshu model currently has no first-class
//  `Chapter` domain type; = keeping the picker as a free-form
//  UUID field is consistent with how CharacterRelationshipTracker
//  treats `establishedInChapterId`). Empty input = `chapterId ==
//  nil` (= pre-chapter backstory event).
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
//        live in CharacterLifecycleTools.swift (= public).
//
//  Visual-gate (boss 2026-09-03 auto-pilot rule): this commit
//  ADDS a 9th tab to the specializedTools pane. Boss acceptance
//  required: open SpecializedTools pane, click the new
//  Character-Lifecycle tab, add a lifecycle event for a
//  character, see the row in the list + the timeline + (when
//  applicable) the contradiction warning.
//

import SwiftUI

/// SpecializedTools pane tab 9: Character Lifecycle.
///
/// Reads the active bookId from `BookStore.selectedBookId`. If
/// no book is selected, renders the empty-state (= "no book
/// selected" hint, matching the ForeshadowingView no-content
/// pattern).
@MainActor
struct CharacterLifecycleView: View {

    @Environment(BookStore.self) private var bookStore

    /// Active book id (= drives the actor's per-book scope).
    private var activeBookId: UUID? { bookStore.selectedBookId }

    /// Actor (= created lazily for the current book; held as
    /// @State so SwiftUI keeps the identity across re-renders).
    @State private var tracker: CharacterLifecycleTracker?

    @State private var events: [LifecycleEvent] = []
    @State private var contradictions: [LifecycleContradiction] = []
    @State private var characters: [Character] = []

    /// Selected character for the timeline section (= nil = no
    /// timeline shown).
    @State private var selectedCharacterId: UUID?

    /// Timeline cache for the selected character (= re-loaded
    /// when events or selectedCharacterId change).
    @State private var timelineRows: [LifecycleEvent] = []

    // Add-row picker state.
    @State private var draftCharacterId: UUID?
    @State private var draftStage: LifecycleStage = .introduced
    @State private var draftChapterUUIDText: String = ""
    @State private var draftExcerpt: String = ""

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
        .padding(DesignTokens.chromePaddingMedium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: activeBookId) {
            await reload()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            LucideIconSystemFallback("clock", size: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(WenshuI18n.t("b5.characterlifecycleview.l136.h46926535"))
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
            return "Track the lifecycle of every character across the chapters of the active book."
        case .loading:
            return "Loading…"
        case .loaded:
            let count = events.count
            let issueCount = contradictions.count
            if issueCount > 0 {
                return "\(count) event\(count == 1 ? "" : "s"), \(issueCount) contradiction\(issueCount == 1 ? "" : "s")"
            }
            return "\(count) event\(count == 1 ? "" : "s")"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(WenshuI18n.t("b5.characterlifecycleview.l168.h1439622"))
                .font(.callout)
                .foregroundStyle(.primary)
            Text(WenshuI18n.t("b5.characterlifecycleview.l171.h40676736"))
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
            timelineSection
            contradictionsSection
            Spacer(minLength: 0)
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Color.red)
            }
        }
    }

    // MARK: - Add row

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(WenshuI18n.t("b5.characterlifecycleview.l200.h38389147"))
                .font(.callout)
                .foregroundStyle(.primary)
            if characters.isEmpty {
                Text(WenshuI18n.t("b5.characterlifecycleview.l204.h79350323"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 8) {
                Picker(WenshuI18n.t("picker.character"), selection: Binding(
                    get: { draftCharacterId ?? characters.first?.id ?? UUID() },
                    set: { draftCharacterId = $0 }
                )) {
                    Text(WenshuI18n.t("b5.characterlifecycleview.l213.h31260689")).tag(UUID())
                    ForEach(characters) { c in
                        Text(c.name).tag(c.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(characters.isEmpty)

                Picker("Stage", selection: $draftStage) {
                    ForEach(LifecycleStage.allCases) { stage in
                        Text(stage.displayName).tag(stage)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Spacer(minLength: 0)

                Button {
                    Task { await addEvent() }
                } label: {
                    Label(WenshuI18n.t("b5.characterlifecycleview.l235.h51075723"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
                .help(WenshuI18n.t("b5.characterlifecycleview.l239.h26593030"))
            }
            HStack(spacing: 8) {
                TextField(WenshuI18n.t("b5.characterlifecycleview.l242.h58864975"), text: $draftChapterUUIDText, axis: .horizontal)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .help(WenshuI18n.t("b5.characterlifecycleview.l245.h27116037"))
                TextField(WenshuI18n.t("b5.characterlifecycleview.l246.h53203368"), text: $draftExcerpt, axis: .horizontal)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .help(WenshuI18n.t("b5.characterlifecycleview.l249.h31682361"))
            }
        }
    }

    private var canAdd: Bool {
        guard let characterId = draftCharacterId, characterId != UUID() else { return false }
        return characters.contains(where: { $0.id == characterId })
    }

    // MARK: - List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("b5.characterlifecycleview.l263.h29792914"))
                .font(.callout)
                .foregroundStyle(.primary)
            if events.isEmpty {
                Text(WenshuI18n.t("b5.characterlifecycleview.l267.h43318691"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(events) { event in
                            eventRow(event)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private func eventRow(_ event: LifecycleEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            LucideIconSystemFallback(event.stage.lucideIcon, size: 16)
                .foregroundStyle(.tint)
                .frame(width: DesignTokens.tabIconSize)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(characterName(for: event.characterId))
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(event.stage.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.chromePaddingSmall)
                        .padding(.vertical, DesignTokens.chromePaddingPico)
                        
                    if let cid = event.chapterId {
                        Text(WenshuI18n.t("b5.characterlifecycleview.l304.h73934719"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                if !event.excerpt.isEmpty {
                    Text(event.excerpt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                Task { await removeEvent(event) }
            } label: {
                LucideIconSystemFallback("trash-2", size: 14)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(WenshuI18n.t("b5.characterlifecycleview.l324.h5673239"))
        }
        .padding(.vertical, DesignTokens.chromePaddingSmall)
        .padding(.horizontal, DesignTokens.chromePaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("b5.characterlifecycleview.l339.h16422962"))
                .font(.callout)
                .foregroundStyle(.primary)
            if characters.isEmpty {
                Text(WenshuI18n.t("b5.characterlifecycleview.l343.h47112699"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    Picker("Character", selection: Binding(
                        get: { selectedCharacterId ?? characters.first?.id ?? UUID() },
                        set: { selectedCharacterId = $0 }
                    )) {
                        Text(WenshuI18n.t("b5.characterlifecycleview.l353.h58360186")).tag(UUID())
                        ForEach(characters) { c in
                            Text(c.name).tag(c.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: selectedCharacterId) { _, _ in
                        Task { await reloadTimeline() }
                    }
                    Spacer(minLength: 0)
                }
                if timelineRows.isEmpty {
                    Text(WenshuI18n.t("b5.characterlifecycleview.l366.h98560518"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(timelineRows) { event in
                                timelineRow(event)
                            }
                        }
                    }
                    .frame(maxHeight: 140)
                }
            }
        }
    }

    private func timelineRow(_ event: LifecycleEvent) -> some View {
        HStack(alignment: .top, spacing: 6) {
            LucideIconSystemFallback(event.stage.lucideIcon, size: 12)
                .foregroundStyle(.tint)
                .frame(width: DesignTokens.iconStandardSize)
            Text(event.stage.displayName)
                .font(.caption)
                .foregroundStyle(.primary)
            if let cid = event.chapterId {
                Text(WenshuI18n.t("b5.characterlifecycleview.l393.h77015228"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Contradictions

    private var contradictionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("b5.characterlifecycleview.l405.h20963905"))
                .font(.callout)
                .foregroundStyle(.primary)
            if contradictions.isEmpty {
                Text(WenshuI18n.t("b5.characterlifecycleview.l409.h10185050"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(contradictions.enumerated()), id: \.offset) { _, issue in
                    HStack(alignment: .top, spacing: 6) {
                        LucideIconSystemFallback("alert-triangle", size: 14)
                            .foregroundStyle(Color.orange)
                            .frame(width: DesignTokens.tabIconSize)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(characterName(for: issue.characterId))
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Text(issue.conflictDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, DesignTokens.chromePaddingNano)
                }
            }
        }
    }

    // MARK: - Helpers

    private func characterName(for id: UUID) -> String {
        characters.first { $0.id == id }?.name ?? id.uuidString.prefix(8) + "…"
    }

    /// Resolve the chapter UUID from the draft text. Returns nil
    /// when the text is empty (= pre-chapter backstory event) or
    /// malformed (= invalid UUID = treated as nil; the writer can
    /// see the row without a chapter anchor rather than getting
    /// an error).
    private func resolveChapterUUID() -> UUID? {
        let trimmed = draftChapterUUIDText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return UUID(uuidString: trimmed)
    }

    // MARK: - Async actions

    private func ensureTracker() -> CharacterLifecycleTracker {
        if let tracker { return tracker }
        let new = CharacterLifecycleTracker(bookStore: bookStore)
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
        // Reset picker defaults to the first character.
        if draftCharacterId == nil { draftCharacterId = characters.first?.id }
        if selectedCharacterId == nil { selectedCharacterId = characters.first?.id }
        do {
            events = try await actor.list(bookId: bookId)
            contradictions = try await actor.contradictions(bookId: bookId)
            await reloadTimeline()
            status = .loaded
        } catch {
            errorText = error.localizedDescription
            status = .failed(error.localizedDescription)
        }
    }

    private func reloadTimeline() async {
        guard let bookId = activeBookId,
              let characterId = selectedCharacterId,
              characterId != UUID() else {
            timelineRows = []
            return
        }
        let actor = ensureTracker()
        do {
            timelineRows = try await actor.timeline(bookId: bookId, characterId: characterId)
        } catch {
            errorText = error.localizedDescription
            timelineRows = []
        }
    }

    private func addEvent() async {
        guard let bookId = activeBookId,
              let characterId = draftCharacterId,
              characterId != UUID() else { return }
        let actor = ensureTracker()
        let event = LifecycleEvent(
            bookId: bookId,
            characterId: characterId,
            stage: draftStage,
            chapterId: resolveChapterUUID(),
            excerpt: draftExcerpt
        )
        do {
            try await actor.add(event)
            draftExcerpt = ""
            draftChapterUUIDText = ""
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func removeEvent(_ event: LifecycleEvent) async {
        let actor = ensureTracker()
        do {
            try await actor.remove(id: event.id)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }
}