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
                    // Column-top chrome band wrapping the search field
                    // (= same shape as the editor zone's top bar; = 28 PT
                    // height + Divider + 8 PT horizontal padding; = the
                    // single source of truth for "column-top chrome row in
                    // wenshu" lives in EditorHeaderView; = no duplicate
                    // chrome geometry per the 41-rule audit + AGENTS §6.2).
                    // RATIONALE: boss 2026-10-16 OOB "给素材区顶部的搜索框, 套上
                    // 一个和编辑器区一样的顶栏" — editor's chrome band is
                    // already the canonical column-top shape; the search
                    // field is the only thing living above the cards grid
                    // (= the assets zone's analog to the editor's title bar
                    // above the NSTextView).
                    EditorHeaderView {
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
                    }
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
