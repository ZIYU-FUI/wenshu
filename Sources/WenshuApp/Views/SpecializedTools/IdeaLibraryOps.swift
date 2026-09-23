//
//  IdeaLibraryOps.swift · Wenshu · v1.74 idealibrary-mvvm T1
//
//  Per-book idea library business layer, extracted from IdeaLibraryView.
//
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离' (= UI /
//  业务 / 数据 separation audit) + the v1.72 settings-kanban-todo
//  precedent (= KanbanOps / TodoOps / SettingsOps = stateless
//  enums with @MainActor static funcs) + the v1.74 tagmanager-mvvm
//  precedent (= TagManagerOps = nil-able actor reference seam
//  for tests): IdeaLibraryView currently owns the business logic
//  for the per-book idea library. reload / addIdea / removeIdea /
//  linkIdea / unlinkIdea / runSuggest are private methods on the
//  View (= coupling UI to the domain actor's lifecycle + the
//  SwiftUI draft state in the same file). This helper lifts the
//  business layer into a stateless enum so the View can become a
//  pure consumer.
//
//  Why a stateless enum (not an @Observable class):
//  - State already lives in `IdeaLibrary` (= the actor defined in
//    Core/Agent/Specialized/IdeaLibraryTools.swift; = source of
//    truth per AGENTS.md §11.3 wenshu-side wins pattern).
//  - View-level state (`library: IdeaLibrary?` + draft form
//    fields + ideas / suggestions arrays) is the SwiftUI layer.
//  - The enum only takes the actor reference as a parameter and
//    returns Result types. Stateless. Reusable from any caller.
//
//  Why async throws (vs the v1.72 KanbanOps sync shape):
//  - IdeaLibrary is an actor (= the canonical domain store for
//    ideas.json); = every method is `async throws` for actor
//    isolation. The Ops enum exposes the same shape so the View's
//    `await actor.foo()` calls land on Ops without changing the
//    TaskGroup wiring.
//
//  `library: IdeaLibrary?` instead of `library: IdeaLibrary` is
//  the seam that lets tests bypass the BookStore (= tests pass
//  nil to drive the empty-result paths + pre-condition guards;
//  = no global env injection needed).
//
//  Apple HIG canonical pattern: stateless business-layer enum +
//  per-call Result structs (= matches Foundation URLSession's
//  completion-handler shape; = no leaky global state).
//
//  All methods are @MainActor-isolated because:
//  - The View writes through them on @MainActor.
//  - The actor's public methods are actor-isolated (= calls land
//    on @MainActor for view safety).
//  - The Result types are simple value types; = no shared
//    mutation.
//
//  Public surface (= 6 entry points):
//    - reload(library:bookId:searchText:filterStatus:filterTag:) -> LoadResult
//    - addIdea(library:bookId:title:description:status:tagsText:) -> WriteResult
//    - removeIdea(library:idea:) -> WriteResult
//    - linkIdea(library:ideaId:target:targetIdText:context:) -> WriteResult
//    - unlinkIdea(library:ideaId:link:) -> WriteResult
//    - runSuggest(library:bookId:context:) -> SuggestResult
//
//  Out of scope (= NOT moved here, stays in View):
//    - UI state (`draftTitle` / `draftDescription` /
//      `draftStatus` / `draftTagsText` / `searchText` /
//      `draftFilterStatus` / `draftFilterTag` /
//      `draftLinkIdeaId` / `draftLinkTarget` /
//      `draftLinkTargetIdText` / `draftLinkContext` /
//      `draftSuggestContext` / `suggestions` + errorText) — these
//      are SwiftUI-only concerns.
//    - The `.task(id:)` triggers that decide WHEN to reload —
//      the helper exposes WHEN via the call site, not WHEN via a
//      subscription (per ADR-0009).
//    - `ensureLibrary()` lazy-actor-construction stays in the
//      View (= state transition, not remote call).
//
//  Honest scope note (= Q46 stop-rule boundary):
//    IdeaLibraryView's `addIdea` had a side effect of clearing 4
//    draft @State strings on success (= SwiftUI-side inline-
//    create UX reset). That reset stays in the View (= binding
//    reset, NOT business rule). The helper returns a WriteResult;
//    the View decides whether to reset based on `result.didSave`.
//

import Foundation

/// Stateless business layer for the per-book idea library. Lifts
/// the actor-call + state-transition logic out of
/// `IdeaLibraryView` per the v1.74 UI/业务/数据 separation audit
/// (= ADR-0009).
@MainActor
enum IdeaLibraryOps {

    // MARK: - Result types

    /// Result of `reload` (= search or list ideas filtered by
    /// status + tag).
    struct LoadResult: Sendable {
        let ideas: [Idea]
        let didLoad: Bool
        let error: String?
        init(ideas: [Idea], didLoad: Bool, error: String? = nil) {
            self.ideas = ideas
            self.didLoad = didLoad
            self.error = error
        }
    }

    /// Result of `addIdea` / `removeIdea` / `linkIdea` /
    /// `unlinkIdea` (= a single write to the actor).
    struct WriteResult: Sendable {
        let didSave: Bool
        let error: String?
        init(didSave: Bool, error: String? = nil) {
            self.didSave = didSave
            self.error = error
        }
    }

    /// Result of `runSuggest` (= ask the LLM for suggestions).
    struct SuggestResult: Sendable {
        let suggestions: [Idea]
        let didRun: Bool
        let error: String?
        init(suggestions: [Idea], didRun: Bool, error: String? = nil) {
            self.suggestions = suggestions
            self.didRun = didRun
            self.error = error
        }
    }

    // MARK: - Load (= search or list)

    /// Load the ideas for `bookId`. Mirrors
    /// `IdeaLibraryView.reload` (= the pre-v1.74 invariant set):
    /// - nil library OR nil bookId → empty ideas + didLoad=false
    /// - non-empty searchText → actor.search(bookId:query:)
    /// - otherwise → actor.list(bookId:status:tag:)
    static func reload(
        library: IdeaLibrary?,
        bookId: UUID?,
        searchText: String,
        filterStatus: IdeaStatus?,
        filterTag: String
    ) async -> LoadResult {
        guard let library = library, let bookId = bookId else {
            return LoadResult(ideas: [], didLoad: false)
        }
        do {
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTag = filterTag.trimmingCharacters(in: .whitespacesAndNewlines)
            let ideas: [Idea]
            if !trimmedSearch.isEmpty {
                ideas = try await library.search(bookId: bookId, query: trimmedSearch)
            } else {
                ideas = try await library.list(
                    bookId: bookId,
                    status: filterStatus,
                    tag: trimmedTag.isEmpty ? nil : trimmedTag
                )
            }
            return LoadResult(ideas: ideas, didLoad: true)
        } catch {
            return LoadResult(ideas: [], didLoad: false,
                              error: error.localizedDescription)
        }
    }

    // MARK: - Add

    /// Add a new idea. Mirrors `IdeaLibraryView.addIdea`:
    /// - nil library OR nil bookId → no-op (didSave=false)
    /// - empty / whitespace-only title → no-op (didSave=false)
    /// - otherwise → actor.add(Idea(bookId:title:description:
    ///   status:tags:))
    /// - tag list = comma-split of `tagsText` (= the inline
    ///   string parsing the View did before; = moves into Ops
    ///   for the same seam reason as TagManagerOps).
    static func addIdea(
        library: IdeaLibrary?,
        bookId: UUID?,
        title: String,
        description: String,
        status: IdeaStatus,
        tagsText: String
    ) async -> WriteResult {
        guard let library = library, let bookId = bookId else {
            return WriteResult(didSave: false)
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return WriteResult(didSave: false)
        }
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagList = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let idea = Idea(
            bookId: bookId,
            title: trimmedTitle,
            description: trimmedDescription,
            status: status,
            tags: tagList
        )
        do {
            try await library.add(idea)
            return WriteResult(didSave: true)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Remove

    /// Remove an idea by id. Mirrors `IdeaLibraryView.removeIdea`:
    /// - nil library → no-op
    /// - otherwise → actor.remove(id:)
    static func removeIdea(
        library: IdeaLibrary?,
        idea: Idea
    ) async -> WriteResult {
        guard let library = library else {
            return WriteResult(didSave: false)
        }
        do {
            try await library.remove(id: idea.id)
            return WriteResult(didSave: true)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Link (= attach an idea to a chapter / character / scene / plot-thread)

    /// Link an idea to an entity. Mirrors
    /// `IdeaLibraryView.linkIdea`:
    /// - nil library OR nil ideaId OR unparseable targetIdText →
    ///   no-op (didSave=false, no error)
    /// - otherwise → actor.link(ideaId:link:)
    static func linkIdea(
        library: IdeaLibrary?,
        ideaId: UUID?,
        target: IdeaLinkTarget,
        targetIdText: String,
        context: String
    ) async -> WriteResult {
        guard let library = library,
              let ideaId = ideaId else {
            return WriteResult(didSave: false)
        }
        let trimmedTargetId = targetIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let targetId = UUID(uuidString: trimmedTargetId) else {
            return WriteResult(didSave: false)
        }
        let link = IdeaLink(
            target: target,
            targetId: targetId,
            context: context
        )
        do {
            try await library.link(ideaId: ideaId, link: link)
            return WriteResult(didSave: true)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Unlink (= remove an idea → entity link)

    /// Unlink an idea from an entity. Mirrors
    /// `IdeaLibraryView.unlinkIdea`:
    /// - nil library → no-op
    /// - otherwise → actor.unlink(ideaId:link:)
    static func unlinkIdea(
        library: IdeaLibrary?,
        ideaId: UUID,
        link: IdeaLink
    ) async -> WriteResult {
        guard let library = library else {
            return WriteResult(didSave: false)
        }
        do {
            try await library.unlink(ideaId: ideaId, link: link)
            return WriteResult(didSave: true)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Suggest (= ask LLM for related ideas)

    /// Run an LLM-based idea suggestion. Mirrors
    /// `IdeaLibraryView.runSuggest`:
    /// - nil library OR nil bookId → no-op (didRun=false,
    ///   suggestions=[])
    /// - otherwise → actor.suggest(bookId:context:)
    static func runSuggest(
        library: IdeaLibrary?,
        bookId: UUID?,
        context: String
    ) async -> SuggestResult {
        guard let library = library, let bookId = bookId else {
            return SuggestResult(suggestions: [], didRun: false)
        }
        do {
            let suggestions = try await library.suggest(bookId: bookId, context: context)
            return SuggestResult(suggestions: suggestions, didRun: true)
        } catch {
            return SuggestResult(suggestions: [], didRun: false,
                                 error: error.localizedDescription)
        }
    }
}