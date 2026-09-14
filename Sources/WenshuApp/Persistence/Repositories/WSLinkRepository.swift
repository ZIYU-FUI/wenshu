//
//  Persistence/Repositories/WSLinkRepository.swift · Wenshu · v0.72 SwiftData migration Phase 2
//
//  Migration commit 27 of 42: WSLinkRepository.
//  Per AGENTS.md §11.4.
//
//  Thin wrapper for LinkIndex actor (= v0.19 ticket 12 Internal Link).
//
//  Public API (preserved 1:1 from old LinkIndex actor):
//    - add(_ link: Link) throws
//    - removeAll(sourceDocId:) throws
//    - searchForward(sourceDocId:) throws -> [Link]
//    - searchBackward(targetRef:) throws -> [Link]
//    - searchBackward(targetDocId:) throws -> [Link]
//
//  Domain type (preserved): Link (= sourceDocId + targetRef + targetDocId +
//  line + offset + createdAt).
//
//  Composite id: "<sourceDocID>:<line>:<targetRef>" (= unique per source +
//  line + target; = matches WSLink.init + Phase 5 ticket 5 fix).

import Foundation
import SwiftData

@MainActor
public final class WSLinkRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    public func add(_ link: Link) throws {
        // Composite id must match WSLink.init (= sourceDocID + line + targetRef; =
        // Phase 5 ticket 5 added targetRef so 2 [[name]] links on same line
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

    public func removeAll(sourceDocId: String) throws {
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.sourceDocID == sourceDocId }
        )
        let models = try context.fetch(descriptor)
        for model in models {
            context.delete(model)
        }
        try context.save()
    }

    public func searchForward(sourceDocId: String) throws -> [Link] {
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.sourceDocID == sourceDocId },
            sortBy: [SortDescriptor(\.line)]
        )
        return try context.fetch(descriptor).map { model in
            Link(
                sourceDocId: model.sourceDocID,
                targetRef: model.targetRef,
                targetDocId: model.targetDocID,
                line: model.line,
                offset: model.offset,
                createdAt: model.createdAt
            )
        }
    }

    public func searchBackward(targetRef: String) throws -> [Link] {
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.targetRef == targetRef },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { mapToDomain(model: $0) }
    }

    public func searchBackward(targetDocId: String) throws -> [Link] {
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.targetDocID == targetDocId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { mapToDomain(model: $0) }
    }

    private func mapToDomain(model: WSLink) -> Link {
        Link(
            sourceDocId: model.sourceDocID,
            targetRef: model.targetRef,
            targetDocId: model.targetDocID,
            line: model.line,
            offset: model.offset,
            createdAt: model.createdAt
        )
    }
}
