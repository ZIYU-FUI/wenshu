//
//  KanbanView.swift · Wenshu · v0.22 ticket h06 (hermes replica, frontend mount)
//  Replica of hermes kanban UI. Reads from KanbanStore.
//

import SwiftUI

/// Standalone kanban board view, presented as sheet from Z-NOVEL toolbar.
public struct KanbanView: View {
    @State private var store: KanbanStore?

    public init() {}

    public var body: some View {
        // v0.22 h06: placeholder kanban UI. Real board layout in follow-up.
        VStack(alignment: .leading, spacing: 8) {
            Text("Kanban")
                .font(.headline)
            Text("Replica of hermes kanban_db")
                .font(.body)
                .foregroundStyle(.secondary)
            if store == nil {
                Text("(store unavailable — bootstrap may have failed)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        // v0.24 boss验收fix: flexible size (was: 480x320 min forcing zone to grow).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            if store == nil { store = try? KanbanStore() }
        }
    }
}