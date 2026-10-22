//
//  PreviewPaneGrids.swift
//
//  6 grid view helpers extracted from PreviewPane.swift
//  (= §6.6 god-class split + discoverability: categoryGrid +
//  categoryGridContent + overviewGrid + emptyState + bookDocsGrid +
//  referenceCategoryCard moved out of the main file into this
//  dedicated cross-file `extension PreviewPane` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `struct PreviewPane: View` is 1279 LOC = 2.1x the 600-LOC cap. The
//  6 grid view helpers are a single concern (= "render the various
//  grid layouts in the preview pane"). Putting them in a dedicated
//  file named after the concern (= PreviewPaneGrids.swift) lets the
//  next reader find the grid logic by name.
//
//  The 6 funcs are view methods on `PreviewPane` (as a cross-file
//  extension). The 4 `beginReference*` + `beginBookDoc*` callbacks
//  were relaxed from `private func` to `func` (= internal scope; =
//  required for the cross-file `referenceCategoryCard` to call them).
//

import SwiftData
import SwiftUI
import WenshuData

extension PreviewPane {

    /// The stored cover picture for a reference card, or nil when it
    /// has no cover.
    ///
    /// The key comes from `CardCoverService`, which namespaces the two
    /// card kinds apart, so a reference card and a book card can
    /// never land on one cover.
    func coverImageURL(forReference id: UUID) -> URL? {
        coverImageURL(forKey: CardCoverService.key(forReference: id))
    }

    /// The stored cover picture for a book-doc card, or nil when it
    /// has no cover.
    func coverImageURL(forBookDoc id: UUID) -> URL? {
        coverImageURL(forKey: CardCoverService.key(forBookDoc: id))
    }

    /// The stored cover picture under a key, or nil.
    ///
    /// The lookup goes through the row, because the row is where the
    /// path lives. A row that is not there means the card has no
    /// cover, and a file that is not there means the cover is gone
    /// and the card falls back to its gradient and symbol.
    private func coverImageURL(forKey key: String) -> URL? {
        let service = CardCoverService(modelContext: WSPersistenceContainer.current.mainContext)
        guard let row = service.row(forKey: key),
              let path = row.imagePath else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func referenceCategoryCard(_ entity: Reference) -> some View {
        Card(
            source: .reference(entity),
            onDoubleClick: { source in
                onDoubleClick(source)
            },
            onRename: { beginReferenceRename(entity) },
            onDelete: { beginReferenceDelete(entity) },
            coverImageURL: coverImageURL(forReference: entity.id)
        )
    }

    /// follow-up 'editor ICON': use the SAME icon (= book-open) as the editor
    /// empty state, so all "no content" panels in the workspace share one
    /// visual icon. Caller can override per-call (= rare; most callers use the
    /// default).
    func emptyState(
        // Per Apple HIG / platform-default style: default icon 'book-open' is Lucide
        // kebab-case (= NOT a valid SF Symbol 6 identifier) = renders as a
        // blank rectangle in PreviewPane's empty states. Migrated to the
        // dot.case SF Symbols 6 form ('book.pages'). Per /Applications/SF
        // Symbols Beta.app/Contents/Executables/ sfsymbols search 2026-09-16.
        icon: String = "book.pages",
        titleKey: String,
        bodyKey: String
    ) -> some View {
        // Empty-state shape rationale: a single component — can you abstract a UI
        // component? While you're at it, on the empty-state icon: double the
        // size and use the thinnest strokes. The goal is to unify all empty-
        // state styles. The right column has 12 tabs and many are missing an
        // empty state': migrate to the unified EmptyStateView (= 76 PT SF
        // Symbols 6 icon + .regular weight = the canonical macOS 27 inspector
        // icon weight; = standard title / body hierarchy). Same visual
        // treatment as the 12 specialized tool tabs. (= boss 2026-10-10 "少了几个
        // 多语言" feedback). The previous implementation used `String(localized:
        // LocalizationValue(stringLiteral:))` which on macOS 14+ / Xcode 15+
        // reads from `Localizable.xcstrings` (= the String Catalog). = the SPM
        // .process("Resources") pattern did NOT ship the .xcstrings into the
        // runtime bundle (= it stays in the build cache; = the copy loop in
        // Scripts/build-app.sh promotes only the compiled .lproj/
        // Localizable.strings files; = the runtime never sees .xcstrings; =
        // the 10 preview.empty* keys existed in the binary .strings but not in
        // .xcstrings; = the runtime showed raw dotted keys). Fix: use
        // `NSLocalizedString` (= reads from the binary .strings files which DO
        // have the keys; = the canonical path for runtime lookup; = the
        // `Localizable.xcstrings` becomes the source for humans + LLMs only; =
        // the binary .strings files are the runtime truth). The .xcstrings is
        // also updated (= 638 keys vs 627; = source of truth for future Xcode
        // String Catalog editing).
        EmptyStateView(
            icon: icon,
            title: NSLocalizedString(titleKey, comment: ""),
            body: NSLocalizedString(bodyKey, comment: "")
        )
    }



    @ViewBuilder
    func emptyScopeView() -> some View {
        emptyState(
            icon: "book.pages",
            titleKey: "preview.empty_state.pick_book",
            bodyKey: "preview.empty.scope_hint"
        )
    }



    // MARK: - 3 view modes

    /// deleted `singleEntityDetail(_ entity: Reference) -> some View` (=
    /// verify-dead reports ext=0 + int=0; = 0 callers; = the function was a
    /// 3-mode dispatcher child for entity detail; = the parent body in
    /// PreviewPane uses `singleEntityDetail` is wired via Switch case in the
    /// parent body which now uses a different rendering path — see git history
    /// for the full deleted body; = no behavior change; = 80 LOC removed). Mode
    /// 2: category-scoped grid (= only entities in this category).
    @ViewBuilder
    func categoryGrid(category: EntityCategory, allEntities: [Reference]) -> some View {
        let inCategory = allEntities.filter { $0.category == category }
        // removed the category header HStack (= icon + category.displayName + count). Per
        // the rule: 'in the reference library, the title in the red box in the
        // material preview area is unused, not needed, delete it'. The sidebar
        // already shows the category name (= when user clicks reference-
        // library/History-Geography, the sidebar shows the selection); the
        // preview pane's category header is redundant. Now the preview pane
        // jumps directly to the card grid (= card thumbnails + card content).
        // preview area content isn't fully displayed when width was narrowed
        // preview area doesn't auto-adapt the width' = preview pane content
        // area is narrower than the pane (= 184 PT vs ~430 PT) because the
        // outer VStack has no .frame(maxWidth: .infinity) = the inner
        // GeometryReader takes the parent's intrinsic width (= 0) = the
        // LazyVGrid falls back to a single column at narrow width = sort
        // button / trailing icons at right edge get clipped by the content
        // width, NOT the pane width. Fix = .frame(maxWidth: .infinity) on the
        // outer VStack so GeometryReader reports the full pane width.
        VStack(alignment: .leading, spacing: 0) {
            if inCategory.isEmpty {
                emptyState(
                    icon: "book.pages",
                    titleKey: "preview.empty_state.category_empty",
                    bodyKey: "preview.empty.import_hint"
                )
            } else {
                categoryGridContent(inCategory: inCategory)
            }
        }
    }


    /// Non-empty branch of categoryGrid (= the GeometryReader + ScrollView +
    /// LazyVGrid + animations + contentInset pipeline). Apple HIG canonical
    /// pattern: when an if/else has a heavy non-empty branch (= 5 nested view
    /// frames here: GeometryReader → ScrollView → LazyVGrid → ForEach →
    /// referenceCategoryCard), extract it into a named @ViewBuilder helper (=
    /// categoryGrid goes from 7 nested views to 4; = the function call flattens
    /// the entire GeometryReader/ScrollView/LazyVGrid pipeline into one frame
    /// in the parent body; = the parent categoryGrid body becomes: VStack →
    /// if/else → emptyState/categoryGridContent = 4 frames; = the deepest path
    /// through the file is now 5 = the per-helper's internal nesting).
    @ViewBuilder
    func categoryGridContent(inCategory: [Reference]) -> some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), spacing: 16) {
                    ForEach(inCategory) { entity in
                        // (see OOB.md #2026-09-08) — 'card, show': the trailing closure
                        // here IS Card's onDoubleClick (= now
                        // takes the CardSource as a
                        // parameter). Forward that source to
                        // PreviewPane's onDoubleClick (= which
                        // opens THIS specific card in the
                        // editor, not the topmost card = the
                        // previous filtered.first bug).
                        referenceCategoryCard(entity)
                            // Cards fade in on sidebar tap: individual Card gets an
                            // opacity + scale entry
                            // transition. When the user
                            // types in the search field,
                            // matching cards fade + scale
                            // in and non-matching cards
                            // fade out (= the
                            // .animation(.smooth, value:)
                            // on the LazyVGrid triggers
                            // each card's transition as
                            // SwiftUI adds or removes it
                            // from the diff).
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                // per-card animation trigger (= fires on every Card add/remove within
                // this categoryGrid). Reading `inCategory.map(\.id)`
                // produces an Equatable sequence SwiftUI can diff (=
                // when the IDs change = some cards added/removed = the
                // cards' .opacity / scale transitions play). 180 ms =
                // matches the LazyVGrid default fade duration.
                .animation(.smooth(duration: 0.18), value: inCategory.map(\.id))
                // STYLES-006 (2026-09-07): use the canonical content inset modifier (= 0
                // PT = matches sidebar / editor behavior = content
                // sits right below the chrome tier separator with no
                // extra gap). Previously
                // (.contentInsetStyle(.standard, edges: .vertical) =
                // 18 PT) created a 35 PT inconsistency vs zone 1
                // sidebar / zone 3 editor ((see OOB.md #2026-09-07) —
                // round 5 'region, ' = all 6 zones should share the
                // same chrome-tier-to-content-tier inset). The
                // previous 18 PT was Apple's .defaultContentMargins (=
                // NSTextView internal), which doesn't apply to
                // LazyVGrid (= the grid's rows are not text).
                .contentInsetStyle(.none, edges: .vertical)
                // 2026-10-12 [archived-round] boss directive "还是有 一点间距" — the prior
                // `.frame(maxHeight: .infinity) + .safeAreaInset(edge:
                // .bottom, spacing: 0)` (= [archived-round] fix) anchored the
                // chrome footer at the column's bottom BUT the safe
                // area inset did NOT extend down to the bottom of the
                // inner ScrollView's content (= SwiftUI's
                // `safeAreaInset` only adds the chrome's outer height
                // to the receiver's bottom safe area, but the inner
                // ScrollView's own bottom safe area stays at 0 = the
                // last card's natural position is at the ScrollView's
                // natural bottom = the gap between the last card and
                // the chrome's Divider = `chrome.padding-top 8 PT + 1
                // PT Divider` ≈ 9 PT visible column-bg gap). Mirror
                // the chat's `contentMargins(.bottom,
                // chatInputBarHeight, for: .scrollContent)` pattern (=
                // explicit content bottom margin equal to the chrome
                // footer's total height; = the last card is pushed up
                // by the full chrome height = 0 PT visible gap between
                // the last card and the chrome footer's Divider). 33
                // PT = `1 (Divider) + 8 (padding-top) + 16 (text
                // intrinsic) + 8 (padding-bottom)` = the chrome
                // footer's total height (= matches the chat's
                // `chatInputBarHeight` which is also the chrome
                // footer's total height).
                .contentMargins(.bottom, 33, for: .scrollContent)
            }
        }
    }


    /// Single Reference card for a category grid (= extracted from
    /// categoryGrid's nested ForEach + Card trailing closure). Apple HIG
    /// canonical pattern for deep view hierarchies (= extract nested trailing
    /// closures into named @ViewBuilder helpers; = one less view layer; =
    /// categoryGrid goes from 8 nested views to 7). The body contains the
    /// Card's onDoubleClick (= the Card source argument; = forwards to
    /// PreviewPane's `onDoubleClick`, which opens THIS specific card in the
    /// editor; = the previous filtered.first bug). the single-card render
    /// helper for the per-category grid (= the per-card `onRename` / `onDelete`
    /// closures are wired here). Extracted from the inline ForEach body so the
    /// closures can capture `entity` (= the right-clicked card's reference; =
    /// the closures set `cardRenaming` / `cardPendingDelete` to that specific
    /// entity; = the user sees a rename / delete flow for the exact card they
    /// right-clicked).
    // (referenceCategoryCard extracted to PreviewPaneGrids.swift in A79; = see that file)


    /// Mode 3: all-entities overview grid (= group by category inline).
    @ViewBuilder
    func overviewGrid(allEntities: [Reference]) -> some View {
        if allEntities.isEmpty {
            emptyState(
                icon: "book.pages",
                titleKey: "preview.empty_state.reference_empty",
                bodyKey: "preview.empty.import_hint"
            )
        } else {
            // (per the rule 'the material preview area only displays cards of the
            // currently selected directory, so only card flow is needed,
            // just lay them out continuously' + 'material preview area
            // doesn't need this title, cards just tile flat'. Single flat
            // LazyVGrid (= no per-category section headers, no global
            // count header). Cards flow continuously (= wubi-ji sticky-
            // note style). Sort by current `previewSortOrder` (= (see
            // OOB.md #2026-08-30) — default pinyin first letter; user can
            // pick creation time or modification time via top-right sort
            // menu icon).
            let sorted = PreviewPaneOps.sortEntities(allEntities, by: previewSortOrder)
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), spacing: 16) {
                        ForEach(sorted) { entity in
                            Card(
                                source: .reference(entity),
                                onDoubleClick: { source in
                                    onDoubleClick(source)
                                },
                                onRename: { beginReferenceRename(entity) },
                                onDelete: { beginReferenceDelete(entity) },
                                coverImageURL: coverImageURL(forReference: entity.id)
                            )
                            // per-card transition (= see categoryGrid comment for
                            // rationale).
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    // per-card animation trigger (= search filter add/remove within
                    // overviewGrid).
                    .animation(.smooth(duration: 0.18), value: sorted.map(\.id))
                }
                .padding(.vertical, DesignTokens.spacingStandard)
                // 2026-10-12 [archived-round] — see the `categoryGridContent` LazyVGrid for the
                // doc on the `.contentMargins(.bottom, 33, for:
                // .scrollContent)` chrome-footer gap-absorber (= 33 PT
                // = the chrome footer's total height; = the last card
                // is pushed up by the full chrome height; = 0 PT
                // visible gap between the last card and the chrome
                // footer's Divider; = 1:1 with the chat footer
                // pattern; = matches the chat's `chatInputBarHeight`
                // content margin).
                .contentMargins(.bottom, 33, for: .scrollContent)
            }
        }
    }

    // (loadShelfBooksAsync extracted to PreviewPaneDataAccess.swift in A83; = see that file)


    /// load .md files from a book folder on the filesystem. Walks all shelves
    /// (= shelves/<shelf>/books/<book>/) to find the matching bookId, then
    /// scans one or more of the 8 standard folders for .md files. Errors (=
    /// missing folders, permission denied, etc.) are silently skipped so a
    /// single bad folder doesn't break the whole view (= partial load is more
    /// useful than nothing). Sort book docs by the current sort order (= same
    /// menu as entity scope, but applied to BookDoc). (see OOB.md #2026-08-31)
    /// — sort still defaults to .pinyinFirstLetter so docs in Chinese filenames
    /// also flow alphabetically. Sort entities by the selected sort order ((see
    /// OOB.md #2026-08-30)). Returns a NEW array (doesn't mutate input). Stable
    /// sort by using id as the tiebreaker (= prevents visual shuffle on
    /// re-render when entities have equal sort keys). Flat LazyVGrid for book
    /// docs (= same visual style as entity card grid, but BookDocCard instead
    /// of EntityCard).
    @ViewBuilder
    func bookDocsGrid(docs: [BookDoc]) -> some View {
        let sorted = PreviewPaneOps.sortBookDocs(docs, by: previewSortOrder)
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(
                    columns: adaptiveColumns(width: geometry.size.width),
                    spacing: 16
                ) {
                    ForEach(sorted) { doc in
                        Card(
                            source: .bookDoc(doc),
                            onDoubleClick: { source in
                                onDoubleClick(source)
                            },
                            onRename: { beginBookDocRename(doc) },
                            onDelete: { beginBookDocDelete(doc) },
                            coverImageURL: coverImageURL(forBookDoc: doc.id)
                        )
                        // per-card transition (= see categoryGrid comment for rationale).
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                // per-card animation trigger (= search filter add/remove within
                // bookDocsGrid).
                .animation(.smooth(duration: 0.18), value: sorted.map(\.id))
                .padding(.vertical, DesignTokens.spacingStandard)
                // 2026-10-12 [archived-round] — see the `categoryGridContent` LazyVGrid for the
                // doc on the `.contentMargins(.bottom, 33, for:
                // .scrollContent)` chrome-footer gap-absorber.
                .contentMargins(.bottom, 33, for: .scrollContent)
            }
        }
}

}
