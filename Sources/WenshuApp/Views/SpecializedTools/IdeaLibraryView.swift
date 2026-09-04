//
//  IdeaLibraryView.swift · Wenshu · P1 ticket #15 (WIRE-SPECIALIZEDTOOLS-009, 2026-09-04)
//
//  SpecializedTools pane tab 11: Idea Library.
//
//  Per the v0.30 boss 2026-08-30 OOB pattern (= ForeshadowingView +
//  PlaceholderView + LongFormGuardrailsView + ReaderExperienceView +
//  PlotThreadView + GenreFitView + EmotionCurveView +
//  CharacterRelationshipsView + CharacterLifecycleView +
//  TagManagerView = 10 tabs in the specializedTools pane), this
//  view is the REAL implementation for the Idea Library tab (=
//  the 11th tab). Renders:
//
//    - Top header (= icon + tab title + book + idea count +
//      link count).
//    - "Add idea" row (= title TextField + description TextEditor
//      + status picker + tag TextField + add button).
//    - Ideas list (= one row per idea; shows status badge +
//      title + description preview + tag chips + link count +
//      remove button).
//    - Search bar (= text field; live-filters the list below).
//    - Status / tag filter pickers (= combine with search).
//    - Link section (= idea picker + target picker + entity-uuid
//      TextField + context TextField + link / unlink buttons +
//      links list for the selected idea).
//    - Suggest section (= context TextField + suggest button +
//      suggestions list).
//
//  State source: `IdeaLibrary` actor (= owned per-book, persisted
//  via per-book JSON sidecar at `books/<bookId>/ideas.json`).
//
//  Entity picker source: a free-form UUID TextField for the
//  target id (= consistent with how CharacterLifecycleView treats
//  `chapterId`, CharacterRelationshipsView treats
//  `establishedInChapterId`, and TagManagerView treats
//  `targetId`; wenshu does not yet have first-class `Chapter` /
//  `Character` / `PlotThread` domain types with id pickers, so a
//  free-form UUID is the least-surprising input).
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
//        live in IdeaLibraryTools.swift (= public).
//
//  Visual-gate (boss 2026-09-03 auto-pilot rule): this commit
//  ADDS an 11th tab to the specializedTools pane. Boss
//  acceptance required: open SpecializedTools pane, click the
//  new Idea-Library tab, add an idea, change its status, see it
//  in the list, link it to a chapter, search for it by title /
//  description, run the suggest-by-context filter.
//

import SwiftUI

/// SpecializedTools pane tab 11: Idea Library.
///
/// Reads the active bookId from `BookStore.selectedBookId`. If
/// no book is selected, renders the empty-state (= "no book
/// selected" hint, matching the ForeshadowingView no-content
/// pattern).
@MainActor
struct IdeaLibraryView: View {

    @Environment(BookStore.self) private var bookStore

    /// Active book id (= drives the actor's per-book scope).
    private var activeBookId: UUID? { bookStore.selectedBookId }

    /// Actor (= created lazily for the current book; held as
    /// @State so SwiftUI keeps the identity across re-renders).
    @State private var library: IdeaLibrary?

    @State private var ideas: [Idea] = []

    // Add-idea picker state.
    @State private var draftTitle: String = ""
    @State private var draftDescription: String = ""
    @State private var draftStatus: IdeaStatus = .seedling
    @State private var draftTagsText: String = ""

    // Search + filter state.
    @State private var searchText: String = ""
    @State private var draftFilterStatus: IdeaStatus? = nil
    @State private var draftFilterTag: String = ""

    // Link picker state.
    @State private var draftLinkIdeaId: UUID?
    @State private var draftLinkTarget: IdeaLinkTarget = .chapter
    @State private var draftLinkTargetIdText: String = ""
    @State private var draftLinkContext: String = ""

    // Suggest picker state.
    @State private var draftSuggestContext: String = ""
    @State private var suggestions: [Idea] = []

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
            LucideIconSystemFallback("lightbulb", size: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Idea Library")
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
            return "Capture reusable ideas across the active book: seedling → developing → mature → planted."
        case .loading:
            return "Loading…"
        case .loaded:
            let ideaCount = ideas.count
            let linkCount = ideas.reduce(0) { $0 + $1.links.count }
            return "\(ideaCount) idea\(ideaCount == 1 ? "" : "s"), \(linkCount) link\(linkCount == 1 ? "" : "s")"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No book selected")
                .font(.callout)
                .foregroundStyle(.primary)
            Text("Pick a book from the sidebar to start managing ideas.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            addIdeaRow
            Divider()
            searchAndFilterRow
            ideasListSection
            Divider()
            linkSection
            Divider()
            suggestSection
            Spacer(minLength: 0)
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
        }
    }

    // MARK: - Add-idea row

    private var addIdeaRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add idea")
                .font(.callout)
                .foregroundStyle(.primary)
            HStack(spacing: 8) {
                TextField("Title (e.g. The Mirror Motif)", text: $draftTitle, axis: .horizontal)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .help("Short, human-readable title for the idea. Whitespace is trimmed.")
                Picker("Status", selection: $draftStatus) {
                    ForEach(IdeaStatus.allCases) { status in
                        Label(status.displayName, systemImage: status.lucideIcon)
                            .tag(status)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer(minLength: 0)
                Button {
                    Task { await addIdea() }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAddIdea)
                .help("Add a new idea with the supplied title + description + status + tags.")
            }
            TextField(
                "Description (2-3 sentences)",
                text: $draftDescription,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .lineLimit(2...4)
            .help("Short description of the idea. Trimmed at save time.")
            TextField("Tags (comma-separated, e.g. mirror, water)", text: $draftTagsText, axis: .horizontal)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .help("Free-form tags. Comma-separated. Trimmed and de-duplicated (case-insensitive) at save time.")
        }
    }

    private var canAddIdea: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Search + filter row

    private var searchAndFilterRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Search + filter")
                .font(.callout)
                .foregroundStyle(.primary)
            HStack(spacing: 8) {
                TextField("Search title / description", text: $searchText, axis: .horizontal)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onChange(of: searchText) { _, _ in
                        Task { await reload() }
                    }
                Picker("Status", selection: Binding(
                    get: { draftFilterStatus ?? IdeaStatus.allCases.first ?? .seedling },
                    set: { newValue in
                        // Map "all" sentinel back to nil (= the
                        // actor's `list` filter takes nil for
                        // "no filter").
                        if newValue == IdeaStatus.allCases.first {
                            draftFilterStatus = nil
                        } else {
                            draftFilterStatus = newValue
                        }
                    }
                )) {
                    Text("All statuses").tag(IdeaStatus.allCases.first ?? .seedling)
                    ForEach(IdeaStatus.allCases) { status in
                        Label(status.displayName, systemImage: status.lucideIcon).tag(status)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: draftFilterStatus) { _, _ in
                    Task { await reload() }
                }
                TextField("Tag", text: $draftFilterTag, axis: .horizontal)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .help("Filter by tag (= case-insensitive exact match).")
                    .onChange(of: draftFilterTag) { _, _ in
                        Task { await reload() }
                    }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Ideas list

    private var ideasListSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ideas (\(ideas.count))")
                .font(.callout)
                .foregroundStyle(.primary)
            if ideas.isEmpty {
                Text("(none yet — add the first one above)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(ideas) { idea in
                            ideaRow(idea)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private func ideaRow(_ idea: Idea) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                LucideIconSystemFallback(idea.status.lucideIcon, size: 16)
                    .foregroundStyle(.tint)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(idea.title)
                            .font(.callout)
                            .foregroundStyle(.primary)
                        Text(idea.status.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.quaternary)
                            )
                        if idea.links.count > 0 {
                            Text("\(idea.links.count)× linked")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if !idea.description.isEmpty {
                        Text(idea.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if !idea.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(idea.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(.tint.opacity(0.15))
                                        )
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    Task { await removeIdea(idea) }
                } label: {
                    LucideIconSystemFallback("trash-2", size: 14)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove this idea.")
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

    // MARK: - Link section

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Link idea to entity")
                .font(.callout)
                .foregroundStyle(.primary)
            if ideas.isEmpty {
                Text("Define at least 1 idea above before linking it.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 8) {
                    Picker("Idea", selection: Binding(
                        get: { draftLinkIdeaId ?? ideas.first?.id ?? UUID() },
                        set: { draftLinkIdeaId = $0 }
                    )) {
                        Text("(choose)").tag(UUID())
                        ForEach(ideas) { idea in
                            Text(idea.title).tag(idea.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: draftLinkIdeaId) { _, _ in
                        // Reset draft state when idea changes.
                        draftLinkTargetIdText = ""
                        draftLinkContext = ""
                    }

                    Picker("Target", selection: $draftLinkTarget) {
                        ForEach(IdeaLinkTarget.allCases) { target in
                            Label(target.displayName, systemImage: target.lucideIcon)
                                .tag(target)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    TextField("Entity UUID", text: $draftLinkTargetIdText, axis: .horizontal)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .help("UUID of the entity to link the idea to. Leave empty to disable Link.")

                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    TextField(
                        "Context (1-sentence: where it appears)",
                        text: $draftLinkContext,
                        axis: .horizontal
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .help("1-sentence description of where the idea appears in the linked entity.")

                    Spacer(minLength: 0)

                    Button {
                        Task { await linkIdea() }
                    } label: {
                        Label("Link", systemImage: "link")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canLink)
                    .help("Record a link from the chosen idea to the chosen entity.")
                }

                linksListForSelectedIdea
            }
        }
    }

    private var canLink: Bool {
        guard let ideaId = draftLinkIdeaId, ideaId != UUID() else { return false }
        guard ideas.contains(where: { $0.id == ideaId }) else { return false }
        guard UUID(uuidString: draftLinkTargetIdText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil else { return false }
        return true
    }

    @ViewBuilder
    private var linksListForSelectedIdea: some View {
        if let ideaId = draftLinkIdeaId,
           let selectedIdea = ideas.first(where: { $0.id == ideaId }) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Links for \"\(selectedIdea.title)\" (\(selectedIdea.links.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if selectedIdea.links.isEmpty {
                    Text("(no links yet)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(selectedIdea.links) { link in
                                linkRow(link, for: ideaId)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
        } else {
            EmptyView()
        }
    }

    private func linkRow(_ link: IdeaLink, for ideaId: UUID) -> some View {
        HStack(alignment: .top, spacing: 6) {
            LucideIconSystemFallback(link.target.lucideIcon, size: 14)
                .foregroundStyle(.tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(link.target.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary)
                        )
                    Text("→ \(link.targetId.uuidString.prefix(8))…")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if !link.context.isEmpty {
                    Text(link.context)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                Task { await unlinkIdea(ideaId: ideaId, link: link) }
            } label: {
                LucideIconSystemFallback("x", size: 12)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove this link.")
        }
        .padding(.vertical, 2)
    }

    // MARK: - Suggest section

    private var suggestSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Suggest ideas by context")
                .font(.callout)
                .foregroundStyle(.primary)
            HStack(spacing: 8) {
                TextField(
                    "Context keywords (e.g. mirror water recognition)",
                    text: $draftSuggestContext,
                    axis: .horizontal
                )
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .help("Free-text context. Suggestions match ideas by tag overlap (+2) + title/description token overlap (+1).")

                Spacer(minLength: 0)

                Button {
                    Task { await runSuggest() }
                } label: {
                    Label("Suggest", systemImage: "wand")
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftSuggestContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Rank ideas by tag overlap + title/description token match against the context keywords.")
            }
            if !suggestions.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(suggestions) { idea in
                            HStack(alignment: .top, spacing: 6) {
                                LucideIconSystemFallback(idea.status.lucideIcon, size: 12)
                                    .foregroundStyle(.tint)
                                    .frame(width: 16)
                                Text(idea.title)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                Text(idea.status.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
        }
    }

    // MARK: - Actions

    private func addIdea() async {
        guard let library, let bookId = activeBookId else { return }
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorText = "Title is empty."
            return
        }
        let trimmedDescription = draftDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagList = draftTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let idea = Idea(
            bookId: bookId,
            title: trimmedTitle,
            description: trimmedDescription,
            status: draftStatus,
            tags: tagList
        )
        do {
            try await library.add(idea)
            draftTitle = ""
            draftDescription = ""
            draftTagsText = ""
            draftStatus = .seedling
            errorText = nil
            await reload()
        } catch {
            errorText = "Add failed: \(error.localizedDescription)"
        }
    }

    private func removeIdea(_ idea: Idea) async {
        guard let library else { return }
        do {
            try await library.remove(id: idea.id)
            await reload()
        } catch {
            errorText = "Remove failed: \(error.localizedDescription)"
        }
    }

    private func linkIdea() async {
        guard let library,
              let ideaId = draftLinkIdeaId,
              let targetId = UUID(uuidString: draftLinkTargetIdText.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return }
        let link = IdeaLink(
            target: draftLinkTarget,
            targetId: targetId,
            context: draftLinkContext
        )
        do {
            try await library.link(ideaId: ideaId, link: link)
            draftLinkTargetIdText = ""
            draftLinkContext = ""
            errorText = nil
            await reload()
        } catch {
            errorText = "Link failed: \(error.localizedDescription)"
        }
    }

    private func unlinkIdea(ideaId: UUID, link: IdeaLink) async {
        guard let library else { return }
        do {
            try await library.unlink(ideaId: ideaId, link: link)
            await reload()
        } catch {
            errorText = "Unlink failed: \(error.localizedDescription)"
        }
    }

    private func runSuggest() async {
        guard let library, let bookId = activeBookId else { return }
        do {
            suggestions = try await library.suggest(bookId: bookId, context: draftSuggestContext)
        } catch {
            suggestions = []
            errorText = "Suggest failed: \(error.localizedDescription)"
        }
    }

    private func reload() async {
        guard let bookId = activeBookId else {
            status = .idle
            ideas = []
            return
        }
        if library == nil {
            library = IdeaLibrary(bookStore: bookStore)
        }
        guard let library else { return }
        status = .loading
        do {
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTag = draftFilterTag.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSearch.isEmpty {
                ideas = try await library.search(bookId: bookId, query: trimmedSearch)
            } else {
                ideas = try await library.list(
                    bookId: bookId,
                    status: draftFilterStatus,
                    tag: trimmedTag.isEmpty ? nil : trimmedTag
                )
            }
            status = .loaded
        } catch {
            ideas = []
            status = .failed(error.localizedDescription)
        }
    }
}