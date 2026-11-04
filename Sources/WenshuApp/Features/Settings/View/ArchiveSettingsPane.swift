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
    /// What kind of work this row records (= Hermes' own `source`
    /// tag: = `subagent`, = `local`, = `kanban`, = ...).
    ///
    /// It is shown as the tag it is, = and not translated: = it is the
    /// vocabulary the rows are filed under, = and a translated name
    /// would hide which value the row actually carries.
    let source: String
    /// What it was asked.
    let task: String
    /// How it ended (= the app's own vocabulary).
    let status: String
    /// When the row was last touched.
    let updatedAt: Date
    /// The finished answer, = when the run produced one.
    let output: String?
}

/// Which agent the archive is showing.
///
/// The filter is on the STORED name, = not on the name the row
/// displays. = A row whose agent is not named (= an ordinary task
/// with no agent behind it) = has no name to filter by, = so it
/// appears under "all" and not under any one agent. = That is the
/// data layer's shape, = and the filter says it rather than
/// pretending otherwise.
enum ArchiveAgentFilter: Hashable, Sendable {
    /// Every agent.
    case all
    /// One named agent (= the name the row stores).
    case agent(String)

    /// The value the data layer takes, = and nil for "every agent".
    var agentName: String? {
        switch self {
        case .all: return nil
        case let .agent(name): return name
        }
    }
}

/// What kind of work the archive is showing.
///
/// The same shape as the agent filter: = the tag the row stores.
enum ArchiveSourceFilter: Hashable, Sendable {
    /// Every kind.
    case all
    /// One kind (= the tag the row stores).
    case source(String)

    /// The value the data layer takes, = and nil for "every kind".
    var sourceValue: String? {
        switch self {
        case .all: return nil
        case let .source(value): return value
        }
    }
}

@MainActor
struct ArchiveSettingsPane: View {

    /// The runs the archive holds.
    @State private var runs: [ArchiveRunRow] = []
    /// Which agent the archive is showing.
    @State private var agentFilter: ArchiveAgentFilter = .all
    /// What kind of work the archive is showing.
    @State private var sourceFilter: ArchiveSourceFilter = .all
    /// The agents the archive holds (= the filter's options).
    ///
    /// Derived from the rows, = and not from a fixed list: = the
    /// roles change, = and a menu that names a role that does not
    /// exist is a menu that lies.
    @State private var availableAgents: [String] = []
    /// The kinds of work the archive holds (= the filter's options).
    @State private var availableSources: [String] = []
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
            filterSection
            historySection
            retentionSection
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.archive.title"))
        .task { await load() }
        .onChange(of: retentionDays) { _, newValue in
            Task { await purge(newValue) }
        }
        .onChange(of: agentFilter) { _, _ in
            Task { await loadRows() }
        }
        .onChange(of: sourceFilter) { _, _ in
            Task { await loadRows() }
        }
    }

    // MARK: - The filters

    /// Narrow the archive by agent and by kind.
    ///
    /// The archive is the agent's work, = and it is filed under two
    /// things: = which agent did it, = and what kind of work it was.
    /// The 2026-11-01 handoff settled both = (= "one session type,
    /// tagged and filtered"), = and the data layer has taken the
    /// filters since. = The pane did not use them, = so the archive
    /// was a list and not a way to look through the work.
    ///
    /// The options come from the rows themselves. = The roles and the
    /// tags change, = and a menu that offers a role that does not
    /// exist is worse than no menu.
    private var filterSection: some View {
        Section {
            Picker(String(localized: "settings.archive.filter.agent"), selection: $agentFilter) {
                Text(String(localized: "settings.archive.filter.all"))
                    .tag(ArchiveAgentFilter.all)
                ForEach(availableAgents, id: \.self) { agent in
                    Text(agent).tag(ArchiveAgentFilter.agent(agent))
                }
            }
            Picker(String(localized: "settings.archive.filter.kind"), selection: $sourceFilter) {
                Text(String(localized: "settings.archive.filter.all"))
                    .tag(ArchiveSourceFilter.all)
                ForEach(availableSources, id: \.self) { source in
                    Text(source).tag(ArchiveSourceFilter.source(source))
                }
            }
        } header: {
            Text(String(localized: "settings.archive.filter"))
        } footer: {
            Text(String(localized: "settings.archive.filter.footer"))
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
            if !run.source.isEmpty {
                // The tag the row is filed under, = shown as the tag
                // it is.
                Text(run.source)
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.tertiary)
            }
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
    ///
    /// Two reads, = and both are needed. = The first is the whole
    /// archive, = and it says which agents and which kinds the
    /// archive holds = (= the filter's options). = The second is the
    /// rows the filters ask for, = and the data layer does the
    /// narrowing.
    private func load() async {
        await loadOptions()
        await loadRows()
    }

    /// Read the agents and the kinds the archive holds.
    private func loadOptions() async {
        do {
            let sessions = try WSChatRepository.shared.listRuns()
            availableAgents = Array(Set(sessions.compactMap(\.agentName))).sorted()
            availableSources = Array(Set(sessions.compactMap(\.source))).sorted()
        } catch {
            loadError = String(localized: "settings.archive.loadFailed")
        }
    }

    /// Read the rows the filters ask for.
    private func loadRows() async {
        do {
            let sessions = try WSChatRepository.shared.listRuns(
                source: sourceFilter.sourceValue,
                agentName: agentFilter.agentName
            )
            runs = sessions.map { session in
                let run = session.subAgentRuns.first
                return ArchiveRunRow(
                    id: session.sessionID,
                    agentName: session.agentName ?? String(localized: "settings.archive.unknownAgent"),
                    source: session.source ?? "",
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
