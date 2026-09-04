//
//  TagManagerView.swift · Wenshu · P1 ticket #14 (WIRE-SPECIALIZEDTOOLS-008, 2026-09-04)
//
//  SpecializedTools pane tab 10: Tag Manager.
//
//  Per the v0.30 boss 2026-08-30 OOB pattern (= ForeshadowingView +
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
//    - Tag cloud (= one row per tag with at least one application,
//      sorted by count descending).
//    - Filter section (= tag picker + target picker + result
//      list of matching entity ids).
//
//  State source: `TagManager` actor (= owned per-book, persisted
//  via per-book JSON sidecar at `books/<bookId>/tags.json`).
//
//  Entity picker source: a free-form UUID TextField for the
//  target id (= consistent with how CharacterLifecycleView treats
//  `chapterId` and how CharacterRelationshipsView treats
//  `establishedInChapterId`; wenshu does not yet have first-class
//  `Scene` / `Chapter` / `PlotThread` domain types with id
//  pickers, so a free-form UUID is the least-surprising input).
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
//        live in TagManagerTools.swift (= public).
//
//  Visual-gate (boss 2026-09-03 auto-pilot rule): this commit
//  ADDS a 10th tab to the specializedTools pane. Boss acceptance
//  required: open SpecializedTools pane, click the new
//  Tag-Manager tab, add a tag, apply it to an entity (chapter /
//  character / scene / plot-thread), see the row in the
//  applications list + the tag cloud + the filter result.
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

    @State private var tags: [Tag] = []
    @State private var applications: [TagApplication] = []
    @State private var cloud: [TagCloudEntry] = []

    // Add-tag picker state.
    @State private var draftLabel: String = ""
    @State private var draftCategory: TagCategory = .theme

    // Apply-tag picker state.
    @State private var draftApplyTagId: UUID?
    @State private var draftApplyTarget: TagTarget = .chapter
    @State private var draftApplyTargetIdText: String = ""

    // Filter picker state.
    @State private var draftFilterTagId: UUID?
    @State private var draftFilterTarget: TagTarget = .chapter
    @State private var filterMatches: [UUID] = []

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
            LucideIconSystemFallback("tag", size: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tag Manager")
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
            return "Define tags across the active book and apply them to chapters / characters / scenes / plot threads."
        case .loading:
            return "Loading…"
        case .loaded:
            let tagCount = tags.count
            let appCount = applications.count
            return "\(tagCount) tag\(tagCount == 1 ? "" : "s"), \(appCount) application\(appCount == 1 ? "" : "s")"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No book selected")
                .font(.callout)
                .foregroundStyle(.primary)
            Text("Pick a book from the sidebar to start managing tags.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
        }
    }

    // MARK: - Add-tag row

    private var addTagRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add tag")
                .font(.callout)
                .foregroundStyle(.primary)
            HStack(spacing: 8) {
                TextField("Label (e.g. redemption)", text: $draftLabel, axis: .horizontal)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .help("Short, human-readable label for the tag. Whitespace is trimmed.")
                Picker("Category", selection: $draftCategory) {
                    ForEach(TagCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.lucideIcon)
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer(minLength: 0)
                Button {
                    Task { await addTag() }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAddTag)
                .help("Add a new tag with the supplied label + category.")
            }
        }
    }

    private var canAddTag: Bool {
        !draftLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Tags list

    private var tagsListSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tags (\(tags.count))")
                .font(.callout)
                .foregroundStyle(.primary)
            if tags.isEmpty {
                Text("(none yet — add the first one above)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(tags) { tag in
                            tagRow(tag)
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
        }
    }

    private func tagRow(_ tag: Tag) -> some View {
        HStack(alignment: .top, spacing: 8) {
            LucideIconSystemFallback(tag.category.lucideIcon, size: 16)
                .foregroundStyle(.tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tag.label)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(tag.category.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary)
                        )
                    let appCount = applications.filter { $0.tagId == tag.id }.count
                    if appCount > 0 {
                        Text("\(appCount)× applied")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                Task { await removeTag(tag) }
            } label: {
                LucideIconSystemFallback("trash-2", size: 14)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove this tag and cascade-delete its applications.")
        }
        .padding(.vertical, DesignTokens.chromePaddingSmall)
        .padding(.horizontal, DesignTokens.chromePaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary.opacity(0.5))
        )
    }

    // MARK: - Apply row

    private var applyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Apply tag to entity")
                .font(.callout)
                .foregroundStyle(.primary)
            if tags.isEmpty {
                Text("Define at least 1 tag above before applying one.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 8) {
                Picker("Tag", selection: Binding(
                    get: { draftApplyTagId ?? tags.first?.id ?? UUID() },
                    set: { draftApplyTagId = $0 }
                )) {
                    Text("(choose)").tag(UUID())
                    ForEach(tags) { tag in
                        Text("\(tag.label) (\(tag.category.displayName))").tag(tag.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(tags.isEmpty)

                Picker("Target", selection: $draftApplyTarget) {
                    ForEach(TagTarget.allCases) { target in
                        Label(target.displayName, systemImage: target.lucideIcon)
                            .tag(target)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                TextField("Entity UUID", text: $draftApplyTargetIdText, axis: .horizontal)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .help("UUID of the entity to attach the tag to. Leave empty to disable Apply.")

                Spacer(minLength: 0)

                Button {
                    Task { await applyTag() }
                } label: {
                    Label("Apply", systemImage: "link")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canApply)
                .help("Record an application of the chosen tag to the chosen entity.")
            }
        }
    }

    private var canApply: Bool {
        guard let tagId = draftApplyTagId, tagId != UUID() else { return false }
        guard tags.contains(where: { $0.id == tagId }) else { return false }
        guard let targetId = UUID(uuidString: draftApplyTargetIdText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return true
    }

    // MARK: - Applications

    private var applicationsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Applications (\(applications.count))")
                .font(.callout)
                .foregroundStyle(.primary)
            if applications.isEmpty {
                Text("(none yet — apply a tag to an entity above)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(applications) { application in
                            applicationRow(application)
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
        }
    }

    private func applicationRow(_ application: TagApplication) -> some View {
        HStack(alignment: .top, spacing: 6) {
            LucideIconSystemFallback(application.target.lucideIcon, size: 14)
                .foregroundStyle(.tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(tagLabel(for: application.tagId))
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Text(application.target.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary)
                        )
                    Text("→ \(application.targetId.uuidString.prefix(8))…")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                Task { await unapply(application) }
            } label: {
                LucideIconSystemFallback("x", size: 12)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove this application.")
        }
        .padding(.vertical, 2)
    }

    // MARK: - Tag cloud

    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tag cloud (\(cloud.count))")
                .font(.callout)
                .foregroundStyle(.primary)
            if cloud.isEmpty {
                Text("(no applications yet — apply a tag to populate the cloud)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(cloud) { entry in
                            cloudRow(entry)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }

    private func cloudRow(_ entry: TagCloudEntry) -> some View {
        HStack(spacing: 6) {
            LucideIconSystemFallback(entry.tag.category.lucideIcon, size: 12)
                .foregroundStyle(.tint)
                .frame(width: 16)
            Text(entry.tag.label)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text("\(entry.count)×")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                )
        }
        .padding(.vertical, 2)
    }

    // MARK: - Filter

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Filter by tag")
                .font(.callout)
                .foregroundStyle(.primary)
            if tags.isEmpty {
                Text("(define a tag to enable filtering)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 8) {
                    Picker("Tag", selection: Binding(
                        get: { draftFilterTagId ?? tags.first?.id ?? UUID() },
                        set: { draftFilterTagId = $0 }
                    )) {
                        Text("(choose)").tag(UUID())
                        ForEach(tags) { tag in
                            Text("\(tag.label) (\(tag.category.displayName))").tag(tag.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: draftFilterTagId) { _, _ in
                        Task { await runFilter() }
                    }

                    Picker("Target", selection: $draftFilterTarget) {
                        ForEach(TagTarget.allCases) { target in
                            Label(target.displayName, systemImage: target.lucideIcon)
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
                if filterMatches.isEmpty {
                    Text("(no entities match the chosen tag + target)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(filterMatches.enumerated()), id: \.offset) { _, id in
                            HStack(spacing: 6) {
                                LucideIconSystemFallback(draftFilterTarget.lucideIcon, size: 12)
                                    .foregroundStyle(.tint)
                                    .frame(width: 16)
                                Text(id.uuidString)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Helpers

    private func tagLabel(for tagId: UUID) -> String {
        tags.first { $0.id == tagId }?.label ?? tagId.uuidString.prefix(8) + "…"
    }

    /// Resolve the entity UUID from the apply-row text. Returns
    /// nil when the text is empty / malformed (= keeps the Apply
    /// button disabled per `canApply`).
    private func resolveApplyTargetUUID() -> UUID? {
        let trimmed = draftApplyTargetIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return UUID(uuidString: trimmed)
    }

    // MARK: - Async actions

    private func ensureManager() -> TagManager {
        if let manager { return manager }
        let new = TagManager(bookStore: bookStore)
        manager = new
        return new
    }

    private func reload() async {
        guard let bookId = activeBookId else { return }
        status = .loading
        let actor = ensureManager()
        // Default pickers to the first tag (when any).
        if draftApplyTagId == nil { draftApplyTagId = tags.first?.id }
        if draftFilterTagId == nil { draftFilterTagId = tags.first?.id }
        do {
            tags = try await actor.listTags(bookId: bookId)
            applications = try await actor.applications(bookId: bookId)
            cloud = try await actor.tagCloud(bookId: bookId)
            await runFilter()
            status = .loaded
        } catch {
            errorText = error.localizedDescription
            status = .failed(error.localizedDescription)
        }
    }

    private func runFilter() async {
        guard let bookId = activeBookId,
              let tagId = draftFilterTagId,
              tagId != UUID() else {
            filterMatches = []
            return
        }
        let actor = ensureManager()
        do {
            filterMatches = try await actor.filterByTag(
                bookId: bookId,
                tagId: tagId,
                target: draftFilterTarget
            )
        } catch {
            errorText = error.localizedDescription
            filterMatches = []
        }
    }

    private func addTag() async {
        guard let bookId = activeBookId else { return }
        let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let actor = ensureManager()
        let tag = Tag(
            bookId: bookId,
            label: trimmed,
            category: draftCategory
        )
        do {
            try await actor.addTag(tag)
            draftLabel = ""
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func removeTag(_ tag: Tag) async {
        let actor = ensureManager()
        do {
            try await actor.removeTag(id: tag.id)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func applyTag() async {
        guard let bookId = activeBookId,
              let tagId = draftApplyTagId,
              tagId != UUID(),
              let targetId = resolveApplyTargetUUID() else { return }
        let actor = ensureManager()
        let application = TagApplication(
            bookId: bookId,
            tagId: tagId,
            target: draftApplyTarget,
            targetId: targetId
        )
        do {
            try await actor.apply(application)
            draftApplyTargetIdText = ""
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func unapply(_ application: TagApplication) async {
        let actor = ensureManager()
        do {
            try await actor.unapply(id: application.id)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
