//
//  LongFormGuardrailsView.swift · Wenshu · P1 ticket #6 (WIRE-SPECIALIZEDTOOLS-001, 2026-09-04)
//
//  SpecializedTools pane tab 3: Long-Form Guardrails.
//
//  Per the v0.30 boss 2026-08-30 OOB pattern (= ForeshadowingView +
//  PlaceholderView = 2 placeholder tabs), this view is the
//  REAL implementation for the Long-Form Guardrails tab (= the
//  3rd tab of the specializedTools pane). Renders:
//
//    - Top header (= icon + tab title + auto-derive hint)
//    - Guardrail list (= 6 kinds, one row each; user-authored +
//      auto-derived)
//    - Add-guardrail popover (= opens on tap of the "+" button)
//    - Remove button (= per row)
//    - "Run check" button (= applies `check(_:against:)` to the
//      current chapter draft text)
//
//  State source: `LongFormGuardrails` actor (read via a Task
//  snapshot into local `@State`). Mutations call the typed
//  `add(_:to:)` / `remove(id:from:)` entry points.
//
//  Persistence pattern: per-book JSON sidecar (= the actor owns
//  the file = `long-form-guardrails.json` in the book root).
//
//  Standards-axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + Lucide icon
//        helper (= already wired into the wenshu chrome). No
//        custom hover / click handlers; Apple `.buttonStyle`
//        .borderless + `.borderedProminent` per the macOS 27
//        Liquid Glass defaults.
//    S3 (single source of truth for JSON parsing): the actor
//        owns the JSON; the view reads the actor and never
//        touches the file system.
//    S5 (no private types the rest of the app needs): all
//        types live in LongFormGuardrails.swift (= internal
//        access = same module).
//

import SwiftUI

/// SpecializedTools pane tab 3: Long-Form Guardrails.
///
/// Reads the active bookId from `BookStore.selectedBookId`. If
/// no book is selected, renders the empty-state (= "no book
/// selected" hint, matching ForeshadowingView's no-content
/// pattern).
@MainActor
struct LongFormGuardrailsView: View {
    @Environment(BookStore.self) private var bookStore

    /// Active book id (= drives the actor's per-book scope).
    private var activeBookId: UUID? { bookStore.selectedBookId }

    /// Actor (= created lazily for the current book; held as
    /// @State so SwiftUI keeps the identity across re-renders).
    @State private var manager: LongFormGuardrails?
    @State private var guardrails: [LongFormGuardrail] = []
    @State private var loadingState: LoadingState = .idle
    @State private var showAddSheet = false
    @State private var draftName: String = ""
    @State private var draftDescription: String = ""
    @State private var draftKind: LongFormGuardrailKind = .constraint
    @State private var draftEnforcement: LongFormGuardrailEnforcement = .warn
    @State private var checkText: String = ""
    @State private var lastViolations: [LongFormGuardrailViolation] = []
    @State private var lastCheckStatus: CheckStatus = .idle

    private enum LoadingState: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private enum CheckStatus: Equatable, Sendable {
        case idle
        case running
        case done(count: Int, hasCritical: Bool)
    }

    init() {}

    var body: some View {
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
        .sheet(isPresented: $showAddSheet) {
            addSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            LucideIconSystemFallback("shield-check", size: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Long-Form Guardrails")
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
        case .idle:        return "Loading…"
        case .loading:     return "Loading guardrails…"
        case .loaded:      return "\(guardrails.count) guardrails (= \(autoDerivedCount) auto / \(userCount) user)"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    private var autoDerivedCount: Int {
        guardrails.filter { $0.isAutoDerived }.count
    }

    private var userCount: Int {
        guardrails.filter { !$0.isAutoDerived }.count
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No book selected")
                .font(.title3)
                .foregroundStyle(.primary)
            Text("Open a book to manage its long-form guardrails. The 6 auto-derived guardrails (= constraint / continuity / self-proof / persona / character-arc / world-consistency) will be created on first open.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            actionRow
            guardrailList
            Divider()
            checkSection
            if !lastViolations.isEmpty {
                violationsSection
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button {
                Task { await autoDerive() }
            } label: {
                Label("Auto-derive", systemImage: "wand.and.stars")
            }
            .buttonStyle(.bordered)
            .help("Replace the guardrail set with the 6 auto-derived rows (= constraint / continuity / self-proof / persona / character-arc / world-consistency).")

            Button {
                showAddSheet = true
            } label: {
                Label(WenshuI18n.t("button.add"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .help("Add a user-authored guardrail row.")

            Spacer(minLength: 0)
        }
    }

    private var guardrailList: some View {
        VStack(spacing: 6) {
            ForEach(guardrails) { row in
                guardrailRow(row)
            }
            if guardrails.isEmpty {
                Text("No guardrails yet. Tap Auto-derive to seed the 6 defaults, or Add to create a custom row.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func guardrailRow(_ row: LongFormGuardrail) -> some View {
        HStack(spacing: 10) {
            LucideIconSystemFallback(row.kind.lucideIcon, size: 16)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    if row.isAutoDerived {
                        Text("auto")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.quaternary)
                            )
                    }
                }
                Text(row.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            enforcementBadge(row.enforce)
            Button {
                Task { await removeRow(row) }
            } label: {
                LucideIconSystemFallback("x", size: 14)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove this guardrail.")
        }
        .padding(.vertical, DesignTokens.chromePaddingSmall)
        .padding(.horizontal, DesignTokens.chromePaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
        )
    }

    private func enforcementBadge(_ level: LongFormGuardrailEnforcement) -> some View {
        Text(level.rawValue)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(badgeColor(for: level))
            )
    }

    private func badgeColor(for level: LongFormGuardrailEnforcement) -> Color {
        switch level {
        case .strict: return Color(nsColor: .systemRed).opacity(0.18)
        case .warn:   return Color(nsColor: .systemOrange).opacity(0.18)
        case .off:    return Color(nsColor: .systemGray).opacity(0.18)
        }
    }

    // MARK: - Check section

    private var checkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Run check")
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                checkStatusLabel
            }
            TextEditor(text: $checkText)
                .font(.caption)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                )
            HStack(spacing: 8) {
                Button {
                    Task { await runCheck() }
                } label: {
                    Label("Run check", systemImage: "play")
                }
                .buttonStyle(.borderedProminent)
                .disabled(checkText.isEmpty || guardrails.isEmpty)
                .help("Evaluate the text above against all active guardrails.")
                Spacer(minLength: 0)
            }
        }
    }

    private var checkStatusLabel: some View {
        Group {
            switch lastCheckStatus {
            case .idle:
                EmptyView()
            case .running:
                Text("Running…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .done(let count, let hasCritical):
                Text(hasCritical ? "\(count) violations (= critical)" : "\(count) violations")
                    .font(.caption)
                    .foregroundStyle(hasCritical ? Color(nsColor: .systemRed) : .secondary)
            }
        }
    }

    private var violationsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Violations")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(lastViolations.enumerated()), id: \.offset) { _, v in
                HStack(alignment: .top, spacing: 6) {
                    Text(severityGlyph(v.severity))
                        .font(.caption)
                        .foregroundStyle(severityColor(v.severity))
                    Text(v.reason)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    if let line = v.lineNumber {
                        Text("L\(line)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
        )
    }

    private func severityGlyph(_ s: LongFormGuardrailViolation.Severity) -> String {
        switch s {
        case .critical: return "■"
        case .warning:  return "▲"
        case .info:     return "·"
        }
    }

    private func severityColor(_ s: LongFormGuardrailViolation.Severity) -> Color {
        switch s {
        case .critical: return Color(nsColor: .systemRed)
        case .warning:  return Color(nsColor: .systemOrange)
        case .info:     return .secondary
        }
    }

    // MARK: - Add sheet

    private var addSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add guardrail")
                .font(.title3)
                .foregroundStyle(.primary)
            Form {
                Picker("Kind", selection: $draftKind) {
                    ForEach(LongFormGuardrailKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                Picker("Enforcement", selection: $draftEnforcement) {
                    ForEach(LongFormGuardrailEnforcement.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                TextField("Name", text: $draftName)
                TextField("Description", text: $draftDescription, axis: .vertical)
                    .lineLimit(3...6)
            }
            HStack {
                Spacer(minLength: 0)
                Button("Cancel") { showAddSheet = false }
                    .buttonStyle(.bordered)
                Button("Save") { Task { await saveDraft() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 360)
        // POLISH-LIQUIDGLASS-004: Add-guardrail modal sheet root uses
        // Apple .glassEffect(.regular) (= macOS 27 Tahoe Liquid Glass;
        // same shape as POLISH-LIQUIDGLASS-001/002/003 that glassed
        // TopBar + Sidebar + Editor chrome + StatusBar). Color.clear
        // provides the glass layer size; the modifier applies the
        // canonical Apple Liquid Glass material. No custom border or
        // shadow (= boss 2026-09-02 hard rule 'every color comes from
        // an Apple API'; .glassEffect already includes the canonical
        // hairline + depth shadow per Apple HIG). Applied AFTER .frame
        // so the glass layer sizes to the sheet's width: 360 outer
        // rect.
        .background { Color.clear.glassEffect(.regular) }
    }

    // MARK: - Async actions

    private func reload() async {
        guard let bookId = activeBookId else { return }
        loadingState = .loading
        let actor = await ensureManager()
        do {
            let rows = try await actor.loadGuardrails(for: bookId)
            guardrails = rows
            loadingState = .loaded
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    private func ensureManager() async -> LongFormGuardrails {
        if let m = manager { return m }
        let m = LongFormGuardrails(bookStore: bookStore)
        manager = m
        return m
    }

    private func autoDerive() async {
        guard let bookId = activeBookId else { return }
        let actor = await ensureManager()
        // Wipe existing rows first (= auto-derive replaces).
        for row in guardrails {
            try? await actor.remove(id: row.id, from: bookId)
        }
        let derived = await actor.extractConstraints(from: "(no book context supplied)")
        for row in derived {
            try? await actor.add(row, to: bookId)
        }
        await reload()
    }

    private func removeRow(_ row: LongFormGuardrail) async {
        guard let bookId = activeBookId else { return }
        let actor = await ensureManager()
        try? await actor.remove(id: row.id, from: bookId)
        await reload()
    }

    private func saveDraft() async {
        guard let bookId = activeBookId else { return }
        let actor = await ensureManager()
        let row = LongFormGuardrail(
            kind: draftKind,
            source: .bookContext,
            enforce: draftEnforcement,
            name: draftName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: draftDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            isAutoDerived: false
        )
        try? await actor.add(row, to: bookId)
        draftName = ""
        draftDescription = ""
        showAddSheet = false
        await reload()
    }

    private func runCheck() async {
        guard let bookId = activeBookId else { return }
        let actor = await ensureManager()
        lastCheckStatus = .running
        do {
            let violations = try await actor.check(checkText, against: guardrails)
            lastViolations = violations
            let hasCritical = violations.contains { $0.severity == .critical }
            lastCheckStatus = .done(count: violations.count, hasCritical: hasCritical)
            _ = bookId
        } catch {
            lastCheckStatus = .done(count: 0, hasCritical: false)
        }
    }
}