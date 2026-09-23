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
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6 icon
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
    @State private var loadingState: SpecializedToolLoadStatus = .idle
    @State private var showAddSheet = false
    @State private var draftName: String = ""
    @State private var draftDescription: String = ""
    @State private var draftKind: LongFormGuardrailKind = .constraint
    @State private var draftEnforcement: LongFormGuardrailEnforcement = .warn
    @State private var checkText: String = ""
    @State private var lastViolations: [LongFormGuardrailViolation] = []
    @State private var lastCheckStatus: CheckStatus = .idle


    private enum CheckStatus: Equatable, Sendable {
        case idle
        case running
        case done(count: Int, hasCritical: Bool)
    }

    init() {}

    var body: some View {
        // v1.28 C3.7.5: migrate to specializedToolBody modifier
        // (= 6th and final SpecializedTool migration; = LongFormGuardrailsView).
        // Note: this view has an additional `.sheet(isPresented: $showAddSheet)`
        // modifier chained AFTER .task; = the migration preserves that.
        specializedToolBody(
            activeBookId: activeBookId,
            emptyContent: { emptyState },
            mainContent: { contentBody }
        )
        .task(id: activeBookId) {
            await reload()
        }
        .sheet(isPresented: $showAddSheet) {
            addSheet
        }
    }

    /// v1.28 B2.1.10: deleted `autoDerivedCount` + `userCount`
    /// (= verify-dead reports both as ext=0 + int=0; = 0 callers;
    /// = the 2 computed vars tallied `guardrails.filter` results for
    /// header counts that the v0.34 MVP never wired into the body;
    /// = the current header uses inline counts; = no behavior
    /// change; = 6 LOC removed).

    // MARK: - Empty state

    private var emptyState: some View {
        // v1.0.0-m1-shell boss 2026-09-12 OOB 'the current empty state isn't
        // v1.0.0-m1-shell boss 2026-09-12 OOB 'the current empty state isn't
        // a single component — can you abstract a UI component? While you're at it, on the
        // empty-state icon: double the size and use the thinnest strokes. The goal is to unify all
        // the unified EmptyStateView component (= 76 PT SF Symbols 6 icon
        // + .regular weight = the canonical macOS 27 inspector
        // icon weight; = standard title/body hierarchy).
        // Same visual treatment as every other empty state in
        // the workspace.
        EmptyStateView(
            icon: "checkmark.shield",
            title: WenshuI18n.t("b5.longformguardrailsview.l144.h89220000"),
            body: WenshuI18n.t("b5.longformguardrailsview.l147.h53334640")
        )
    }


    // MARK: - Content body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMedium) {
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
        HStack(spacing: DesignTokens.chromePaddingVertical) {
            Button {
                Task { await autoDerive() }
            } label: {
                Label { Text(WenshuI18n.t("b5.longformguardrailsview.l175.h64020782")) } icon: { Image(systemName: "wand.and.sparkles").font(.system(size: 16, weight: .regular)) }
            }
            .buttonStyle(.bordered)
            .help(WenshuI18n.t("b5.longformguardrailsview.l178.h38811731"))

            Button {
                showAddSheet = true
            } label: {
                Label { Text(WenshuI18n.t("button.add")) } icon: { Image(systemName: "plus").font(.system(size: 16, weight: .regular)) }
            }
            .buttonStyle(.borderedProminent)
            .help(WenshuI18n.t("b5.longformguardrailsview.l186.h97888008"))

            Spacer(minLength: 0)
        }
    }

    private var guardrailList: some View {
        VStack(spacing: DesignTokens.chromePaddingSmall) {
            ForEach(guardrails) { row in
                guardrailRow(row)
            }
            if guardrails.isEmpty {
                Text(WenshuI18n.t("b5.longformguardrailsview.l198.h9169095"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func guardrailRow(_ row: LongFormGuardrail) -> some View {
        HStack(spacing: 10) {
            Image(systemName: row.kind.icon).font(.system(size: 16, weight: .regular))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.chromePaddingSmall) {
                    Text(row.name)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    if row.isAutoDerived {
                        Text(WenshuI18n.t("b5.longformguardrailsview.l216.h73542843"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DesignTokens.chromePaddingMicro)
                            .padding(.vertical, DesignTokens.chromePaddingPico)
                            
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
                Image(systemName: "xmark").font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(WenshuI18n.t("b5.longformguardrailsview.l241.h76114491"))
        }
        .padding(.vertical, DesignTokens.chromePaddingSmall)
        .padding(.horizontal, DesignTokens.chromePaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        
    }

    private func enforcementBadge(_ level: LongFormGuardrailEnforcement) -> some View {
        Text(level.rawValue)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignTokens.chromePaddingSmall)
            .padding(.vertical, DesignTokens.chromePaddingPico)
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
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingSmall) {
            HStack(spacing: DesignTokens.chromePaddingSmall) {
                Text(WenshuI18n.t("b5.longformguardrailsview.l277.h87864753"))
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                checkStatusLabel
            }
            TextEditor(text: $checkText)
                .font(.caption)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(DesignTokens.chromePaddingSmall)
                
            HStack(spacing: DesignTokens.chromePaddingVertical) {
                Button {
                    Task { await runCheck() }
                } label: {
                    Label { Text(WenshuI18n.t("b5.longformguardrailsview.l295.h18206542")) } icon: { Image(systemName: "play").font(.system(size: 16, weight: .regular)) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(checkText.isEmpty || guardrails.isEmpty)
                .help(WenshuI18n.t("b5.longformguardrailsview.l299.h65143897"))
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
                Text(WenshuI18n.t("b5.longformguardrailsview.l311.h19133696"))
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
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
            Text(WenshuI18n.t("b5.longformguardrailsview.l324.h5287930"))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(lastViolations.enumerated()), id: \.offset) { _, v in
                HStack(alignment: .top, spacing: DesignTokens.chromePaddingSmall) {
                    Text(severityGlyph(v.severity))
                        .font(.caption)
                        .foregroundStyle(severityColor(v.severity))
                    Text(v.reason)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    if let _ = v.lineNumber {
                        Text(WenshuI18n.t("b5.longformguardrailsview.l337.h13219410"))
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.statusForeground)
                    }
                }
            }
        }
        .padding(DesignTokens.chromePaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        
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
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMedium) {
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
                    TextField(WenshuI18n.t("b5.longformguardrailsview.l384.h26664612"), text: $draftName)
                    TextField(WenshuI18n.t("b5.longformguardrailsview.l385.h2063"), text: $draftDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .padding(DesignTokens.chromePaddingLarge)
            .frame(width: DesignTokens.guardrailSheetWidth)
            // v0.40 apple-001 HIG absent batch: .navigationTitle +
            // .toolbar (= Apple HIG standard for sheet title bar +
            // action buttons). The inline Text(\"Add guardrail\") +
            // Cancel/Save buttons were removed; the title moves to
            // .navigationTitle and Cancel/Save move to .toolbar
            // (= Apple canonical pattern for sheet chrome).
            .navigationTitle(WenshuI18n.t("guardrail.add.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(WenshuI18n.t("b5.longformguardrailsview.l400.h71046230")) { showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(WenshuI18n.t("b5.longformguardrailsview.l403.h11223252")) { Task { await saveDraft() } }
                        .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        // macOS 27 doc-alignment (boss 9/18 OOB '全都改一下',
        // audit ticket 2): per-pane `.glassEffect(.regular)` is
        // forbidden per boss 2026-09-02 OOB "默认不加液态玻璃效果
        // 的, 我们就不加; 默认带的, 我们就默认带". The canonical
        // pattern = Apple NSColor.windowBackgroundColor for sheet
        // surface = the 2-layer NSColor micro-differentiation
        // boundary (windowBackground vs controlBackground = the
        // visible boundary, NOT custom per-pane glass overlays).
        .background { Color(nsColor: .windowBackgroundColor) }
    }

    // MARK: - Async actions

    private func reload() async {
        guard activeBookId != nil else { return }
        loadingState = .loading
        let actor = await ensureManager()
        let result = await LongFormGuardrailsOps.reload(manager: actor, bookId: activeBookId)
        guardrails = result.rows
        if let err = result.error {
            loadingState = .failed(err)
        } else if result.didLoad {
            loadingState = .loaded
        }
    }

    private func ensureManager() async -> LongFormGuardrails {
        if let m = manager { return m }
        let m = LongFormGuardrails(bookStore: bookStore)
        manager = m
        return m
    }

    private func autoDerive() async {
        let actor = await ensureManager()
        let result = await LongFormGuardrailsOps.autoDerive(manager: actor, bookId: activeBookId)
        if let err = result.error {
            loadingState = .failed(err)
        }
        await reload()
    }

    private func removeRow(_ row: LongFormGuardrail) async {
        let actor = await ensureManager()
        _ = await LongFormGuardrailsOps.removeRow(manager: actor, bookId: activeBookId, row: row)
        await reload()
    }

    private func saveDraft() async {
        let actor = await ensureManager()
        let result = await LongFormGuardrailsOps.saveDraft(
            manager: actor,
            bookId: activeBookId,
            kind: draftKind,
            enforcement: draftEnforcement,
            name: draftName,
            description: draftDescription
        )
        if result.didSave {
            draftName = ""
            draftDescription = ""
            showAddSheet = false
            await reload()
        } else if let err = result.error {
            loadingState = .failed(err)
        }
    }

    private func runCheck() async {
        guard activeBookId != nil else { return }
        let actor = await ensureManager()
        lastCheckStatus = .running
        let result = await LongFormGuardrailsOps.runCheck(
            manager: actor,
            guardrails: guardrails,
            checkText: checkText
        )
        lastViolations = result.violations
        if result.didRun {
            lastCheckStatus = .done(count: result.violations.count, hasCritical: result.hasCritical)
        } else {
            lastCheckStatus = .done(count: 0, hasCritical: false)
        }
    }
}