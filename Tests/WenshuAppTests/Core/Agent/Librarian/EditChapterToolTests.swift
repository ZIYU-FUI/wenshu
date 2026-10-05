//
//  Core/Agent/Librarian/EditChapterToolTests.swift · wenshu · edit-chapter-tool 2026-09-28 T4
//
//  EditChapterTool (= hermes 0.21.5 edit_file 1:1). Patch-style
//  chapter edits: replace a substring `old_text` with `new_text`,
//  returning the unified-diff envelope (= the same kind:"diff" shape
//  BookChapterTool.update emits; = ChatToolDiffPreview's input is
//  stable across the two surfaces).
//
//  Async Swift Testing — drives the actor directly via its async API.
//
//  ActiveLibrary.overrideForTesting is a `@TaskLocal` (= Apple
//  HIG canonical pattern for test seams). Tests wrap their body
//  in `ActiveLibrary.$overrideForTesting.withValue(...) { ... }`
//  via the `withLibraryRoot` helper (= per-task scope; = no
//  cross-suite pollution; = no init() reset needed).
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("EditChapterActor patch-style edit (edit-chapter-tool 2026-09-28 T4)")
struct EditChapterActorTests {

    /// Canonical library root for these tests (= /tmp, resolved
    /// through /private/tmp symlink so PathGuard's canonical-root
    /// comparison matches).
    private static let libraryRoot = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path

    /// Run `body` with `ActiveLibrary.overrideForTesting` bound to
    /// the canonical /tmp library root (= Apple HIG canonical
    /// TaskLocal pattern; = no cross-suite pollution).
    private func withLibraryRoot<R>(_ body: () async throws -> R) async rethrows -> R {
        try await ActiveLibrary.$overrideForTesting.withValue(Self.libraryRoot, operation: body)
    }

    @Test("edit replaces a single occurrence of old_text with new_text")
    func singleReplacement() async throws {
        try await withLibraryRoot {
            let (actor, bookId, chapterId) = try await Self.seedChapter(
                initialBody: "第一行。\n第二行原文。\n第三行。\n"
            )

            let result = try await actor.editChapter(
                chapterId: chapterId,
                bookId: bookId,
                oldText: "第二行原文。",
                newText: "第二行改后。",
                summary: nil
            )

            // The chapter body on disk reflects the patch.
            let storeBody = Self.loadBody(chapterId: chapterId)
            #expect(storeBody?.contains("第二行原文。") == false)
            #expect(storeBody?.contains("第二行改后。") == true)

            // The diff envelope mirrors the chat-diff-preview shape
            // (= hermes tool-fallback.tsx).
            #expect(result.envelope.kind == "diff")
            let stats = result.envelope.stats
            #expect(stats.addedChars > 0)
            #expect(stats.removedChars > 0)
            // The body matches what is now on disk.
            #expect(result.envelope.newText == storeBody)
        }
    }

    @Test("edit fails when old_text is not present (= hermes edit_file semantics)")
    func missingOldTextThrows() async throws {
        try await withLibraryRoot {
            let (actor, bookId, chapterId) = try await Self.seedChapter(
                initialBody: "alpha\nbeta\ngamma\n"
            )

            await #expect(throws: EditChapterError.self) {
                try await actor.editChapter(
                    chapterId: chapterId,
                    bookId: bookId,
                    oldText: "delta",
                    newText: "epsilon",
                    summary: nil
                )
            }
            // Body unchanged on disk.
            #expect(Self.loadBody(chapterId: chapterId) == "alpha\nbeta\ngamma\n")
        }
    }

    @Test("edit's diff envelope carries old_text + new_text + path so the chat preview can render the file card without a second read.")
    func diffEnvelopeCarriesContext() async throws {
        try await withLibraryRoot {
            let (actor, bookId, chapterId) = try await Self.seedChapter(
                initialBody: "before-patch"
            )
            let result = try await actor.editChapter(
                chapterId: chapterId,
                bookId: bookId,
                oldText: "before-patch",
                newText: "after-patch",
                summary: nil
            )
            let diff = result.envelope
            #expect(diff.path == "chapters/\(chapterId.uuidString).md")
            #expect(diff.oldText == "before-patch")
            #expect(diff.newText == "after-patch")
        }
    }

    // MARK: - Fixtures

    /// Seeds a chapter in a tmp library root and returns the actor +
    /// book id + chapter id (= so each test can drive `editChapter`
    /// without rebuilding the whole ladder).
    private static func seedChapter(
        initialBody: String
    ) async throws -> (actor: EditChapterActor, bookId: UUID, chapterId: UUID) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-edit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)

        let bookId = UUID()
        // Seed via FileSystemChapterStore directly (= bypasses the
        // BookChapterActor wiring; we just need a chapter row + body
        // file on disk).
        let store = FileSystemChapterStore(bookDirectory: tmpRoot)
        let chapter = Document(
            id: UUID(),
            bookId: bookId,
            category: .chapter,
            title: "T",
            summary: "",
            createdAt: Date(),
            updatedAt: Date()
        )
        try store.saveChapter(chapter, bodyMarkdown: initialBody)

        let actor = EditChapterActor(bookDirectoryProvider: { tmpRoot })
        return (actor, bookId, chapter.id)
    }

    private static func loadBody(chapterId: UUID) -> String? {
        let tmp = FileManager.default.temporaryDirectory
        // Tmp files are written by FileSystemChapterStore under the
        // tmpRoot we created; = we look them up by walking the most
        // recent wenshu-edit-* dir.
        let candidates = (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/tmp"),
            includingPropertiesForKeys: nil
        )) ?? []
        for dir in candidates where dir.lastPathComponent.hasPrefix("wenshu-edit-") {
            let store = FileSystemChapterStore(bookDirectory: dir)
            if let body = store.loadChapterBody(id: chapterId) {
                return body
            }
        }
        return nil
    }
}

// MARK: - Diff envelope (= canonical shape emitted by both
// EditChapterActor (= the new actor in
// Core/Agent/Librarian/EditChapterActor.swift) and
// BookChapterActor.update. The struct is defined in the actor
// file so both call sites use one type.)
//
// (Forward declarations are NOT mirrored here — the test imports
// `@testable import WenshuApp` and resolves the canonical types
// from the actor file directly.)
