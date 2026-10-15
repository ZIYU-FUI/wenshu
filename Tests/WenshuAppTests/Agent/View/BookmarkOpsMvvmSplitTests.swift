//
//  BookmarkOpsMvvmSplitTests.swift · Wenshu · v2.9d ticket T34 (boss 2026-09-28 OOB A2 follow-up)
//
//  Structural tests for the v2.9d BookmarkView MVVM split
//  (= boss 2026-09-28 OOB inventory follow-up A2 = 'Bookmark
//  UI polish'; = the v2.8a bookmark UI was a single 223-LOC
//  struct with three inline funcs (reload / addBookmark /
//  removeBookmark); = §11.13 P2-06 + §11.10 v1.74 MVVM
//  split template lifts the inline funcs to a separate
//  BookmarkOps file).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testBookmarkOpsExists — BookmarkOps.swift exists
//       (= the canonical @MainActor bridge per the
//       MVVM split template).
//
//    2. testBookmarkOpsHasLoadAddRemove — BookmarkOps has
//       load + add + remove static entry points (= the
//       view never calls the repository directly).
//
//    3. testBookmarkViewDelegatesToBookmarkOps —
//       BookmarkView.reload + addBookmark + removeBookmark
//       delegate to BookmarkOps (= the view is render-only
//       after the split).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112:
//  source-level tests following the v2.8a BookmarkViewTests
//  + v2.9a InspectorCatalogTests pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookmarkView MVVM split (v2.9d — boss 2026-09-28 OOB A2 follow-up)")
struct BookmarkOpsMvvmSplitTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("BookmarkOps.swift exists (= the canonical @MainActor bridge)")
    func testBookmarkOpsExists() throws {
        let path = resolve("Sources/WenshuApp/Views/SpecializedTools/BookmarkOps.swift")
        let exists = FileManager.default.fileExists(atPath: path)
        #expect(exists,
                "BookmarkOps.swift must exist at Sources/WenshuApp/Views/SpecializedTools/BookmarkOps.swift (= boss A2 follow-up = 'Bookmark UI polish')")
    }

    @Test("BookmarkOps has load + add + remove static entry points")
    func testBookmarkOpsHasLoadAddRemove() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/SpecializedTools/BookmarkOps.swift"), encoding: .utf8)
        let hasLoad = source.contains("static func load(")
        let hasAdd = source.contains("static func add(")
        let hasRemove = source.contains("static func remove(")
        #expect(hasLoad && hasAdd && hasRemove,
                "BookmarkOps must expose static load + add + remove entry points (= MVVM split template)")
    }

    @Test("BookmarkView delegates reload / addBookmark / removeBookmark to BookmarkOps")
    func testBookmarkViewDelegatesToBookmarkOps() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/SpecializedTools/BookmarkView.swift"), encoding: .utf8)
        let callsLoad = source.contains("BookmarkOps.load(")
        let callsAdd = source.contains("BookmarkOps.add(")
        let callsRemove = source.contains("BookmarkOps.remove(")
        #expect(callsLoad && callsAdd && callsRemove,
                "BookmarkView must delegate reload + addBookmark + removeBookmark to BookmarkOps (= the view is render-only)")
    }
}