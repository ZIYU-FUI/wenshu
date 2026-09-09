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
            Text(WenshuI18n.t("b5.cronscheduleview.l17.h81796733"))
                .font(.headline)
            Text(WenshuI18n.t("b5.cronscheduleview.l19.h49619526"))
                .font(.body)
                .foregroundStyle(.secondary)
            if store == nil {
                Text(WenshuI18n.t("b5.cronscheduleview.l23.h89948587"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        // v0.24 bossverificationfix: flexible sizing (zone size controlled by splitter, not view).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            if store == nil { store = CronjobStore() }
        }
    }
}