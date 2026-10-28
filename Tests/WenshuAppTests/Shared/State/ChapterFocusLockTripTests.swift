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
//  The suite drives all three halves of the lock:
//
//  - the guard and the actor (= the file on disk), = the focused
//    chapter raises the locked error and the chapter the user is not
//    editing is written;
//  - the wrapped tool the LLM calls (= the Allow / Deny dialog), = the
//    dialog comes up, the allowed write lands, and the user's
//    focus comes back;
//  - the dialog's own publication (= the chat zone hears about the
//    request), = the request is enqueued from outside the view, so the
//    chat zone only learns about it if the presenter's property is
//    observed.
//
//  So the property is proved by what happens, = not by reading the
//  source of the locator.
//
//  The halves that touch the chat share one suite (= one serialized
//  domain), = because the dialog's request lives in one slot of one
//  singleton, = and two suites running at once would answer each
//  other's request.
//
//  swift test --filter ChapterFocusLockTripTests
//

import AppKit
import Foundation
import Observation
import SwiftUI
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
        private let storedTabs: Data?
        private let storedActiveTabID: UUID?

        init(focusedDocumentPath: String?) {
            let storedTabs = UserDefaultsStore.shared.data(forKey: .openTabs)
            let storedActiveTabID = UserDefaultsStore.shared.uuid(forKey: .activeTabId)
            self.storedTabs = storedTabs
            self.storedActiveTabID = storedActiveTabID

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
            restoreStore()
        }

        /// Release the locator.
        func release() {
            AppStateLocator.shared.unbindForTest()
            restoreStore()
        }

        /// Put the store back to the snapshot the fixture took.
        ///
        /// The release + restore of an allowed write writes the
        /// active tab id back (= so the store is restored again on
        /// the way out, = after the write).
        private func restoreStore() {
            if let storedTabs {
                UserDefaultsStore.shared.setData(storedTabs, forKey: .openTabs)
            } else {
                UserDefaultsStore.shared.remove(.openTabs)
            }
            UserDefaultsStore.shared.setUUID(storedActiveTabID, forKey: .activeTabId)
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

    // MARK: - The LLM-facing path (= the Allow / Deny dialog)

    /// The tool the LLM calls: the chapter tool wrapped in the
    /// conductor's focus-lock wrapper (= the same pair the conductor
    /// wires for `book_edit_chapter`).
    private func makeWrappedTool(fixture: BookFixture) -> any Tool {
        WenshuConductor.ChapterFocusLockWrappedTool(
            inner: EditChapterTool(
                actor: EditChapterActor(bookDirectoryProvider: { fixture.directory })
            ),
            toolName: "book_edit_chapter"
        )
    }

    /// The LLM's edit call, in the envelope the tool parses.
    private func editEnvelope(_ fixture: BookFixture) throws -> String {
        let payload: [String: String] = [
            "id": fixture.chapterID.uuidString,
            "book_id": fixture.bookID.uuidString,
            "old_text": "The old sentence.",
            "new_text": "The new sentence."
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try #require(String(data: data, encoding: .utf8))
    }

    /// Wait for the dialog to reach the presenter.
    ///
    /// The presenter holds the request until the user answers, = so
    /// the test answers it the way the chat surface's button does.
    private func awaitDialogRequest(
        timeout: Duration = .seconds(5)
    ) async -> ChapterFocusLockDialogRequest? {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let request = ChapterFocusLockDialogPresenter.shared.pendingRequest {
                return request
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return nil
    }

    @Test("the Allow path completes the write and hands the focus back")
    func allowPathCompletesTheWriteAndRestoresTheFocus() async throws {
        let fixture = try makeBookFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let bound = BoundState(focusedDocumentPath: fixture.chapterPath)
        defer { bound.release() }

        let tool = makeWrappedTool(fixture: fixture)
        let envelope = try editEnvelope(fixture)
        let before = try readChapterBody(fixture)

        let call = Task { try await tool.execute(input: envelope) }

        // The dialog is up (= the presenter holds the request), and the
        // chapter the user is editing is still untouched.
        let request = try #require(await awaitDialogRequest(),
                                   "the wrapper must ask the user before it writes")
        #expect(request.chapterPath == fixture.chapterPath)
        #expect(request.toolName == "book_edit_chapter")
        #expect(try readChapterBody(fixture) == before,
                "the chapter must stay untouched while the dialog is up")

        // The user allows.
        ChapterFocusLockDialogPresenter.shared.allowCurrentRequest()
        let output = try await call.value

        #expect(output.contains("\"ok\":true"))
        #expect(try readChapterBody(fixture).contains("The new sentence."),
                "the allowed write must land on disk")
        #expect(bound.state.focusedChapterPath == fixture.chapterPath,
                "the Allow path must hand the user's focus back")
    }

    @Test("the Deny path throws and leaves the chapter alone")
    func denyPathThrowsAndLeavesTheChapterAlone() async throws {
        let fixture = try makeBookFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let bound = BoundState(focusedDocumentPath: fixture.chapterPath)
        defer { bound.release() }

        let tool = makeWrappedTool(fixture: fixture)
        let envelope = try editEnvelope(fixture)
        let before = try readChapterBody(fixture)

        let call = Task { try await tool.execute(input: envelope) }

        // The dialog is up.
        _ = try #require(await awaitDialogRequest(),
                         "the wrapper must ask the user before it writes")

        // The user denies.
        ChapterFocusLockDialogPresenter.shared.denyCurrentRequest()
        await #expect(throws: DatasetLockDeniedByBoss.self) {
            _ = try await call.value
        }

        #expect(try readChapterBody(fixture) == before,
                "the denied write must not touch the chapter")
        #expect(bound.state.focusedChapterPath == fixture.chapterPath,
                "the Deny path must leave the user's focus where it was")
    }

    @Test("an allowed write that fails still hands the focus back")
    func allowPathRestoresTheFocusWhenTheWriteFails() async throws {
        let fixture = try makeBookFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let bound = BoundState(focusedDocumentPath: fixture.chapterPath)
        defer { bound.release() }

        // A tool that raises the locked error once (= the guard fires)
        // and then fails on the retry (= the allowed write does not
        // land).
        let tool = WenshuConductor.ChapterFocusLockWrappedTool(
            inner: FailingAfterAllowTool(chapterPath: fixture.chapterPath),
            toolName: "book_edit_chapter"
        )

        let call = Task { try await tool.execute(input: "book_edit_chapter") }

        _ = try #require(await awaitDialogRequest(),
                         "the wrapper must ask the user before it writes")

        ChapterFocusLockDialogPresenter.shared.allowCurrentRequest()
        await #expect(throws: WriteDidNotLand.self) {
            _ = try await call.value
        }

        #expect(bound.state.focusedChapterPath == fixture.chapterPath,
                "a failed allowed write must hand the user's focus back too")
    }

    // MARK: - The dialog reaches the user

    @Test("the presenter publishes its request to an observer")
    func presenterPublishesTheRequest() async throws {
        let flag = ObservationFlag()
        withObservationTracking {
            _ = ChapterFocusLockDialogPresenter.shared.pendingRequest
        } onChange: {
            flag.fire()
        }

        let call = Task { @MainActor in
            _ = await ChapterFocusLockDialogPresenter.shared.present(
                chapterPath: requestedChapterPath,
                toolName: "book_edit_chapter",
                summary: "the agent wants to write this chapter"
            )
        }
        defer { ChapterFocusLockDialogPresenter.shared.allowCurrentRequest() }

        _ = try #require(await awaitDialogRequest(),
                         "the request must reach the presenter")

        #expect(flag.fired)

        ChapterFocusLockDialogPresenter.shared.allowCurrentRequest()
        _ = await call.value
    }

    @Test("the chat zone re-evaluates when the request arrives")
    func chatZoneReEvaluatesWhenTheRequestArrives() async throws {
        let counter = BodyCounter()
        let (window, host) = hostHarnessWindow(ChatZoneAlertHost(counter: counter))
        defer { window.orderOut(nil) }

        let before = counter.evaluations

        let call = Task { @MainActor in
            _ = await ChapterFocusLockDialogPresenter.shared.present(
                chapterPath: requestedChapterPath,
                toolName: "book_edit_chapter",
                summary: "the agent wants to write this chapter"
            )
        }
        defer { ChapterFocusLockDialogPresenter.shared.allowCurrentRequest() }

        _ = try #require(await awaitDialogRequest(),
                         "the request must reach the presenter")

        pumpSwiftUI(0.5)
        host.layoutSubtreeIfNeeded()
        pumpSwiftUI(0.4)

        #expect(counter.evaluations > before)

        ChapterFocusLockDialogPresenter.shared.allowCurrentRequest()
        _ = await call.value
    }

    @Test("CONTROL: the harness observes a value published from outside")
    func controlObservesAnExternalPublication() async throws {
        let counter = BodyCounter()
        let holder = ControlHolder()
        let (window, host) = hostHarnessWindow(ControlHost(counter: counter, holder: holder))
        defer { window.orderOut(nil) }

        let before = counter.evaluations
        holder.chapterPath = requestedChapterPath
        pumpSwiftUI(0.4)
        host.layoutSubtreeIfNeeded()
        pumpSwiftUI(0.4)

        #expect(counter.evaluations > before)
    }
}

/// The chapter the dialog tests ask about (= the presenter's request
/// carries a path, = it never reaches the disk).
private let requestedChapterPath = "/books/demo/chapters/one.md"

/// The failure the stubbed tool raises (= the wrapper must pass it on
/// and hand the focus back).
private struct WriteDidNotLand: Error, Equatable {}

/// A tool that raises the locked error on its first call (= the guard
/// fires) and fails on the retry (= the write the user allowed does
/// not land).
private actor FailingAfterAllowTool: Tool {
    private let chapterPath: String
    private var calls = 0

    init(chapterPath: String) {
        self.chapterPath = chapterPath
    }

    func execute(input: String) async throws -> String {
        calls += 1
        if calls == 1 {
            throw ChapterFocusLockedError(chapterPath: chapterPath)
        }
        throw WriteDidNotLand()
    }
}
