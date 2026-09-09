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
//  `ReaderExperienceReport`. The view holds the latest report in
//  `@State` and re-renders the result panel.
//
//  Standards-axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + Lucide icon
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
//  the report.
//

import SwiftUI

/// SpecializedTools pane tab 4: Reader Experience.
///
/// Stateless UI (= the `ReaderExperienceAnalyzer` actor is
/// stateless). User pastes chapter text, picks a kind, taps
/// Analyze, sees a report.
@MainActor
struct ReaderExperienceView: View {

    /// The analyzer actor (= lazy-created so the view can be
    /// instantiated without a BookStore).
    @State private var analyzer: ReaderExperienceAnalyzer?

    /// Currently selected analyzer kind (= drives the report).
    @State private var selectedKind: ReaderExperienceKind = .tension

    /// Chapter text input (= the user pastes a finished chapter
    /// here).
    @State private var chapterText: String = ""

    /// Latest report (= nil until the user runs an analyze).
    @State private var report: ReaderExperienceReport?

    /// Analyzer status (= idle / running / failed).
    @State private var status: AnalyzeStatus = .idle

    private enum AnalyzeStatus: Equatable, Sendable {
        case idle
        case running
        case failed(String)
    }

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            pickerRow
            inputSection
            Divider()
            if let report = report {
                resultSection(for: report)
            } else {
                emptyState
            }
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.chromePaddingMedium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            ensureAnalyzer()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            LucideIconSystemFallback("sparkles", size: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(WenshuI18n.t("b5.readerexperienceview.l103.h22896014"))
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
        switch status {
        case .idle:
            return "Paste a finished chapter and pick an analyzer to inspect reader-experience signals."
        case .running:
            return "Running \(selectedKind.displayName) analyzer…"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    // MARK: - Picker

    private var pickerRow: some View {
        HStack(spacing: 8) {
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
                .frame(maxWidth: 320, alignment: .trailing)
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(WenshuI18n.t("b5.readerexperienceview.l155.h15975486"))
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text(WenshuI18n.t("b5.readerexperienceview.l159.h48868028"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            TextEditor(text: $chapterText)
                .font(.caption)
                .frame(minHeight: 80, maxHeight: 140)
                .padding(DesignTokens.chromePaddingSmall)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                )
            HStack(spacing: 8) {
                Button {
                    Task { await runAnalyze() }
                } label: {
                    Label(WenshuI18n.t("b5.readerexperienceview.l175.h61672688"), systemImage: "play")
                }
                .buttonStyle(.borderedProminent)
                .disabled(chapterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || status == .running)
                .help(WenshuI18n.t("b5.readerexperienceview.l179.h93248900"))
                Button {
                    chapterText = ""
                    report = nil
                    status = .idle
                } label: {
                    Label(WenshuI18n.t("b5.readerexperienceview.l185.h22504814"), systemImage: "x")
                }
                .buttonStyle(.bordered)
                .help(WenshuI18n.t("b5.readerexperienceview.l188.h90304051"))
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Result

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(WenshuI18n.t("b5.readerexperienceview.l198.h54334339"))
                .font(.callout)
                .foregroundStyle(.primary)
            Text(WenshuI18n.t("b5.readerexperienceview.l201.h81086064"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultSection(for report: ReaderExperienceReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                LucideIconSystemFallback(report.kind.lucideIcon, size: 16)
                    .foregroundStyle(.tint)
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
        .padding(DesignTokens.chromePaddingPickerItem)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
        )
    }

    private func scoreBadge(_ score: Double) -> some View {
        let pct = Int((score * 100.0).rounded())
        let color: Color = {
            if score >= 0.7 { return Color.green.opacity(0.22) }
            if score >= 0.4 { return Color.orange.opacity(0.22) }
            return Color.gray.opacity(0.22)
        }()
        return Text(WenshuI18n.t("b5.readerexperienceview.l247.h50530381"))
            .font(.caption2)
            .foregroundStyle(.primary)
            .padding(.horizontal, DesignTokens.chromePaddingSmall)
            .padding(.vertical, DesignTokens.chromePaddingPico)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
            )
    }

    private func highlightsSection(_ highlights: [ReaderExperienceHighlight]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("b5.readerexperienceview.l260.h48696486"))
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(highlights.enumerated()), id: \.offset) { _, h in
                    HStack(alignment: .top, spacing: 6) {
                        Text(h.label)
                            .font(.caption2)
                            .foregroundStyle(.tint)
                            .padding(.horizontal, DesignTokens.chromePaddingMicro)
                            .padding(.vertical, DesignTokens.chromePaddingPico)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.quaternary)
                            )
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
        VStack(alignment: .leading, spacing: 4) {
            Text(WenshuI18n.t("b5.readerexperienceview.l288.h40277958"))
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { _, s in
                    HStack(alignment: .top, spacing: 6) {
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
        ensureAnalyzer()
        guard let analyzer = analyzer else { return }
        status = .running
        let text = chapterText
        let kind = selectedKind
        do {
            let newReport = try await analyzer.analyze(chapterText: text, kind: kind)
            report = newReport
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
            report = nil
        }
    }
}
