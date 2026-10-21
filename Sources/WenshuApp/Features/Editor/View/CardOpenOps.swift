// CardOpenOps.swift · Wenshu Card-open business layer (= reference filter + body load +
// bookDoc load + duplicate-tab detection + EditorTab construction + appState mutation)
// is a single concern that was duplicated 3x. This helper lifts the business layer
// into a stateless enum so the 3 views call one shared function. Why a stateless enum
// (not an @Observable class): - The business logic is a single, atomic operation (=
// open one card in the editor) with no persistent state. - The 3 callers differ only
// in how they expose `previewScope` (= computed var / func / @Environment read); = Ops
// accepts a value `PreviewScope` (= the seam that lets tests pass any scope without
// standing up a view). - Per the settings-kanban precedent (= KanbanOps
// / SettingsOps = stateless enums with @MainActor static funcs), the wenshu MVVM shape
// is "enum + static + Result types", not "@Observable class ViewModel". Why
// `bookStore: BookStore?` (nil-able): - `referenceStore.loadAllReferences()` is the
// only IO call (= optional anyway: `(try? bookStore.referenceStore.loadAllRef…)` in
// the original View code). - nil bookStore (= the rare on-launch race where the
// sidebar's click lands before BookStore is ready) → empty entities → silent no-op (=
// matches the existing 3 view bodies' behaviour verbatim). All methods are @MainActor-
// isolated because: - The 3 callers are @MainActor views. - The mutation
// (`appState.openTabs.append` + activeTabId = newTab.id) is on @MainActor. Public
// surface (= 2 entry points): - computeCardTriad(source:previewScope:bookStore:) ->
// CardTriad - openTab(triad:previewScope:appState:) -> OpenCardResult Why 2 entry
// points (not 1): - WorkspaceView's openCardInEditor handles only the reference- scope
// + bookScope-deferred paths (= [archived] will lift the BookDocLoader into a
// shared service). - The preview pane's openCardInEditor adds a filesystem scan in the
// bookScope case (= walk shelves/<shelf-uuid>/books/ <book-uuid>/<folder>/*.md and
// pick the first .md). That scan stays in the View (= too view-specific to lift; =
// [archived] will replace it). - The shared part = the dedup check + EditorTab
// construction + appState.openTabs.append + activeTabId mutation. That's what
// `openTab` does (= the body that all 3 views duplicated verbatim after the scope
// switch). - `computeCardTriad` wraps the reference-scope filter + body load (= the
// part all 3 views duplicated verbatim). The book- scope case in `computeCardTriad`
// returns a "deferred" triad (= silent no-op); the preview pane's view-local file-scan
// overrides that triad before calling `openTab`. Out of scope (= NOT moved here, stays
// in View): - `previewScope` derivation (= the view-local computed var / func that
// reads `workspaceUI.sidebarSelection`). Ops accepts a value `PreviewScope`; = the
// view computes the value first then calls Ops. - The view-local `previewScope` + call
// sites (= the .button action that triggers the open). Ops is invoked from each view's
// call site; = the gesture / button stays in the view.

import Foundation
import os.log

/// Stateless business layer for opening a card in the editor.
/// Lifts the duplicated openCardInEditor (= the 3 verbatim copies
/// that lived in the now-deleted WorkspaceView /
/// ShellMiddleColumn) into a single shared function (= UI /
/// business logic / data separation audit per ADR-0009).
@MainActor
enum CardOpenOps {

    /// Resolved card content (= the trio the 3 view-local helpers
    /// all computed as `let (path, content, title)`). Empty
    /// content means "silent no-op" (= the caller checks
    /// `content.isEmpty` per (see OOB.md #2026-09-03) — 'no .alert noise' rule).
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
    ///   (see OOB.md #2026-09-08) — fix; otherwise return a deferred triad (=
    ///   empty content). The preview pane's view-local file-scan
    ///   overrides this triad before calling `openTab`.
    /// - `.shelfScope` / `.empty` → empty triad.
    static func computeCardTriad(
        source: CardSource?,
        previewScope: PreviewScope,
        bookStore: BookStore?
    ) -> CardTriad {
        switch previewScope {
        case .referenceScope(let category):
            let entities: [Reference] = (try? bookStore?.loadAllReferences()) ?? []
            let filtered = entities.filter { entity in
                entity.layer == .layerEntities
                    && (category == nil || entity.category == category)
            }
            // (see OOB.md #2026-09-08) — fix: if the caller passed the actually- clicked
            // CardSource, use its entity (= correct card). Otherwise fall
            // back to filtered.first (= legacy behavior for callers that
            // don't pass source).
            let pickedReference: Reference? = {
                if case .reference(let r) = source { return r }
                return filtered.first
            }()
            // "多次双击"清明"，没有打开" — log (see OOB.md #2026-07-23) the picked reference's body
            // + summary so the boss can grep whether the body came back
            // empty (= the silent no-op in openTab fires when
            // triad.content = "" and no tab is appended).
            if let first = pickedReference {
                let body = bookStore?.loadReferenceBody(id: first.id) ?? first.summary
                let bodyPreview = body.isEmpty ? "EMPTY" : String(body.prefix(80))
                let summaryPreview = first.summary.isEmpty ? "EMPTY" : String(first.summary.prefix(80))
                os_log("[wenshu.card] v0.74 referenceScope picked id=%{public}@ title=%{public}@ bodyLen=%{public}d bodyPreview=%{public}@ summaryPreview=%{public}@ bookStoreNil=%{public}@",
                       first.id.uuidString,
                       first.title,
                       body.count,
                       bodyPreview,
                       summaryPreview,
                       bookStore == nil ? "true" : "false")
                return CardTriad(
                    // 2026-10-14: assign the canonical single-file reference path instead
                    // of nil. The previous nil path (= 027-35 left
                    // a TODO to "resolve later") caused the
                    // editor's auto-save to fall through to
                    // /tmp/wenshu-preview-sample.md because the
                    // path-aware save path (= path =
                    // "<libraryRoot>/chapters /<uuid>.md") only
                    // fires when `tab.documentPath != nil`. With a
                    // real reference path, the auto-save writes
                    // the reference body to
                    // `<libraryRoot>/references /<uuid>.md` (= the
                    // new doc-truth single-source location), and
                    // the next launch's `restoreOpenTabs` (= the
                    // 2026-10-14 v6 fix that re-reads `tab.draft`
                    // from `tab.documentPath`) loads the user's
                    // edits back. Without the path, the user's
                    // reference edits were lost across relaunch (=
                    // the boss 2026-10-14 (see OOB.md #2026-10-14)
                    // 保存机制是假的" report).
                    path: bookStore.flatMap {
                        FileSystemReferenceStore
                            .referenceFileURL(
                                id: first.id,
                                referenceLibraryRoot:
                                    $0.stores.referenceLibraryRoot
                            )
                            .path
                    },
                    content: body,
                    title: first.title
                )
            }
            return CardTriad(
                path: nil,
                content: "",
                title: category?.displayName ?? String(localized: "tab.title.reference_library")
            )
        case .bookScope:
            // Deferred to [archived]: PreviewPane's private loadBookDocs helper is the
            // source of truth for bookDoc discovery; = WorkspaceView
            // doesn't share it. fallback = silent no-op (= no .alert, no
            // popup = user feedback comes from PreviewPane being empty).
            // (see OOB.md #2026-09-08) — fix: if the caller passed a
            // .bookDoc source, use its doc (= correct book doc).
            if case .bookDoc(let doc) = source {
                // (= boss 2026-10-10 "指 定目录 实现 了 ， 但 导 入 的 内 容 少 了 好 我" feedback): the
                // previous implementation returned only `doc.summary`
                // (= the 200-char preview prefix = the user saw only
                // 元信息 + 8 行 反链 but NOT the actual 534-line 故事宪法 body).
                // Fix: read the full .md file via the same path
                // resolution that `SidebarService.findBookDocFile`
                // uses for rename/delete; = the user now sees the
                // complete body (= ~200x more content for the 故事宪法
                // case).
                if let loaded = bookStore.flatMap({
                    CardOpenOps.loadBookDoc(shelvesRoot: $0.stores.shelvesRoot, doc: doc)
                }) {
                    return CardTriad(
                        // 2026-10-14: set the on-disk file URL as the doc-truth path. The
                        // previous `path: nil` forced the
                        // editor's auto-save to fall through
                        // to `/tmp/wenshu-preview-sample.md`
                        // (= the boss 2026-10-14 (see OOB.md
                        // #2026-10-14) gone). The
                        // `loadBookDoc` overload returns both
                        // the body and the URL (= see its
                        // docstring for the wenshu canonical
                        // doc-truth surface rationale).
                        path: loaded.url.path,
                        content: loaded.body,
                        title: doc.title
                    )
                }
                // Fallback (= the file is gone OR path resolution failed): show the
                // 200-char summary (= better than blank).
                return CardTriad(
                    path: nil,
                    content: doc.summary,
                    title: doc.title
                )
            }
            return CardTriad(path: nil, content: "", title: "book-doc")
        case .shelfScope, .empty:
            return CardTriad(path: nil, content: "", title: "")
        case .tagScope(let tag):
            // tagScope opens a reference entity (= the same triad shape as
            // .referenceScope; = the editor opens the document by id; =
            // tag is a facet of the reference, not a separate document
            // type). The preview pane routes .tagScope through this helper via the
            // .referenceScope branch (= see its switch; = this case is
            // here for exhaustiveness and to keep the editor's sourceScope
            // Codable for .tagScope pickling across launches).
            let entities: [Reference] = (try? bookStore?.loadAllReferences()) ?? []
            let filtered = entities.filter { entity in
                entity.layer == .layerEntities && entity.tags.contains(tag)
            }
            let pickedReference: Reference? = {
                if case .reference(let r) = source, r.tags.contains(tag) { return r }
                return filtered.first
            }()
            if let first = pickedReference {
                let body = bookStore?.loadReferenceBody(id: first.id) ?? first.summary
                return CardTriad(
                    path: nil,
                    content: body,
                    title: first.title
                )
            }
            return CardTriad(
                path: nil,
                content: "",
                title: tag
            )
        }
    }

    // MARK: - Open (= dedup + new tab)

    /// Open a card in the editor given a resolved triad. Mirrors
    /// WorkspaceView.openCardInEditor's tail body (= dedup check +
    /// EditorTab construction + appState.openTabs.append +
    /// activeTabId mutation):
    /// 1. Guard `!triad.content.isEmpty` (= silent no-op per (see OOB.md #2026-09-03)
    ///    9/3 'no .alert noise').
    /// 2. Duplicate-tab check (= first-200-char fingerprint vs
    ///    `appState.openTabs[*].originalBody.prefix(200)`); when
    ///    matched, switch `activeTabId` to that tab + return
    ///    `didSwitchExistingTab=true`.
    /// 3. Otherwise, create `EditorTab(id: UUID(), documentPath:
    ///    triad.path, draft: triad.content, originalBody:
    ///    triad.content, mode: .preview, title: triad.title.isEmpty
    ///    ? nil : triad.title)` (=
    ///    OOB 'tab title didn't go to the document name bug' =
    ///    pass title so tab strip shows the real card name instead
    ///    of 'preview-sample') + set `newTab.sourceScope =
    ///    previewScope` ((see OOB.md #2026-09-07) — 'card zone should show
    ///    in progress card' = drives sidebar selection on restore)
    ///    + append to `appState.openTabs` + set `appState.activeTabId
    ///    = newTab.id` (= Safari multi-tab strip behavior per
    /// -FIX).
    static func openTab(
        triad: CardTriad,
        previewScope: PreviewScope,
        appState: AppState,
        mode: EditorMode = .preview
    ) -> OpenCardResult {
        let path = triad.path
        let content = triad.content
        let title = triad.title

        // No content (= no reference in scope OR bookDoc deferred). Silent no-op per (see
        // OOB.md #2026-09-03) — feedback (= no .alert noise).
        guard !content.isEmpty else {
            return OpenCardResult(openedTabId: nil,
                                 didSwitchExistingTab: false,
                                 contentLength: 0)
        }

        // Duplicate-tab check ((see OOB.md #2026-09-03) — core requirement). If any
        // existing tab's `originalBody` (= the on-disk content = canonical
        // identity, more stable than draft which can be dirty) matches our new
        // content, switch to that tab instead of opening a duplicate. Safari
        // behavior. Content fingerprint = first 200 chars (= fast; =
        // sufficient since the chance of two distinct .md files sharing the
        // first 200 chars is negligible).
        let fingerprint = String(content.prefix(200))
        if let existingIdx = appState.openTabs.firstIndex(where: {
            String($0.originalBody.prefix(200)) == fingerprint
        }) {
            // 2026-10-14: doc-truth-git ticket. The previous behavior was to switch to
            // the existing tab without updating its `documentPath`. With
            // the new single-file truth location (= this `CardTriad.path`
            // is now the doc-truth per-reference file path produced by
            // `FileSystemReferenceStore .referenceFileURL`), an existing
            // tab opened by an older build may still carry `documentPath =
            // nil` (= the pre-doc-truth-git reference tab shape; = the
            // `EditorPersistence.save` path-aware write fell through to
            // `/tmp/wenshu-preview-sample.md` for those tabs; = the user's
            // edits were lost across relaunch). Force the existing tab to
            // adopt the new `documentPath` (= the doc-truth file) so
            // subsequent auto-saves land in the right place. The
            // `originalBody` is also refreshed (= the file content on the
            // doc-truth disk is the new canonical baseline; = otherwise
            // the tab would appear dirty on first edit after the migration
            // and the user would have to re-save the migrated body to
            // clear the 已保存 -> 未保存 indicator).
            appState.openTabs[existingIdx].documentPath = path
            appState.openTabs[existingIdx].originalBody = content
            appState.openTabs[existingIdx].draft = content
            appState.activeTabId = appState.openTabs[existingIdx].id
            return OpenCardResult(openedTabId: nil,
                                 didSwitchExistingTab: true,
                                 contentLength: content.count)
        }

        // No duplicate. Open as new tab (= reuse current tab if clean, otherwise append).
        let newTab = EditorTab(
            id: UUID(),
            documentPath: path,
            draft: content,
            originalBody: content,
            mode: mode,
            // Pass title so tab strip shows the real card name instead of 'preview-
            // sample'.
            title: title.isEmpty ? nil : title
        )
        // "多次双击"清明"，没有打开" (= the (see OOB.md #2026-07-23) double-click fires
        // onDoubleClick on the Card, but the tab never appears in the strip; =
        // either the append hits an exception, or activeTabId is not set, or
        // SwiftUI doesn't re-render the strip). Log every successful open so
        // the boss can grep Console.app to confirm whether the tab was created
        // at all.
        let openTabsCountBefore = appState.openTabs.count
        // Capture the scope where this doc was opened from (= drives sidebar selection +
        // preview cards on restore). = .referenceScope(cat) for library refs,
        // = .bookScope (bookId, folder) for book docs, etc.
        newTab.sourceScope = previewScope
        // Always append a new tab (= Safari multi-tab strip behavior). Duplicate-tab
        // detection (= the fingerprint check earlier in this function) handles
        // the "switch to existing tab if same .md is open" case (= check
        // whether an existing tab already opened the current MD). = no
        // replacement of the active tab; = no "second click fails" race.
        appState.openTabs.append(newTab)
        appState.activeTabId = newTab.id
        let openTabsCountAfter = appState.openTabs.count
        os_log("[wenshu.tab] v0.74 openTab appended title=%{public}@ tabId=%{public}@ openTabs=%{public}d→%{public}d activeTabId=%{public}@ path=%{public}@",
               title.isEmpty ? "?" : title,
               newTab.id.uuidString,
               openTabsCountBefore, openTabsCountAfter,
               appState.activeTabId.uuidString,
               path ?? "nil")
        return OpenCardResult(openedTabId: newTab.id,
                             didSwitchExistingTab: false,
                             contentLength: content.count)
    }

    // MARK: - book doc body loader

    /// Load the full .md body for a `BookDoc` (= the
    /// per-file .md body in a book's folder; = e.g.
    /// the 534-line 故事宪法.md body in
    /// `12地仙/world/故事宪法.md`). The
    /// `BookDoc.id` is a UUID v5 derived from
    /// `(bookId, folderName, fileName)` (= stable
    /// across re-evaluations; = unique per .md
    /// file; = the canonical wenshu BookDoc
    /// identity). To find the file on disk, we
    /// walk the shelves root and match the
    /// `(bookId, folderName, fileName)` triple
    /// that re-derives the same UUID (= same
    /// algorithm as `SidebarService.findBookDocFile`
    /// and the orchestrator's Stage 2
    /// content-same check). Returns the body
    /// string, or `nil` if the file is gone or
    /// the walk fails (= the caller falls back to
    /// `doc.summary` for the 200-char preview).
    ///
    /// Boss 2026-10-10 feedback: "指定目录实现
    /// 了，但导入的内容少了好我"; = the
    /// 故事宪法 was imported correctly (= 534
    /// lines on disk; = see [archived-round] commit E's
    /// `prepareBodyForWrite`), but the editor
    /// only showed the 200-char `doc.summary`.
    /// Root cause: the previous
    /// `CardOpenOps.computeCardTriad` used
    /// `doc.summary` (= the 200-char thumbnail)
    /// for `.bookDoc` cases, with a comment
    /// deferring real body loading to "ticket
    /// 027-35". This helper implements that
    /// ticket (= the path resolution is small
    /// enough to inline; = no new service
    /// needed; = the test suite can mock
    /// `BookStore` and verify the walk).
    static func loadBookDocBody(
        bookStore: BookStore?,
        doc: BookDoc
    ) -> String? {
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            return nil
        }
        return loadBookDocBody(shelvesRoot: shelvesRoot, doc: doc)
    }

    /// Overload that takes the shelves root URL directly (= the
    /// unit-test entry point; = the integration entry point is
    /// the `bookStore`-taking overload above). The path
    /// resolution is the same UUID v5 walk as
    /// `SidebarService.findBookDocFile` (= see the
    /// orchestrator's Stage 2 content-same check for the
    /// identical algorithm).
    static func loadBookDocBody(
        shelvesRoot: URL,
        doc: BookDoc
    ) -> String? {
        loadBookDoc(shelvesRoot: shelvesRoot, doc: doc)?.body
    }

    /// 2026-10-14: returns both the body
    /// and the on-disk file URL (=
    /// the wenshu canonical
    /// doc-truth per-document
    /// file). The previous
    /// `loadBookDocBody` only
    /// returned the body, so the
    /// `CardOpenOps.computeCardTriad`
    /// caller had no way to set
    /// `CardTriad.path` to the
    /// real file (= it was
    /// `path: nil`; = the
    /// editor's auto-save fell
    /// through to the /tmp
    /// fallback; = the user
    /// reported the book-doc
    /// edits as "修改了不保存"
    /// = the boss 2026-10-14 (see OOB.md #2026-10-14)
    /// root cause). The
    /// `bookDoc` source passed
    /// to `computeCardTriad` is
    /// the canonical "where the
    /// doc lives on disk"
    /// surface (= the
    /// `PreviewPane.bookDocsGrid`
    /// already walks the shelves
    /// tree to populate each
    /// `BookDoc` row; = the
    /// same walk is reused here
    /// to resolve the file URL).
    /// The URL is the absolute
    /// on-disk path that the
    /// `EditorPersistence.save`
    /// writes to (= the
    /// `tab.documentPath` field;
    /// = the doc-truth-git
    /// ticket's per-document
    /// file at
    /// `<shelvesRoot>/books/<bookId>/<folderName>/<fileName>.md`).
    static func loadBookDoc(
        shelvesRoot: URL,
        doc: BookDoc
    ) -> (body: String, url: URL)? {
        guard FileManager.default.fileExists(atPath: shelvesRoot.path) else {
            return nil
        }
        let shelfDirs = (try? FileManager.default.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for shelfDir in shelfDirs {
            let booksDir = shelfDir.appendingPathComponent("books")
            guard FileManager.default.fileExists(atPath: booksDir.path) else { continue }
            let bookDirs = (try? FileManager.default.contentsOfDirectory(
                at: booksDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            for bookDir in bookDirs {
                guard UUID(uuidString: bookDir.lastPathComponent) == doc.bookId else { continue }
                let folderDirs = (try? FileManager.default.contentsOfDirectory(
                    at: bookDir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )) ?? []
                for folderDir in folderDirs where folderDir.lastPathComponent == doc.folderName {
                    let mdFiles = (try? FileManager.default.contentsOfDirectory(
                        at: folderDir,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )) ?? []
                    for mdFile in mdFiles where mdFile.pathExtension == "md" {
                        let candidate = PreviewPane.stableBookDocId(
                            bookId: doc.bookId,
                            folderName: doc.folderName,
                            fileName: mdFile.lastPathComponent
                        )
                        if candidate == doc.id {
                            guard let body = try? String(
                                contentsOf: mdFile,
                                encoding: .utf8
                            ) else { return nil }
                            return (body, mdFile)
                        }
                    }
                }
            }
        }
        return nil
    }
}
