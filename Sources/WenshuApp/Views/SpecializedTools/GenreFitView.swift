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
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            ensureAnalyzer()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            LucideIconSystemFallback("book-marked", size: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Genre Fit")
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
            return "Paste a finished chapter and pick a genre to score how well it fits the conventions."
        case .running:
            return "Scoring \(selectedGenre.displayName)…"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    // MARK: - Picker

    private var pickerRow: some View {
        HStack(spacing: 8) {
            Text("Genre")
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Chapter text")
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text("\(chapterText.count) chars")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            TextEditor(text: $chapterText)
                .font(.caption)
                .frame(minHeight: 80, maxHeight: 140)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                )
            HStack(spacing: 8) {
                Button {
                    Task { await runAnalyze() }
                } label: {
                    Label("Analyze", systemImage: "play")
                }
                .buttonStyle(.borderedProminent)
                .disabled(chapterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || status == .running)
                .help("Score the chapter against \(selectedGenre.displayName) conventions.")
                Button {
                    chapterText = ""
                    report = nil
                    status = .idle
                } label: {
                    Label("Clear", systemImage: "x")
                }
                .buttonStyle(.bordered)
                .help("Clear the input text and the last report.")
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Result

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No report yet")
                .font(.callout)
                .foregroundStyle(.primary)
            Text("Paste a chapter, pick a genre, and tap Analyze. The genre-fit analyzer evaluates the draft against the genre's required beats + expected vocabulary + forbidden patterns, and returns a 0–100 score with matched / missing / forbidden lists.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultSection(for report: GenreFitReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                LucideIconSystemFallback(report.genre.lucideIcon, size: 16)
                    .foregroundStyle(.tint)
                Text(report.genre.displayName)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                scoreBadge(report.score)
            }
            HStack(alignment: .top, spacing: 12) {
                column(title: "Matched beats (\(report.matchedBeats.count))",
                       items: report.matchedBeats,
                       tint: Color(nsColor: .systemGreen))
                column(title: "Missing beats (\(report.missingBeats.count))",
                       items: report.missingBeats,
                       tint: Color(nsColor: .systemOrange))
            }
            HStack(alignment: .top, spacing: 12) {
                column(title: "Expected vocab used (\(report.expectedVocabUsed.count))",
                       items: report.expectedVocabUsed,
                       tint: Color(nsColor: .systemBlue))
                column(title: "Expected vocab missing (\(report.expectedVocabMissing.count))",
                       items: report.expectedVocabMissing,
                       tint: Color(nsColor: .systemGray))
            }
            column(title: "Forbidden hits (\(report.forbiddenHits.count))",
                   items: report.forbiddenHits,
                   tint: Color(nsColor: .systemRed))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
        )
    }

    private func scoreBadge(_ score: Double) -> some View {
        let pct = Int(score.rounded())
        let color: Color = {
            if score >= 70 { return Color(nsColor: .systemGreen).opacity(0.22) }
            if score >= 40 { return Color(nsColor: .systemOrange).opacity(0.22) }
            return Color(nsColor: .systemRed).opacity(0.22)
        }()
        return Text("score \(pct)/100")
            .font(.caption2)
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
            )
    }

    private func column(title: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                if items.isEmpty {
                    Text("(none)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(tint)
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
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
