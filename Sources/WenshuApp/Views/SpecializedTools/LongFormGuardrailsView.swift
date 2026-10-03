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
//  the file = `long-form-state.guardrails.json` in the book root).
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
    /// Business state mirror (= state.guardrails + state.loadingState +
    /// state.lastViolations). Form drafts + transient check status
    /// stay on the View per §11.3.
    @State private var state = LongFormGuardrailsViewState()

    // Add-sheet picker state.
    @State private var showAddSheet = false
    @State private var draftName: String = ""
    @State private var draftDescription: String = ""
    @State private var draftKind: LongFormGuardrailKind = .constraint
    @State private var draftEnforcement: LongFormGuardrailEnforcement = .warn
    @State private var checkText: String = ""

    // Transient check status (= lives on the View; = the guardrail
    // check is a one-shot user action so this is form-draft
    // territory per §11.3).
    @State private var lastCheckStatus: CheckStatus = .idle

    init() {}

    private enum CheckStatus: Equatable, Sendable {
        case idle
        case running
        case done(Int, Bool)
        case failed(String)
    }


    var body: some View {
        // C3.7.5: migrate to specializedToolBody modifier
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

    /// deleted `autoDerivedCount` + `userCount`
    /// (= verify-dead reports both as ext=0 + int=0; = 0 callers;
    /// = the 2 computed vars tallied `state.guardrails.filter` results for
    /// header counts that the v0.34 MVP never wired into the body;
    /// = the current header uses inline counts; = no behavior
    /// change; = 6 LOC removed).

    // MARK: - Empty state

    private var emptyState: some View {
        // -m1-shell boss 2026-09-12 OOB 'the current empty state isn't
        // -m1-shell boss 2026-09-12 OOB 'the current empty state isn't
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
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            actionRow
            guardrailList
            Divider()
            checkSection
            if !state.lastViolations.isEmpty {
                violationsSection
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var actionRow: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            Button {
                Task { await autoDerive() }
            } label: {
                Label { Text(WenshuI18n.t("b5.longformguardrailsview.l175.h64020782")) } icon: { SFIcon("wand.and.sparkles", style: .inlineSmall, color: IconColor.tint) }
            }
            .buttonStyle(.bordered)
            .help(WenshuI18n.t("b5.longformguardrailsview.l178.h38811731"))

            Button {
                showAddSheet = true
            } label: {
                Label { Text(WenshuI18n.t("button.add")) } icon: { SFIcon("plus", style: .inlineSmall, color: IconColor.tint) }
            }
            .buttonStyle(.borderedProminent)
            .help(WenshuI18n.t("b5.longformguardrailsview.l186.h97888008"))

            Spacer(minLength: 0)
        }
    }

    private var guardrailList: some View {
        VStack(spacing: DesignTokens.spacingTight) {
            ForEach(state.guardrails) { row in
                guardrailRow(row)
            }
            if state.guardrails.isEmpty {
                Text(WenshuI18n.t("b5.longformguardrailsview.l198.h9169095"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func guardrailRow(_ row: LongFormGuardrail) -> some View {
        HStack(spacing: DesignTokens.spacingRelaxed) {
            SFIcon(row.kind.icon, style: .inlineSmall, color: IconColor.tint)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.spacingTight) {
                    Text(row.name)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    if row.isAutoDerived {
                        Text(WenshuI18n.t("b5.longformguardrailsview.l216.h73542843"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DesignTokens.spacingIconic)
                            .padding(.vertical, DesignTokens.spacingHairline)
                            
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
                SFIcon("xmark", style: .inlineSmall, color: IconColor.secondary)
            }
            .buttonStyle(.borderless)
            .help(WenshuI18n.t("b5.longformguardrailsview.l241.h76114491"))
        }
        .padding(.vertical, DesignTokens.spacingTight)
        .padding(.horizontal, DesignTokens.spacingStandard)
        .frame(maxWidth: .infinity, alignment: .leading)
        
    }

    private func enforcementBadge(_ level: LongFormGuardrailEnforcement) -> some View {
        Text(level.rawValue)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignTokens.spacingTight)
            .padding(.vertical, DesignTokens.spacingHairline)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip)
                    .fill(badgeColor(for: level))
            )
    }

    private func badgeColor(for level: LongFormGuardrailEnforcement) -> Color {
        switch level {
        case .strict: return .red.opacity(0.18)
        case .warn:   return .orange.opacity(0.18)
        case .off:    return .gray.opacity(0.18)
        }
    }

    // MARK: - Check section

    private var checkSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            HStack(spacing: DesignTokens.spacingTight) {
                Text(WenshuI18n.t("b5.longformguardrailsview.l277.h87864753"))
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                checkStatusLabel
            }
            TextEditor(text: $checkText)
                .font(.caption)
                .frame(minHeight: DesignTokens.textEditorSmallMinHeight, maxHeight: DesignTokens.textEditorCompactMaxHeight)
                .padding(DesignTokens.spacingTight)
                
            HStack(spacing: DesignTokens.spacingStandard) {
                Button {
                    Task { await runCheck() }
                } label: {
                    Label { Text(WenshuI18n.t("b5.longformguardrailsview.l295.h18206542")) } icon: { SFIcon("play", style: .inlineSmall, color: IconColor.tint) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(checkText.isEmpty || state.guardrails.isEmpty)
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
                    .foregroundStyle(hasCritical ? .red : .secondary)
            case .failed(let message):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var violationsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(WenshuI18n.t("b5.longformguardrailsview.l324.h5287930"))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(state.lastViolations.enumerated()), id: \.offset) { _, v in
                HStack(alignment: .top, spacing: DesignTokens.spacingTight) {
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
        .padding(DesignTokens.spacingStandard)
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
        case .critical: return .red
        case .warning:  return .orange
        case .info:     return .secondary
        }
    }

    // MARK: - Add sheet

    private var addSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
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
            .padding(DesignTokens.spacingLoose)
            .frame(width: DesignTokens.guardrailSheetWidth)
            // apple-001 HIG absent batch: .navigationTitle +
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
        .background(.windowBackground)
    }

    // MARK: - Async actions

    private func reload() async {
        guard activeBookId != nil else { return }
        state.loadingState = .loading
        let actor = await ensureManager()
        let result = await LongFormGuardrailsOps.reload(manager: actor, bookId: activeBookId)
        state.guardrails = result.rows
        if let err = result.error {
            state.loadingState = .failed(err)
        } else if result.didLoad {
            state.loadingState = .loaded
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
            state.loadingState = .failed(err)
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
            state.loadingState = .failed(err)
        }
    }

    private func runCheck() async {
        guard activeBookId != nil else { return }
        let actor = await ensureManager()
        lastCheckStatus = .running
        let result = await LongFormGuardrailsOps.runCheck(
            manager: actor,
            guardrails: state.guardrails,
            checkText: checkText
        )
        state.lastViolations = result.violations
        if result.didRun {
            lastCheckStatus = .done(result.violations.count, result.hasCritical)
        } else {
            lastCheckStatus = .done(0, false)
        }
    }
}
