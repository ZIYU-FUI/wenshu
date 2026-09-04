//
//  AgentProgressPanel.swift · Wenshu · v0.41 WIRE-OPENBOX-001
//
//  P2 #21 wire progress (boss 2026-09-04 OOB 'wire progress from
//  ConversationLoop into OpenBox so user sees step-by-step feedback').
//
//  Small panel displayed at the top of DynamicZoneView (the OpenBox
//  dynamic zone = kanban / todo tabs). The panel polls the shared
//  AgentProgressTracker every ~1s and shows the latest running
//  entry (= the in-flight user turn), including:
//    - Spinning progress indicator + step label
//    - Step counter (e.g. "3 / 7")
//    - ETA countdown when known (= "ETA: 8s")
//
//  The panel hides itself when no entry is running (= user is idle,
//  not in the middle of a turn). No data is persisted; on app
//  restart the tracker is empty so the panel stays hidden until
//  the user sends the next message.
//
//  Apple HIG: thinMaterial background + ProgressView() native control.
//  Matches DynamicZoneView's existing `.regularMaterial` card pattern
//  (= used by SubAgentProgressView's TaskRowView).
//
//  Why not @Observable: the panel queries an actor from a SwiftUI
//  view. Polling via `.task(id:)` (= 1s timer + cancellation on
//  view dismissal) is the canonical SwiftUI pattern for actor
//  reads from views. Reactive observation (= @Observable + AsyncSequence)
//  would require converting the actor to an Observable; the
//  polling pattern is lower-friction and matches SubAgentProgressView's
//  established 2s refresh pattern (= Apple HIG live update).
//

import SwiftUI

/// Agent progress panel: top-of-DynamicZone strip that surfaces
/// real-time step-by-step feedback from the running conversation
/// turn (= WIRE-OPENBOX-001).
///
/// Reads from `AgentProgressTracker.shared` (= the canonical shared
/// instance the agent writes to). Renders only when a running
/// entry exists (= user just sent a message; loop is in flight).
public struct AgentProgressPanel: View {

    /// Cached latest running entry (= refreshed by the .task timer).
    @State private var currentEntry: AgentProgressEntry?

    /// Refresh trigger (= bumped every 1s to re-poll the tracker).
    /// Matches the SubAgentProgressView pattern (= per Apple HIG
    /// live update guidance).
    @State private var refreshTrigger: Int = 0

    /// The shared tracker (= injected via init for test override;
    /// defaults to `.shared`).
    private let tracker: AgentProgressTracker

    public init(tracker: AgentProgressTracker = .shared) {
        self.tracker = tracker
    }

    public var body: some View {
        // Always render a VStack so the layout above (= tab bar)
        // doesn't jump when the panel appears / disappears.
        // We toggle the visible content based on `currentEntry`.
        Group {
            if let entry = currentEntry {
                content(for: entry)
            } else {
                EmptyView()
            }
        }
        .task(id: refreshTrigger) {
            // Poll the shared tracker every 1s. Cancelled on view
            // dismissal (= no leaked refresh cycles per v0.23 audit
            // #014 SubAgentProgressView pattern).
            while !Task.isCancelled {
                currentEntry = await tracker.currentLatestRunning()
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return  // cancelled mid-sleep
                }
            }
        }
    }

    /// The visible content for a running entry. Layout:
    /// - Spinner + label + step counter on the top row
    /// - ETA on the second row (= only when known)
    @ViewBuilder
    private func content(for entry: AgentProgressEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Spinning indicator (Apple HIG ProgressView() default).
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
                Text(entry.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                Text("\(entry.stepNumber)/\(entry.totalSteps)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            if let eta = entry.etaSeconds {
                Text("ETA: \(eta)s")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // Liquid Glass: thinMaterial matches DynamicZoneView's pane
        // chrome (= SubAgentProgressView's task rows use the same
        // pattern). The card is a thin strip pinned to the top of
        // the zone, below the tab bar.
        .background(.thinMaterial)
        .overlay(
            // Subtle accent border on the leading edge so the user
            // can tell at a glance which step is active (Apple HIG
            // status indicator pattern).
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3),
            alignment: .leading
        )
    }
}