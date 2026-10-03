//
//  ReaderExperienceView.swift · Wenshu · P1 ticket #7 (WIRE-SPECIALIZEDTOOLS-002, 2026-09-04)
//
//  SpecializedTools pane tab 4: Reader Experience.
//
//  Per the v0.30 boss 2026-08-30 OOB pattern (= ForeshadowingView +
//  PlaceholderView + LongFormGuardrailsView = 3 tabs in the
//  specializedTools pane), this view is the REAL implementation
//  for the Reader Experience tab (= the 4th tab). Renders:
//
//    - Top header (= icon + tab title + analyzer-kind picker)
//    - Chapter-text input (= a TextEditor bound to local state;
//      user pastes the finished chapter body)
//    - "Analyze" button (= runs the selected analyzer against
//      the input text)
//    - Result panel (= score + summary + highlights + suggestions)
//
//  State source: `ReaderExperienceAnalyzer` actor (= stateless;
//  = no BookStore required). Each analyze call returns a fresh
//  `ReaderExperienceReport`. The view holds the latest state.report in
//  `@State` and re-renders the result panel.
//
//  Standards-axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6 icon
//        helper (= already wired into the wenshu chrome). No
//        custom hover / click handlers; Apple `.buttonStyle`
//        .borderless + `.borderedProminent` per the macOS 27
//        Liquid Glass defaults.
//    S3 (single source of truth for JSON parsing): the actor
//        ships no JSON I/O (= stateless).
//    S5 (no private types the rest of the app needs): all
//        types live in ReaderExperienceTools.swift (= public).
//
//  Visual-gate (boss 2026-09-03 auto-pilot rule): this commit
//  ADDS a 4th tab to the specializedTools pane. Boss acceptance
//  required: open SpecializedTools pane, click the new
//  Reader-Experience tab, paste a chapter, run an analyzer, see
//  the state.report.
//

import SwiftUI

/// SpecializedTools pane tab 4: Reader Experience.
///
/// Stateless UI (= the `ReaderExperienceAnalyzer` actor is
/// stateless). User pastes chapter text, picks a kind, taps
/// Analyze, sees a state.report.
@MainActor
struct ReaderExperienceView: View {

    /// The analyzer actor (= lazy-created so the view can be
    /// instantiated without a BookStore).
    @State private var analyzer: ReaderExperienceAnalyzer?

    /// Currently selected analyzer kind (= drives the state.report).
    @State private var selectedKind: ReaderExperienceKind = .tension

    /// Chapter text input (= the user pastes a finished chapter
    /// here).
    @State private var chapterText: String = ""

    /// Business state mirror (= state.report + status). Picker + input
    /// stay on the View per §11.3.
    @State private var state = ReaderExperienceViewState()

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            pickerRow
            inputSection
            Divider()
            if let report = state.report {
                resultSection(for: report)
            } else {
                emptyState
            }
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.spacingModerate)
        .task {
            ensureAnalyzer()
        }
    }

    // MARK: - Picker

    private var pickerRow: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            Text(WenshuI18n.t("b5.readerexperienceview.l130.h50931159"))
                .font(.callout)
                .foregroundStyle(.primary)
            Picker("", selection: $selectedKind) {
                ForEach(ReaderExperienceKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .help(selectedKind.hint)
            Spacer(minLength: 0)
            Text(selectedKind.hint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: DesignTokens.metadataPanelMaxWidth, alignment: .trailing)
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            HStack(spacing: DesignTokens.spacingTight) {
                Text(WenshuI18n.t("b5.readerexperienceview.l155.h15975486"))
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text(WenshuI18n.t("b5.readerexperienceview.l159.h48868028"))
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.statusForeground)
            }
            TextEditor(text: $chapterText)
                .font(.caption)
                .frame(minHeight: DesignTokens.textEditorSmallMinHeight, maxHeight: DesignTokens.textEditorSmallMaxHeight)
                .padding(DesignTokens.spacingTight)
                
            HStack(spacing: DesignTokens.spacingStandard) {
                Button {
                    Task { await runAnalyze() }
                } label: {
                    Label { Text(WenshuI18n.t("b5.readerexperienceview.l175.h61672688")) } icon: { SFIcon("play", style: .inlineSmall, color: IconColor.tint) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(chapterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.status == .loading)
                .help(WenshuI18n.t("b5.readerexperienceview.l179.h93248900"))
                Button {
                    chapterText = ""
                    state.report = nil
                    state.status = .idle
                } label: {
                    Label { Text(WenshuI18n.t("b5.readerexperienceview.l185.h22504814")) } icon: { SFIcon("xmark", style: .inlineSmall, color: IconColor.tint) }
                }
                .buttonStyle(.bordered)
                .help(WenshuI18n.t("b5.readerexperienceview.l188.h90304051"))
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Result

    private var emptyState: some View {
        // -m1-shell boss 2026-09-12 OOB 'the current empty state isn't
        // a single component — can you abstract a UI component? While you're at it, on the
        // empty-state icon: double the size and use the thinnest strokes. The goal is to unify all
        // empty-state styles. The right column has 12 tabs and many are missing an empty state': use
        // the unified EmptyStateView component (= 76 PT SF Symbols 6 icon + .regular weight = the canonical macOS 27 inspector icon weight; = standard
        // title/body hierarchy). Same visual treatment as every
        // other empty state in the workspace.
        EmptyStateView(
            icon: "sparkles",
            title: WenshuI18n.t("b5.readerexperienceview.l198.h54334339"),
            body: WenshuI18n.t("b5.readerexperienceview.l201.h81086064")
        )
    }


    private func resultSection(for report: ReaderExperienceReport) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
            HStack(spacing: DesignTokens.spacingStandard) {
                SFIcon(report.kind.icon, style: .inlineSmall, color: IconColor.tint)
                Text(report.kind.displayName)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                scoreBadge(report.score)
            }
            if !report.summary.isEmpty {
                Text(report.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !report.highlights.isEmpty {
                highlightsSection(report.highlights)
            }
            if !report.suggestions.isEmpty {
                suggestionsSection(report.suggestions)
            }
        }
        .padding(DesignTokens.spacingModerate)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        
    }

    private func scoreBadge(_ score: Double) -> some View {
        let color: Color = {
            if score >= 0.7 { return .green.opacity(0.22) }
            if score >= 0.4 { return .orange.opacity(0.22) }
            return .gray.opacity(0.22)
        }()
        return Text(WenshuI18n.t("b5.readerexperienceview.l247.h50530381"))
            .font(.caption2)
            .foregroundStyle(.primary)
            .padding(.horizontal, DesignTokens.spacingTight)
            .padding(.vertical, DesignTokens.spacingHairline)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip)
                    .fill(color)
            )
    }

    private func highlightsSection(_ highlights: [ReaderExperienceHighlight]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(WenshuI18n.t("b5.readerexperienceview.l260.h48696486"))
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
                ForEach(Array(highlights.enumerated()), id: \.offset) { _, h in
                    HStack(alignment: .top, spacing: DesignTokens.spacingTight) {
                        Text(h.label)
                            .font(.caption2)
                            .foregroundStyle(.tint)
                            .padding(.horizontal, DesignTokens.spacingIconic)
                            .padding(.vertical, DesignTokens.spacingHairline)
                            
                        Text(WenshuI18n.t("b5.readerexperienceview.l275.h51340592"))
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func suggestionsSection(_ suggestions: [ReaderExperienceSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(WenshuI18n.t("b5.readerexperienceview.l288.h40277958"))
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { _, s in
                    HStack(alignment: .top, spacing: DesignTokens.spacingTight) {
                        Text(WenshuI18n.t("b5.readerexperienceview.l294.h54608200"))
                            .font(.caption)
                            .foregroundStyle(.tint)
                        Text(s.text)
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - Async actions

    private func ensureAnalyzer() {
        if analyzer == nil {
            analyzer = ReaderExperienceAnalyzer()
        }
    }

    private func runAnalyze() async {
        ReaderExperienceOps.ensureAnalyzer(analyzer: &analyzer)
        state.status = .loading
        let result = await ReaderExperienceOps.runAnalyze(
            analyzer: analyzer,
            chapterText: chapterText,
            kind: selectedKind
        )
        state.report = result.report
        if result.didRun {
            state.status = .idle
        } else if let err = result.error {
            state.status = .failed(err)
        }
    }
}
