//
//  WSEntityTests.swift · Wenshu · v2.3 (2026-09-25)
//
//  Tests for the WSEntity / WSBody SwiftData @Models.
//
//  Verifies:
//  - WSEntity stores every field, round-trips through init.
//  - WSEntity.touch() stamps updatedAt.
//  - WSBody.replaceBody mutates the markdown and stamps updatedAt.
//  - WSEntity + WSBody both register in Container (= schema
//    integrity; = this would be caught at first ModelContainer
//    init in production).
//

import Testing
import Foundation
import SwiftData
@testable import WenshuApp

@Suite("WSEntity (v2.3)")
struct WSEntityTests {

    @Test func initStoresEveryField() {
        let entity = WSEntity(
            id: "ent-1",
            bookID: "book-1",
            kind: "person",
            name: "Lin Fan",
            aliasesJoined: "凡人",
            tagsJoined: "主角,修道",
            description: "Main character",
            attributesJSON: "{\"hair\":\"black\"}",
            kindSpecificJSON: nil,
            bodyID: "body-1"
        )
        #expect(entity.id == "ent-1")
        #expect(entity.bookID == "book-1")
        #expect(entity.kind == "person")
        #expect(entity.name == "Lin Fan")
        #expect(entity.aliasesJoined == "凡人")
        #expect(entity.tagsJoined == "主角,修道")
        #expect(entity.description_ == "Main character")
        #expect(entity.attributesJSON == "{\"hair\":\"black\"}")
        #expect(entity.kindSpecificJSON == nil)
        #expect(entity.bodyID == "body-1")
    }

    @Test func initDefaultsAreEmpty() {
        let entity = WSEntity(
            id: "ent-2",
            bookID: "book-2",
            kind: "location",
            name: "Beijing",
            bodyID: "body-2"
        )
        #expect(entity.aliasesJoined.isEmpty)
        #expect(entity.tagsJoined.isEmpty)
        #expect(entity.description_.isEmpty)
        #expect(entity.attributesJSON == nil)
        #expect(entity.kindSpecificJSON == nil)
    }

    @Test func touchUpdatesUpdatedAt() async {
        let entity = WSEntity(
            id: "ent-3",
            bookID: "book-3",
            kind: "ability",
            name: "御剑术",
            bodyID: "body-3"
        )
        let originalUpdatedAt = entity.updatedAt
        // Wait long enough that Date() differs at sub-second
        // resolution (= Date() is sub-second precision but
        // we sleep 50ms to be safe).
        try? await Task.sleep(nanoseconds: 50_000_000)
        entity.touch()
        #expect(entity.updatedAt > originalUpdatedAt)
    }
}

@Suite("WSBody (v2.3)")
struct WSBodyTests {

    @Test func initStoresMarkdown() {
        let body = WSBody(id: "body-1", markdown: "# Lin Fan\n\nMain character.")
        #expect(body.id == "body-1")
        #expect(body.markdown == "# Lin Fan\n\nMain character.")
    }

    @Test func replaceBodyMutatesAndStamps() async {
        let body = WSBody(id: "body-2", markdown: "v1")
        let originalUpdatedAt = body.updatedAt
        try? await Task.sleep(nanoseconds: 50_000_000)
        body.replaceBody("v2 with longer content")
        #expect(body.markdown == "v2 with longer content")
        #expect(body.updatedAt > originalUpdatedAt)
    }

    @Test func emptyBodyAllowed() {
        let body = WSBody(id: "body-3", markdown: "")
        #expect(body.markdown.isEmpty)
    }
}

@Suite("WSEntity in Container (v2.3)")
struct WSEntityContainerTests {

    @Test func schemaContainsEntityAndBody() throws {
        // Build an in-memory container with the production schema
        // array; = if WSEntity / WSBody were missing from Container,
        // this would fail to instantiate.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WSPersistenceContainer.schema,
            configurations: [config]
        )
        let context = ModelContext(container)
        let body = WSBody(id: "b1", markdown: "hello")
        let entity = WSEntity(id: "e1", bookID: "book-x", kind: "person", name: "A", bodyID: "b1")
        context.insert(body)
        context.insert(entity)
        try context.save()

        // Round-trip read.
        let descriptor = FetchDescriptor<WSEntity>(
            predicate: #Predicate { $0.id == "e1" }
        )
        let entities = try context.fetch(descriptor)
        #expect(entities.count == 1)
        #expect(entities.first?.name == "A")
        #expect(entities.first?.bodyID == "b1")
    }
}