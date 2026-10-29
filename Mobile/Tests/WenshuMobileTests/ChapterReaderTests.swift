import Foundation
import Testing
import WenshuMobileKit
@testable import WenshuMobileApp

/// The chapter the reader opens: the body the Mac sent, the revision it
/// was read at, the command that asked for it, the Markdown the screen
/// renders, and the failure that is not an empty library.
@Suite("ChapterReaderTests")
struct ChapterReaderTests {
    @Test @MainActor func theStoreReadsOneChapterAndTheRevisionItWasReadAt() async throws {
        let transport = ChapterRecordingTransport(
            answer: ChapterRead(body: "The tide turns at dawn.", revision: 7)
        )
        let link = ConnectionStore()
        link.accept(companion: CompanionInfo(name: "Mac", revision: 3))
        let store = LinkLibraryStore(link: link, transport: transport)

        let read = try await store.read(chapter: ChapterID(id: "chapter-harbour"))

        #expect(read.body == "The tide turns at dawn.")
        #expect(read.revision == 7)
    }

    @Test @MainActor func theLinkStoreAsksTheProtocolForReadChapterWithThatId() async throws {
        let transport = ChapterRecordingTransport(
            answer: ChapterRead(body: "The tide turns at dawn.", revision: 7)
        )
        let link = ConnectionStore()
        link.accept(companion: CompanionInfo(name: "Mac", revision: 3))
        let store = LinkLibraryStore(link: link, transport: transport)

        _ = try await store.read(chapter: ChapterID(id: "chapter-harbour"))

        let sent = await transport.sent
        #expect(sent.count == 1)
        #expect(sent.first?.kind == .readChapter)
        #expect(sent.first?.identifier == "chapter-harbour")
        #expect(sent.first?.baseRevision == 3)
    }

    @Test func aBodyThatReadsAsMarkdownRendersAsMarkdown() throws {
        let rendered = ChapterReaderView.markdown("The tide **turns** at dawn.")

        #expect(rendered.characters.contains("turns"))
        #expect(!rendered.characters.contains("*"))
        let emphasised = rendered.runs.contains { run in
            guard let intent = run.inlinePresentationIntent else { return false }
            return intent.contains(.stronglyEmphasized)
        }
        #expect(emphasised)
    }

    @Test @MainActor func aFailedReadIsReportedAsAFailureAndNotAsAnEmptyLibrary() async throws {
        let transport = ChapterRecordingTransport(
            answer: ChapterRead(body: "", revision: 0),
            failure: .unreadable
        )
        let link = ConnectionStore()
        link.accept(companion: CompanionInfo(name: "Mac", revision: 3))
        let store = LinkLibraryStore(link: link, transport: transport)

        await #expect(throws: ChapterReadFailure.unreadable) {
            try await store.read(chapter: ChapterID(id: "chapter-harbour"))
        }

        let state = ChapterReaderView.state(for: ChapterReadFailure.unreadable)
        #expect(state == .failed(.unreadable))
        let message = ChapterReadFailure.unreadable.message
        #expect(message.lowercased().contains("chapter"))
        #expect(!message.lowercased().contains("library"))
        #expect(!message.lowercased().contains("empty"))
    }

    @Test func theReaderNeverShowsTheEmptyLibrary() throws {
        let source = try readerSource()

        #expect(!source.contains("LibraryEmptyState"))
        #expect(!source.contains("No Library"))
        #expect(!source.contains("arrive from the Mac"))
    }

    @Test @MainActor func aChapterOpensInTheOrderTheOutlineGave() async throws {
        let store = FixtureLibraryStore()

        let first = store.state.chapter(ChapterID(id: "chapter-harbour"))
        let second = store.state.chapter(ChapterID(id: "chapter-ferry"))

        #expect(first?.number == 1)
        #expect(first?.total == 2)
        #expect(first?.title == "The Harbour")
        #expect(second?.number == 2)
        #expect(second?.total == 2)
        #expect(second?.title == "Night Ferry")
    }
}

/// A transport that records the commands it is sent and answers a
/// chapter read with a fixed body and revision.
actor ChapterRecordingTransport: LinkTransport {
    /// The commands the transport was sent.
    private(set) var sent: [LinkCommand] = []
    /// The chapter the transport answers with.
    let answer: ChapterRead
    /// The failure the transport answers with, when it fails.
    let failure: ChapterReadFailure?

    init(answer: ChapterRead, failure: ChapterReadFailure? = nil) {
        self.answer = answer
        self.failure = failure
    }

    func send(_ command: LinkCommand) async throws -> [LibraryShelf] {
        sent.append(command)
        return []
    }

    func read(_ command: LinkCommand) async throws -> ChapterRead {
        sent.append(command)
        if let failure {
            throw failure
        }
        return answer
    }
}

/// The reader's own source, read to see what it shows when a read fails.
private func readerSource() throws -> String {
    let reader = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(
            "Sources/WenshuMobileApp/Features/Library/View/ChapterReaderView.swift"
        )
    return try String(contentsOf: reader, encoding: .utf8)
}
