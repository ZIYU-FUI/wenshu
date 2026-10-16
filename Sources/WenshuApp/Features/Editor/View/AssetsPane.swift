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
    let appState: AppState
    // previewSortOrder / sidebarSelection / activeTag live in
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // tracking on every body render).
    @Bindable var workspaceUI: WorkspaceUIState
    // `openCardInEditor` needs `BookStore.referenceStore` to load
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // fallback in `openCardInEditor`).
    @Environment(BookStore.self) private var envBookStore

    private var bookStore: BookStore? { envBookStore }

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
                    HStack(spacing: DesignTokens.spacingIconic) {
                        SFIcon("magnifyingglass", style: .inlineSmall, color: IconColor.secondary)
                        TextField(
                            String(localized: "preview.search.placeholder"),
                            text: Binding(
                                get: { envAppState.searchText },
                                set: { newValue in envAppState.searchText = newValue }
                            )
                        )
                        // Apply `.controlSize(.regular)` (= the canonical
                        // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // NavigationSplitView).
                        .controlSize(.regular)
                        .textFieldStyle(.plain)
                    }
                    // Total height = 22 PT
                    // … (= 34 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // gutter).
                    .padding(.horizontal, DesignTokens.spacingModerate)
                    .padding(.vertical, DesignTokens.spacingStandard)
                    .frame(maxWidth: .infinity)
                    // 2026-10-12 boss directive "素材栏里写的搜索
                    // … (= 18 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // unchanged but the surface is transparent).
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard, style: .continuous)
                            .fill(Color.clear)
                    )
                    // The search field,
                    // … (= 34 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // left; = no visual change inside the field).
                    .frame(maxWidth: .infinity)
                    // 2026-10-12 boss directive round 2 "还在, 黑
                    // … (= 23 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // invisible until the user types.
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard, style: .continuous)
                            .fill(Color.clear)
                    )
                    // Search field
                    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // '' aesthetic per the search-field rhythm.
                )
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
                    }
                }
            }
            // Header (= assets + divider
            // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // the column-top chrome).
        }
    }
}
