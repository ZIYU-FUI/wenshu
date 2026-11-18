//
//  InspectorStatusElapsedLabel.swift
//  wenshu
//
//  The elapsed time of one status card.
//
//  The tick lives HERE (= in the label that shows a time), = and not
//  on the page: = a page-level tick re-renders every card on the
//  page once a second, = and only a running card's clock moves.
//
//  A finished task's clock stopped at its completion (= so its label
//  is a fixed text, = and it carries no tick at all), = and a task
//  that has not started has no elapsed time to show.
//
//

import SwiftUI

/// The elapsed time on one status card.
///
/// The label is the one subtree of the status page that changes on
/// its own, so the page's other cards (= and the page's own list)
/// are not rebuilt once a second.
struct InspectorStatusElapsedLabel: View {
    /// The task whose elapsed time this label shows.
    let task: InspectorStatusTask

    var body: some View {
        switch task.state {
        case .pending:
            // A task that has not started has no elapsed time to show.
            EmptyView()
        case .running:
            // The running clock (= the one subtree that ticks).
            TimelineView(.periodic(from: .now, by: 1)) { context in
                elapsed(task.elapsedText(at: context.date))
            }
        case .completed, .failed, .timeout:
            // A finished task's clock is frozen at its completion.
            elapsed(task.elapsedText(at: task.completedAt ?? task.startedAt))
        }
    }

    /// The elapsed text (= the house's own format).
    @ViewBuilder
    private func elapsed(_ text: String?) -> some View {
        if let text {
            Text(text)
                .font(.caption.monospacedDigit())
                .foregroundStyle(DesignTokens.statusForeground)
        }
    }
}
