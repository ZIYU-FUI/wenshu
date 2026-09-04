//
//  EmotionCurveView.swift · Wenshu · P1 ticket #11 (WIRE-SPECIALIZEDTOOLS-005, 2026-09-04)
//
//  SpecializedTools pane tab 7: Emotion Curve.
//
//  Per the v0.30 boss 2026-08-30 OOB pattern (= ForeshadowingView
//  + PlaceholderView + LongFormGuardrailsView +
//  ReaderExperienceView + PlotThreadView + GenreFitView = 6 tabs
//  in the specializedTools pane), this view is the REAL
//  implementation for the Emotion Curve tab (= the 7th tab).
//  Renders:
//
//    - Top header (= icon + tab title + window-count stepper +
//      status)
//    - Chapter-text input (= a TextEditor bound to local state;
//      user pastes the finished chapter body)
//    - "Analyze" button (= runs the EmotionCurveAnalyzer against
//      the input text + the chosen window count)
//    - Curve visualization (= SwiftUI Canvas drawing the
//      per-window scores as a line chart, with a zero baseline
//      + flat-spot markers + lift suggestions)
//    - Report panel (= overall score + volatility + flat-spot
//      list + lift suggestions + pacing hint)
//
//  State source: `EmotionCurveAnalyzer` actor (= stateless; = no
//  BookStore required). Each analyze call returns a fresh
//  `EmotionCurveReport`. The view holds the latest report in
//  `@State` and re-renders the curve + result panel.
//
//  Standards-axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + Lucide icon
//        helper + Canvas (= already shipped by Apple SwiftUI on
//        macOS 27). No custom hover / click handlers; Apple
//        `.buttonStyle` .borderless + .borderedProminent per the
//        macOS 27 Liquid Glass defaults.
//    S3 (single source of truth for JSON parsing): the actor
//        ships no JSON I/O (= stateless).
//    S5 (no private types the rest of the app needs): all types
//        live in EmotionCurveTools.swift (= public).
//
//  Visual-gate (boss 2026-09-03 auto-pilot rule): this commit
//  ADDS a 7th tab to the specializedTools pane. Boss acceptance
//  required: open SpecializedTools pane, click the new
//  Emotion-Curve tab, paste a chapter, run analyze, see the
//  curve visualization + report.
//

import SwiftUI

/// SpecializedTools pane tab 7: Emotion Curve.
///
/// Stateless UI (= the `EmotionCurveAnalyzer` actor is
/// stateless). User pastes chapter text, picks a window count,
/// taps Analyze, sees a curve + report.
@MainActor
struct EmotionCurveView: View {

    /// The analyzer actor (= lazy-created so the view can be
    /// instantiated without a BookStore).
    @State private var analyzer: EmotionCurveAnalyzer?

    /// Chapter text input (= the user pastes a finished chapter
    /// here).
    @State private var chapterText: String = ""

    /// Window count (= mirrors the actor's default).
    @State private var windowCount: Int = EmotionCurveAnalyzer.defaultWindowCount

    /// Latest report (= nil until the user runs an analyze).
    @State private var report: EmotionCurveReport?

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
            LucideIconSystemFallback("activity", size: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Emotion Curve")
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
            return "Paste a finished chapter and split it into windows to chart the emotional valence over time."
        case .running:
            return "Analyzing \(windowCount) windows…"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    // MARK: - Picker

    private var pickerRow: some View {
        HStack(spacing: 8) {
            Text("Windows")
                .font(.callout)
                .foregroundStyle(.primary)
            Stepper(
                value: $windowCount,
                in: 1...32
            ) {
                Text("\(windowCount)")
                    .font(.callout.monospacedDigit())
                    .frame(minWidth: 28, alignment: .trailing)
            }
            .help("Number of windows to split the chapter into (1–32).")
            Spacer(minLength: 0)
            Text("\(windowCount) windows × ~\(estimatedWindowChars) chars each")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var estimatedWindowChars: Int {
        let total = chapterText.count
        guard windowCount > 0 else { return 0 }
        return total / windowCount
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
                .help("Score the chapter across \(windowCount) windows and chart the emotion curve.")
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
            Text("Paste a chapter, pick a window count, and tap Analyze. The emotion-curve analyzer splits the chapter into equal windows, scores each via a small sentiment lexicon, and returns a curve with overall score, volatility, flat-spot indices, and pacing-lift suggestions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultSection(for report: EmotionCurveReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            curveChart(for: report)
                .frame(height: 140)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                )
            HStack(spacing: 10) {
                metricBadge(title: "Overall", value: String(format: "%+.2f", report.overallScore))
                metricBadge(title: "Volatility", value: String(format: "%.2f", report.volatility))
                metricBadge(title: "Flat spots", value: "\(report.flatSpots.count)")
                metricBadge(title: "Lifts", value: "\(report.suggestedLifts.count)")
            }
            HStack(alignment: .top, spacing: 12) {
                indexColumn(title: "Flat spots",
                            items: report.flatSpots.map { String($0) },
                            tint: Color(nsColor: .systemGray))
                indexColumn(title: "Suggested lifts",
                            items: report.suggestedLifts.map { String($0) },
                            tint: Color(nsColor: .systemBlue))
            }
            Text(report.pacingHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.4))
        )
    }

    private func metricBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minWidth: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
        )
    }

    private func indexColumn(title: String, items: [String], tint: Color) -> some View {
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
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Curve visualization

    @ViewBuilder
    private func curveChart(for report: EmotionCurveReport) -> some View {
        Canvas { context, size in
            drawCurve(report: report, context: &context, size: size)
        }
        .accessibilityLabel("Emotion curve")
    }

    private func drawCurve(
        report: EmotionCurveReport,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let windows = report.windows
        guard windows.count > 0 else { return }

        // Layout
        let leftPad: CGFloat = 28
        let rightPad: CGFloat = 8
        let topPad: CGFloat = 8
        let bottomPad: CGFloat = 18
        let chartRect = CGRect(
            x: leftPad,
            y: topPad,
            width: max(1, size.width - leftPad - rightPad),
            height: max(1, size.height - topPad - bottomPad)
        )

        // 1) Background baseline (= zero line, the boundary
        // between positive and negative sentiment).
        let baselineY = chartRect.midY
        var baselinePath = Path()
        baselinePath.move(to: CGPoint(x: chartRect.minX, y: baselineY))
        baselinePath.addLine(to: CGPoint(x: chartRect.maxX, y: baselineY))
        context.stroke(
            baselinePath,
            with: .color(Color(nsColor: .separatorColor).opacity(0.6)),
            lineWidth: 1
        )

        // 2) Top + bottom border lines (= +1 / -1 reference).
        let topY = chartRect.minY
        let bottomY = chartRect.maxY
        var referencePath = Path()
        referencePath.move(to: CGPoint(x: chartRect.minX, y: topY))
        referencePath.addLine(to: CGPoint(x: chartRect.maxX, y: topY))
        referencePath.move(to: CGPoint(x: chartRect.minX, y: bottomY))
        referencePath.addLine(to: CGPoint(x: chartRect.maxX, y: bottomY))
        context.stroke(
            referencePath,
            with: .color(Color(nsColor: .separatorColor).opacity(0.25)),
            style: StrokeStyle(lineWidth: 0.5, dash: [3, 3])
        )

        // 3) X positions for each window.
        let n = windows.count
        let xStep = n > 1 ? chartRect.width / CGFloat(n - 1) : 0
        let xPositions: [CGFloat] = (0..<n).map { i in
            chartRect.minX + CGFloat(i) * xStep
        }

        // 4) Map a score [-1, +1] to a y position within
        // [bottomY, topY].
        func y(forScore score: Double) -> CGFloat {
            let clamped = max(-1.0, min(1.0, score))
            // Positive score → upper half; negative → lower half.
            let normalized = (clamped + 1.0) / 2.0 // 0..1
            return chartRect.maxY - CGFloat(normalized) * chartRect.height
        }

        // 5) Curve path.
        var curvePath = Path()
        for (i, window) in windows.enumerated() {
            let pt = CGPoint(x: xPositions[i], y: y(forScore: window.score))
            if i == 0 {
                curvePath.move(to: pt)
            } else {
                curvePath.addLine(to: pt)
            }
        }
        context.stroke(
            curvePath,
            with: .color(Color.accentColor),
            lineWidth: 2
        )

        // 6) Filled area under the curve (= subtle fill above
        // and below the baseline).
        var fillPath = curvePath
        fillPath.addLine(to: CGPoint(x: xPositions[n - 1], y: baselineY))
        fillPath.addLine(to: CGPoint(x: xPositions[0], y: baselineY))
        fillPath.closeSubpath()
        context.fill(
            fillPath,
            with: .color(Color.accentColor.opacity(0.12))
        )

        // 7) Score dots.
        for (i, window) in windows.enumerated() {
            let pt = CGPoint(x: xPositions[i], y: y(forScore: window.score))
            let dotRect = CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5)
            context.fill(
                Path(ellipseIn: dotRect),
                with: .color(Color.accentColor)
            )
        }

        // 8) Flat-spot markers (= small open circles below the
        // chart).
        let flatSet = Set(report.flatSpots)
        let liftSet = Set(report.suggestedLifts)
        for index in flatSet {
            guard index >= 0, index < n else { continue }
            let x = xPositions[index]
            let markerY = chartRect.maxY + 8
            let dotRect = CGRect(x: x - 3, y: markerY - 3, width: 6, height: 6)
            context.stroke(
                Path(ellipseIn: dotRect),
                with: .color(Color(nsColor: .systemGray)),
                lineWidth: 1
            )
        }

        // 9) Lift markers (= upward triangle above the chart).
        for index in liftSet {
            guard index >= 0, index < n else { continue }
            let x = xPositions[index]
            let markerY = chartRect.minY - 6
            var triangle = Path()
            triangle.move(to: CGPoint(x: x, y: markerY - 4))
            triangle.addLine(to: CGPoint(x: x - 4, y: markerY + 2))
            triangle.addLine(to: CGPoint(x: x + 4, y: markerY + 2))
            triangle.closeSubpath()
            context.fill(
                triangle,
                with: .color(Color(nsColor: .systemBlue))
            )
        }

        // 10) Y-axis labels (= +1 / 0 / -1).
        let labelShading = GraphicsContext.Shading.color(Color(nsColor: .secondaryLabelColor))
        context.draw(
            Text("+1").font(.caption2).foregroundColor(Color(nsColor: .secondaryLabelColor)),
            at: CGPoint(x: 10, y: topY)
        )
        context.draw(
            Text("0").font(.caption2).foregroundColor(Color(nsColor: .secondaryLabelColor)),
            at: CGPoint(x: 10, y: baselineY)
        )
        context.draw(
            Text("-1").font(.caption2).foregroundColor(Color(nsColor: .secondaryLabelColor)),
            at: CGPoint(x: 10, y: bottomY)
        )

        // 11) Legend (= flat dot + lift triangle), bottom row.
        let legendY = chartRect.maxY + 14
        context.draw(
            Text("○ flat   ▲ lift").font(.caption2).foregroundColor(Color(nsColor: .secondaryLabelColor)),
            at: CGPoint(x: chartRect.maxX, y: legendY)
        )
    }

    // MARK: - Async actions

    private func ensureAnalyzer() {
        if analyzer == nil {
            analyzer = EmotionCurveAnalyzer()
        }
    }

    private func runAnalyze() async {
        ensureAnalyzer()
        guard let analyzer = analyzer else { return }
        status = .running
        let text = chapterText
        let count = windowCount
        do {
            let newReport = try await analyzer.analyze(
                chapterText: text,
                windowCount: count
            )
            report = newReport
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
            report = nil
        }
    }
}
