//
//  CronScheduleView.swift · Wenshu · v0.22 ticket h08 (hermes replica, frontend mount)
//  Replica of hermes cronjob UI.
//

import SwiftUI

/// Standalone cron schedule view, presented as sheet from Settings (or toolbar).
public struct CronScheduleView: View {
    @State private var store: CronjobStore?

    public init() {}

    public var body: some View {
        // v0.22 h08: placeholder cron UI. Real schedule management in follow-up.
        VStack(alignment: .leading, spacing: 8) {
            Text("Cron Schedule")
                .font(.headline)
            Text("0 schedules · replica of hermes cronjob")
                .font(.system(size: 13))
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
            if store == nil { store = CronjobStore() }
        }
    }
}