//
//  Persistence/Repositories/WSLinkRepositoryTests.swift · Wenshu · v0.72 SwiftData migration Phase 2

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSLinkRepository (= SwiftData @Model LinkIndex replacement)")
struct WSLinkRepositoryTests {

    @MainActor
    private func makeRepository() throws -> WSLinkRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSLinkRepository(container: container)
    }

    @Test("add + searchForward round-trip")
    @MainActor
    func searchForward() throws {
        let repo = try makeRepository()
        try repo.add(Link(sourceDocId: "doc-1", targetRef: "OtherDoc", targetDocId: nil, line: 10, offset: 0))
        try repo.add(Link(sourceDocId: "doc-1", targetRef: "YetAnother", targetDocId: nil, line: 20, offset: 0))
        let links = try repo.searchForward(sourceDocId: "doc-1")
        #expect(links.count == 2)
        #expect(links[0].line == 10)
        #expect(links[1].line == 20)
    }

    @Test("searchBackward(targetRef:) finds incoming links")
    @MainActor
    func searchBackwardByRef() throws {
        let repo = try makeRepository()
        try repo.add(Link(sourceDocId: "src-1", targetRef: "Target", targetDocId: nil, line: 1, offset: 0))
        try repo.add(Link(sourceDocId: "src-2", targetRef: "Target", targetDocId: nil, line: 1, offset: 0))
        let backlinks = try repo.searchBackward(targetRef: "Target")
        #expect(backlinks.count == 2)
    }

    @Test("searchBackward(targetDocId:) finds incoming links by resolved id")
    @MainActor
    func searchBackwardByDocId() throws {
        let repo = try makeRepository()
        try repo.add(Link(sourceDocId: "src", targetRef: "x", targetDocId: "doc-target", line: 1, offset: 0))
        let backlinks = try repo.searchBackward(targetDocId: "doc-target")
        #expect(backlinks.count == 1)
        #expect(backlinks[0].sourceDocId == "src")
    }

    @Test("removeAll(sourceDocId:) deletes all links from that source")
    @MainActor
    func removeAll() throws {
        let repo = try makeRepository()
        try repo.add(Link(sourceDocId: "doc-1", targetRef: "x", targetDocId: nil, line: 1, offset: 0))
        try repo.add(Link(sourceDocId: "doc-1", targetRef: "y", targetDocId: nil, line: 2, offset: 0))
        try repo.add(Link(sourceDocId: "doc-2", targetRef: "z", targetDocId: nil, line: 3, offset: 0))
        try repo.removeAll(sourceDocId: "doc-1")
        let doc1 = try repo.searchForward(sourceDocId: "doc-1")
        let doc2 = try repo.searchForward(sourceDocId: "doc-2")
        #expect(doc1.isEmpty)
        #expect(doc2.count == 1)
    }

    @Test("add replaces existing link at same sourceDocId + line (= composite id)")
    @MainActor
    func addReplaces() throws {
        let repo = try makeRepository()
        try repo.add(Link(sourceDocId: "doc", targetRef: "old", targetDocId: nil, line: 5, offset: 0))
        try repo.add(Link(sourceDocId: "doc", targetRef: "new", targetDocId: nil, line: 5, offset: 1))
        let links = try repo.searchForward(sourceDocId: "doc")
        #expect(links.count == 1)
        #expect(links[0].targetRef == "new")
        #expect(links[0].offset == 1)
    }
}
