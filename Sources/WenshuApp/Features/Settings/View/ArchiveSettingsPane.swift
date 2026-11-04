//
//  ArchiveSettingsPane.swift · Wenshu
//
//  What the agents did, and for how long it is kept.
//
//  The archive is a record of the agent's work: = which agent ran,
//  = what it was asked, = how it ended. = It is NOT the user's
//  conversation history, = and the pane says so, = because the
//  difference is the difference between "the agent's work" and
//  "my words", = and a pane that mixed them would be deleting the
//  wrong things.
//
//  The shape follows the memory pane, = which is the house shape for
//  a retention setting: = a closed set of days, = and a change to the
//  setting purges what fell out of it. = The footer says how many
//  rows the last purge took, = because a setting that deletes
//  silently is a setting the user cannot trust.
//

import SwiftUI
import WenshuData

/// One row in the archive's list.
struct ArchiveRunRow: Identifiable, Sendable, Equatable {
    /// The run's session id (= the row's identity).
    let id: String
    /// Which agent did the work.
    let agentName: String
    /// What it was asked.
    let task: String
    /// How it ended (= the app's own vocabulary).
    let status: String
    /// When the row was last touched.
    let updatedAt: Date
    /// The finished answer, = when the run produced one.
    let output: String?
}

@MainActor
struct ArchiveSettingsPane: View {

    /// The runs the archive holds.
    @State private var runs: [ArchiveRunRow] = []
    /// The run whose detail is open.
    @State private var expandedRunID: String?
    /// How many rows the last purge took.
    @State private var lastPurgeCount: Int?
    /// The message shown when the list is empty.
    @State private var loadError: String?

    /// How long the archive keeps the agent's work.
    ///
    /// A closed set, = the memory pane's set. = A free-form number
    /// would let the user type "0", = and zero days of history is a
    /// setting that empties the archive the moment it is set.
    @AppStorage(ArchiveSettings.retentionDaysKey)
    private var retentionDays: Int = 90

    var body: some View {
        Form {
            historySection
            retentionSection
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.archive.title"))
        .task { await load() }
        .onChange(of: retentionDays) { _, newValue in
            Task { await purge(newValue) }
        }
    }

    // MARK: - The list

    private var historySection: some View {
        Section {
            if let loadError {
                Text(loadError)
                    .foregroundStyle(.secondary)
            } else if runs.isEmpty {
                Text(String(localized: "settings.archive.empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(runs) { run in
                    runRow(run)
                }
            }
        } header: {
            Text(String(localized: "settings.archive.history"))
        } footer: {
            Text(String(localized: "settings.archive.history.footer"))
        }
    }

    private func runRow(_ run: ArchiveRunRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(run.agentName)
                    .font(.headline)
                Spacer()
                Text(run.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(run.task)
                .font(.subheadline)
                .lineLimit(expandedRunID == run.id ? nil : 2)
            HStack {
                Text(run.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(expandedRunID == run.id
                      ? String(localized: "settings.archive.collapse")
                      : String(localized: "settings.archive.expand")) {
                    expandedRunID = expandedRunID == run.id ? nil : run.id
                }
                .buttonStyle(.link)
                Button(String(localized: "settings.archive.delete")) {
                    Task { await delete(run) }
                }
                .buttonStyle(.link)
            }
            if expandedRunID == run.id, let output = run.output, !output.isEmpty {
                Text(output)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - The retention

    private var retentionSection: some View {
        Section {
            Picker(String(localized: "settings.archive.retention"), selection: $retentionDays) {
                Text(String(localized: "settings.archive.retention.d30")).tag(30)
                Text(String(localized: "settings.archive.retention.d90")).tag(90)
                Text(String(localized: "settings.archive.retention.d180")).tag(180)
                Text(String(localized: "settings.archive.retention.d365")).tag(365)
            }
            if let lastPurgeCount {
                Text(String.localizedStringWithFormat(
                    NSLocalizedString("settings.archive.purge.count", comment: ""),
                    lastPurgeCount
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "settings.archive.retention"))
        } footer: {
            Text(String(localized: "settings.archive.retention.footer"))
        }
    }

    // MARK: - The work

    /// Read the archive.
    private func load() async {
        do {
            let sessions = try WSChatRepository.shared.listRuns()
            runs = sessions.map { session in
                let run = session.subAgentRuns.first
                return ArchiveRunRow(
                    id: session.sessionID,
                    agentName: session.agentName ?? String(localized: "settings.archive.unknownAgent"),
                    task: run?.taskDescription ?? session.title ?? "",
                    status: run?.status ?? SubAgentRunStatus.running.rawValue,
                    updatedAt: session.updatedAt,
                    output: run?.outputText
                )
            }
            loadError = nil
        } catch {
            loadError = String(localized: "settings.archive.loadFailed")
        }
    }

    /// Delete one run's row.
    private func delete(_ run: ArchiveRunRow) async {
        _ = try? WSChatRepository.shared.deleteRun(sessionID: run.id)
        if expandedRunID == run.id { expandedRunID = nil }
        await load()
    }

    /// Delete what fell out of the retention window.
    private func purge(_ days: Int) async {
        let deleted = (try? WSChatRepository.shared.purgeRuns(olderThanDays: days)) ?? 0
        lastPurgeCount = deleted
        await load()
    }
}

/// The archive's own settings.
enum ArchiveSettings {
    /// Where the retention window is kept.
    ///
    /// Its own key, = not the memory pane's. = The two settings mean
    /// different things (= how long the agent's work is kept, = how
    /// long the agent's memory is kept), = and one key for two
    /// meanings is a setting the user cannot reason about.
    static let retentionDaysKey = "wenshu.archive.retentionDays"
}
