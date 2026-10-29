import Foundation
import Testing
import WenshuMobileKit
@testable import WenshuMobileApp

/// The library boundary: the fixture's outline, the command the
/// link-backed store sends, the app's own "not yet" state, and the
/// fixture's absence from the shipped app.
@Suite("LibraryStoreTests")
struct LibraryStoreTests {
    #if DEBUG
    @Test @MainActor func theFixtureStoreCarriesTheShelvesBooksAndChapters() async throws {
        let store = FixtureLibraryStore()

        let shelves = try await store.outline()

        #expect(shelves.count == 2)
        let fiction = try #require(shelves.first { $0.name == "Fiction" })
        #expect(fiction.books.count == 1)
        let book = try #require(fiction.books.first)
        #expect(book.title == "The Long Tide")
        #expect(book.chapters.count == 2)
        let chapter = try #require(book.chapters.first)
        #expect(chapter.title == "The Harbour")
        #expect(chapter.wordCount == 3120)
    }
    #endif

    @Test @MainActor func theLinkStoreAsksTheProtocolForListChapters() async throws {
        let answer = [
            LibraryShelf(
                id: "shelf-fiction",
                name: "Fiction",
                books: [
                    LibraryBook(
                        id: "book-tide",
                        title: "The Long Tide",
                        chapters: [
                            LibraryChapter(id: "chapter-harbour", title: "The Harbour", wordCount: 3120)
                        ]
                    )
                ]
            )
        ]
        let transport = RecordingTransport(answer: answer)
        let link = ConnectionStore()
        link.accept(companion: CompanionInfo(name: "Mac", revision: 7))
        let store = LinkLibraryStore(link: link, transport: transport)

        let shelves = try await store.outline()

        let sent = await transport.sent
        #expect(sent.count == 1)
        #expect(sent.first?.kind == .listChapters)
        #expect(sent.first?.baseRevision == 7)
        #expect(shelves == answer)
        #expect(store.state == .loaded(answer))
    }

    @Test @MainActor func aStoreWithNoLibraryIsNotAnError() async throws {
        let link = ConnectionStore()
        let store = LinkLibraryStore(link: link)

        let shelves = try await store.outline()

        #expect(shelves.isEmpty)
        #expect(store.state == .notYet)
    }

    @Test @MainActor func aMacThatSentNoLibraryIsNotAnError() async throws {
        let transport = RecordingTransport(answer: [])
        let link = ConnectionStore()
        link.accept(companion: CompanionInfo(name: "Mac", revision: 7))
        let store = LinkLibraryStore(link: link, transport: transport)

        let shelves = try await store.outline()

        #expect(shelves.isEmpty)
        #expect(store.state == .notYet)
    }

    @Test func theShippedAppCannotReachTheFixture() throws {
        let mentions = try fixtureMentions()

        #expect(!mentions.isEmpty)
        for mention in mentions {
            #expect(
                mention.isDebugOnly,
                "the fixture is named outside a debug build: \(mention.file):\(mention.line)"
            )
            #expect(!mention.declaration.contains("public"))
        }
    }
}

/// A transport that records the commands it is sent and answers with a
/// fixed outline.
actor RecordingTransport: LinkTransport {
    /// The commands the transport was sent.
    private(set) var sent: [LinkCommand] = []
    /// The outline the transport answers with.
    let answer: [LibraryShelf]

    init(answer: [LibraryShelf]) {
        self.answer = answer
    }

    func send(_ command: LinkCommand) async throws -> [LibraryShelf] {
        sent.append(command)
        return answer
    }
}

/// One line of the app target that names the fixture.
private struct FixtureMention {
    /// The file the mention is in.
    let file: String
    /// The line of the mention.
    let line: Int
    /// The text of the line.
    let declaration: String
    /// Whether the line sits inside a debug-only region.
    let isDebugOnly: Bool
}

/// Every line of the app target that names the fixture.
///
/// The shipped app is a release build, so the fixture has to be gone
/// from it: a line that names it outside a debug-only region would put
/// the type in the release binary.
private func fixtureMentions() throws -> [FixtureMention] {
    let appTarget = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/WenshuMobileApp")
    let files = FileManager.default
        .enumerator(at: appTarget, includingPropertiesForKeys: nil)?
        .compactMap { $0 as? URL }
        .filter { $0.pathExtension == "swift" } ?? []

    var mentions: [FixtureMention] = []
    for file in files {
        let text = try String(contentsOf: file, encoding: .utf8)
        let lines = text.components(separatedBy: "\n")
        var regions = RegionStack()
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#if ") {
                regions.push(condition: String(trimmed.dropFirst("#if ".count)))
            } else if trimmed.hasPrefix("#elseif ") {
                regions.moveToElseIf(condition: String(trimmed.dropFirst("#elseif ".count)))
            } else if trimmed == "#else" {
                regions.moveToElse()
            } else if trimmed.hasPrefix("#endif") {
                regions.pop()
            }
            guard line.contains("FixtureLibraryStore") else { continue }
            mentions.append(
                FixtureMention(
                    file: file.lastPathComponent,
                    line: index + 1,
                    declaration: line,
                    isDebugOnly: regions.isDebugOnly
                )
            )
        }
    }
    return mentions
}

/// The conditional-compilation regions a line is in.
///
/// A region is debug-only when its branch compiles only in a debug
/// build, and a line inside a debug-only region stays debug-only.
private struct RegionStack {
    /// One region of the conditional-compilation nest.
    private struct Region {
        /// Whether the region sits inside a debug-only region.
        var parentIsDebugOnly: Bool
        /// Whether any condition of this branch chain is debug-only.
        var anyConditionIsDebugOnly: Bool
        /// Whether the branch the line is on compiles only in a debug build.
        var isDebugOnly: Bool
    }

    /// The regions the line is in, outermost first.
    private var regions: [Region] = []

    /// Whether every region the line is in is a debug-only one.
    ///
    /// A line outside every region is in no debug-only region at all:
    /// the release build compiles it.
    var isDebugOnly: Bool {
        !regions.isEmpty && regions.allSatisfy(\.isDebugOnly)
    }

    /// Enters the region whose condition is `condition`.
    mutating func push(condition: String) {
        let parent = regions.last?.isDebugOnly ?? false
        let conditionIsDebugOnly = isDebugCondition(condition)
        regions.append(
            Region(
                parentIsDebugOnly: parent,
                anyConditionIsDebugOnly: conditionIsDebugOnly,
                isDebugOnly: parent || conditionIsDebugOnly
            )
        )
    }

    /// Moves the innermost region to the branch of an `#elseif`.
    mutating func moveToElseIf(condition: String) {
        guard var region = regions.popLast() else { return }
        let conditionIsDebugOnly = isDebugCondition(condition)
        region.anyConditionIsDebugOnly = region.anyConditionIsDebugOnly || conditionIsDebugOnly
        region.isDebugOnly = region.parentIsDebugOnly || conditionIsDebugOnly
        regions.append(region)
    }

    /// Moves the innermost region to its `#else` branch.
    mutating func moveToElse() {
        guard var region = regions.popLast() else { return }
        region.isDebugOnly = region.parentIsDebugOnly || !region.anyConditionIsDebugOnly
        regions.append(region)
    }

    /// Leaves the innermost region.
    mutating func pop() {
        _ = regions.popLast()
    }

    /// Whether a condition compiles only in a debug build.
    private func isDebugCondition(_ condition: String) -> Bool {
        condition.contains("DEBUG") && !condition.contains("!DEBUG")
    }
}
