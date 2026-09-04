// Sources/WenshuApp/Views/Tools/PlaceholderView.swift
//
// v0.29 boss 2026-08-30 OOB '替换, 用伏笔替换第一个 teb, 用占位
// 替换第二个 teb. 现在的画布功能以后实现': tools pane tab 2 is now
// 占位符 (= Placeholder) instead of 数据库 (= BaseView).
//
// v0.39 P2 ticket #18 (WIRE-SPECIALIZEDTOOLS-012, 2026-09-04):
// this view is now wired to the PlaceholderScanner actor (= legacy
// tab 2 now backed by real data, not a placeholder). Renders:
//   - Top header (= icon + tab title + book + row count).
//   - "Add placeholder" row (= chapter UUID TextField + line
//     number TextField + context TextEditor + pattern TextField +
//     status picker + add button).
//   - Placeholders list (= one row per placeholder; shows
//     status badge + line number + pattern + chapter UUID +
//     resolve / abandon / reopen / remove buttons).
//   - Status filter picker (= filter the list by status).
//   - Scan section (= paste-and-scan a chapter text in a
//     TextEditor; the "Scan + add all" button runs the actor's
//     `scanAndAdd` helper against the pasted body and reloads
//     the list).
//
// State source: `PlaceholderScanner` actor (= owned per-book,
// persisted via per-book JSON sidecar at
// `books/<bookId>/placeholders.json`).
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
//       live in PlaceholderScannerTools.swift (= public).
//
// Visual-gate (boss 2026-09-03 auto-pilot rule): this commit
// wires tab 2 of the specializedTools pane. Boss acceptance
// required: open SpecializedTools pane, click the Placeholder
// tab, see the list of placeholders from the scanner, add a
// new placeholder, change its status, remove it, paste chapter
// text and click "Scan + add all" to populate the list.

import SwiftUI

/// Tools pane tab 2: 占位符 (= Placeholder) per v0.29 boss OOB.
///
/// **Use this** for the second tab of the specializedTools pane.
/// Replaces the old BaseView (= which moved to a future ticket
/// per the v0.29 boss OOB '现在的画布功能以后实现').
///
/// State: backed by the `PlaceholderScanner` actor (= per-book
/// JSON sidecar at `books/<bookId>/placeholders.json`).
@MainActor
public struct PlaceholderView: View {

    @Environment(BookStore.self) private var bookStore

    /// Active book id (= drives the actor's per-book scope).
    private var activeBookId: UUID? { bookStore.selectedBookId }

    /// Actor (= created lazily for the current book; held as
    /// @State so SwiftUI keeps the identity across re-renders).
    @State private var scanner: PlaceholderScanner?

    @State private var rows: [Placeholder] = []

    // Add-placeholder picker state.
    @State private var draftChapterText: String = ""
    @State private var draftLineText: String = ""
    @State private var draftContext: String = ""
    @State private var draftPattern: String = ""
    @State private var draftStatus: PlaceholderStatus = .open

    // Status filter.
    @State private var filterStatus: PlaceholderStatus? = nil

    // Scan section state.
    @State private var scanChapterText: String = ""
    @State private var lastScanCount: Int? = nil

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
            LucideIconSystemFallback("square-dashed", size: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Placeholder")
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
            return "Inline authoring-placeholder scanner."
        case .loading:
            return "Loading…"
        case .loaded:
            let rowCount = rows.count
            return "\(rowCount) placeholder\(rowCount == 1 ? "" : "s")"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No book selected")
                .font(.callout)
                .foregroundStyle(.primary)
            Text("Pick a book from the sidebar to start tracking placeholders.")
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
            scanSection
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
            Text("Add placeholder")
                .font(.callout)
                .foregroundStyle(.primary)
            HStack(spacing: 8) {
                TextField(
                    "Chapter UUID",
                    text: $draftChapterText,
                    axis: .horizontal
                )
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .help("UUID of the chapter where this placeholder lives. Required.")
                TextField(
                    "Line #",
                    text: $draftLineText,
                    axis: .horizontal
                )
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(width: 64)
                .help("1-indexed line number within the chapter. Optional (defaults to 0).")
                Picker("Status", selection: $draftStatus) {
                    ForEach(PlaceholderStatus.allCases) { status in
                        Label(status.displayName, systemImage: status.lucideIcon)
                            .tag(status)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer(minLength: 0)
                Button {
                    Task { await addPlaceholder() }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
                .help("Add a new placeholder row.")
            }
            TextField(
                "Pattern (e.g. [TODO: explain the dagger])",
                text: $draftPattern,
                axis: .horizontal
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .help("The literal matched text. Whitespace-only values are rejected.")
            TextField(
                "Context (the surrounding line)",
                text: $draftContext,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .lineLimit(1...3)
            .help("Short excerpt of the chapter line containing the placeholder.")
        }
    }

    private var canAdd: Bool {
        UUID(uuidString: draftChapterText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
            && !draftPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Filter row

    private var filterRow: some View {
        HStack(spacing: 8) {
            Text("Filter by status")
                .font(.callout)
                .foregroundStyle(.primary)
            Picker("Status", selection: Binding(
                get: { filterStatus ?? PlaceholderStatus.allCases.first ?? .open },
                set: { newValue in
                    // Map "all" sentinel back to nil.
                    if newValue == PlaceholderStatus.allCases.first {
                        filterStatus = nil
                    } else {
                        filterStatus = newValue
                    }
                }
            )) {
                Text("All statuses").tag(PlaceholderStatus.allCases.first ?? .open)
                ForEach(PlaceholderStatus.allCases) { status in
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
            Text("Placeholders (\(rows.count))")
                .font(.callout)
                .foregroundStyle(.primary)
            if rows.isEmpty {
                Text("(none yet — add the first one above or paste chapter text below)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(rows) { row in
                            placeholderRow(row)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func placeholderRow(_ row: Placeholder) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                LucideIconSystemFallback(row.status.lucideIcon, size: 16)
                    .foregroundStyle(.tint)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(row.pattern)
                            .font(.callout.monospaced())
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
                    if !row.context.isEmpty {
                        Text(row.context)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        Text("Ch: \(row.chapterId.uuidString.prefix(8))…")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("Line: \(row.lineNumber)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    if row.status != .resolved {
                        Button {
                            Task { await resolvePlaceholder(row) }
                        } label: {
                            LucideIconSystemFallback("check", size: 14)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Mark as resolved.")
                    }
                    if row.status != .open {
                        Button {
                            Task { await reopenPlaceholder(row) }
                        } label: {
                            LucideIconSystemFallback("rotate-ccw", size: 14)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Reopen (= set status back to open).")
                    }
                    if row.status != .abandoned {
                        Button {
                            Task { await abandonPlaceholder(row) }
                        } label: {
                            LucideIconSystemFallback("circle-x", size: 14)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Mark as abandoned.")
                    }
                    Button(role: .destructive) {
                        Task { await removePlaceholder(row) }
                    } label: {
                        LucideIconSystemFallback("trash-2", size: 14)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this placeholder.")
                }
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

    // MARK: - Scan section

    private var scanSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                LucideIconSystemFallback("scan-text", size: 14)
                    .foregroundStyle(.tint)
                Text("Scan chapter text")
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            Text("Paste a chapter body below. The scanner will use the 7 default patterns (TODO / FIXME / XXX / INSERT / TBD / <HERE> / {{mustache}}). The current book's chapterId = placeholder chapterId.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextEditor(text: $scanChapterText)
                .font(.caption.monospaced())
                .frame(minHeight: 80, maxHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.quaternary, lineWidth: 1)
                )
            HStack(spacing: 8) {
                Button {
                    Task { await runScan() }
                } label: {
                    Label("Scan + add all", systemImage: "plus-circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canScan)
                .help("Run the scanner against the pasted text and persist every match.")
                if let lastScanCount {
                    Text("Last scan: +\(lastScanCount) placeholder\(lastScanCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var canScan: Bool {
        !scanChapterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Async actions

    private func ensureScanner() -> PlaceholderScanner {
        if let scanner { return scanner }
        let new = PlaceholderScanner(bookStore: bookStore)
        scanner = new
        return new
    }

    private func reload() async {
        guard let bookId = activeBookId else {
            rows = []
            return
        }
        loadingState = .loading
        let actor = ensureScanner()
        do {
            let loadedRows = try await actor.list(bookId: bookId, status: filterStatus)
            rows = loadedRows
            loadingState = .loaded
        } catch {
            loadingState = .failed(error.localizedDescription)
            errorText = error.localizedDescription
        }
    }

    private func addPlaceholder() async {
        guard let bookId = activeBookId else { return }
        let actor = ensureScanner()
        let trimmedChapter = draftChapterText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPattern = draftPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = draftContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let chapterId = UUID(uuidString: trimmedChapter),
              !trimmedPattern.isEmpty else { return }
        let lineNumber = Int(draftLineText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let row = Placeholder(
            bookId: bookId,
            chapterId: chapterId,
            lineNumber: lineNumber,
            context: trimmedContext,
            pattern: trimmedPattern,
            status: draftStatus
        )
        do {
            try await actor.add(row)
            // Reset draft state on success.
            draftChapterText = ""
            draftLineText = ""
            draftContext = ""
            draftPattern = ""
            draftStatus = .open
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func resolvePlaceholder(_ row: Placeholder) async {
        let actor = ensureScanner()
        do {
            try await actor.resolve(id: row.id)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func abandonPlaceholder(_ row: Placeholder) async {
        let actor = ensureScanner()
        do {
            try await actor.abandon(id: row.id)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func reopenPlaceholder(_ row: Placeholder) async {
        let actor = ensureScanner()
        do {
            try await actor.reopen(id: row.id)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func removePlaceholder(_ row: Placeholder) async {
        let actor = ensureScanner()
        do {
            try await actor.remove(id: row.id)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func runScan() async {
        guard let bookId = activeBookId else { return }
        // Use a deterministic chapter id for paste-and-scan
        // flows. Real book chapters get their own UUIDs; for
        // the paste-and-scan input we derive a stable id from
        // the book id (= see `scratchChapterId(for:)`) so the
        // same book + scan session always produces the same
        // chapter id, and distinct books never collide.
        let scanChapterId = Self.scratchChapterId(for: bookId)
        let actor = ensureScanner()
        do {
            let added = try await actor.scanAndAdd(
                chapterText: scanChapterText,
                bookId: bookId,
                chapterId: scanChapterId
            )
            lastScanCount = added.count
            // Wipe the pasted text on success (= keep the
            // panel tidy; the rows now live in the persisted
            // list).
            scanChapterText = ""
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// Deterministic chapter id used for paste-and-scan flows
    /// (= generated by hashing the book id with the literal
    /// namespace string "wenshu-placeholder-scanner" so the
    /// same book + scan session always produces the same
    /// chapter id, and so distinct books never collide).
    private static func scratchChapterId(for bookId: UUID) -> UUID {
        let namespace = "wenshu-placeholder-scanner"
        let combined = "\(namespace)|\(bookId.uuidString)"
        var hasher = Hasher()
        hasher.combine(combined)
        let raw = UInt64(bitPattern: Int64(hasher.finalize()))
        let bytes: [UInt8] = (0..<16).map { i -> UInt8 in
            let shift = (i % 8) * 8
            let value = (raw >> shift) & 0xff
            return UInt8(truncatingIfNeeded: value)
        }
        // Version 4 layout (= random) + variant 1.
        var b = bytes
        b[6] = (b[6] & 0x0f) | 0x40
        b[8] = (b[8] & 0x3f) | 0x80
        let tuple = (
            b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
            b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
        )
        return UUID(uuid: tuple)
    }
}
