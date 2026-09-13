//
//  Persistence/WSLinkTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSLink (= links @Model)")
struct WSLinkTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSLink.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSLink init builds composite id from sourceDocID + line")
    @MainActor
    func compositeId() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let link = WSLink(
            sourceDocID: "doc-42",
            targetRef: "EntityName",
            line: 17,
            offset: 5
        )
        context.insert(link)
        try context.save()
        #expect(link.id == "doc-42:17")
        #expect(link.sourceDocID == "doc-42")
        #expect(link.targetRef == "EntityName")
        #expect(link.line == 17)
        #expect(link.offset == 5)
        #expect(link.targetDocID == nil)
    }

    @Test("WSLink with targetDocID resolved (= internal link to existing doc)")
    @MainActor
    func targetDocIDResolved() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let link = WSLink(
            sourceDocID: "doc-A",
            targetRef: "B",
            targetDocID: "doc-B",
            line: 1,
            offset: 0
        )
        context.insert(link)
        try context.save()
        #expect(link.targetDocID == "doc-B")
    }

    @Test("WSLink id uniqueness (= same sourceDocID + line rejected)")
    @MainActor
    func idUniqueRejectsDuplicate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSLink(sourceDocID: "doc", targetRef: "X", line: 5, offset: 0)
        let b = WSLink(sourceDocID: "doc", targetRef: "Y", line: 5, offset: 0)
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }

    @Test("WSLink same target at different lines allowed (= different ids)")
    @MainActor
    func differentLinesAllowed() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSLink(sourceDocID: "doc", targetRef: "X", line: 5, offset: 0)
        let b = WSLink(sourceDocID: "doc", targetRef: "X", line: 6, offset: 0)
        context.insert(a)
        context.insert(b)
        try context.save()
        let all = try context.fetch(FetchDescriptor<WSLink>())
        #expect(all.count == 2)
        #expect(a.id == "doc:5")
        #expect(b.id == "doc:6")
    }
}
