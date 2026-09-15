//
//  GenreFitView.swift · Wenshu · P1 ticket #9 (WIRE-SPECIALIZEDTOOLS-004, 2026-09-04)
//
//  SpecializedTools pane tab 6: Genre Fit.
//
//  Per the v0.30 boss 2026-08-30 OOB pattern (= ForeshadowingView +
//  PlaceholderView + LongFormGuardrailsView + ReaderExperienceView +
//  PlotThreadView = 5 tabs in the specializedTools pane), this
//  view is the REAL implementation for the Genre Fit tab (= the
//  6th tab). Renders:
//
//    - Top header (= icon + tab title + genre picker + hint)
//    - Chapter-text input (= a TextEditor bound to local state;
//      user pastes the finished chapter body)
//    - "Analyze" button (= runs the GenreFitAnalyzer against the
//      input text + the selected genre)
//    - Result panel (= score badge + matched / missing /
//      forbidden / vocab sections)
//
//  State source: `GenreFitAnalyzer` actor (= stateless; = no
//  BookStore required). Each analyze call returns a fresh
//  `GenreFitReport`. The view holds the latest report in
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
//        types live in GenreFitTools.swift (= public).
//
//  Visual-gate (boss 2026-09-03 auto-pilot rule): this commit
//  ADDS a 6th tab to the specializedTools pane. Boss acceptance
//  required: open SpecializedTools pane, click the new
//  Genre-Fit tab, paste a chapter, pick a genre, run analyze,
//  see the score + matches / misses / forbidden hits.
//

import SwiftUI

/// SpecializedTools pane tab 6: Genre Fit.
///
/// Stateless UI (= the `GenreFitAnalyzer` actor is stateless).
/// User pastes chapter text, picks a genre, taps Analyze, sees a
/// report.
@MainActor
struct GenreFitView: View {

    /// The analyzer actor (= lazy-created so the view can be
    /// instantiated without a BookStore).
    @State private var analyzer: GenreFitAnalyzer?

    /// Currently selected genre (= drives the report).
    @State private var selectedGenre: LiteraryGenre = .mystery

    /// Chapter text input (= the user pastes a finished chapter
    /// here).
    @State private var chapterText: String = ""

    /// Latest report (= nil until the user runs an analyze).
    @State private var report: GenreFitReport?

    /// Analyzer status (= idle / running / failed).
    @State private var status: AnalyzeStatus = .idle

    private enum AnalyzeStatus: Equatable, Sendable {
        case idle
        case running
        case failed(String)
    }

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMedium) {
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
        .task {
            ensureAnalyzer()
        }
    }

    // MARK: - Picker

    private var pickerRow: some View {
        HStack(spacing: DesignTokens.chromePaddingVertical) {
            Text(WenshuI18n.t("b5.genrefitview.l132.h73166390"))
                .font(.callout)
                .foregroundStyle(.primary)
            Picker("", selection: $selectedGenre) {
                ForEach(LiteraryGenre.allCases) { genre in
                    Text(genre.displayName).tag(genre)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .help(selectedGenre.hint)
            Spacer(minLength: 0)
            Text(selectedGenre.hint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: 320, alignment: .trailing)
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingSmall) {
            HStack(spacing: DesignTokens.chromePaddingSmall) {
                Text(WenshuI18n.t("b5.genrefitview.l157.h55071280"))
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text(WenshuI18n.t("b5.genrefitview.l161.h19367178"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            TextEditor(text: $chapterText)
                .font(.caption)
                .frame(minHeight: 80, maxHeight: 140)
                .padding(DesignTokens.chromePaddingSmall)
                
            HStack(spacing: DesignTokens.chromePaddingVertical) {
                Button {
                    Task { await runAnalyze() }
                } label: {
                    Label { Text(WenshuI18n.t("button.analyze")) } icon: { Image(systemName: "play").font(.system(size: 16, weight: .regular)) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(chapterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || status == .running)
                .help(WenshuI18n.t("b5.genrefitview.l181.h2218881"))
                Button {
                    chapterText = ""
                    report = nil
                    status = .idle
                } label: {
                    Label { Text(WenshuI18n.t("button.clear")) } icon: { Image(systemName: "xmark").font(.system(size: 16, weight: .regular)) }
                }
                .buttonStyle(.bordered)
                .help(WenshuI18n.t("b5.genrefitview.l190.h26662967"))
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Result

    private var emptyState: some View {
        // v1.0.0-m1-shell boss 2026-09-12 OOB 'the current empty state isn't
        // a single component — can you abstract a UI component? While you're at it, on the
        // empty-state icon: double the size and use the thinnest strokes. The goal is to unify all
        // empty-state styles. The right column has 12 tabs and many are missing an empty state': use
        // the unified EmptyStateView component (= Lucide icon
        // at 76 PT + 1 PT stroke via LucideThinIcon + standard
        // title/body hierarchy). Same visual treatment as every
        // other empty state in the workspace.
        EmptyStateView(
            icon: "book-marked",
            title: WenshuI18n.t("b5.genrefitview.l200.h95444806"),
            body: WenshuI18n.t("b5.genrefitview.l203.h79122074")
        )
    }


    private func resultSection(for report: GenreFitReport) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingVertical) {
            HStack(spacing: DesignTokens.chromePaddingVertical) {
                Image(systemName: report.genre.lucideIcon).font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.tint)
                Text(report.genre.displayName)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                scoreBadge(report.score)
            }
            HStack(alignment: .top, spacing: DesignTokens.chromePaddingMedium) {
                column(title: "Matched beats (\(report.matchedBeats.count))",
                       items: report.matchedBeats,
                       tint: Color.green)
                column(title: "Missing beats (\(report.missingBeats.count))",
                       items: report.missingBeats,
                       tint: Color.orange)
            }
            HStack(alignment: .top, spacing: DesignTokens.chromePaddingMedium) {
                column(title: "Expected vocab used (\(report.expectedVocabUsed.count))",
                       items: report.expectedVocabUsed,
                       tint: Color.blue)
                column(title: "Expected vocab missing (\(report.expectedVocabMissing.count))",
                       items: report.expectedVocabMissing,
                       tint: Color.gray)
            }
            column(title: "Forbidden hits (\(report.forbiddenHits.count))",
                   items: report.forbiddenHits,
                   tint: Color.red)
        }
        .padding(DesignTokens.chromePaddingPickerItem)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        
    }

    private func scoreBadge(_ score: Double) -> some View {
        let pct = Int(score.rounded())
        let color: Color = {
            if score >= 70 { return Color.green.opacity(0.22) }
            if score >= 40 { return Color.orange.opacity(0.22) }
            return Color.red.opacity(0.22)
        }()
        return Text(WenshuI18n.t("b5.genrefitview.l256.h78050164"))
            .font(.caption2)
            .foregroundStyle(.primary)
            .padding(.horizontal, DesignTokens.chromePaddingSmall)
            .padding(.vertical, DesignTokens.chromePaddingPico)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
            )
    }

    private func column(title: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
                if items.isEmpty {
                    Text(WenshuI18n.t("b5.genrefitview.l274.h53280066"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: DesignTokens.chromePaddingSmall) {
                            Circle()
                                .fill(tint)
                                .frame(width: DesignTokens.bulletSizeTiny, height: DesignTokens.bulletSizeTiny)
                                .padding(.top, DesignTokens.chromePaddingXS)
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Async actions

    private func ensureAnalyzer() {
        if analyzer == nil {
            analyzer = GenreFitAnalyzer()
        }
    }

    private func runAnalyze() async {
        ensureAnalyzer()
        guard let analyzer = analyzer else { return }
        status = .running
        let text = chapterText
        let genre = selectedGenre
        do {
            let newReport = try await analyzer.analyze(chapterText: text, genre: genre)
            report = newReport
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
            report = nil
        }
    }
}
