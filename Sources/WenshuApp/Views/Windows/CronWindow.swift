//
// Sources/WenshuApp/Views/Windows/_FILE_.swift
//
//  Independent Cron window (= the previously-unwired cron schedule
//  + prompt-scanner surface).
//
//  Per the existing kanban + todo window pattern: build an MVP
//  independent Cron window that lists + edits cron schedules (= the future
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

/// One cron schedule row (= the shape we display + edit; =
/// the underlying storage is the canonical CronjobStore
/// actor per AGENTS.md §11 baseline).
///
/// Maps to the canonical Cronjob struct (= name + command +
/// schedule); = the window displays the cron expression and
/// the command (= the LLM-or-shell payload) per row.
struct CronSchedule: Identifiable, Equatable {
    let id: String
    let cronExpression: String
    let command: String
    var displayName: String { "\(cronExpression) → \(command)" }
}

/// Independent dedicated window (= the multi-window MVP):
/// The canonical actor wiring lives in the follow-on surface.
/// canonical CronjobStore actor).
@MainActor
struct CronWindow: View {

    @State private var schedules: [CronSchedule] = []
    @State private var draftSchedule: String = ""
    @State private var draftCommand: String = ""
    @State private var draftName: String = ""
    @State private var errorText: String?

    /// Canonical cron store (= the actor that owns the
    /// LaunchAgent plist generation per AGENTS.md §11
    /// baseline).
    private let store = CronjobStore()

    init() {}

    var body: some View {
        NavigationStack {
            contentBody
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await reload() }
                        } label: {
                            Label {
                                Text(WenshuI18n.t("cron.refresh"))
                            } icon: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                }
        }
        .frame(minWidth: 540, minHeight: 400)
        .task { await reload() }
    }

    @ViewBuilder
    private var contentBody: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMedium) {
            // v2.9c: inline add-form for a new cron schedule
            // (= the actor path adds directly via store.add).
            addFormBody
        }
    }

    @ViewBuilder
    private var addFormBody: some View {
        if schedules.isEmpty {
            VStack {
                EmptyStateView(
                    icon: "clock",
                    title: WenshuI18n.t("cron.empty.title"),
                    body: WenshuI18n.t("cron.empty.body")
                )
                newScheduleForm
            }
        } else {
            List {
                Section {
                    ForEach(schedules) { schedule in
                        Text(schedule.displayName)
                    }
                }
                Section {
                    newScheduleForm
                } header: {
                    Text(WenshuI18n.t("cron.add_section"))
                }
            }
        }
    }

    private var newScheduleForm: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingSmall) {
            TextField(
                WenshuI18n.t("cron.field.schedule"),
                text: $draftSchedule
            )
            .textFieldStyle(.roundedBorder)
            TextField(
                WenshuI18n.t("cron.field.name"),
                text: $draftName
            )
            .textFieldStyle(.roundedBorder)
            TextField(
                WenshuI18n.t("cron.field.command"),
                text: $draftCommand
            )
            .textFieldStyle(.roundedBorder)
            Button(WenshuI18n.t("cron.add")) {
                Task { await addSchedule() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(draftSchedule.isEmpty || draftCommand.isEmpty || draftName.isEmpty)
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // Wire to the canonical `CronjobStore` actor (= the view
    // never reads the plist directly; = SSOT on `CronjobStore`).
    private func reload() async {
        let rows = await store.list()
        schedules = rows.map { row in
            CronSchedule(
                id: row.id,
                cronExpression: row.schedule,
                command: row.command
            )
        }
    }

    private func addSchedule() async {
        // Cronjob struct (= id / name / schedule / command /
        // enabled / createdAt); = the MVP path generates a
        // UUID here and persists via the canonical actor.
        let job = Cronjob(
            id: UUID().uuidString,
            name: draftName,
            schedule: draftSchedule,
            command: draftCommand,
            enabled: true,
            createdAt: Date()
        )
        await store.add(job)
        draftSchedule = ""
        draftCommand = ""
        draftName = ""
        errorText = nil
        await reload()
    }
}