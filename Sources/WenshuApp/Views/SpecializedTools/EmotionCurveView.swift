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
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6 icon
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
            Text(WenshuI18n.t("b5.emotioncurveview.l137.h23463773"))
                .font(.callout)
                .foregroundStyle(.primary)
            Stepper(
                value: $windowCount,
                in: 1...32
            ) {
                Text(WenshuI18n.t("b5.emotioncurveview.l144.h9449225"))
                    .font(.callout.monospacedDigit())
                    .frame(minWidth: 28, alignment: .trailing)
            }
            .help(WenshuI18n.t("b5.emotioncurveview.l148.h87664998"))
            Spacer(minLength: 0)
            Text(WenshuI18n.t("b5.emotioncurveview.l150.h38155704"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingSmall) {
            HStack(spacing: DesignTokens.chromePaddingSmall) {
                Text(WenshuI18n.t("b5.emotioncurveview.l167.h48770099"))
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text(WenshuI18n.t("b5.emotioncurveview.l171.h283252"))
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.statusForeground)
            }
            TextEditor(text: $chapterText)
                .font(.caption)
                .frame(minHeight: 80, maxHeight: 140)
                .padding(DesignTokens.chromePaddingSmall)
                
            HStack(spacing: DesignTokens.chromePaddingVertical) {
                Button {
                    Task { await runAnalyze() }
                } label: {
                    Label { Text(WenshuI18n.t("b5.emotioncurveview.l187.h73202981")) } icon: { Image(systemName: "play").font(.system(size: 16, weight: .regular)) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(chapterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || status == .running)
                .help(WenshuI18n.t("b5.emotioncurveview.l191.h43420055"))
                Button {
                    chapterText = ""
                    report = nil
                    status = .idle
                } label: {
                    Label { Text(WenshuI18n.t("b5.emotioncurveview.l197.h82618035")) } icon: { Image(systemName: "xmark").font(.system(size: 16, weight: .regular)) }
                }
                .buttonStyle(.bordered)
                .help(WenshuI18n.t("b5.emotioncurveview.l200.h12079331"))
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
        // the unified EmptyStateView component (= 76 PT SF Symbols 6 icon + .regular weight = the canonical macOS 27 inspector icon weight; = standard
        // title/body hierarchy). Same visual treatment as every
        // other empty state in the workspace.
        EmptyStateView(
            icon: "waveform.path.ecg",
            title: WenshuI18n.t("b5.emotioncurveview.l210.h68237505"),
            body: WenshuI18n.t("b5.emotioncurveview.l213.h26939185")
        )
    }


    private func resultSection(for report: EmotionCurveReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            curveChart(for: report)
                .frame(height: DesignTokens.zoneEditorWidth)
                .padding(DesignTokens.chromePaddingVertical)
                
            HStack(spacing: 10) {
                metricBadge(title: "Overall", value: String(format: "%+.2f", report.overallScore))
                metricBadge(title: "Volatility", value: String(format: "%.2f", report.volatility))
                metricBadge(title: "Flat spots", value: "\(report.flatSpots.count)")
                metricBadge(title: "Lifts", value: "\(report.suggestedLifts.count)")
            }
            HStack(alignment: .top, spacing: DesignTokens.chromePaddingMedium) {
                indexColumn(title: "Flat spots",
                            items: report.flatSpots.map { String($0) },
                            tint: Color.gray)
                indexColumn(title: "Suggested lifts",
                            items: report.suggestedLifts.map { String($0) },
                            tint: Color.blue)
            }
            Text(report.pacingHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.chromePaddingPickerItem)
        
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
        .padding(.horizontal, DesignTokens.chromePaddingVertical)
        .padding(.vertical, DesignTokens.chromePaddingMicro)
        .frame(minWidth: 64, alignment: .leading)
        
    }

    private func indexColumn(title: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
                if items.isEmpty {
                    Text(WenshuI18n.t("b5.emotioncurveview.l280.h69702322"))
                        .font(.caption)
                        .foregroundStyle(DesignTokens.statusForeground)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: DesignTokens.chromePaddingSmall) {
                            Circle()
                                .fill(tint)
                                .frame(width: DesignTokens.bulletSizeTiny, height: DesignTokens.bulletSizeTiny)
                                .padding(.top, DesignTokens.chromePaddingXS)
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
        .accessibilityLabel(WenshuI18n.t("a11y.emotion_curve"))
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
            // macOS 27 doc-alignment (boss 9/18 OOB '全都改一下',
            // audit ticket 6): HierarchicalShapeStyle.separator
            // is the Apple semantic ShapeStyle that auto-adapts
            // to dark mode + Liquid Glass (= not the solid
            // NSColor.separatorColor that fails on dark mode +
            // glass tint backgrounds per
            // wenshu-macos26-liquid-glass-pitfalls Pitfall 1
            // Attempt 1/2 boss-rejected).
            //
            // Implementation note (= reason we keep
            // Color(nsColor: .separatorColor) here): SwiftUI
            // GraphicsContext.Shading.color() (= the API
            // signature on macOS 27) accepts Color only, NOT
            // ShapeStyle. Color.init(_ style: ShapeStyle, opacity:)
            // = the candidate overload that should accept a
            // ShapeStyle, but the Swift 6 type checker resolves
            // Color(_ white: Double, opacity:) (= gray Color
            // initializer) before the ShapeStyle overload when
            // the context is .color(...) on a GraphicsContext.
            // = the only working Color path through this API
            // today is Color(nsColor: .separatorColor). When
            // Apple ships a GraphicsContext.Shading.color(_
            // style: ShapeStyle) overload (= a ShapeStyle-aware
            // Color), this site should switch to
            // Color(.separator, opacity: 0.6).
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
            // macOS 27 doc-alignment (audit ticket 6): same
            // GraphicsContext.Shading.color() Color-only
            // limitation as the baseline stroke above.
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
                with: .color(Color.gray),
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
                with: .color(Color.blue)
            )
        }

        // 10) Y-axis labels (= +1 / 0 / -1).
        context.draw(
            Text(WenshuI18n.t("b5.emotioncurveview.l446.h6941667")).font(.caption2).foregroundStyle(.secondary),
            at: CGPoint(x: 10, y: topY)
        )
        context.draw(
            Text(WenshuI18n.t("b5.emotioncurveview.l450.h82202228")).font(.caption2).foregroundStyle(.secondary),
            at: CGPoint(x: 10, y: baselineY)
        )
        context.draw(
            Text(WenshuI18n.t("b5.emotioncurveview.l454.h50895112")).font(.caption2).foregroundStyle(.secondary),
            at: CGPoint(x: 10, y: bottomY)
        )

        // 11) Legend (= flat dot + lift triangle), bottom row.
        let legendY = chartRect.maxY + 14
        context.draw(
            Text(WenshuI18n.t("b5.emotioncurveview.l461.h66795892")).font(.caption2).foregroundStyle(.secondary),
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
