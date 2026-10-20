//
// SubAgentProgressView.swift
//
// 'kanbanchat, userworkprogress'.
//  Reads from WSKanbanRepository.shared (= @MainActor SwiftData wrapper; =  deleted KanbanStore actor), renders running / done sub-agent tasks in aiDynamic zone.
//

import SwiftUI
import WenshuData

private nonisolated func toDomain(_ model: WSKanbanTask) -> KanbanTask {
    KanbanTask(
        id: model.id,
        title: model.title,
        status: KanbanStatus(rawValue: model.status) ?? .new,
        createdAt: model.createdAt,
        updatedAt: model.updatedAt,
        priority: model.priority,
        assignee: model.assignee,
        startedAt: model.startedAt,
        completedAt: model.completedAt,
        modelOverride: model.modelOverride,
        body: model.body
    )
}
