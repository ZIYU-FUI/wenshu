//
//  Persistence/Repositories/WSLinkRepositoryTests.swift · Wenshu · v0.72 SwiftData migration 

import Foundation
import Testing
import WenshuData

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
        try repo.add(sourceDocID: "doc-1", targetRef: "OtherDoc", targetDocID: nil, line: 10, offset: 0)
        try repo.add(sourceDocID: "doc-1", targetRef: "YetAnother", targetDocID: nil, line: 20, offset: 0)
        let links = try repo.searchForward(sourceDocId: "doc-1")
        #expect(links.count == 2)
        #expect(links[0].line == 10)
        #expect(links[1].line == 20)
    }

    @Test("searchBackward(targetRef:) finds incoming links")
    @MainActor
    func searchBackwardByRef() throws {
        let repo = try makeRepository()
        try repo.add(sourceDocID: "src-1", targetRef: "Target", targetDocID: nil, line: 1, offset: 0)
        try repo.add(sourceDocID: "src-2", targetRef: "Target", targetDocID: nil, line: 1, offset: 0)
        let backlinks = try repo.searchBackward(targetRef: "Target")
        #expect(backlinks.count == 2)
    }

    @Test("searchBackward(targetDocId:) finds incoming links by resolved id")
    @MainActor
    func searchBackwardByDocId() throws {
        let repo = try makeRepository()
        try repo.add(sourceDocID: "src", targetRef: "x", targetDocID: "doc-target", line: 1, offset: 0)
        let backlinks = try repo.searchBackward(targetDocId: "doc-target")
        #expect(backlinks.count == 1)
        #expect(backlinks[0].sourceDocID == "src")
    }

    @Test("removeAll(sourceDocId:) deletes all links from that source")
    @MainActor
    func removeAll() throws {
        let repo = try makeRepository()
        try repo.add(sourceDocID: "doc-1", targetRef: "x", targetDocID: nil, line: 1, offset: 0)
        try repo.add(sourceDocID: "doc-1", targetRef: "y", targetDocID: nil, line: 2, offset: 0)
        try repo.add(sourceDocID: "doc-2", targetRef: "z", targetDocID: nil, line: 3, offset: 0)
        try repo.removeAll(sourceDocId: "doc-1")
        let doc1 = try repo.searchForward(sourceDocId: "doc-1")
        let doc2 = try repo.searchForward(sourceDocId: "doc-2")
        #expect(doc1.isEmpty)
        #expect(doc2.count == 1)
    }

    @Test("addMultipleAtSameLine: 2 distinct [[name]] links on the same line = 2 distinct rows (= composite id includes targetRef after )")
    @MainActor
    func addMultipleAtSameLine() throws {
        let repo = try makeRepository()
        try repo.add(sourceDocID: "doc", targetRef: "old", targetDocID: nil, line: 5, offset: 0)
        try repo.add(sourceDocID: "doc", targetRef: "new", targetDocID: nil, line: 5, offset: 1)
        let links = try repo.searchForward(sourceDocId: "doc")
        #expect(links.count == 2)
        // Both targetRefs preserved (= composite id = "<doc>:<line>:<targetRef>").
        let refs = Set(links.map(\.targetRef))
        #expect(refs == Set(["old", "new"]))
    }
}
