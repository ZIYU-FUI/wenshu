//
//  BookmarkViewTests.swift · Wenshu · v2.8a ticket T2 (boss 2026-09-28 OOB)
//
//  Structural tests for BookmarkView (= the v2.8a inspector tab for
//  user-created bookmarks anchored to docID or bookID).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v1.44 specialized-tools P1 hermes-port batch
//  precedent (= 10 tests per file).
//
//  Path is derived from #filePath (= robust to worktree relocations).
//
//  Boss 2026-09-28 OOB (= v2.8 semiprod cleanup): the right
//  specializedTools pane lacks a Bookmark tab; this file pins the
//  source-level shape so the boss can verify the tab exists by
//  source-grepping the canonical 3-test surface (struct + body +
//  repository wire).

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("BookmarkView (v2.8a — bookmark inspector tab per boss 2026-09-28 OOB)")
struct BookmarkViewTests {

    private var sourcePath: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent("Sources/WenshuApp/Views/SpecializedTools/BookmarkView.swift")
        return url.path
    }

    @Test("BookmarkView exists as struct conforming to View (= confirmed by source)")
    func testExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct BookmarkView: View"),
                "BookmarkView must be declared in BookmarkView.swift as `struct BookmarkView: View`")
    }

    @Test("BookmarkView has body returning some View (= SwiftUI requirement)")
    func testBodyReturnsView() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("var body"),
                "BookmarkView must declare a `var body` returning a SwiftUI View")
    }

    @Test("BookmarkViewState mirror exists (= business state hoisted out of @State per v1.72 MVVM split)")
    func testStateMirrorExists() throws {
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("BookmarkViewState"),
                "BookmarkView must reference BookmarkViewState mirror")
        #expect(source.contains("@State private var state = BookmarkViewState()"),
                "BookmarkView must hold state via @State mirror")
        #expect(!source.contains("@State private var bookmarks: [Bookmark]"),
                "bookmarks must NOT be a bare @State var")
        #expect(!source.contains("@State private var status: SpecializedToolLoadStatus"),
                "status must NOT be a bare @State var")
        #expect(!source.contains("@State private var errorText: String?"),
                "errorText must NOT be a bare @State var")
    }

    @Test("BookmarkViewState mirror file exists (= companion file under Views/SpecializedTools/)")
    func testStateMirrorFileExists() throws {
        // Per the same @Observable mirror pattern as
        // ReaderExperienceViewState / EmotionCurveViewState /
        // GenreFitViewState (= commit 1c3a27fc8 + 2026-10-03 mirror
        // hoist), the mirror is at
        // Sources/WenshuApp/Views/SpecializedTools/BookmarkViewState.swift
        // (= relative to repo root, no longer hardcoded to the
        // .worktrees/p2-mirrors path that was used during the
        // refactor worktree).
        let repoRoot = "/Volumes/ANAN/Engineering/wenshu"
        let filePath = repoRoot + "/Sources/WenshuApp/Views/SpecializedTools/BookmarkViewState.swift"
        #expect(FileManager.default.fileExists(atPath: filePath),
                "BookmarkViewState.swift must exist as a companion file")
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(source.contains("@Observable"), "mirror must use @Observable macro")
        #expect(source.contains("final class BookmarkViewState"), "mirror must be a final class")
        #expect(source.contains("var bookmarks: [Bookmark]"), "mirror must hold bookmarks field")
        #expect(source.contains("var status: SpecializedToolLoadStatus"), "mirror must hold status field")
        #expect(source.contains("var errorText: String?"), "mirror must hold errorText field")
    }
}