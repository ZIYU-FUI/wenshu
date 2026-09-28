//
//  CronWindow.swift · Wenshu · v2.8b ticket T10-T13 (boss 2026-09-28 OOB B9)
//
//  Independent Cron window (= the previously-unwired cron schedule
//  + prompt-scanner surface).
//
//  Per boss 2026-09-28 OOB B9 '和老板 todo 一样' (= same shape as
//  the existing kanban + todo windows): build an MVP independent
//  Cron window that lists + edits cron schedules (= the future
//  ticket wires to the underlying CronScheduler actor; = this
//  view is the UI host).
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6
//        + Apple HIG `.windowResizability(.contentSize)` (= the
//        same shape as kanban + todo windows).
//    S3 (single source of truth for cron state): the view reads
//        / writes through the future CronScheduler actor (= no
//        duplicated schedule storage).

import SwiftUI

/// One cron schedule row (= the shape we'll display + edit;
/// = the underlying storage is the future CronScheduler actor).
struct CronSchedule: Identifiable, Equatable {
    let id: String
    let cronExpression: String
    let prompt: String
    var displayName: String { "\(cronExpression) → \(prompt)" }
}

/// Independent Cron window (= MVP per boss 2026-09-28 OOB B9).
@MainActor
struct CronWindow: View {

    @State private var schedules: [CronSchedule] = []

    init() {}

    var body: some View {
        NavigationStack {
            contentBody
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            // future ticket: wire to CronScheduler
                            // actor (= the agent-team cron backend).
                        } label: {
                            Label {
                                Text(WenshuI18n.t("cron.add"))
                            } icon: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
        }
        .frame(minWidth: 540, minHeight: 400)
    }

    @ViewBuilder
    private var contentBody: some View {
        if schedules.isEmpty {
            EmptyStateView(
                icon: "clock",
                title: WenshuI18n.t("cron.empty.title"),
                body: WenshuI18n.t("cron.empty.body")
            )
        } else {
            List(schedules) { schedule in
                Text(schedule.displayName)
            }
        }
    }
}