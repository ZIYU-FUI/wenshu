//
//  TagManagerView.swift · Wenshu · P1 ticket #14 (WIRE-SPECIALIZEDTOOLS-008, 2026-09-04)
//
//  SpecializedTools pane tab 10: Tag Manager.
//
//  PlaceholderView + LongFormGuardrailsView + ReaderExperienceView +
//  PlotThreadView + GenreFitView + EmotionCurveView +
//  CharacterRelationshipsView + CharacterLifecycleView = 9 tabs in
//  the specializedTools pane), this view is the REAL implementation
//  for the Tag Manager tab (= the 10th tab). Renders:
//
//    - Top header (= icon + tab title + book + tag count +
//      application count).
//    - "Add tag" row (= label TextField + category picker + add
//      button).
//    - Tags list (= one row per tag; shows category badge + label
//      + application count + remove button).
//    - "Apply tag" row (= tag picker + target picker + entity-id
//      TextField + apply button).
//    - Applications list (= one row per application; shows the
//      tag label + target kind + target-id fragment + unapply
//      button).
//    - Tag state.cloud (= one row per tag with at least one application,
//      sorted by count descending).
//    - Filter section (= tag picker + target picker + result
//      list of matching entity ids).
//
//  State source: `TagManager` actor (= owned per-book, persisted
//  via per-book JSON sidecar at `books/<bookId>/state.tags.json`).
//
//  Entity picker source: a free-form UUID TextField for the
//  target id (= consistent with how CharacterLifecycleView treats
//  `chapterId` and how CharacterRelationshipsView treats
//  `establishedInChapterId`; wenshu does not yet have first-class
//  `Scene` / `Chapter` / `PlotThread` domain types with id
//  pickers, so a free-form UUID is the least-surprising input).
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
//        live in TagManagerTools.swift (= public).
//
//  Visual-gate (boss 2026-09-03 auto-pilot rule): this commit
//  ADDS a 10th tab to the specializedTools pane. Boss acceptance
//  required: open SpecializedTools pane, click the new
//  Tag-Manager tab, add a tag, apply it to an entity (chapter /
//  character / scene / plot-thread), see the row in the
//  state.applications list + the tag state.cloud + the filter result.
//

import SwiftUI

/// SpecializedTools pane tab 10: Tag Manager.
///
/// Reads the active bookId from `BookStore.selectedBookId`. If
/// no book is selected, renders the empty-state (= "no book
/// selected" hint, matching the ForeshadowingView no-content
/// pattern).
@MainActor
struct TagManagerView: View {

    @Environment(BookStore.self) private var bookStore

    /// Active book id (= drives the actor's per-book scope).
    private var activeBookId: UUID? { bookStore.selectedBookId }

    /// Actor (= created lazily for the current book; held as
    /// @State so SwiftUI keeps the identity across re-renders).
    @State private var manager: TagManager?

    /// Business state mirror (= state.tags + state.applications + state.cloud +
    /// state.filterMatches + status + state.errorText). Form drafts stay on the
    /// View per §11.3.
    @State private var state = TagManagerViewState()

    // Add-tag picker state.
    @State private var draftLabel: String = ""
    @State private var draftCategory: TagCategory = .theme

    // Apply-tag picker state.
    @State private var draftApplyTagId: UUID?
    @State private var draftApplyTarget: TagTarget = .chapter
    @State private var draftApplyTargetIdText: String = ""

    // Filter state.
    @State private var draftFilterTagId: UUID?
    @State private var draftFilterTarget: TagTarget = .chapter



    init() {}

    var body: some View {
        // C3.7.2: migrate to specializedToolBody modifier (= extracted by
        // C3.7.1; = the canonical chromePadding + if/else pattern now lives
        // in a single modifier instead of being repeated verbatim across the
        // 6 SpecializedTools files).
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
        // -m1-shell boss 2026-09-12 OOB 'the current empty state isn't
        // a single component — can you abstract a UI component? While you're at it, on the
        // empty-state icon: double the size and use the thinnest strokes. The goal is to unify all
        // empty-state styles. The right column has 12 tabs and many are missing an empty state': use
        // the unified EmptyStateView component (= 76 PT SF Symbols 6 icon + .regular weight = the canonical macOS 27 inspector icon weight; = standard
        // title/body hierarchy). Same visual treatment as every
        // other empty state in the workspace.
        EmptyStateView(
            icon: "tag",
            title: WenshuI18n.t("b5.tagmanagerview.l162.h82459098"),
            body: WenshuI18n.t("b5.tagmanagerview.l165.h1104135")
        )
    }


    // MARK: - Body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            addTagRow
            Divider()
            tagsListSection
            Divider()
            applyRow
            applicationsSection
            Divider()
            cloudSection
            Divider()
            filterSection
            Spacer(minLength: 0)
            if let errorText = state.errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Add-tag row

    private var addTagRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            Text(WenshuI18n.t("b5.tagmanagerview.l199.h92873556"))
                .font(.callout)
                .foregroundStyle(.primary)
            HStack(spacing: DesignTokens.spacingStandard) {
                TextField(WenshuI18n.t("b5.tagmanagerview.l203.h87808991"), text: $draftLabel, axis: .horizontal)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .help(WenshuI18n.t("b5.tagmanagerview.l206.h48887491"))
                Picker("Category", selection: $draftCategory) {
                    ForEach(TagCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.icon)
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer(minLength: 0)
                Button {
                    Task { await addTag() }
                } label: {
                    Label { Text(WenshuI18n.t("b5.tagmanagerview.l219.h42031648")) } icon: { SFIcon("plus", style: .inlineSmall, color: IconColor.tint) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAddTag)
                .help(WenshuI18n.t("b5.tagmanagerview.l223.h5074077"))
            }
        }
    }

    private var canAddTag: Bool {
        !draftLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Tags list

    private var tagsListSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(WenshuI18n.t("b5.tagmanagerview.l236.h12934415"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.tags.isEmpty {
                Text(WenshuI18n.t("b5.tagmanagerview.l240.h97833218"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                        ForEach(state.tags) { tag in
                            tagRow(tag)
                        }
                    }
                }
                .frame(maxHeight: DesignTokens.textEditorSmallMaxHeight)
            }
        }
    }

    private func tagRow(_ tag: Tag) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingStandard) {
            SFIcon(tag.category.icon, style: .inlineSmall, color: IconColor.tint)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.spacingTight) {
                    Text(tag.label)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(tag.category.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.spacingTight)
                        .padding(.vertical, DesignTokens.spacingHairline)
                        
                    let appCount = state.applications.filter { $0.tagId == tag.id }.count
                    if appCount > 0 {
                        Text(WenshuI18n.t("b5.tagmanagerview.l278.h7057400"))
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.statusForeground)
                    }
                }
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                Task { await removeTag(tag) }
            } label: {
                SFIcon("trash", style: .inlineSmall, color: IconColor.secondary)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(WenshuI18n.t("b5.tagmanagerview.l292.h29196125"))
        }
        .padding(.vertical, DesignTokens.spacingTight)
        .padding(.horizontal, DesignTokens.spacingStandard)
        .frame(maxWidth: .infinity, alignment: .leading)
        
    }

    // MARK: - Apply row

    private var applyRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            Text(WenshuI18n.t("b5.tagmanagerview.l307.h96892915"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.tags.isEmpty {
                Text(WenshuI18n.t("b5.tagmanagerview.l311.h83311017"))
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.statusForeground)
            }
            HStack(spacing: DesignTokens.spacingStandard) {
                Picker("Tag", selection: Binding(
                    get: { draftApplyTagId ?? state.tags.first?.id ?? UUID() },
                    set: { draftApplyTagId = $0 }
                )) {
                    Text(WenshuI18n.t("b5.tagmanagerview.l320.h7801028")).tag(UUID())
                    ForEach(state.tags) { tag in
                        Text(WenshuI18n.t("b5.tagmanagerview.l322.h1349617")).tag(tag.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(state.tags.isEmpty)

                Picker("Target", selection: $draftApplyTarget) {
                    ForEach(TagTarget.allCases) { target in
                        Label(target.displayName, systemImage: target.icon)
                            .tag(target)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                TextField(WenshuI18n.t("b5.tagmanagerview.l338.h98581825"), text: $draftApplyTargetIdText, axis: .horizontal)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .help(WenshuI18n.t("b5.tagmanagerview.l341.h77687966"))

                Spacer(minLength: 0)

                Button {
                    Task { await applyTag() }
                } label: {
                    Label { Text(WenshuI18n.t("b5.tagmanagerview.l348.h96054186")) } icon: { SFIcon("link", style: .inlineSmall, color: IconColor.tint) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canApply)
                .help(WenshuI18n.t("b5.tagmanagerview.l352.h54731122"))
            }
        }
    }

    private var canApply: Bool {
        guard let tagId = draftApplyTagId, tagId != UUID() else { return false }
        guard state.tags.contains(where: { $0.id == tagId }) else { return false }
        guard UUID(uuidString: draftApplyTargetIdText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil else { return false }
        return true
    }

    // MARK: - Applications

    private var applicationsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(WenshuI18n.t("b5.tagmanagerview.l368.h75731289"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.applications.isEmpty {
                Text(WenshuI18n.t("b5.tagmanagerview.l372.h9838641"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
                        ForEach(state.applications) { application in
                            applicationRow(application)
                        }
                    }
                }
                .frame(maxHeight: DesignTokens.textEditorSmallMaxHeight)
            }
        }
    }

    private func applicationRow(_ application: TagApplication) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingTight) {
            SFIcon(application.target.icon, style: .inlineSmall, color: IconColor.tint)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: DesignTokens.spacingTight) {
                    Text(tagLabel(for: application.tagId))
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Text(application.target.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.spacingIconic)
                        .padding(.vertical, DesignTokens.spacingHairline)
                        
                    Text(WenshuI18n.t("b5.tagmanagerview.l408.h8961516"))
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.statusForeground)
                }
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                Task { await unapply(application) }
            } label: {
                SFIcon("xmark", style: .inlineSmall, color: IconColor.secondary)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(WenshuI18n.t("b5.tagmanagerview.l421.h66833572"))
        }
        .padding(.vertical, DesignTokens.spacingCaption)
    }

    // MARK: - Tag state.cloud

    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(WenshuI18n.t("b5.tagmanagerview.l430.h82273461"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.cloud.isEmpty {
                Text(WenshuI18n.t("b5.tagmanagerview.l434.h60440302"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
                        ForEach(state.cloud) { entry in
                            cloudRow(entry)
                        }
                    }
                }
                .frame(maxHeight: DesignTokens.textEditorCompactMaxHeight)
            }
        }
    }

    private func cloudRow(_ entry: TagCloudEntry) -> some View {
        HStack(spacing: DesignTokens.spacingTight) {
            SFIcon(entry.tag.category.icon, style: .inlineSmall, color: IconColor.tint)
            Text(entry.tag.label)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text(WenshuI18n.t("b5.tagmanagerview.l460.h65001910"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignTokens.spacingTight)
                .padding(.vertical, DesignTokens.spacingHairline)
                
        }
        .padding(.vertical, DesignTokens.spacingCaption)
    }

    // MARK: - Filter

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            Text(WenshuI18n.t("b5.tagmanagerview.l477.h41034022"))
                .font(.callout)
                .foregroundStyle(.primary)
            if state.tags.isEmpty {
                Text(WenshuI18n.t("b5.tagmanagerview.l481.h78063039"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
            } else {
                HStack(spacing: DesignTokens.spacingStandard) {
                    Picker("Tag", selection: Binding(
                        get: { draftFilterTagId ?? state.tags.first?.id ?? UUID() },
                        set: { draftFilterTagId = $0 }
                    )) {
                        Text(WenshuI18n.t("b5.tagmanagerview.l490.h54878954")).tag(UUID())
                        ForEach(state.tags) { tag in
                            Text(WenshuI18n.t("b5.tagmanagerview.l492.h77758122")).tag(tag.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: draftFilterTagId) { _, _ in
                        Task { await runFilter() }
                    }

                    Picker("Target", selection: $draftFilterTarget) {
                        ForEach(TagTarget.allCases) { target in
                            Label(target.displayName, systemImage: target.icon)
                                .tag(target)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: draftFilterTarget) { _, _ in
                        Task { await runFilter() }
                    }

                    Spacer(minLength: 0)
                }
                if state.filterMatches.isEmpty {
                    Text(WenshuI18n.t("b5.tagmanagerview.l516.h78857770"))
                        .font(.caption)
                        .foregroundStyle(DesignTokens.statusForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(state.filterMatches.enumerated()), id: \.offset) { _, id in
                            HStack(spacing: DesignTokens.spacingTight) {
                                SFIcon(draftFilterTarget.icon, style: .inlineSmall, color: IconColor.tint)
                                Text(id.uuidString)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .padding(.vertical, DesignTokens.spacingCaption)
                }
            }
        }
    }

    // MARK: - Helpers (= view-only glue: calls TagManagerOps, assigns @State)

    private func tagLabel(for tagId: UUID) -> String {
        state.tags.first { $0.id == tagId }?.label ?? tagId.uuidString.prefix(8) + "…"
    }

    /// Lazily construct (= or fetch) the `TagManager` actor for the
    /// active book (= held in @State so SwiftUI keeps the identity
    /// across re-renders).
    private func ensureManager() -> TagManager {
        if let manager { return manager }
        let new = TagManager(bookStore: bookStore)
        manager = new
        return new
    }

    private func reload() async {
        guard activeBookId != nil else { return }
        state.status = .loading
        let actor = ensureManager()
        let result = await TagManagerOps.reload(manager: actor, bookId: activeBookId)
        state.tags = result.tags
        state.applications = result.applications
        state.cloud = result.cloud
        // Default pickers to the first tag (when any).
        if draftApplyTagId == nil { draftApplyTagId = state.tags.first?.id }
        if draftFilterTagId == nil { draftFilterTagId = state.tags.first?.id }
        if let error = result.error {
            state.errorText = error
            state.status = .failed(error)
        } else {
            state.status = .loaded
        }
        await runFilter()
    }

    private func runFilter() async {
        guard manager != nil else {
            state.filterMatches = []
            return
        }
        let actor = ensureManager()
        let result = await TagManagerOps.runFilter(
            manager: actor,
            bookId: activeBookId,
            tagId: draftFilterTagId,
            target: draftFilterTarget
        )
        state.filterMatches = result.matches
        if let error = result.error { state.errorText = error }
    }

    private func addTag() async {
        guard activeBookId != nil else { return }
        let actor = ensureManager()
        let result = await TagManagerOps.addTag(
            manager: actor,
            bookId: activeBookId,
            label: draftLabel,
            category: draftCategory
        )
        if result.didSave {
            // SwiftUI-side reset (= inline-create TextField clears on
            // successful save; = a binding reset, NOT a business
            // rule, = stays in the view per ADR-0009).
            draftLabel = ""
        }
        if let error = result.error { state.errorText = error }
        await reload()
    }

    private func removeTag(_ tag: Tag) async {
        let actor = ensureManager()
        let result = await TagManagerOps.removeTag(manager: actor, tag: tag)
        if let error = result.error { state.errorText = error }
        await reload()
    }

    private func applyTag() async {
        guard activeBookId != nil else { return }
        let actor = ensureManager()
        let result = await TagManagerOps.applyTag(
            manager: actor,
            bookId: activeBookId,
            tagId: draftApplyTagId,
            target: draftApplyTarget,
            targetIdText: draftApplyTargetIdText
        )
        if result.didSave {
            draftApplyTargetIdText = ""
        }
        if let error = result.error { state.errorText = error }
        await reload()
    }

    private func unapply(_ application: TagApplication) async {
        let actor = ensureManager()
        let result = await TagManagerOps.unapply(manager: actor, application: application)
        if let error = result.error { state.errorText = error }
        await reload()
    }
}
