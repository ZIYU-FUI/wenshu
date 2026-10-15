//
//  Persistence/Repositories/WSLinkRepository.swift
//
//  v3.1 governance A1 refactor (= boundary probe 3/8).
//  Apple canonical layering per Backyard Birds:
//    - write API = domain in (Repository converts Link -> WSLink @Model)
//    - read  API = @Model out (caller converts WSLink -> Link)
//
//  Public API after A1 probe:
//    - add(_ link: Link) throws                (write: domain in)
//    - removeAll(sourceDocId:) throws          (delete by source)
//    - searchForward(sourceDocId:) -> [WSLink]  (read: raw @Model out)
//    - searchBackward(targetRef:) -> [WSLink]
//    - searchBackward(targetDocId:) -> [WSLink]
//
//  Per AGENTS.md §11.4.

import Foundation
import SwiftData

@MainActor
final class WSLinkRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    func add(_ link: Link) throws {
        // Composite id must match WSLink.init (= sourceDocID + line + targetRef; =
        //  added targetRef so 2 [[name]] links on same line
        // don't collide). Lookup using truncated id here would miss the
        // existing row and trigger @Attribute(.unique) insert failure.
        let id = "\(link.sourceDocId):\(link.line):\(link.targetRef)"
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.id == id }
        )
        // Replace existing (= old api `add` is upsert behavior)
        if let existing = try context.fetch(descriptor).first {
            existing.targetRef = link.targetRef
            existing.targetDocID = link.targetDocId
            existing.offset = link.offset
        } else {
            let model = WSLink(
                sourceDocID: link.sourceDocId,
                targetRef: link.targetRef,
                targetDocID: link.targetDocId,
                line: link.line,
                offset: link.offset
            )
            context.insert(model)
        }
        try context.save()
    }

    func removeAll(sourceDocId: String) throws {
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.sourceDocID == sourceDocId }
        )
        let models = try context.fetch(descriptor)
        for model in models {
            context.delete(model)
        }
        try context.save()
    }

    func searchForward(sourceDocId: String) throws -> [WSLink] {
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.sourceDocID == sourceDocId },
            sortBy: [SortDescriptor(\.line)]
        )
        return try context.fetch(descriptor)
    }

    func searchBackward(targetRef: String) throws -> [WSLink] {
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.targetRef == targetRef },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func searchBackward(targetDocId: String) throws -> [WSLink] {
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.targetDocID == targetDocId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
