// ChatContextGaugeView.swift
//
// The chat zone's context meter.
//
// It carries an Apple capacity gauge beside the reading (= a level
// indicator whose fill stops at the value's place on the path), and
// opens a popover on click that names the parts of the prompt the value
// is made of.
//
// Apple canonical:
//   - Gauges: "a gauge that uses the capacity style displays a fill that
//     stops at the value's location on the path"; "Consider using the
//     continuous style for large ranges" (= a 1,000,000-token window is a
//     large range, so a segmented fill would have too little resolution to
//     read); "Consider changing the fill color to inform people about
//     significant parts of the range"; and "Write succinct labels that
//     describe the current value and both endpoints of the range" (=
//     VoiceOver reads the visible labels).
//   - Popovers: "Use a popover to expose a small amount of information";
//     "Position popovers appropriately. Make sure a popover's arrow points
//     as directly as possible to the element that revealed it"; "Show one
//     popover at a time"; "Avoid making a popover too big".

import SwiftUI
import WenshuAgent

/// The chat zone's context meter: a capacity gauge plus the breakdown
/// popover it opens.
struct ChatContextGaugeView: View {
    /// The reading (= the provider's own count of the last request's
    /// prompt, and the parts that made it up).
    let snapshot: ContextUsageSnapshot?

    /// Whether the popover is open.
    ///
    /// One popover at a time (= the HIG's rule), so the state lives here
    /// rather than being spread across the footer.
    @State private var showingBreakdown = false

    var body: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            gauge
            label
        }
        .popover(
            isPresented: $showingBreakdown,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            ChatContextBreakdownView(snapshot: snapshot)
        }
    }

    /// The gauge itself.
    ///
    /// The value is the tokens the last request's prompt carried; the
    /// range is the window those tokens have to fit into. The fill turns
    /// from the accent to the warning colour as the occupancy passes the
    /// point where the agent starts compressing (= the same fraction the
    /// compressor uses), so the writer sees the threshold coming.
    private var gauge: some View {
        Gauge(
            value: Double(snapshot?.promptTokens ?? 0),
            in: 0 ... Double(max(snapshot?.contextWindow ?? 0, 1))
        ) {
            EmptyView()
        }
        .gaugeStyle(.accessoryLinearCapacity)
        .tint(fillColor)
        .frame(
            width: DesignTokens.contextGaugeWidth,
            height: DesignTokens.contextGaugeHeight
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showingBreakdown.toggle()
        }
        .help(String(localized: "chat.context.gauge.help"))
        .accessibilityLabel(Text(String(localized: "chat.context.gauge")))
        .accessibilityValue(Text(accessibilityReading))
    }

    /// The label beside the gauge (= the current value and the window).
    ///
    /// The label carries the numbers the gauge's own fill cannot: how
    /// many tokens are in use, and how many the window holds.
    private var label: some View {
        Text(reading)
            .font(.callout)
            .foregroundStyle(labelColor)
    }

    /// The reading the label shows.
    ///
    /// With a reading in hand the label names the current value and the
    /// window's upper end. Without one it says the meter has nothing to
    /// report yet (= an empty state is silence, not a confusing zero).
    private var reading: String {
        guard let snapshot, snapshot.promptTokens > 0, snapshot.contextWindow > 0 else {
            return String(localized: "chat.context.gauge.empty")
        }
        return String(
            format: String(localized: "chat.context.gauge.reading"),
            snapshot.promptTokens,
            snapshot.contextWindow
        )
    }

    /// The label's tone.
    ///
    /// The same signal the gauge's fill carries, so the two agree.
    private var labelColor: Color {
        guard let snapshot, snapshot.contextWindow > 0 else {
            return IconColor.secondary.style
        }
        return snapshot.occupancy >= ContextCompressionThreshold.fraction
            ? IconColor.orange.style
            : IconColor.secondary.style
    }

    /// The gauge's fill colour.
    ///
    /// The accent while there is room, the warning colour once the
    /// occupancy passes the compression threshold. The threshold is the
    /// fraction of the window the compressor acts on, so the colour
    /// change means the same thing the compression does.
    ///
    /// The label beside the gauge carries the same signal in its own
    /// tone, so the state reads whether or not the fill takes the tint.
    private var fillColor: Color {
        guard let snapshot, snapshot.contextWindow > 0 else {
            return IconColor.accent.style
        }
        guard snapshot.occupancy >= ContextCompressionThreshold.fraction else {
            return IconColor.accent.style
        }
        return IconColor.orange.style
    }

    /// The reading VoiceOver speaks.
    ///
    /// The label beside the gauge says how much is in use and how much the
    /// window holds; the reading adds the share, which is the number the
    /// writer compares against the threshold.
    private var accessibilityReading: String {
        guard let snapshot, snapshot.promptTokens > 0, snapshot.contextWindow > 0 else {
            return String(localized: "chat.context.gauge.empty")
        }
        let percent = Int((snapshot.occupancy * 100).rounded())
        return String(
            format: String(localized: "chat.context.gauge.percent"),
            percent
        )
    }
}

/// The breakdown of what the prompt carried.
///
/// One number per part, plus the cache's own counters (= the cache is
/// what the provider read and wrote, which is a fact about the bill
/// rather than about the window's occupancy).
struct ChatContextBreakdownView: View {
    let snapshot: ContextUsageSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            header
            if let snapshot {
                Divider()
                categories(snapshot)
                Divider()
                cacheRows(snapshot)
            } else {
                Text(String(localized: "chat.context.breakdown.empty"))
                    .font(.callout)
                    .foregroundStyle(DesignTokens.textChrome)
            }
        }
        .padding(DesignTokens.spacingStandard)
        .frame(width: DesignTokens.contextBreakdownPopoverWidth)
    }

    /// The headline (= the same three numbers the gauge carries).
    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingCaption) {
            Text(String(localized: "chat.context.breakdown.title"))
                .font(.headline)
            if let snapshot, snapshot.promptTokens > 0 {
                let percent = Int((snapshot.occupancy * 100).rounded())
                Text(
                    String(
                        format: String(localized: "chat.context.breakdown.summary"),
                        snapshot.promptTokens,
                        snapshot.contextWindow,
                        percent
                    )
                )
                .font(.callout)
                .foregroundStyle(DesignTokens.textChrome)
            }
        }
    }

    /// The prompt's parts, one row each.
    private func categories(_ snapshot: ContextUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingCaption) {
            ForEach(snapshot.categories) { category in
                HStack(spacing: DesignTokens.spacingTight) {
                    Text(label(for: category.id))
                        .font(.callout)
                    Spacer(minLength: DesignTokens.spacingTight)
                    Text(category.tokens.formatted())
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(DesignTokens.textChrome)
                }
            }
        }
    }

    /// The cache's counters.
    ///
    /// These are a fact about the bill, not about the window's
    /// occupancy, so they sit under the parts rather than inside the
    /// fill.
    private func cacheRows(_ snapshot: ContextUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingCaption) {
            HStack(spacing: DesignTokens.spacingTight) {
                Text(String(localized: "chat.context.breakdown.cache_read"))
                    .font(.callout)
                Spacer(minLength: DesignTokens.spacingTight)
                Text(snapshot.cacheReadTokens.formatted())
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(DesignTokens.textChrome)
            }
            HStack(spacing: DesignTokens.spacingTight) {
                Text(String(localized: "chat.context.breakdown.cache_creation"))
                    .font(.callout)
                Spacer(minLength: DesignTokens.spacingTight)
                Text(snapshot.cacheCreationTokens.formatted())
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(DesignTokens.textChrome)
            }
            HStack(spacing: DesignTokens.spacingTight) {
                Text(String(localized: "chat.context.breakdown.completion"))
                    .font(.callout)
                Spacer(minLength: DesignTokens.spacingTight)
                Text(snapshot.completionTokens.formatted())
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(DesignTokens.textChrome)
            }
        }
    }

    /// The row's label.
    private func label(for id: ContextUsageCategory.ID) -> String {
        switch id {
        case .systemPrompt:
            return String(localized: "chat.context.breakdown.system_prompt")
        case .toolSchemas:
            return String(localized: "chat.context.breakdown.tool_schemas")
        case .messages:
            return String(localized: "chat.context.breakdown.messages")
        case .toolResults:
            return String(localized: "chat.context.breakdown.tool_results")
        case .memory:
            return String(localized: "chat.context.breakdown.memory")
        }
    }
}
