// Sources/WenshuApp/Views/Tools/ForeshadowingView.swift
//
// v0.29 boss 2026-08-30 OOB '替换, 用伏笔替换第一个 teb, 用占位
// 替换第二个 teb. 现在的画布功能以后实现': tools pane tab 1 is now
// 伏笔 (= Foreshadowing) instead of 画布 (= Canvas).
//
// v0.39 P2 ticket #17 (WIRE-SPECIALIZEDTOOLS-011, 2026-09-04):
// this view is now wired to the ForeshadowingTracker actor (=
// legacy tab 1 now backed by real data, not a placeholder).
// Renders:
//   - Top header (= icon + tab title + book + row count +
//     stale count).
//   - "Add foreshadowing" row (= title TextField + setup chapter
//     UUID TextField + setup excerpt TextEditor + status picker +
//     add button).
//   - Foreshadowings list (= one row per foreshadowing; shows
//     status badge + title + setup chapter UUID + status badge
//     + remove button).
//   - Status filter picker (= filter the list by status).
//   - Stale section (= renders the ForeshadowingTracker
//     staleForeshadowings result for the active book).
//
// State source: `ForeshadowingTracker` actor (= owned per-book,
// persisted via per-book JSON sidecar at
// `books/<bookId>/foreshadowings.json`).
//
// Standards-axis:
//   S1 (Apple-API-first): pure SwiftUI primitives + Lucide icon
//       helper (= already wired into wenshu). No custom hover /
//       click handlers; Apple `.buttonStyle` .borderless +
//       .borderedProminent per the macOS 27 Liquid Glass
//       defaults.
//   S3 (single source of truth for JSON parsing): the actor
//       owns the JSONDecoder / JSONEncoder pair; the view reads
//       / mutates the actor and never touches the file system.
//   S5 (no private types the rest of the app needs): all types
//       live in ForeshadowingTrackerTools.swift (= public).
//
// Visual-gate (boss 2026-09-03 auto-pilot rule): this commit
// wires tab 1 of the specializedTools pane. Boss acceptance
// required: open SpecializedTools pane, click the Foreshadowing
// tab, see the list of foreshadowings from the tracker, add a
// new foreshadowing, change its status, remove it, see the
// stale section.
//
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)

import SwiftUI

/// Tools pane tab 1: 伏笔 (= Foreshadowing) per v0.29 boss OOB.
///
/// **Use this** for the first tab of the specializedTools pane.
/// Replaces the old CanvasView (= which moved to a future ticket
/// per the v0.29 boss OOB '现在的画布功能以后实现').
///
/// State: backed by the `ForeshadowingTracker` actor (= per-book
/// JSON sidecar at `books/<bookId>/foreshadowings.json`).
@MainActor
public struct ForeshadowingView: View {

    @Environment(BookStore.self) private var bookStore

    /// Active book id (= drives the actor's per-book scope).
    private var activeBookId: UUID? { bookStore.selectedBookId }

    /// Actor (= created lazily for the current book; held as
    /// @State so SwiftUI keeps the identity across re-renders).
    @State private var tracker: ForeshadowingTracker?

    @State private var rows: [Foreshadowing] = []
    @State private var staleRows: [Foreshadowing] = []

    // Add-foreshadowing picker state.
    @State private var draftTitle: String = ""
    @State private var draftSetupChapterText: String = ""
    @State private var draftSetupExcerpt: String = ""
    @State private var draftStatus: ForeshadowingStatus = .setup

    // Status filter.
    @State private var filterStatus: ForeshadowingStatus? = nil

    @State private var loadingState: LoadStatus = .idle
    @State private var errorText: String?

    private enum LoadStatus: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if activeBookId == nil {
                emptyState
            } else {
                contentBody
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: activeBookId) {
            await reload()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            LucideIconSystemFallback("git-fork", size: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Foreshadowing")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitleText: String {
        switch loadingState {
        case .idle:
            return "Cross-chapter foreshadowing tracker."
        case .loading:
            return "Loading…"
        case .loaded:
            let rowCount = rows.count
            let staleCount = staleRows.count
            return "\(rowCount) foreshadowing\(rowCount == 1 ? "" : "s"), \(staleCount) stale"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No book selected")
                .font(.callout)
                .foregroundStyle(.primary)
            Text("Pick a book from the sidebar to start tracking foreshadowings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            addRow
            Divider()
            filterRow
            rowsSection
            Divider()
            staleSection
            Spacer(minLength: 0)
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
        }
    }

    // MARK: - Add row

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add foreshadowing")
                .font(.callout)
                .foregroundStyle(.primary)
            HStack(spacing: 8) {
                TextField(
                    "Title (e.g. The silver dagger)",
                    text: $draftTitle,
                    axis: .horizontal
                )
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .help("Short, human-readable label for the foreshadowing.")
                Picker("Status", selection: $draftStatus) {
                    ForEach(ForeshadowingStatus.allCases) { status in
                        Label(status.displayName, systemImage: status.lucideIcon)
                            .tag(status)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer(minLength: 0)
                Button {
                    Task { await addForeshadowing() }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
                .help("Add a new foreshadowing row.")
            }
            HStack(spacing: 8) {
                TextField(
                    "Setup chapter UUID (optional)",
                    text: $draftSetupChapterText,
                    axis: .horizontal
                )
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .help("UUID of the chapter where the setup beat appears. Leave empty if undecided.")
                Spacer(minLength: 0)
            }
            TextField(
                "Setup excerpt (1-2 sentences)",
                text: $draftSetupExcerpt,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .lineLimit(1...3)
            .help("Short excerpt of the setup beat. Trimmed at save time.")
        }
    }

    private var canAdd: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Filter row

    private var filterRow: some View {
        HStack(spacing: 8) {
            Text("Filter by status")
                .font(.callout)
                .foregroundStyle(.primary)
            Picker("Status", selection: Binding(
                get: { filterStatus ?? ForeshadowingStatus.allCases.first ?? .open },
                set: { newValue in
                    // Map "all" sentinel back to nil.
                    if newValue == ForeshadowingStatus.allCases.first {
                        filterStatus = nil
                    } else {
                        filterStatus = newValue
                    }
                }
            )) {
                Text("All statuses").tag(ForeshadowingStatus.allCases.first ?? .open)
                ForEach(ForeshadowingStatus.allCases) { status in
                    Label(status.displayName, systemImage: status.lucideIcon).tag(status)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .onChange(of: filterStatus) { _, _ in
                Task { await reload() }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Rows section

    private var rowsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Foreshadowings (\(rows.count))")
                .font(.callout)
                .foregroundStyle(.primary)
            if rows.isEmpty {
                Text("(none yet — add the first one above)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(rows) { row in
                            foreshadowingRow(row)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func foreshadowingRow(_ row: Foreshadowing) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                LucideIconSystemFallback(row.status.lucideIcon, size: 16)
                    .foregroundStyle(.tint)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(row.title)
                            .font(.callout)
                            .foregroundStyle(.primary)
                        Text(row.status.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.quaternary)
                            )
                    }
                    if !row.setupExcerpt.isEmpty {
                        Text(row.setupExcerpt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        if let setupId = row.setupChapterId {
                            Text("Setup: \(setupId.uuidString.prefix(8))…")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if let payoffId = row.payoffChapterId {
                            Text("Payoff: \(payoffId.uuidString.prefix(8))…")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    Task { await removeForeshadowing(row) }
                } label: {
                    LucideIconSystemFallback("trash-2", size: 14)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove this foreshadowing.")
            }
        }
        .padding(.vertical, DesignTokens.chromePaddingSmall)
        .padding(.horizontal, DesignTokens.chromePaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary.opacity(0.5))
        )
    }

    // MARK: - Stale section

    private var staleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                LucideIconSystemFallback("alert-triangle", size: 14)
                    .foregroundStyle(Color(nsColor: .systemOrange))
                Text("Stale foreshadowings (\(staleRows.count))")
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            if staleRows.isEmpty {
                Text("(none — every in-flight foreshadowing has a recent createdAt)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(staleRows) { row in
                            staleRow(row)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }

    private func staleRow(_ row: Foreshadowing) -> some View {
        HStack(spacing: 6) {
            LucideIconSystemFallback(row.status.lucideIcon, size: 12)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(row.title)
                .font(.caption)
                .foregroundStyle(.primary)
            Text(row.status.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Async actions

    private func ensureTracker() -> ForeshadowingTracker {
        if let tracker { return tracker }
        let new = ForeshadowingTracker(bookStore: bookStore)
        tracker = new
        return new
    }

    private func reload() async {
        guard let bookId = activeBookId else {
            rows = []
            staleRows = []
            return
        }
        loadingState = .loading
        let actor = ensureTracker()
        do {
            // Pull rows + stale in parallel.
            async let rowsTask = actor.list(bookId: bookId, status: filterStatus)
            async let staleTask = actor.staleForeshadowings(bookId: bookId)
            let (loadedRows, loadedStale) = try await (rowsTask, staleTask)
            rows = loadedRows
            staleRows = loadedStale
            loadingState = .loaded
        } catch {
            loadingState = .failed(error.localizedDescription)
            errorText = error.localizedDescription
        }
    }

    private func addForeshadowing() async {
        guard let bookId = activeBookId else { return }
        let actor = ensureTracker()
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedExcerpt = draftSetupExcerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        let setupChapterId = UUID(uuidString: draftSetupChapterText.trimmingCharacters(in: .whitespacesAndNewlines))
        let row = Foreshadowing(
            bookId: bookId,
            title: trimmedTitle,
            setupChapterId: setupChapterId,
            setupExcerpt: trimmedExcerpt,
            status: draftStatus
        )
        do {
            try await actor.add(row)
            // Reset draft state on success.
            draftTitle = ""
            draftSetupChapterText = ""
            draftSetupExcerpt = ""
            draftStatus = .setup
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func removeForeshadowing(_ row: Foreshadowing) async {
        let actor = ensureTracker()
        do {
            try await actor.remove(id: row.id)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }
}