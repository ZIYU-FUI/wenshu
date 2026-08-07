// MainView.swift · 文枢 (Wenshu) · v0.01.0 WO-001
//
// Top-level skeleton view. Pure placeholder for WO-001:
// - NavigationSplitView (the three-pane shape that the long-form
//   dashboard layout in CLAUDE.md §4 calls for)
// - Left sidebar: 项目 placeholder
// - Right detail: 欢迎 placeholder
//
// No business logic. No data flow. No state. Just enough surface area
// for PM-direct to verify the window opens and renders.

import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationSplitView {
            // Sidebar (left) — 项目 list placeholder.
            // WO-002 will replace the placeholder list with the real
            // ProjectListView bound to the WenshuStore actor.
            List {
                Section("项目") {
                    Text("(empty — WO-002)")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("文枢")
            .frame(minWidth: 220)
        } detail: {
            // Detail (right) — 欢迎 placeholder.
            // WO-002 will host the DashboardView (CLAUDE.md §4 module row
            // for 看板).
            VStack(spacing: 12) {
                Image(systemName: "book.closed")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.secondary)
                Text("欢迎")
                    .font(.title)
                Text("WO-001 baseline · v0.01.0")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Empty window. Swift toolchain wired.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle("欢迎")
        }
    }
}

// WO-001 ships no PreviewProvider / no tests yet. `swift test` will be
// meaningful once WO-002 introduces WenshuStoreActor (see CLAUDE.md §8
// Verification list).
