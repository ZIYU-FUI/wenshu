//
//  BookXxxToolPathGuardTests.swift · Wenshu · wt/path-guard-v2-2026-09-25
//
//  Coverage for the second-line PathGuard assertion in
//  BookChapterActor.resolveStore / BookOutlineActor.resolveStore /
//  BookEntityActor.resolveStore. v1 (= WenshuSandbox) only checked
//  tool_use paths at the ToolExecutor pre-dispatch layer; = the
//  path that the book_X tools constructed from UUID inputs was
//  unchecked. This test pins the second-line guard (= defense in
//  depth against a misconfigured bookDirectoryProvider that returns
//  a path outside the .ws library root).
//
//  ActiveLibrary.overrideForTesting is a `@TaskLocal` (= Apple
//  HIG canonical pattern for test seams). Tests wrap their body
//  in `ActiveLibrary.$overrideForTesting.withValue(...) { ... }`
//  via the `withLibraryRoot` helper (= per-task scope; = no
//  cross-suite pollution; = no init() reset needed).
//

import Testing
import Foundation
@testable import WenshuApp

@MainActor
@Suite("BookXxxTool ↔ PathGuard (wt/path-guard-v2-2026-09-25)", .serialized)
struct BookXxxToolPathGuardTests {

    private let libraryRoot = "/Users/anbaiqiang/libraries/test.ws"

    /// Run `body` with `ActiveLibrary.overrideForTesting` bound to
    /// `libraryRoot` for the duration of the closure (= Apple HIG
    /// canonical TaskLocal pattern; = no cross-suite pollution).
    private func withLibraryRoot<R>(_ body: () async throws -> R) async rethrows -> R {
        try await ActiveLibrary.$overrideForTesting.withValue(libraryRoot, operation: body)
    }

    @Test("BookChapterActor rejects bookDirectoryProvider that points outside the library")
    func testBookChapterActorRejectsOutsideDirectory() async throws {
        try await withLibraryRoot {
            let outsideDir = URL(fileURLWithPath: "/tmp")
            let actor = BookChapterActor(
                bookDirectoryProvider: { outsideDir },
                currentChatBookIDProvider: { nil }
            )
            await #expect(throws: PathGuard.GuardError.self) {
                _ = try await actor.createChapter(
                    bookId: UUID(),
                    title: "title",
                    bodyMarkdown: "body"
                )
            }
        }
    }

    @Test("BookOutlineActor rejects bookDirectoryProvider that points outside the library")
    func testBookOutlineActorRejectsOutsideDirectory() async throws {
        try await withLibraryRoot {
            let outsideDir = URL(fileURLWithPath: "/tmp")
            let actor = BookOutlineActor(
                bookDirectoryProvider: { outsideDir },
                currentChatBookIDProvider: { nil }
            )
            await #expect(throws: PathGuard.GuardError.self) {
                _ = try await actor.createOutline(
                    bookId: UUID(),
                    title: "title",
                    bodyMarkdown: "body"
                )
            }
        }
    }

    @Test("BookEntityActor rejects bookDirectoryProvider that points outside the library")
    func testBookEntityActorRejectsOutsideDirectory() async throws {
        try await withLibraryRoot {
            let outsideDir = URL(fileURLWithPath: "/tmp")
            let actor = BookEntityActor(
                bookDirectoryProvider: { outsideDir },
                currentChatBookIDProvider: { nil }
            )
            await #expect(throws: PathGuard.GuardError.self) {
                _ = try await actor.createEntity(
                    bookId: UUID(),
                    kind: "person",
                    name: "x"
                )
            }
        }
    }

    @Test("BookChapterActor accepts bookDirectoryProvider that points inside the library")
    func testBookChapterActorAcceptsInsideDirectory() async throws {
        try await withLibraryRoot {
            let insideDir = URL(
                fileURLWithPath: "\(libraryRoot)/book-uuid",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: insideDir,
                withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: insideDir) }
            let actor = BookChapterActor(
                bookDirectoryProvider: { insideDir },
                currentChatBookIDProvider: { nil }
            )
            _ = try await actor.createChapter(
                bookId: UUID(),
                title: "title",
                bodyMarkdown: "body"
            )
        }
    }
}
