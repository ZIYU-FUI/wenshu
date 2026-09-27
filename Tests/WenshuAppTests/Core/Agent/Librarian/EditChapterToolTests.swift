//
//  Core/Agent/Librarian/EditChapterToolTests.swift · wenshu · edit-chapter-tool 2026-09-28 T4
//
//  RED tests for Phase 4 of chat-diff-preview arc:
//  EditChapterTool (= hermes 0.21.5 edit_file 1:1). Patch-style
//  chapter edits: replace a substring `old_text` with `new_text`,
//  returning the unified-diff envelope (= the same kind:"diff" shape
//  BookChapterTool.update emits; = ChatToolDiffPreview's input is
//  stable across the two surfaces).
//
//  Async Swift Testing — drives the actor directly via its async API.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("EditChapterActor patch-style edit (edit-chapter-tool 2026-09-28 T4)")
struct EditChapterActorTests {

    @Test("edit replaces a single occurrence of old_text with new_text")
    func singleReplacement() async throws {
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

    @Test("edit fails when old_text is not present (= hermes edit_file semantics)")
    func missingOldTextThrows() async throws {
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

    @Test("edit's diff envelope carries old_text + new_text + path so the chat preview can render the file card without a second read.")
    func diffEnvelopeCarriesContext() async throws {
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

    // MARK: - Fixtures

    /// Seeds a chapter in a tmp library root and returns the actor +
    /// book id + chapter id (= so each test can drive `editChapter`
    /// without rebuilding the whole ladder).
    private static func seedChapter(
        initialBody: String
    ) async throws -> (actor: EditChapterActor, bookId: UUID, chapterId: UUID) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-edit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)

        UserDefaultsStore.shared.setString(
            URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path,
            forKey: .libraryPath
        )

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

// MARK: - Forward-declared types (RED: not yet implemented)

/// Mirror of the hermes edit_file tool surface (= wenshu chat scene).
/// Patch-style chapter edits = replace `old_text` with `new_text`
/// in the chapter's body, returning a unified-diff envelope.
actor EditChapterActor {
    private let bookDirectoryProvider: @Sendable () -> URL?
    private let currentChatBookIDProvider: @Sendable () -> UUID?

    init(
        bookDirectoryProvider: @escaping @Sendable () -> URL?,
        currentChatBookIDProvider: @escaping @Sendable () -> UUID? = { nil }
    ) {
        self.bookDirectoryProvider = bookDirectoryProvider
        self.currentChatBookIDProvider = currentChatBookIDProvider
    }

    struct EditResult: Equatable, Sendable {
        let envelope: EditDiffEnvelope
    }

    /// Replace `oldText` with `newText` inside the chapter body.
    /// Throws `EditChapterError.oldTextNotFound` when `oldText` is
    /// not a substring of the body.
    func editChapter(
        chapterId: UUID,
        bookId: UUID,
        oldText: String,
        newText: String,
        summary: String?
    ) async throws -> EditResult {
        fatalError("T4 GREEN will land this")
    }
}

struct EditDiffEnvelope: Equatable, Sendable {
    let kind: String
    let path: String
    let oldText: String
    let newText: String
    let addedChars: Int
    let removedChars: Int
    let addedLines: Int
    let removedLines: Int

    var stats: Stats { Stats(addedChars: addedChars, removedChars: removedChars) }
    struct Stats: Equatable, Sendable {
        let addedChars: Int
        let removedChars: Int
    }
}

enum EditChapterError: Error, Equatable {
    case oldTextNotFound
    case chapterNotFound
}