//
//  Persistence/WSSummaryTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSSummary (= chat_summaries @Model)")
struct WSSummaryTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSSummary.self, WSSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSSummary init sets summary + token counts + range + model")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let summary = WSSummary(
            id: "sum-001",
            sessionID: "sess-A",
            summary: "User asked about X. Agent explained Y.",
            startMessageID: "msg-1",
            endMessageID: "msg-10",
            coveredTokenCount: 5000,
            summaryTokenCount: 200,
            modelUsed: "claude-sonnet-4.5"
        )
        context.insert(summary)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSSummary>())
        #expect(fetched.count == 1)
        #expect(fetched[0].id == "sum-001")
        #expect(fetched[0].sessionID == "sess-A")
        #expect(fetched[0].summary.contains("X"))
        #expect(fetched[0].coveredTokenCount == 5000)
        #expect(fetched[0].summaryTokenCount == 200)
        #expect(fetched[0].startMessageID == "msg-1")
        #expect(fetched[0].endMessageID == "msg-10")
        #expect(fetched[0].modelUsed == "claude-sonnet-4.5")
    }

    @Test("WSSummary 1↔1 relationship to WSSession")
    @MainActor
    func relationshipToSession() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let session = WSSession(sessionID: "sess-sum", title: "with summary")
        context.insert(session)
        let summary = WSSummary(
            id: "sum-rel",
            sessionID: session.sessionID,
            summary: "x",
            startMessageID: "m1",
            endMessageID: "m2",
            coveredTokenCount: 100,
            summaryTokenCount: 10,
            modelUsed: "claude-sonnet-4.5"
        )
        context.insert(summary)
        summary.session = session
        try context.save()

        // Forward + inverse
        #expect(summary.session?.sessionID == "sess-sum")
        #expect(session.summary?.id == "sum-rel")
    }

    @Test("WSSummary id uniqueness enforced")
    @MainActor
    func idUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSSummary(id: "same", sessionID: "s", summary: "a", startMessageID: "m", endMessageID: "m", coveredTokenCount: 0, summaryTokenCount: 0, modelUsed: "x")
        let b = WSSummary(id: "same", sessionID: "s", summary: "b", startMessageID: "m", endMessageID: "m", coveredTokenCount: 0, summaryTokenCount: 0, modelUsed: "x")
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }
}
