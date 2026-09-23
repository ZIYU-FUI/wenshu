//
//  CardOpenOps.swift · Wenshu · v1.74 cardopen-dedupe T1
//
//  Card-open business layer, extracted from WorkspaceView /
//  ZoneModuleView / ShellMiddleColumn (= 3 verbatim copies of
//  `openCardInEditor`).
//
//  Per boss 2026-09-22 OOB '按MVVM UI 业务 数据，三分离' (= UI /
//  业务 / 数据 separation audit) + the 2026-09-23 spec at
//  .scratch/2026-09-23-mvvm-audit/spec.md §2.6 / §2.7 / §2.11
//  (= the audit surfaced verbatim duplication of
//  `openCardInEditor(source:)` across 3 view files): the open-
//  card business layer (= reference filter + body load + bookDoc
//  load + duplicate-tab detection + EditorTab construction +
//  appState mutation) is a single concern that was duplicated 3x.
//  This helper lifts the business layer into a stateless enum so
//  the 3 views call one shared function.
//
//  Why a stateless enum (not an @Observable class):
//  - The business logic is a single, atomic operation (= open
//    one card in the editor) with no persistent state.
//  - The 3 callers differ only in how they expose `previewScope`
//    (= computed var / func / @Environment read); = Ops accepts
//    a value `PreviewScope` (= the seam that lets tests pass any
//    scope without standing up a view).
//  - Per the v1.72 settings-kanban-todo precedent (= KanbanOps /
//    TodoOps / SettingsOps = stateless enums with @MainActor
//    static funcs), the wenshu MVVM shape is "enum + static +
//    Result types", not "@Observable class ViewModel".
//
//  Why `bookStore: BookStore?` (nil-able):
//  - `referenceStore.loadAllReferences()` is the only IO call (=
//    optional anyway: `(try? bookStore.referenceStore.loadAllRef…)`
//    in the original View code).
//  - nil bookStore (= the rare on-launch race where the sidebar's
//    click lands before BookStore is ready) → empty entities →
//    silent no-op (= matches the existing 3 view bodies' behaviour
//    verbatim).
//
//  All methods are @MainActor-isolated because:
//  - The 3 callers are @MainActor views.
//  - The mutation (`appState.openTabs.append` + activeTabId =
//    newTab.id) is on @MainActor.
//
//  Public surface (= 2 entry points):
//    - computeCardTriad(source:previewScope:bookStore:) -> CardTriad
//    - openTab(triad:previewScope:appState:) -> OpenCardResult
//
//  Why 2 entry points (not 1):
//  - WorkspaceView's openCardInEditor handles only the reference-
//    scope + bookScope-deferred paths (= ticket 027-35 will lift
//    the BookDocLoader into a shared service).
//  - ZoneModuleView's openCardInEditor adds a filesystem scan
//    in the bookScope case (= walk shelves/<shelf-uuid>/books/
//    <book-uuid>/<folder>/*.md and pick the first .md). That scan
//    stays in the View (= too ZoneModuleView-specific to lift; =
//    ticket 027-35 will replace it).
//  - The shared part = the dedup check + EditorTab construction +
//    appState.openTabs.append + activeTabId mutation. That's what
//    `openTab` does (= the body that all 3 views duplicated
//    verbatim after the scope switch).
//  - `computeCardTriad` wraps the reference-scope filter + body
//    load (= the part all 3 views duplicated verbatim). The book-
//    scope case in `computeCardTriad` returns a "deferred" triad
//    (= silent no-op); ZoneModuleView's view-local file-scan
//    overrides that triad before calling `openTab`.
//
//
//  Out of scope (= NOT moved here, stays in View):
//    - `previewScope` derivation (= the view-local computed var /
//      func that reads `appState.sidebarSelection`). Ops accepts
//      a value `PreviewScope`; = the view computes the value
//      first then calls Ops.
//    - The view-local `previewScope` + call sites (= the .button
//      action that triggers the open). Ops is invoked from each
//      view's call site; = the gesture / button stays in the
//      view.
//

import Foundation

/// Stateless business layer for opening a card in the editor.
/// Lifts the duplicated openCardInEditor (= 3 verbatim copies
/// across WorkspaceView / ZoneModuleView / ShellMiddleColumn) into
/// a single shared function per the v1.74 UI/业务/数据 separation
/// audit (= ADR-0009).
@MainActor
enum CardOpenOps {

    /// Resolved card content (= the trio the 3 view-local helpers
    /// all computed as `let (path, content, title)`). Empty
    /// content means "silent no-op" (= the caller checks
    /// `content.isEmpty` per boss 9/3 'no .alert noise' rule).
    struct CardTriad: Sendable {
        let path: String?
        let content: String
        let title: String
        init(path: String?, content: String, title: String) {
            self.path = path
            self.content = content
            self.title = title
        }

        /// True when the triad is a silent no-op (= no content).
        var isEmpty: Bool { content.isEmpty }
    }

    /// Result of `openTab`. The View uses it to drive side
    /// effects (= optional analytics / telemetry in a future
    /// ticket) + for tests to assert what opened.
    struct OpenCardResult: Sendable {
        /// ID of the tab that was created (= nil when the call was
        /// a silent no-op = no content in scope OR a duplicate-tab
        /// switch).
        let openedTabId: UUID?
        /// True when an existing tab was reused (= the duplicate-
        /// tab fingerprint matched; = the call did NOT create a new
        /// tab but DID switch activeTabId).
        let didSwitchExistingTab: Bool
        /// Length of the resolved content (= 0 = silent no-op; >0
        /// = a tab was opened or an existing tab was switched to).
        let contentLength: Int
        init(openedTabId: UUID?, didSwitchExistingTab: Bool,
             contentLength: Int) {
            self.openedTabId = openedTabId
            self.didSwitchExistingTab = didSwitchExistingTab
            self.contentLength = contentLength
        }
    }

    // MARK: - Compute (= scope switch + filter + body load)

    /// Compute the `(path, content, title)` triad for the given
    /// preview scope (= the part all 3 views duplicated verbatim).
    /// Mirrors WorkspaceView.openCardInEditor's switch body:
    /// - `.referenceScope(category)` → filter entities by layer +
    ///   category + pick the requested source (= `CardSource.reference`)
    ///   or fall back to `filtered.first` (= legacy behavior);
    ///   load the body via `bookStore.referenceStore.loadReferenceBody
    ///   (id:)` (= falls back to `reference.summary`).
    /// - `.bookScope(bookId, folderName)` → if the caller passed a
    ///   `.bookDoc(source)` use its doc (= correct book doc per
    ///   BOSS 9/8 fix); otherwise return a deferred triad (=
    ///   empty content). ZoneModuleView's view-local file-scan
    ///   overrides this triad before calling `openTab`.
    /// - `.shelfScope` / `.empty` → empty triad.
    static func computeCardTriad(
        source: CardSource?,
        previewScope: PreviewScope,
        bookStore: BookStore?
    ) -> CardTriad {
        switch previewScope {
        case .referenceScope(let category):
            let entities: [Reference] = (try? bookStore?.referenceStore.loadAllReferences()) ?? []
            let filtered = entities.filter { entity in
                entity.layer == .layerEntities
                    && (category == nil || entity.category == category)
            }
            // BOSS 9/8 fix: if the caller passed the actually-
            // clicked CardSource, use its entity (= correct card).
            // Otherwise fall back to filtered.first (= legacy
            // behavior for callers that don't pass source).
            let pickedReference: Reference? = {
                if case .reference(let r) = source { return r }
                return filtered.first
            }()
            if let first = pickedReference {
                let body = bookStore?.referenceStore.loadReferenceBody(id: first.id) ?? first.summary
                return CardTriad(
                    path: nil,  // reference is library-public; ticket 027-35 will resolve
                    content: body,
                    title: first.title
                )
            }
            return CardTriad(
                path: nil,
                content: "",
                title: category?.displayName ?? WenshuI18n.t("tab.title.reference_library")
            )
        case .bookScope:
            // Deferred to ticket 027-35: PreviewPane's private
            // loadBookDocs helper is the source of truth for bookDoc
            // discovery; = WorkspaceView doesn't share it. v0.34
            // fallback = silent no-op (= no .alert, no popup = user
            // feedback comes from PreviewPane being empty).
            // BOSS 9/8 fix: if the caller passed a .bookDoc source,
            // use its doc (= correct book doc).
            if case .bookDoc(let doc) = source {
                // BookDoc doesn't carry an absolute path (= only
                // fileName + folderName per PreviewPane L159).
                // path = nil (= PreviewPane's own loadBookDocs owns
                // the path resolution; = ticket 027-35 will lift
                // BookDocLoader into a shared service that returns
                // the absolute path).
                //
                // PreviewPane.loadBookDocs (= L764) returns docs
                // with .summary as the only body content (= real
                // .md body loading is deferred to ticket 027-35;
                // = the previous behavior was silent no-op).
                // Use .summary here (= matches the fallback that
                // loadReferenceBody → first.summary already uses for
                // reference docs).
                return CardTriad(path: nil, content: doc.summary, title: doc.title)
            }
            return CardTriad(path: nil, content: "", title: "book-doc")
        case .shelfScope, .empty:
            return CardTriad(path: nil, content: "", title: "")
        }
    }

    // MARK: - Open (= dedup + new tab)

    /// Open a card in the editor given a resolved triad. Mirrors
    /// WorkspaceView.openCardInEditor's tail body (= dedup check +
    /// EditorTab construction + appState.openTabs.append +
    /// activeTabId mutation):
    /// 1. Guard `!triad.content.isEmpty` (= silent no-op per boss
    ///    9/3 'no .alert noise').
    /// 2. Duplicate-tab check (= first-200-char fingerprint vs
    ///    `appState.openTabs[*].originalBody.prefix(200)`); when
    ///    matched, switch `activeTabId` to that tab + return
    ///    `didSwitchExistingTab=true`.
    /// 3. Otherwise, create `EditorTab(id: UUID(), documentPath:
    ///    triad.path, draft: triad.content, originalBody:
    ///    triad.content, mode: .preview, title: triad.title.isEmpty
    ///    ? nil : triad.title)` (= v1.0.0-m1-shell boss 2026-09-12
    ///    OOB 'tab title didn't go to the document name bug' =
    ///    pass title so tab strip shows the real card name instead
    ///    of 'preview-sample') + set `newTab.sourceScope =
    ///    previewScope` (= v0.40 boss 9/7 'card zone should show
    ///    in progress card' = drives sidebar selection on restore)
    ///    + append to `appState.openTabs` + set `appState.activeTabId
    ///    = newTab.id` (= Safari multi-tab strip behavior per
    ///    v0.34 B-26-FIX).
    static func openTab(
        triad: CardTriad,
        previewScope: PreviewScope,
        appState: AppState,
        mode: EditorMode = .preview
    ) -> OpenCardResult {
        let path = triad.path
        let content = triad.content
        let title = triad.title

        // No content (= no reference in scope OR bookDoc deferred).
        // Silent no-op per boss 9/3 feedback (= no .alert noise).
        guard !content.isEmpty else {
            return OpenCardResult(openedTabId: nil,
                                 didSwitchExistingTab: false,
                                 contentLength: 0)
        }

        // Duplicate-tab check (= boss 9/3 OOB core requirement).
        // If any existing tab's `originalBody` (= the on-disk content
        // = canonical identity, more stable than draft which can be
        // dirty) matches our new content, switch to that tab instead
        // of opening a duplicate. Safari behavior.
        //
        // Content fingerprint = first 200 chars (= fast; = sufficient
        // since the chance of two distinct .md files sharing the
        // first 200 chars is negligible).
        let fingerprint = String(content.prefix(200))
        if let existingIdx = appState.openTabs.firstIndex(where: {
            String($0.originalBody.prefix(200)) == fingerprint
        }) {
            appState.activeTabId = appState.openTabs[existingIdx].id
            // (No edit / no new tab — reuse the existing one.)
            return OpenCardResult(openedTabId: nil,
                                 didSwitchExistingTab: true,
                                 contentLength: content.count)
        }

        // No duplicate. Open as new tab (= reuse current tab if clean,
        // otherwise append).
        let newTab = EditorTab(
            id: UUID(),
            documentPath: path,
            draft: content,
            originalBody: content,
            mode: mode,
            // v1.0.0-m1-shell boss 2026-09-12 OOB 'tab title didn't go to the document name bug':
            // pass title so tab strip shows the real card name
            // instead of 'preview-sample'.
            title: title.isEmpty ? nil : title
        )
        // v0.40 boss 9/7 OOB 'card zoneshouldshowin progress
        // card': capture the scope where this doc was opened
        // from (= drives sidebar selection + preview cards on
        // restore). = .referenceScope(cat) for library refs,
        // = .bookScope(bookId, folder) for book docs, etc.
        newTab.sourceScope = previewScope
        // v0.34 B-26-FIX (= boss 9/3 'first double-click can switch, not a new tab, it replaces
        // the old tab'): always append a new tab (= Safari multi-tab strip
        // behavior). Duplicate-tab detection (= the fingerprint check
        // earlier in this function) handles the "switch to existing
        // tab if same .md is open" case (= boss 9/3 'check whether an existing tab
        // already opened the current MD'). = no replacement of the active tab;
        // = no "second click fails" race.
        appState.openTabs.append(newTab)
        appState.activeTabId = newTab.id
        return OpenCardResult(openedTabId: newTab.id,
                             didSwitchExistingTab: false,
                             contentLength: content.count)
    }
}