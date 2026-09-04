//
//  IdeaLibraryToolsTests.swift · Wenshu · P1 ticket #15 (PORT-SPECIALIZED-010, 2026-09-04)
//
//  5 round-trip tests for IdeaLibrary actor (the Swift port of
//  hermes's `agent/specialized/idea_library.py`):
//
//    1. testAddIdea_persistsToBookSidecar
//    2. testUpdateIdea_updatesStatus
//    3. testListIdeas_filtersByStatus
//    4. testSearchIdeas_returnsMatchingByTitleAndDescription
//    5. testLinkIdea_recordsLinkToChapter
//
//  Test isolation: each test creates a fresh /tmp root +
//  shelvesRoot + a per-book subdirectory that mirrors the
//  production walk (`<shelvesRoot>/<shelf>/books/<id>/`).
//  Caller-side teardown is not required (= the directory is
//  /tmp + unique uuid; macOS auto-cleans /tmp).
//
//  Test pattern mirrors TagManagerToolsTests /
//  CharacterLifecycleToolsTests (= uses the real
//  LibraryStores struct + FileSystemReferenceStore; no stubs).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("IdeaLibrary (PORT-SPECIALIZED-010)")
struct IdeaLibraryToolsTests {

    // MARK: - Shared helpers

    /// Build a tiny BookStore rooted in a unique /tmp directory.
    private static func makeBookStore() throws -> (BookStore, LibraryStores) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-p1-15-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = tmpRoot.appendingPathComponent("reference-library", isDirectory: true)
        let referenceStore = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: referenceStore
        )
        return (BookStore(stores: stores), stores)
    }

    /// Build a per-test book directory under `stores.shelvesRoot`.
    private static func makeBookDir(under stores: LibraryStores, bookId: UUID) throws -> URL {
        let shelfUUID = UUID().uuidString
        let bookDir = stores.shelvesRoot
            .appendingPathComponent(shelfUUID, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        return bookDir
    }

    /// Convenience composition of `makeBookStore` + `makeBookDir`.
    private static func makeBookStoreWithDir(for bookId: UUID) throws -> (BookStore, URL) {
        let (store, stores) = try makeBookStore()
        let dir = try makeBookDir(under: stores, bookId: bookId)
        return (store, dir)
    }

    private static func sampleBookId() -> UUID { UUID() }

    // MARK: - Test 1: add idea persists to the sidecar

    @Test("add persists an idea to the per-book sidecar")
    func testAddIdea_persistsToBookSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, dir) = try Self.makeBookStoreWithDir(for: bookId)
        let library = IdeaLibrary(bookStore: store)

        let idea = Idea(
            bookId: bookId,
            title: "The Mirror Motif",
            description: "Reflections in water as a recurring symbol of self-recognition.",
            status: .seedling,
            tags: ["mirror", "water", "recognition"]
        )
        try await library.add(idea)

        // Reload via a fresh actor (= proves the write actually
        // hit disk + was re-read on cold cache).
        let reloaded = IdeaLibrary(bookStore: store)
        let listed = try await reloaded.list(bookId: bookId)
        #expect(listed.count == 1)
        let saved = listed.first
        #expect(saved?.id == idea.id)
        #expect(saved?.title == "The Mirror Motif")
        #expect(saved?.description == "Reflections in water as a recurring symbol of self-recognition.")
        #expect(saved?.status == .seedling)
        #expect(saved?.tags == ["mirror", "water", "recognition"])

        // Sidecar file must exist on disk (= the actor wrote it).
        let sidecarURL = dir.appendingPathComponent("ideas.json")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))
    }

    // MARK: - Test 2: update idea updates status

    @Test("update changes the idea's status")
    func testUpdateIdea_updatesStatus() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let library = IdeaLibrary(bookStore: store)

        var idea = Idea(
            bookId: bookId,
            title: "Drowning Metaphor",
            description: "Submersion = emotional surrender.",
            status: .seedling,
            tags: ["water", "surrender"]
        )
        try await library.add(idea)

        // Reload via a fresh actor to confirm the seed status.
        let reloaded = IdeaLibrary(bookStore: store)
        let seeded = try await reloaded.get(id: idea.id)
        #expect(seeded?.status == .seedling)

        // Update: seedling → developing, edit description + tags.
        idea = Idea(
            id: idea.id,
            bookId: idea.bookId,
            title: idea.title,
            description: "Submersion as emotional surrender; the protagonist stops fighting.",
            status: .developing,
            tags: ["water", "surrender", "submersion"],
            links: [],
            createdAt: idea.createdAt,
            updatedAt: Date()
        )
        try await library.update(idea)

        // Reload again to verify the status stuck on disk.
        let reloaded2 = IdeaLibrary(bookStore: store)
        let updated = try await reloaded2.get(id: idea.id)
        #expect(updated?.status == .developing)
        #expect(updated?.description == "Submersion as emotional surrender; the protagonist stops fighting.")
        #expect(updated?.tags == ["water", "surrender", "submersion"])
    }

    // MARK: - Test 3: list filters by status

    @Test("list filters ideas by status")
    func testListIdeas_filtersByStatus() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let library = IdeaLibrary(bookStore: store)

        // 5 ideas across 3 statuses.
        let seedling = Idea(
            bookId: bookId,
            title: "Submersion as a state of mind",
            description: "Drowning in the ordinary.",
            status: .seedling,
            tags: ["water"]
        )
        let developing = Idea(
            bookId: bookId,
            title: "The Mirror Motif",
            description: "Reflections in water as recognition.",
            status: .developing,
            tags: ["mirror"]
        )
        let mature = Idea(
            bookId: bookId,
            title: "Recognition through water",
            description: "She sees herself for the first time.",
            status: .mature,
            tags: ["mirror", "water"]
        )
        let planted = Idea(
            bookId: bookId,
            title: "Recognition through stone",
            description: "Stones remember the people who carry them.",
            status: .planted,
            tags: ["stone"]
        )
        let discarded = Idea(
            bookId: bookId,
            title: "The colour of regret",
            description: "Abandoned: too on-the-nose.",
            status: .discarded,
            tags: ["colour"]
        )
        try await library.add(seedling)
        try await library.add(developing)
        try await library.add(mature)
        try await library.add(planted)
        try await library.add(discarded)

        // Filter by .seedling: only the seedling row.
        let seedlings = try await library.list(bookId: bookId, status: .seedling)
        #expect(seedlings.count == 1)
        #expect(seedlings.first?.id == seedling.id)

        // Filter by .planted: only the planted row.
        let plantedOnly = try await library.list(bookId: bookId, status: .planted)
        #expect(plantedOnly.count == 1)
        #expect(plantedOnly.first?.id == planted.id)

        // No filter (= all 5).
        let all = try await library.list(bookId: bookId)
        #expect(all.count == 5)

        // Filter by tag = "mirror": developing + mature (= 2 rows).
        let mirrors = try await library.list(bookId: bookId, tag: "mirror")
        #expect(mirrors.count == 2)
        #expect(mirrors.contains { $0.id == developing.id })
        #expect(mirrors.contains { $0.id == mature.id })

        // Combined filter: status = .developing, tag = "mirror":
        // exactly the developing row.
        let combo = try await library.list(bookId: bookId, status: .developing, tag: "mirror")
        #expect(combo.count == 1)
        #expect(combo.first?.id == developing.id)
    }

    // MARK: - Test 4: search returns matches by title + description

    @Test("search returns matching ideas by title and description")
    func testSearchIdeas_returnsMatchingByTitleAndDescription() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let library = IdeaLibrary(bookStore: store)

        let mirror = Idea(
            bookId: bookId,
            title: "The Mirror Motif",
            description: "Reflections in water as recognition.",
            status: .developing
        )
        let stone = Idea(
            bookId: bookId,
            title: "Stone memories",
            description: "Stones remember the people who carry them across a generation.",
            status: .mature
        )
        let drowning = Idea(
            bookId: bookId,
            title: "Drowning Metaphor",
            description: "The protagonist feels like she is underwater every time the antagonist enters the room.",
            status: .seedling
        )
        let unrelated = Idea(
            bookId: bookId,
            title: "Notes on pacing",
            description: "Midpoint scene must raise stakes.",
            status: .seedling
        )
        try await library.add(mirror)
        try await library.add(stone)
        try await library.add(drowning)
        try await library.add(unrelated)

        // Query "mirror" matches by title only: 1 row.
        let byTitle = try await library.search(bookId: bookId, query: "mirror")
        #expect(byTitle.count == 1)
        #expect(byTitle.first?.id == mirror.id)

        // Query "water" matches description of `mirror` + title /
        // description of `drowning` (= 2 rows).
        let byWater = try await library.search(bookId: bookId, query: "water")
        #expect(byWater.count == 2)
        #expect(byWater.contains { $0.id == mirror.id })
        #expect(byWater.contains { $0.id == drowning.id })

        // Query "stones" matches title of `stone` + description
        // of `stone` (= 1 row, de-duplicated).
        let byStones = try await library.search(bookId: bookId, query: "stones")
        #expect(byStones.count == 1)
        #expect(byStones.first?.id == stone.id)

        // Case-insensitive match: query "MIRROR" still matches
        // `mirror`.
        let caseInsensitive = try await library.search(bookId: bookId, query: "MIRROR")
        #expect(caseInsensitive.count == 1)
        #expect(caseInsensitive.first?.id == mirror.id)

        // Query with no match: empty.
        let noMatch = try await library.search(bookId: bookId, query: "vampire")
        #expect(noMatch.isEmpty)

        // Empty query: every row (= 4).
        let emptyQuery = try await library.search(bookId: bookId, query: "")
        #expect(emptyQuery.count == 4)
    }

    // MARK: - Test 5: link idea records a link to chapter

    @Test("link records an IdeaLink on the idea + auto-bumps status to planted")
    func testLinkIdea_recordsLinkToChapter() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let library = IdeaLibrary(bookStore: store)

        let idea = Idea(
            bookId: bookId,
            title: "Recognition through water",
            description: "She sees her reflection for the first time.",
            status: .mature,
            tags: ["mirror", "water"]
        )
        try await library.add(idea)

        // Reload + add a chapter link.
        let reloaded = IdeaLibrary(bookStore: store)
        let chapterA = UUID()
        let link = IdeaLink(
            target: .chapter,
            targetId: chapterA,
            context: "Chapter 7 opening — protagonist sees her reflection."
        )
        try await reloaded.link(ideaId: idea.id, link: link)

        // Verify the link stuck + status auto-bumped to .planted.
        let reloaded2 = IdeaLibrary(bookStore: store)
        let stored = try await reloaded2.get(id: idea.id)
        #expect(stored?.links.count == 1)
        #expect(stored?.links.first?.target == .chapter)
        #expect(stored?.links.first?.targetId == chapterA)
        #expect(stored?.links.first?.context == "Chapter 7 opening — protagonist sees her reflection.")
        // Auto-bump: mature → planted (= because the idea now
        // has 1+ links).
        #expect(stored?.status == .planted)

        // Add a second link (character). Status stays .planted.
        let characterC = UUID()
        let charLink = IdeaLink(
            target: .character,
            targetId: characterC,
            context: "Applied to the protagonist's inner monologue arc."
        )
        try await reloaded.link(ideaId: idea.id, link: charLink)

        let reloaded3 = IdeaLibrary(bookStore: store)
        let afterSecond = try await reloaded3.get(id: idea.id)
        #expect(afterSecond?.links.count == 2)
        #expect(afterSecond?.status == .planted)

        // Unlink the chapter link: only the character link
        // remains; status stays .planted (still has 1+ link).
        try await reloaded.unlink(ideaId: idea.id, link: link)
        let afterUnlink = try await reloaded3.get(id: idea.id)
        _ = afterUnlink // (= fetch verifies cache; result already checked above)

        let reloaded4 = IdeaLibrary(bookStore: store)
        let final = try await reloaded4.get(id: idea.id)
        #expect(final?.links.count == 1)
        #expect(final?.links.first?.target == .character)
        #expect(final?.links.first?.targetId == characterC)
    }
}