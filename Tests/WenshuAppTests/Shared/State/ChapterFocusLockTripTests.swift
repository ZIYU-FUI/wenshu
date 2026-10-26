//
//  ChapterFocusLockTripTests.swift · wenshu
//
//  Behavioral test for the chapter focus lock.
//
//  The lock is the protection the user can see: while the user has a
//  chapter's editor tab focused, the agent's chapter tools must
//  refuse to write to that chapter, because the user is editing that
//  text right now.
//
//  The lock reads the focus through AppStateLocator, a MainActor
//  singleton the app binds once at launch. The locator had no way to
//  be bound, so every read returned nil, the guard compared the
//  chapter path against nil, and the agent wrote straight into the
//  chapter the user was editing.
//
//  These tests bind the locator and drive the real guard and the
//  real actor, so the property is proved by what happens: the
//  focused chapter raises the locked error and the file on disk is
//  left alone, and an unfocused chapter is written.
//
//  swift test --filter ChapterFocusLockTripTests
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp

@Suite("Chapter focus lock trips on the chapter the user is editing", .serialized)
@MainActor
struct ChapterFocusLockTripTests {

    // MARK: - Fixtures

    /// The app state the locator points at.
    ///
    /// The app state restores its tabs from the store on init and
    /// writes them back on every change, so the stored snapshot is
    /// taken before the state is built and put back right after (= the
    /// suite leaves the store as it found it, and no other suite
    /// restores this suite's tab).
    @MainActor
    private struct BoundState {
        let state: AppState

        init(focusedDocumentPath: String?) {
            let storedTabs = UserDefaultsStore.shared.data(forKey: .openTabs)
            let storedActiveTabID = UserDefaultsStore.shared.uuid(forKey: .activeTabId)

            // A snapshot left by another test would decide the focus
            // this suite measures, so the store starts empty.
            UserDefaultsStore.shared.remove(.openTabs)
            UserDefaultsStore.shared.remove(.activeTabId)

            let state = AppState()
            if let focusedDocumentPath {
                let tab = EditorTab(
                    id: UUID(),
                    documentPath: focusedDocumentPath,
                    draft: "",
                    originalBody: "",
                    mode: .edit,
                    title: nil
                )
                state.openTabs = [tab]
                state.activeTabId = tab.id
            } else {
                state.openTabs = []
            }
            self.state = state
            AppStateLocator.shared.bind(appState: state)

            // Put the store back (= the state above is the only
            // reader of the focus, and the store is nobody's).
            if let storedTabs {
                UserDefaultsStore.shared.setData(storedTabs, forKey: .openTabs)
            } else {
                UserDefaultsStore.shared.remove(.openTabs)
            }
            UserDefaultsStore.shared.setUUID(storedActiveTabID, forKey: .activeTabId)
        }

        /// Release the locator.
        func release() {
            AppStateLocator.shared.unbindForTest()
        }
    }

    /// A book on disk with one chapter, so the actor has a real file
    /// to write.
    private struct BookFixture {
        let directory: URL
        let chapterID: UUID
        let bookID: UUID
        /// The path the guard compares against (= the chapter file).
        var chapterPath: String {
            directory
                .appendingPathComponent("chapters", isDirectory: true)
                .appendingPathComponent("\(chapterID.uuidString).md", isDirectory: false)
                .path
        }
    }

    private func makeBookFixture() throws -> BookFixture {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wenshu-focus-lock-\(UUID().uuidString)", isDirectory: true)
        let chapters = directory.appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: chapters, withIntermediateDirectories: true)

        let chapterID = UUID()
        let bookID = UUID()
        let body = "## Chapter One\n\nThe old sentence.\n"
        try body.write(
            to: chapters.appendingPathComponent("\(chapterID.uuidString).md"),
            atomically: true,
            encoding: .utf8
        )

        let document = Document(
            id: chapterID,
            bookId: bookID,
            category: .chapter,
            title: "Chapter One",
            byteSize: body.utf8.count
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let index = try encoder.encode([document])
        try index.write(to: directory.appendingPathComponent("chapters.json"), options: .atomic)

        return BookFixture(directory: directory, chapterID: chapterID, bookID: bookID)
    }

    private func readChapterBody(_ fixture: BookFixture) throws -> String {
        let url = fixture.directory
            .appendingPathComponent("chapters", isDirectory: true)
            .appendingPathComponent("\(fixture.chapterID.uuidString).md")
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - The guard

    @Test("the guard refuses the chapter the user is editing")
    func guardRefusesTheFocusedChapter() async throws {
        let chapterPath = "/tmp/wenshu-focus-lock/chapters/\(UUID().uuidString).md"
        let bound = BoundState(focusedDocumentPath: chapterPath)
        defer { bound.release() }

        await #expect(throws: ChapterFocusLockedError.self) {
            try await ChapterFocusLockGuard.assertNotLocked(
                documentPath: chapterPath,
                focusedChapterPathProvider: { @Sendable in
                    await ChapterFocusLockGuard.currentFocusedChapterPath()
                }
            )
        }

        #expect(bound.state.focusedChapterPath == chapterPath,
                "the bound app state must report the chapter the user is editing")
    }

    @Test("the guard lets the write through when no chapter is focused")
    func guardAllowsWhenNothingIsFocused() async throws {
        let bound = BoundState(focusedDocumentPath: nil)
        defer { bound.release() }

        await #expect(throws: Never.self) {
            try await ChapterFocusLockGuard.assertNotLocked(
                documentPath: "/tmp/wenshu-focus-lock/chapters/\(UUID().uuidString).md",
                focusedChapterPathProvider: { @Sendable in
                    await ChapterFocusLockGuard.currentFocusedChapterPath()
                }
            )
        }

        #expect(bound.state.focusedChapterPath == nil,
                "no tab means no focused chapter")
    }

    @Test("the guard lets the write through when another chapter is focused")
    func guardAllowsWhenAnotherChapterIsFocused() async throws {
        let otherPath = "/tmp/wenshu-focus-lock/chapters/other.md"
        let bound = BoundState(focusedDocumentPath: otherPath)
        defer { bound.release() }

        await #expect(throws: Never.self) {
            try await ChapterFocusLockGuard.assertNotLocked(
                documentPath: "/tmp/wenshu-focus-lock/chapters/\(UUID().uuidString).md",
                focusedChapterPathProvider: { @Sendable in
                    await ChapterFocusLockGuard.currentFocusedChapterPath()
                }
            )
        }

        #expect(bound.state.focusedChapterPath == otherPath,
                "the focused chapter is the other one, not the one being written")
    }

    // MARK: - The actor (= the file on disk)

    @Test("the agent does not write the chapter the user is editing")
    func actorLeavesTheFocusedChapterAlone() async throws {
        let fixture = try makeBookFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let bound = BoundState(focusedDocumentPath: fixture.chapterPath)
        defer { bound.release() }

        let actor = EditChapterActor(bookDirectoryProvider: { fixture.directory })
        let before = try readChapterBody(fixture)

        do {
            _ = try await actor.editChapter(
                chapterId: fixture.chapterID,
                bookId: fixture.bookID,
                oldText: "The old sentence.",
                newText: "The new sentence.",
                summary: nil
            )
            Issue.record("the agent wrote the chapter the user is editing")
        } catch let error as ChapterFocusLockedError {
            #expect(error.chapterPath == fixture.chapterPath)
        }

        #expect(try readChapterBody(fixture) == before,
                "the chapter file must be untouched while the user is editing it")
        #expect(bound.state.focusedChapterPath == fixture.chapterPath,
                "the focus must survive the refused write")
    }

    @Test("the agent writes a chapter the user is not editing")
    func actorWritesTheUnfocusedChapter() async throws {
        let fixture = try makeBookFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let bound = BoundState(focusedDocumentPath: "/tmp/wenshu-focus-lock/chapters/other.md")
        defer { bound.release() }

        let actor = EditChapterActor(bookDirectoryProvider: { fixture.directory })

        _ = try await actor.editChapter(
            chapterId: fixture.chapterID,
            bookId: fixture.bookID,
            oldText: "The old sentence.",
            newText: "The new sentence.",
            summary: nil
        )

        #expect(try readChapterBody(fixture).contains("The new sentence."),
                "the chapter the user is not editing must be written")
        #expect(bound.state.focusedChapterPath == "/tmp/wenshu-focus-lock/chapters/other.md",
                "the write must not move the focus")
    }
}
