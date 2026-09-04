//
//  TodoListView.swift · Wenshu · v0.22 ticket h07 (hermes replica, frontend mount)
//  Replica of hermes todo UI. Reads from TodoStore.
//

import SwiftUI

/// Standalone todo list view, presented as sheet from Z-CHAT toolbar.
public struct TodoListView: View {
    @State private var store: TodoStore?

    public init() {}

    public var body: some View {
        // v0.22 h07: placeholder todo list UI. Real bind to user todos in follow-up.
        VStack(alignment: .leading, spacing: 8) {
            Text("Todo")
                .font(.headline)
            Text("0 items · replica of hermes todo")
                .font(.body)
                .foregroundStyle(.secondary)
            if store == nil {
                Text("(store unavailable — bootstrap may have failed)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        // v0.24 boss验收fix: flexible sizing (zone size controlled by splitter, not view).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            if store == nil { store = try? TodoStore() }
        }
    }
}