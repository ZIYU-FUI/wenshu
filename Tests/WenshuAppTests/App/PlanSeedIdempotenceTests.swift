//
//  PlanSeedIdempotenceTests.swift · Wenshu
//
//  The dev seed's board write is a set, not an append.
//
//  The task store outlives the launch that wrote it, so a seed that
//  only writes leaves one more copy of every sample each time the
//  environment asks for a seed, and the board then draws the same card
//  again and again. These cases hold both halves of the rule: a
//  repeated seeded launch leaves the same set, and a row the seed did
//  not write is never taken by it.
//

import Testing
@testable import WenshuApp
import WenshuData

@Suite("Plan seed (= the board's sample is written once, not once per launch)")
struct PlanSeedIdempotenceTests {
    /// A throwaway store (= no disk, = the board reads it as it reads
    /// the app's live store).
    @MainActor
    private static func makeRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }

    /// Every row the store holds, whatever board it names.
    @MainActor
    private static func allRows(_ repository: WSKanbanRepository) throws -> [WSKanbanTask] {
        try repository.list(status: nil)
    }

    /// The store keeps its rows across launches, so the launch before
    /// this one already left a copy. A second seeded launch must not
    /// lay a second set down beside it.
    @Test("a second seeded launch leaves the same set")
    @MainActor
    func aSecondSeededLaunchLeavesTheSameSet() throws {
        let repository = try Self.makeRepository()
        PlanSeed.seedTasks(bookID: "book-a", repository: repository)
        let afterFirst = try Self.allRows(repository)

        PlanSeed.seedTasks(bookID: "book-a", repository: repository)
        let afterSecond = try Self.allRows(repository)

        #expect(afterSecond.count == afterFirst.count)
        let pairs = afterSecond.map { "\($0.title)\u{1}\($0.body ?? "")" }
        #expect(Set(pairs).count == pairs.count)
    }

    /// The symptom: copies an earlier launch left, stacked under the
    /// new one. A seeded launch takes the seed's own rows back, so the
    /// stack collapses instead of growing.
    @Test("copies an earlier launch left collapse to one")
    @MainActor
    func copiesAnEarlierLaunchLeftCollapseToOne() throws {
        let repository = try Self.makeRepository()
        PlanSeed.seedTasks(bookID: "book-a", repository: repository)
        let sample = try #require(Self.allRows(repository).first)

        for _ in 0 ..< 3 {
            _ = try repository.add(
                title: sample.title,
                status: sample.status,
                body: sample.body,
                bookID: sample.bookID
            )
        }
        let stacked = try Self.allRows(repository)
        #expect(stacked.filter { $0.title == sample.title }.count == 4)

        PlanSeed.seedTasks(bookID: "book-a", repository: repository)
        let swept = try Self.allRows(repository)
        #expect(swept.filter { $0.title == sample.title }.count == 1)
    }

    /// A real task is not the seed's row. The title alone does not make
    /// it one: a task the user wrote can carry a sample's title, and
    /// the seed only takes rows whose body is a sample's body too.
    @Test("a task that only shares a sample's title stays")
    @MainActor
    func aTaskThatOnlySharesASamplesTitleStays() throws {
        let repository = try Self.makeRepository()
        PlanSeed.seedTasks(bookID: "book-a", repository: repository)
        let sample = try #require(Self.allRows(repository).first)

        _ = try repository.add(
            title: sample.title,
            status: "new",
            body: "The user's own note under the same title.",
            bookID: "book-a"
        )
        _ = try repository.add(
            title: sample.title,
            status: "new",
            bookID: "book-a"
        )

        PlanSeed.seedTasks(bookID: "book-a", repository: repository)
        let rows = try Self.allRows(repository)
        #expect(rows.contains { $0.body == "The user's own note under the same title." })
        #expect(rows.contains { $0.title == sample.title && $0.body == nil })
    }

    /// The board follows the session, so the sample moves with it. It
    /// does not stay behind on the board the previous session named and
    /// pile up across books.
    @Test("the sample follows the session instead of piling up per book")
    @MainActor
    func theSampleFollowsTheSessionInsteadOfPilingUpPerBook() throws {
        let repository = try Self.makeRepository()
        PlanSeed.seedTasks(bookID: "book-a", repository: repository)
        let setSize = try Self.allRows(repository).count

        PlanSeed.seedTasks(bookID: "book-b", repository: repository)

        #expect(try repository.list(bookID: "book-a").isEmpty)
        #expect(try repository.list(bookID: "book-b").count == setSize)
        #expect(try Self.allRows(repository).count == setSize)
    }
}
