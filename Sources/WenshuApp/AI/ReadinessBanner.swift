// ReadinessBanner.swift · Wenshu (文枢) · v0.34
//
// v0.34 boss 2026-09-02 OOB: user-facing readiness banner (= Apple
// canonical ContentUnavailableView for macOS 14+; rendered when
// WenshuReadinessCheck surfaces any critical or warning issue).
//
// 3 visual states (= boss 8/25 UI rule):
// - .critical: red tint + SF Symbol "exclamationmark.triangle.fill"
// - .warning:  yellow tint + SF Symbol "exclamationmark.circle"
// - .info:    blue tint + SF Symbol "info.circle"
//
// Banner is hidden when readinessReport is nil OR empty (= all
// capabilities ready; user does not see anything).
//
// Apple-API-first check: SwiftUI native `ContentUnavailableView`
// (= macOS 14+; = Apple canonical empty/error state view = no
// custom drawing). No third-party dependency needed.

import SwiftUI

/// Top-banner view rendered inside the WindowGroup's
/// `.safeAreaInset(edge: .top)` slot. Shows the highest-severity
/// readiness issue + a button that opens the Settings scene.
struct ReadinessBanner: View {
    let report: ReadinessReport
    let openSettings: OpenSettingsAction?

    /// Highest-severity issue (= first in the report's severity-sorted
    /// array; nil only if the report is fully ready).
    private var topIssue: ReadinessIssue? {
        report.issues.first
    }

    var body: some View {
        if let issue = topIssue {
            // Apple canonical ContentUnavailableView (= macOS 14+).
            // Icon = SF Symbol per severity; title = capability + issue
            // message; description = "+N more issues" if applicable;
            // actions = "open Settings" button when the report has
            // an actionLabel.
            ContentUnavailableView {
                Label {
                    Text("\(issue.capability.displayName): \(issue.message)")
                } icon: {
                    Image(systemName: iconName(issue.severity))
                        .foregroundStyle(foregroundAccent(issue.severity))
                }
            } description: {
                if report.issues.count > 1 {
                    Text("另有 \(report.issues.count - 1) 项问题")
                }
            } actions: {
                if let actionLabel = issue.actionLabel {
                    Button(actionLabel) {
                        openSettings?()
                    }
                    .buttonStyle(.bordered)
                    .tint(foregroundAccent(issue.severity))
                }
            }
            // Tint the banner background per severity (= subtle
            // background wash; ContentUnavailableView on macOS
            // 14+ auto-positions inside its safe area).
            .background(backgroundTint(issue.severity))
        } else {
            // Should never render (= banner is hidden when
            // report is ready); defensive return = empty spacer.
            Color.clear.frame(height: 0)
        }
    }

    /// SF Symbol name per severity (= Apple HIG iconography).
    private func iconName(_ severity: ReadinessSeverity) -> String {
        switch severity {
        case .critical: return "exclamationmark.triangle.fill"
        case .warning:  return "exclamationmark.circle.fill"
        case .info:     return "info.circle.fill"
        }
    }

    /// Background tint per severity (= Apple HIG semantics: red =
    /// critical, yellow = warning, blue = info).
    private func backgroundTint(_ severity: ReadinessSeverity) -> Color {
        switch severity {
        case .critical: return Color.red.opacity(0.15)
        case .warning:  return Color.orange.opacity(0.15)
        case .info:     return Color.blue.opacity(0.15)
        }
    }

    /// Foreground accent (= border / icon tint) per severity.
    private func foregroundAccent(_ severity: ReadinessSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning:  return .orange
        case .info:     return .blue
        }
    }
}