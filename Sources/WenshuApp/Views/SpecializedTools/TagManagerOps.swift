//
//  TagManagerOps.swift · Wenshu · v1.74 tagmanager-mvvm T1
//
//  Per-book tag business layer, extracted from TagManagerView.
//
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离' (= UI /
//  业务 / 数据 separation audit) + the v1.72 settings-kanban-todo
//  precedent (= KanbanOps / TodoOps / SettingsOps = stateless
//  enums with @MainActor static funcs): TagManagerView currently
//  owns the business logic for the per-book tag board. reload /
//  runFilter / addTag / removeTag / applyTag / unapply are
//  private methods on the View (= coupling UI to the domain
//  actor's lifecycle + the SwiftUI draft state in the same file).
//  This helper lifts the business layer into a stateless enum so
//  the View can become a pure consumer.
//
//  Why a stateless enum (not an @Observable class):
//  - State already lives in `TagManager` (= the actor defined in
//    Core/Agent/Specialized/TagManagerTools.swift; = source of
//    truth per AGENTS.md §11.3 wenshu-side wins pattern).
//  - View-level state (`manager: TagManager?` + draft form
//    fields + tags/applications/cloud/filterMatches arrays) is
//    the SwiftUI layer; == transient for the v1 tab session.
//  - The enum only takes the actor reference as a parameter and
//    returns Result types. Stateless. Reusable from any caller
//    (TagManagerView today, future reader from a tools panel,
//    etc.).
//
//  Why async throws (vs the v1.72 KanbanOps sync shape):
//  - TagManager is an actor (= the canonical domain store for
//    tags.json); = every method is `async throws` for actor
//    isolation. The Ops enum exposes the same shape so the View's
//    `await actor.foo()` calls land on Ops without changing the
//    TaskGroup wiring.
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
//  - Same isolation as KanbanOps / TodoOps per v1.72.
//
//  Public surface (= 6 entry points):
//    - reload(manager:bookId:) -> LoadResult
//    - runFilter(manager:bookId:tagId:target:) -> FilterResult
//    - addTag(manager:bookId:label:category:) -> AddResult
//    - removeTag(manager:tag:) -> WriteResult
//    - applyTag(manager:bookId:tagId:target:targetIdText:) -> ApplyResult
//    - unapply(manager:application:) -> WriteResult
//
//  Out of scope (= NOT moved here, stays in View):
//    - UI state (`draftLabel` text field, `draftCategory` picker,
//      `draftApplyTagId` / `draftFilterTagId` selections,
//      `errorText` display string) — these are SwiftUI-only
//      concerns that have no business meaning outside the view.
//    - The `.onChange(of:)` triggers that decide WHEN to reload —
//      the helper exposes WHEN via the call site, not WHEN via a
//      subscription (per ADR-0009 = the view layer owns reactive
//      triggers; the business layer is pure).
//    - `ensureManager()` lazy-actor-construction stays in the
//      View (= it is a state transition, not a remote call).
//
//  Honest scope note (= Q46 stop-rule boundary):
//    TagManagerView's `addTag` had a side effect of clearing the
//    `draftLabel` @State string on success (= the SwiftUI-side
//    inline-create UX reset). That reset stays in the View (= it
//    is a SwiftUI binding reset, not a business rule). The helper
//    returns an AddResult; the View decides whether to reset the
//    text field based on `result.didSave`.
//

import Foundation

/// Stateless business layer for the per-book tag board. Lifts
/// the actor-call + state-transition logic out of `TagManagerView`
/// per the v1.74 UI/业务/数据 separation audit (= ADR-0009).
///
/// All public static funcs accept `manager: TagManager?` (= the
/// actor may be nil when no book is selected / the actor has not
/// been lazily constructed yet). The Ops helper does NOT import
/// `BookStore` (= keeps the helper usable from any caller without
/// dragging in the global env). Lazy construction of the actor
/// lives in the View (= `ensureManager()` private func = the
/// canonical wenshu-side pattern from v1.72 KanbanOps).
///
/// `manager: TagManager?` instead of `manager: TagManager` is the
/// seam that lets tests bypass the BookStore (= tests pass nil
/// to drive the empty-result paths + pre-condition guards; = no
/// global env injection needed).
@MainActor
enum TagManagerOps {

    // MARK: - Result types

    /// Result of `reload` (= load tags + applications + cloud +
    /// run filter with current draft filter selection).
    struct LoadResult: Sendable {
        let tags: [Tag]
        let applications: [TagApplication]
        let cloud: [TagCloudEntry]
        let didLoad: Bool
        let error: String?
        init(tags: [Tag], applications: [TagApplication],
             cloud: [TagCloudEntry], didLoad: Bool, error: String? = nil) {
            self.tags = tags
            self.applications = applications
            self.cloud = cloud
            self.didLoad = didLoad
            self.error = error
        }
    }

    /// Result of `runFilter` (= filter entities by the chosen
    /// tag + target).
    struct FilterResult: Sendable {
        let matches: [UUID]
        let didRun: Bool
        let error: String?
        init(matches: [UUID], didRun: Bool, error: String? = nil) {
            self.matches = matches
            self.didRun = didRun
            self.error = error
        }
    }

    /// Result of `addTag` (= create + persist a new Tag).
    struct AddResult: Sendable {
        let didSave: Bool
        let error: String?
        init(didSave: Bool, error: String? = nil) {
            self.didSave = didSave
            self.error = error
        }
    }

    /// Result of `removeTag` / `unapply` (= delete by id).
    struct WriteResult: Sendable {
        let didSave: Bool
        let error: String?
        init(didSave: Bool, error: String? = nil) {
            self.didSave = didSave
            self.error = error
        }
    }

    /// Result of `applyTag` (= record a TagApplication).
    struct ApplyResult: Sendable {
        let didSave: Bool
        let error: String?
        init(didSave: Bool, error: String? = nil) {
            self.didSave = didSave
            self.error = error
        }
    }

    // MARK: - Load (= reload tags + applications + cloud + run filter)

    /// Load the tag board for `bookId`. Mirrors
    /// `TagManagerView.reload` (= the B-09 + B-13 invariant set):
    /// - nil bookId → empty result with didLoad=false (= View
    ///   shows the empty state, NOT the red error caption)
    /// - non-nil bookId → calls actor.listTags / applications /
    ///   tagCloud + runFilter on the current draft filter
    ///   selection (= the View passes the current
    ///   draftFilterTagId / draftFilterTarget so the picker
    ///   defaults land before the actor reads).
    static func reload(
        manager: TagManager?,
        bookId: UUID?
    ) async -> LoadResult {
        guard let actor = manager, let bookId = bookId else {
            return LoadResult(tags: [], applications: [], cloud: [],
                              didLoad: false)
        }
        do {
            async let tagsTask = actor.listTags(bookId: bookId)
            async let appsTask = actor.applications(bookId: bookId)
            async let cloudTask = actor.tagCloud(bookId: bookId)
            let tags = try await tagsTask
            let applications = try await appsTask
            let cloud = try await cloudTask
            // Filter pass is a separate call (= caller invokes
            // TagManagerOps.runFilter after reload to refresh the
            // filter matches row).
            return LoadResult(tags: tags, applications: applications,
                              cloud: cloud, didLoad: true)
        } catch {
            return LoadResult(tags: [], applications: [], cloud: [],
                              didLoad: false, error: error.localizedDescription)
        }
    }

    // MARK: - Filter (= filter entities by tag + target)

    /// Run the per-tag filter. Mirrors `TagManagerView.runFilter`:
    /// - nil bookId → empty matches
    /// - nil tagId OR the NEW Magic UUID → empty matches
    /// - otherwise → actor.filterByTag(bookId:tagId:target:)
    static func runFilter(
        manager: TagManager?,
        bookId: UUID?,
        tagId: UUID?,
        target: TagTarget
    ) async -> FilterResult {
        guard manager != nil,
              let bookId = bookId,
              let tagId = tagId,
              tagId != UUID() else {
            return FilterResult(matches: [], didRun: false)
        }
        // re-narrow manager after the nil-guard (= Swift can't
        // thread the unwrap through the && chain).
        guard let actor = manager else {
            return FilterResult(matches: [], didRun: false)
        }
        do {
            let matches = try await actor.filterByTag(
                bookId: bookId,
                tagId: tagId,
                target: target
            )
            return FilterResult(matches: matches, didRun: true)
        } catch {
            return FilterResult(matches: [], didRun: false,
                                error: error.localizedDescription)
        }
    }

    // MARK: - Add

    /// Add a new tag with the given label + category. Mirrors
    /// `TagManagerView.addTag`:
    /// - nil bookId → no-op (didSave=false, no error)
    /// - empty / whitespace-only label → no-op (didSave=false,
    ///   no error)
    /// - otherwise → actor.addTag(Tag(bookId:label:category:))
    static func addTag(
        manager: TagManager?,
        bookId: UUID?,
        label: String,
        category: TagCategory
    ) async -> AddResult {
        guard let actor = manager, let bookId = bookId else {
            return AddResult(didSave: false)
        }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AddResult(didSave: false)
        }
        let tag = Tag(bookId: bookId, label: trimmed, category: category)
        do {
            try await actor.addTag(tag)
            return AddResult(didSave: true)
        } catch {
            return AddResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Remove (= delete a tag by id)

    /// Remove a tag by id (= cascades its applications). Mirrors
    /// `TagManagerView.removeTag`:
    /// - actor.removeTag(id:) + didSave on success
    static func removeTag(manager: TagManager?, tag: Tag) async -> WriteResult {
        guard let actor = manager else {
            return WriteResult(didSave: false)
        }
        do {
            try await actor.removeTag(id: tag.id)
            return WriteResult(didSave: true)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Apply (= record a TagApplication)

    /// Apply a tag to an entity (= chapter / character / scene /
    /// plot-thread). Mirrors `TagManagerView.applyTag`:
    /// - nil bookId / nil tagId / unknown-tag tagId / unparseable
    ///   targetId → no-op (didSave=false, no error per the
    ///   inline guard chain)
    /// - otherwise → actor.apply(TagApplication(bookId:tagId:
    ///   target:targetId:))
    static func applyTag(
        manager: TagManager?,
        bookId: UUID?,
        tagId: UUID?,
        target: TagTarget,
        targetIdText: String
    ) async -> ApplyResult {
        guard let actor = manager else {
            return ApplyResult(didSave: false)
        }
        guard let bookId = bookId,
              let tagId = tagId,
              tagId != UUID() else {
            return ApplyResult(didSave: false)
        }
        let trimmedTargetId = targetIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let targetId = UUID(uuidString: trimmedTargetId) else {
            return ApplyResult(didSave: false)
        }
        let application = TagApplication(
            bookId: bookId,
            tagId: tagId,
            target: target,
            targetId: targetId
        )
        do {
            try await actor.apply(application)
            return ApplyResult(didSave: true)
        } catch {
            return ApplyResult(didSave: false, error: error.localizedDescription)
        }
    }

    // MARK: - Unapply (= remove an application by id)

    /// Remove a TagApplication by id. Mirrors
    /// `TagManagerView.unapply`:
    /// - actor.unapply(id:) + didSave on success
    static func unapply(
        manager: TagManager?,
        application: TagApplication
    ) async -> WriteResult {
        guard let actor = manager else {
            return WriteResult(didSave: false)
        }
        do {
            try await actor.unapply(id: application.id)
            return WriteResult(didSave: true)
        } catch {
            return WriteResult(didSave: false, error: error.localizedDescription)
        }
    }
}