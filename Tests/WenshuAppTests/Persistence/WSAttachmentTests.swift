//
//  Persistence/WSAttachmentTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSAttachment (= attachments @Model)")
struct WSAttachmentTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSAttachment.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSAttachment init with inline data (= thumbnail / small file)")
    @MainActor
    func initInlineData() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])  // PNG header
        let att = WSAttachment(
            id: "att-001",
            parentKind: "chat_message",
            parentID: "msg-42",
            filename: "thumb.png",
            mimeType: "image/png",
            sizeBytes: png.count
        )
        att.data = png
        context.insert(att)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSAttachment>())
        #expect(fetched.count == 1)
        #expect(fetched[0].data == png)
        #expect(fetched[0].externalPath == nil)
        #expect(fetched[0].hasValidStorage == true)
    }

    @Test("WSAttachment init with externalPath (= large file on disk)")
    @MainActor
    func initExternalPath() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let att = WSAttachment(
            id: "att-002",
            parentKind: "kanban_task",
            parentID: "task-1",
            filename: "diagram.pdf",
            mimeType: "application/pdf",
            sizeBytes: 1_234_567
        )
        att.externalPath = "/Users/anbaiqiang/Library/Caches/wenshu/diagram.pdf"
        context.insert(att)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSAttachment>())
        #expect(fetched[0].data == nil)
        #expect(fetched[0].externalPath == "/Users/anbaiqiang/Library/Caches/wenshu/diagram.pdf")
        #expect(fetched[0].hasValidStorage == true)
    }

    @Test("WSAttachment hasValidStorage invariant (= data XOR externalPath)")
    @MainActor
    func storageInvariant() throws {
        let both = WSAttachment(id: "1", parentKind: "x", parentID: "y", filename: "f", mimeType: "z", sizeBytes: 0)
        both.data = Data(repeating: 0, count: 4)
        both.externalPath = "/p"
        #expect(both.hasValidStorage == false)

        let neither = WSAttachment(id: "2", parentKind: "x", parentID: "y", filename: "f", mimeType: "z", sizeBytes: 0)
        #expect(neither.hasValidStorage == false)

        let dataOnly = WSAttachment(id: "3", parentKind: "x", parentID: "y", filename: "f", mimeType: "z", sizeBytes: 0)
        dataOnly.data = Data(repeating: 0, count: 4)
        #expect(dataOnly.hasValidStorage == true)

        let pathOnly = WSAttachment(id: "4", parentKind: "x", parentID: "y", filename: "f", mimeType: "z", sizeBytes: 0)
        pathOnly.externalPath = "/p"
        #expect(pathOnly.hasValidStorage == true)
    }

    @Test("WSAttachment id uniqueness enforced")
    @MainActor
    func idUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSAttachment(id: "same", parentKind: "chat_message", parentID: "m1", filename: "f", mimeType: "z", sizeBytes: 0)
        let b = WSAttachment(id: "same", parentKind: "kanban_task", parentID: "k1", filename: "f", mimeType: "z", sizeBytes: 0)
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }
}
