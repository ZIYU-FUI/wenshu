//
//  Persistence/Repositories/WSLinkRepository.swift
//
//  (= boundary decouple WSLinkRepository).
//  Apple canonical layering per Backyard Birds:
//    - write API = raw fields in (no app-side Link domain type).
//    - read  API = @Model out (= caller converts WSLink -> Link).
//
//    - add(sourceDocID:targetRef:targetDocID:line:offset:) throws
//    - removeAll(sourceDocId:) throws
//    - searchForward(sourceDocId:) -> [WSLink]
//    - searchBackward(targetRef:) -> [WSLink]
//    - searchBackward(targetDocId:) -> [WSLink]
//
//  Per AGENTS.md §11.4. Link is the caller-side domain type;
//  data layer treats it as raw primitives (= String / Int / String?).
//  Caller converts at the boundary (= Link(sourceDocID:...,
//
//  = caller converts WSLink -> Link).

import Foundation
import SwiftData

@MainActor
public final class WSLinkRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    public func add(
        sourceDocID: String,
        targetRef: String,
        targetDocID: String?,
        line: Int,
        offset: Int
    ) throws {
        // Composite id must match WSLink.init (= sourceDocID + line + targetRef; =
        //  added targetRef so 2 [[name]] links on same line
        // don't collide). Lookup using truncated id here would miss the
        // existing row and trigger @Attribute(.unique) insert failure.
        let id = "\(sourceDocID):\(line):\(targetRef)"
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.id == id }
        )
        // Replace existing (= old api `add` is upsert behavior)
        if let existing = try context.fetch(descriptor).first {
            existing.targetRef = targetRef
            existing.targetDocID = targetDocID
            existing.offset = offset
        } else {
            let model = WSLink(
                sourceDocID: sourceDocID,
                targetRef: targetRef,
                targetDocID: targetDocID,
                line: line,
                offset: offset
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

    public func searchForward(sourceDocId: String) throws -> [WSLink] {
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.sourceDocID == sourceDocId },
            sortBy: [SortDescriptor(\.line)]
        )
        return try context.fetch(descriptor)
    }

    public func searchBackward(targetRef: String) throws -> [WSLink] {
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.targetRef == targetRef },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    public func searchBackward(targetDocId: String) throws -> [WSLink] {
        let descriptor = FetchDescriptor<WSLink>(
            predicate: #Predicate { $0.targetDocID == targetDocId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
