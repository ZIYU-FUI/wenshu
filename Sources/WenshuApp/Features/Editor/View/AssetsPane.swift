// ShellMiddleColumn.swift · Wenshu
// … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
// - ShellDetailColumn
import SwiftUI
import os.log

// / Apple HIG content column (= 1 zone: the card grid).
// … (= 22 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / too and the card zone owns the full column height.
struct AssetsPane: View {
    // The cards column did not re-render when the user clicked a
    // … (= 20 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // observation tracking inside body.
    @Bindable var envAppState: AppState
    // previewSortOrder / sidebarSelection / activeTag live in
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // tracking on every body render).
    @Bindable var workspaceUI: WorkspaceUIState
    // `openCardInEditor` needs `BookStore.referenceStore` to load
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // fallback in `openCardInEditor`).
    @Environment(BookStore.self) private var envBookStore

    /// The cover services this pane shares.
    ///
    /// ONE holder, so the batch and the card menu hold ONE per-card
    /// lock. Two services would be two locks, and a batch run and a
    /// manual click on the same card would each spend an image call.
    @State private var coverServices = CoverPaneServices.live()

    /// Whether a batch is running right now.
    @State private var isBatchRunning = false

    private var bookStore: BookStore? { envBookStore }

    /// Starts the cover batch.
    ///
    /// The batch covers every document in the library that lacks a
    /// cover. It runs ONE document at a time (= the image allowance
    /// is large but not unlimited, and a burst would spend it on
    /// documents the user may not care about), and it can be stopped.
    private func startCoverBatch() {
        let service = coverServices.batch
        isBatchRunning = true
        Task { @MainActor in
            await service.run(for: coverCandidates())
            isBatchRunning = false
        }
    }

    /// The documents the cover paths consider.
    ///
    /// Every reference and every book doc in the library. The batch
    /// skips the ones that already have a cover, and the automatic
    /// pass skips the ones the policy says belong to the batch (= the
    /// documents that were already here when the switch was turned
    /// on), so this is the whole set for both paths.
    private func coverCandidates() -> [CoverCandidate] {
        guard let bookStore else { return [] }
        let references = (try? bookStore.loadAllReferences()) ?? []
        let referenceItems = references.map { reference in
            CoverCandidate(
                target: .reference(reference.id),
                title: reference.title,
                summary: reference.summary,
                createdAt: reference.createdAt
            )
        }
        // The book docs come from the shelves walk, the same way the
        // grid gets them.
        var bookItems: [CoverCandidate] = []
        for book in bookStore.books {
            let docs = PreviewPaneOps.loadBookDocs(
                bookStore: bookStore,
                bookId: book.id,
                folderName: nil
            ).docs
            bookItems += docs.map { doc in
                CoverCandidate(
                    target: .bookDoc(doc.id),
                    title: doc.title,
                    summary: doc.summary,
                    createdAt: doc.createdAt
                )
            }
        }
        return referenceItems + bookItems
    }

    /// Gives the documents that arrived later their own covers.
    ///
    /// The trigger asks the policy, and the policy is what knows the
    /// difference between "already here" and "comes later". This
    /// method only hands the trigger the documents and lets it
    /// decide.
    private func coverNewDocuments() async {
        await coverServices.autoTrigger.coverNewDocuments(coverCandidates())
    }

    // `previewSortOrder` lives in `envAppState.previewSortOrder`
    // … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // column body (= body re-renders on every mutation).
    private var searchText: String {
        get { envAppState.searchText }
        nonmutating set { envAppState.searchText = newValue }
    }

    // / Tree selection → cards column. Selecting `.book(worldview)`
    // … (= 35 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / correctly.
    private func previewScope() -> PreviewScope {
        // Read from `envAppState` (= the @Environment-tracked
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // never re-rendered).
        switch workspaceUI.sidebarSelection {
        case .referenceLibraryRoot:
            return .referenceScope(nil)
        case .referenceUnclassified:
            // The catch-all row (= the references no category claims). It
            // resolves to the same scope the library root row uses.
            return .referenceScope(nil)
        case .referenceCategory(let dirName):
            // SidebarItem.referenceCategory(directoryName) carries
            // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // overview.
            if let raw = EntityCategory(rawValue: dirName) {
                return .referenceScope(raw)
            }
            let upper = dirName.uppercased()
            if let raw = EntityCategory(rawValue: upper) {
                return .referenceScope(raw)
            }
            return .referenceScope(nil)
        case .book(let bookId):
            return .bookScope(bookId: bookId, folderName: nil)
        case .shelf(let shelfId):
            return .shelfScope(shelfId: shelfId)
        case .folder(let bookId, let folderName):
            return .bookScope(bookId: bookId, folderName: folderName)
        case .tag(let tagString):
            // tag is a dedicated PreviewScope
            // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // .referenceScope(nil) routing path elsewhere).
            return .tagScope(tagString)
        case nil:
            return .referenceScope(nil)
        }
    }

    // The card double-click handler reads the actually-clicked
    // … (= 77 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / throwaway).
    private func openCardInEditor(source: CardSource?) {
        let scope = previewScope()
        // "多次双击"清明"，没有打开" — log (see OOB.md #2026-07-23)
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // double-click does not produce a tab).
        os_log("[wenshu.assets] v0.74 openCardInEditor entry source=%{public}@ scope=%{public}@",
               source.map { String(describing: $0) } ?? "nil",
               String(describing: scope))
        let triad: CardOpenOps.CardTriad
        if let source {
            // the source through the scope branch
            // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // - .bookDoc → .bookScope(bookId, folderName)
            let sourceScope: PreviewScope
            switch source {
            case .reference(let ref):
                let category: EntityCategory? = ref.category
                sourceScope = .referenceScope(category)
            case .bookDoc(let doc):
                sourceScope = .bookScope(
                    bookId: doc.bookId,
                    folderName: doc.folderName
                )
            }
            os_log("[wenshu.assets] v0.74 openCardInEditor sourceScope=%{public}@",
                   String(describing: sourceScope))
            triad = CardOpenOps.computeCardTriad(
                source: source,
                previewScope: sourceScope,
                bookStore: bookStore
            )
        } else {
            // No source (= the
            // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // compatibility).
            triad = CardOpenOps.computeCardTriad(
                source: nil,
                previewScope: scope,
                bookStore: bookStore
            )
        }
        _ = CardOpenOps.openTab(
            triad: triad,
            previewScope: scope,
            appState: envAppState,
            mode: .edit
        )
    }

    var body: some View {
        // + 'we only need the original assets cards':
        // … (= 60 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // correctly; = survives PreviewPane re-instantiation).
        VStack(spacing: 0) {
            // 2026-10-12 [archived-round] boss directive "你看其它三
            // … (= 98 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // updates the other live (= the same envAppState.searchText).
            PreviewPane(
                scope: previewScope(),
                // Card double-click opens the document in the editor pane
                // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // name' regression).
                onDoubleClick: { source in
                    openCardInEditor(source: source)
                },
                previewSortOrder: $workspaceUI.previewSortOrder,
                searchQuery: Binding<String?>(
                    get: { envAppState.searchText },
                    set: { newValue in envAppState.searchText = newValue ?? "" }
                ),
                customLeadingSearch: AnyView(
                    // Column-top chrome band wrapping the search field
                    // (= same shape as the editor zone's top bar; = 28 PT
                    // height + Divider + 8 PT horizontal padding; = the
                    // single source of truth for "column-top chrome row in
                    // wenshu" lives in ChromeTopBar; = no duplicate
                    // chrome geometry per the 41-rule audit + AGENTS §6.2).
                    // RATIONALE: boss 2026-10-16 OOB "给素材区顶部的搜索框, 套上
                    // 一个和编辑器区一样的顶栏" — editor's chrome band is
                    // already the canonical column-top shape; the search
                    // field is the only thing living above the cards grid
                    // (= the assets zone's analog to the editor's title bar
                    // above the NSTextView).
                    ChromeTopBar(usesMaterial: false) {
                        // Search field body lives INSIDE the chrome band's
                        // leading slot (= title cluster replaced). Per
                        // Apple HIG macOS toolbar pattern, the icons sit
                        // inline with the input; = no inner-padded
                        // TextField wrapper (= the 28 PT chrome band itself
                        // provides the row height). The two prior
                        // RoundedRectangle(.clear) backgrounds were no-ops
                        // (= previous round dropped the inner pill
                        // background; the chrome band is the surface now).
                        HStack(spacing: DesignTokens.spacingIconic) {
                            SFIcon(
                                "magnifyingglass",
                                style: .inlineSmall,
                                color: IconColor.secondary
                            )
                            TextField(
                                String(localized: "preview.search.placeholder"),
                                text: Binding(
                                    get: { envAppState.searchText },
                                    set: { newValue in
                                        envAppState.searchText = newValue
                                    }
                                )
                            )
                            .controlSize(.regular)
                            .textFieldStyle(.plain)
                        }
                        .frame(height: DesignTokens.paneTabHotArea)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: DesignTokens.paneTabHotArea)
                ),
                // The SAME cover services the batch uses, so the card
                // menu and the batch hold ONE per-card lock between
                // them (= a batch run and a manual click on the same
                // card make one image call, not two).
                coverServices: coverServices
            )
            // 2026-10-12 boss directive "在素材栏也加一个底栏,
            // … (= 45 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // attachment pattern).
            .frame(maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ChromeBottomFooter {
                    HStack(spacing: DesignTokens.spacingTight) {
                        // 2026-10-12 [archived-round] boss directive "先这
                        // … (= 22 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // share the same icon cap height).
                        SFIcon("tray.full", style: .inlineSmall, color: IconColor.secondary)
                        Text(String.localizedStringWithFormat(
                            NSLocalizedString("assets.count.label", comment: ""),
                            PreviewPaneOps.countCardsInScope(
                                scope: previewScope(),
                                bookStore: bookStore,
                                searchQuery: envAppState.searchText
                            )
                        ))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        Spacer()
                        // The batch action (= the STOCK half of the
                        // user's rule: = the documents that are already
                        // in the library get their covers when the
                        // user asks, in one action, here).
                        //
                        // It covers every document that lacks a cover,
                        // rather than a selection: the pane has no
                        // multi-select, and adding one for this would
                        // change the pane's selection model for a
                        // feature the user did not ask for.
                        //
                        // The documents that arrive LATER get their
                        // covers on their own (= the automatic pass,
                        // = a settings switch).
                        if isBatchRunning {
                            // The progress, so a long run is not a
                            // frozen pane. The counts come from the
                            // runner, so they are the truth rather
                            // than an estimate.
                            //
                            // The spinner is MINI, so the progress row
                            // is the height of the text beside it: a
                            // regular spinner is taller than the
                            // footer's fixed content row and would
                            // push the bar's top edge up out of line
                            // with the other columns' bars.
                            ProgressView()
                                .controlSize(.mini)
                            Text(String.localizedStringWithFormat(
                                NSLocalizedString("cover.batch.progress", comment: ""),
                                coverServices.batch.progress.completed,
                                coverServices.batch.progress.skipped,
                                coverServices.batch.progress.failed
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            // The stop action reads as one line of
                            // text with an action in it, for the same
                            // reason the make-all action does.
                            Button(String(localized: "cover.action.stop")) {
                                coverServices.batch.stop()
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else {
                            // The action is PLAIN (= no border) and in
                            // the SAME text tier as the count beside
                            // it (= `.callout`).
                            //
                            // WHY: the shared footer's content row is
                            // a fixed height (= the height of one
                            // `.callout` line), so a default-size
                            // bordered button would not fit inside it.
                            // It inflated the materials column's bar
                            // past the sidebar's and the chat's, and
                            // the three bars' top edges stopped
                            // lining up. The action stays a button
                            // with the same label and the same
                            // behaviour; only its size and its border
                            // changed.
                            Button(String(localized: "cover.action.makeAll")) {
                                startCoverBatch()
                            }
                            .buttonStyle(.plain)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            // The automatic pass for the documents that arrive LATER.
            //
            // The material zone is where a new document becomes
            // visible, and this is the point where that happens: the
            // pane reloads when the library changes, and the trigger
            // is asked about the documents it now sees. The trigger
            // decides, using the policy, whether each one is
            // automatic (= created after the switch was turned on)
            // or belongs to the batch.
            //
            // Every path that brings a document in announces that the
            // library changed: the import, the sidebar's own writes,
            // and the agent's writes. So a document the agent wrote
            // reaches this pass as soon as it lands.
            .onReceive(NotificationCenter.default.publisher(for: .wenshuLibraryDidChange)) { _ in
                Task { @MainActor in
                    await coverNewDocuments()
                }
            }
            .task {
                await coverNewDocuments()
            }
            // Header (= assets + divider
            // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // the column-top chrome).
        }
    }
}
