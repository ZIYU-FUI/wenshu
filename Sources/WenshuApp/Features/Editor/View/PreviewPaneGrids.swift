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

import SwiftUI

extension PreviewPane {
    func referenceCategoryCard(_ entity: Reference) -> some View {
        Card(
            source: .reference(entity),
            onDoubleClick: { source in
                onDoubleClick(source)
            },
            onRename: { beginReferenceRename(entity) },
            onDelete: { beginReferenceDelete(entity) }
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


}
