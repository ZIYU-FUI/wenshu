//
//  CharacterLifecycleView.swift
//
//  SpecializedTools pane tab 9: Character Lifecycle.
//
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
//  no state.characters yet, the picker rows show "(no state.characters
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
//        live in CharacterLifecycleTools.swift (= public).
//
//  Visual-gate ((see OOB.md #2026-09-03) auto-pilot rule): this commit
//  ADDS a 9th tab to the specializedTools pane. The acceptance
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

    /// Business state mirror (= state.events + state.contradictions +
    /// state.characters + state.timelineRows + status + errorText). Form
    /// picker + input drafts stay on the View per §11.3.
    @State private var state = CharacterLifecycleViewState()

    /// Selected character for the timeline section (= nil = no
    /// timeline shown).
    @State private var selectedCharacterId: UUID?

    // Add-row picker state.
    @State private var draftCharacterId: UUID?
    @State private var draftStage: LifecycleStage = .introduced
    @State private var draftChapterUUIDText: String = ""
    @State private var draftExcerpt: String = ""



    init() {}

    var body: some View {
        // C3.7.3: migrate to specializedToolBody modifier
        // (= see SpecializedToolBodyModifier.swift; = extracted by C3.7.1
        // and adopted by TagManagerView in C3.7.2).
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
            icon: "clock",
            title: WenshuI18n.t("b5.characterlifecycleview.l168.h1439622"),
            body: WenshuI18n.t("b5.characterlifecycleview.l171.h40676736")
        )
    }


    // MARK: - Body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            addRow
            Divider()
            listSection
            timelineSection
            contradictionsSection
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
            Text(WenshuI18n.t("b5.characterlifecycleview.l200.h38389147"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.characters.isEmpty {
                Text(WenshuI18n.t("b5.characterlifecycleview.l204.h79350323"))
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.statusForeground)
            }
            HStack(spacing: DesignTokens.spacingStandard) {
                Picker(WenshuI18n.t("picker.character"), selection: Binding(
                    get: { draftCharacterId ?? state.characters.first?.id ?? UUID() },
                    set: { draftCharacterId = $0 }
                )) {
                    Text(WenshuI18n.t("b5.characterlifecycleview.l213.h31260689")).tag(UUID())
                    ForEach(state.characters) { c in
                        Text(c.name).tag(c.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(state.characters.isEmpty)

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
                    Label { Text(WenshuI18n.t("b5.characterlifecycleview.l235.h51075723")) } icon: { SFIcon("plus", style: .inlineSmall, color: IconColor.tint) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
                .help(WenshuI18n.t("b5.characterlifecycleview.l239.h26593030"))
            }
            HStack(spacing: DesignTokens.spacingStandard) {
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
        return state.characters.contains(where: { $0.id == characterId })
    }

    // MARK: - List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(WenshuI18n.t("b5.characterlifecycleview.l263.h29792914"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.events.isEmpty {
                Text(WenshuI18n.t("b5.characterlifecycleview.l267.h43318691"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                        ForEach(state.events) { event in
                            eventRow(event)
                        }
                    }
                }
                .frame(maxHeight: DesignTokens.panelMediumMaxHeight)
            }
        }
    }

    private func eventRow(_ event: LifecycleEvent) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingStandard) {
            SFIcon(event.stage.icon, style: .inlineSmall, color: IconColor.tint)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.spacingTight) {
                    Text(characterName(for: event.characterId))
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(event.stage.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.spacingTight)
                        .padding(.vertical, DesignTokens.spacingHairline)
                        
                    if let _ = event.chapterId {
                        Text(WenshuI18n.t("b5.characterlifecycleview.l304.h73934719"))
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.statusForeground)
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
                SFIcon("trash", style: .inlineSmall, color: IconColor.secondary)
            }
            .buttonStyle(.borderless)
            .help(WenshuI18n.t("b5.characterlifecycleview.l324.h5673239"))
        }
        .padding(.vertical, DesignTokens.spacingTight)
        .padding(.horizontal, DesignTokens.spacingStandard)
        .frame(maxWidth: .infinity, alignment: .leading)
        
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(WenshuI18n.t("b5.characterlifecycleview.l339.h16422962"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.characters.isEmpty {
                Text(WenshuI18n.t("b5.characterlifecycleview.l343.h47112699"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: DesignTokens.spacingStandard) {
                    Picker("Character", selection: Binding(
                        get: { selectedCharacterId ?? state.characters.first?.id ?? UUID() },
                        set: { selectedCharacterId = $0 }
                    )) {
                        Text(WenshuI18n.t("b5.characterlifecycleview.l353.h58360186")).tag(UUID())
                        ForEach(state.characters) { c in
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
                if state.timelineRows.isEmpty {
                    Text(WenshuI18n.t("b5.characterlifecycleview.l366.h98560518"))
                        .font(.caption)
                        .foregroundStyle(DesignTokens.statusForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
                            ForEach(state.timelineRows) { event in
                                timelineRow(event)
                            }
                        }
                    }
                    .frame(maxHeight: DesignTokens.textEditorSmallMaxHeight)
                }
            }
        }
    }

    private func timelineRow(_ event: LifecycleEvent) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingTight) {
            SFIcon(event.stage.icon, style: .inlineSmall, color: IconColor.tint)
            Text(event.stage.displayName)
                .font(.caption)
                .foregroundStyle(.primary)
            if let _ = event.chapterId {
                Text(WenshuI18n.t("b5.characterlifecycleview.l393.h77015228"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Contradictions

    private var contradictionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(WenshuI18n.t("b5.characterlifecycleview.l405.h20963905"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.contradictions.isEmpty {
                Text(WenshuI18n.t("b5.characterlifecycleview.l409.h10185050"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(state.contradictions.enumerated()), id: \.offset) { _, issue in
                    HStack(alignment: .top, spacing: DesignTokens.spacingTight) {
                        SFIcon("exclamationmark.triangle", style: .inlineSmall, color: IconColor.orange)
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
                    .padding(.vertical, DesignTokens.spacingCaption)
                }
            }
        }
    }

    // MARK: - Helpers

    private func characterName(for id: UUID) -> String {
        state.characters.first { $0.id == id }?.name ?? id.uuidString.prefix(8) + "…"
    }

    /// Resolve the chapter UUID from the draft text. Returns nil
    /// when the text is empty (= pre-chapter backstory event) or
    /// malformed (= invalid UUID = treated as nil; the writer can
    /// see the row without a chapter anchor rather than getting
    /// an error).
    // (resolveChapterUUID removed 2026-10 in q99-spec-p0-batch2 —
    //  verify-dead.py confirmed 0 external callers; = the private
    //  helper was retained as the "parse a UUID string from
    //  draftChapterUUIDText input" affordance but no body call
    //  site invokes it (= the chapter anchor is set via
    //  CharacterLifecycleOps, not the view's @State binding).
    //  See wenshu-pocock-workflow references/v3.0-design-system-rule.md
    //  + wenshu-dead-code-cleanup SKILL.md.)

    // MARK: - Helpers (= view-only glue: calls CharacterLifecycleOps, assigns @State)

    private func reload() async {
        guard activeBookId != nil else { return }
        state.status = .loading
        let actor = ensureTracker()
        let result = await CharacterLifecycleOps.reload(
            manager: actor,
            bookId: activeBookId,
            bookStore: bookStore
        )
        state.characters = result.characters
        // Default picker selections to the first character (when any).
        if draftCharacterId == nil { draftCharacterId = state.characters.first?.id }
        if selectedCharacterId == nil { selectedCharacterId = state.characters.first?.id }
        state.events = result.events
        state.contradictions = result.contradictions
        if let err = result.error {
            state.errorText = err
            state.status = .failed(err)
        } else if result.didLoad {
            state.status = .loaded
        }
        await reloadTimeline()
    }

    private func reloadTimeline() async {
        let actor = ensureTracker()
        let result = await CharacterLifecycleOps.reloadTimeline(
            manager: actor,
            bookId: activeBookId,
            characterId: selectedCharacterId
        )
        state.timelineRows = result.rows
        if let err = result.error { state.errorText = err }
    }

    private func addEvent() async {
        let actor = ensureTracker()
        let result = await CharacterLifecycleOps.addEvent(
            manager: actor,
            bookId: activeBookId,
            characterId: draftCharacterId,
            stage: draftStage,
            chapterUUIDText: draftChapterUUIDText,
            excerpt: draftExcerpt
        )
        if let err = result.error {
            state.errorText = err
            return
        }
        if result.didSave {
            draftExcerpt = ""
            draftChapterUUIDText = ""
            await reload()
        }
    }

    private func removeEvent(_ event: LifecycleEvent) async {
        let actor = ensureTracker()
        let result = await CharacterLifecycleOps.removeEvent(
            manager: actor,
            event: event
        )
        if let err = result.error {
            state.errorText = err
            return
        }
        if result.didSave {
            await reload()
        }
    }

    /// Returns the actor (= from @State tracker) if constructed; = nil
        /// before the first .task fires. View glue does not construct the
        /// actor (= that happens lazily in the first call site; = Ops
        /// itself takes optional actor per v1.74 TagManagerOps precedent).
        /// Renamed from `ensureManagerOrNil` (= v1.76 spec-fix arc;
    /// = spec §9.2 row 1 lists one helper = `ensureTracker`).
    private func ensureTracker() -> CharacterLifecycleTracker? {
        if let tracker { return tracker }
        // Build it here so the Ops call gets a real actor (= the
        // first call after launch is the one that pays the
        // construction cost; = subsequent calls reuse the @State
        // identity).
        let new = CharacterLifecycleTracker(bookStore: bookStore)
        tracker = new
        return new
    }
}
