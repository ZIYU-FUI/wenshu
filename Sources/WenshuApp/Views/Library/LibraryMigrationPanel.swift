//
//  Views/Library/LibraryMigrationPanel.swift
//
//  macOS-system-upgrade-style migration panel for the .ws library
//  SwiftData upgrade arc (= boss OOB on 2026-10-06: 'visible progress
//  panel like macOS system updates, not silent background work').
//
//  Layout (= modeled on macOS system upgrade window):
//
//      +----------------------------------------------+
//      |  [icon]  文枢库升级                       X |
//      |  V1 → V2                                  |
//      |  ---------------------------------------- |
//      |  (1) 准备数据   ✓ done                     |
//      |  (2) 执行升级   ⟳ active  (spinner + text) |
//      |  (3) 完成确认   … pending                  |
//      |  ---------------------------------------- |
//      |  [============ progress ===========>    ] |
//      |  预计还需 12 秒                              |
//      |  ---------------------------------------- |
//      |  失败态: 红字 + 备份路径 + [重试] [退出]    |
//      +----------------------------------------------+
//
//  State source: LibraryMigrationState (= @MainActor @Observable
//  from the previous ticket; = the panel is purely a render of that
//  state machine). The panel does not own the migration flow; =
//  LibraryMigrationPanel just translates the state into the user-
//  facing layout.
//
//  Retry semantics (= boss OOB on 2026-10-06 'match Apple system
//  upgrade'): auto-retry up to 3 times. After 3 failed attempts the
//  retry button disappears and only [退出] remains. The panel calls
//  onRetry (= closure passed in by the wire-up layer in 005) which
//  triggers the migrator to re-attempt; = onExit closes the app.
//
//  Apple HIG compliance:
//  - icon: SFIcon central factory (no naked Image(systemName:)).
//  - spacing: DesignTokens.spacing*.
//  - color: hierarchical foregroundStyle (no naked Color.X.opacity).
//  - font: SwiftUI built-in (.title2 / .headline / .callout / .caption).
//  - window: windowResizability(.contentSize) (= same as
//    ManifestWindow and other independent windows).
//  - retry / exit: standard SwiftUI Button + .keyboardShortcut
//    shortcuts (= R for retry, Esc for exit). Stage rows update via
//    Apple's default animation (= no custom easing).

import SwiftUI

@MainActor
struct LibraryMigrationPanel: View {

    @Bindable var state: LibraryMigrationState
    /// Invoked when the user presses 重试. The wire-up layer (= 005
    /// ticket) restarts the migration from .preparing. Required
    /// because the panel itself is pure UI; = it does not own the
    /// SwiftData ModelContainer init.
    let onRetry: () -> Void
    /// Invoked when the user presses 退出. The wire-up layer calls
    /// NSApp.terminate(nil) (= same path as Cmd-Q).
    let onExit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLoose) {
            header
            versionLabel
            Divider()
            stagesList
            progressBlock
            if state.stage == .failed {
                Divider()
                failureBlock
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(DesignTokens.spacingHero)
        .frame(
            minWidth: DesignTokens.onboardingWelcomeMaxWidth,
            idealWidth: DesignTokens.onboardingWelcomeMaxWidth,
            minHeight: 320,
            idealHeight: 320
        )
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            SFIcon("arrow.up.circle", style: .nav, color: IconColor.accent)
            Text(String(localized: "library.migration.title"))
                .font(.title2)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    private var versionLabel: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            SFIcon("tag", style: .inlineSmall, color: IconColor.secondary)
            Text("V1")
                .font(.callout)
                .foregroundStyle(.secondary)
            SFIcon("arrow.right", style: .inlineSmall, color: IconColor.tertiary)
            Text("V2")
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    private var stagesList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            stageRow(
                index: 1,
                label: String(localized: "library.migration.stage.preparing"),
                icon: "doc.on.doc",
                state: stateForStage(.preparing)
            )
            stageRow(
                index: 2,
                label: String(localized: "library.migration.stage.executing"),
                icon: "arrow.triangle.2.circlepath",
                state: stateForStage(.executing)
            )
            stageRow(
                index: 3,
                label: String(localized: "library.migration.stage.finalizing"),
                icon: "checkmark.seal",
                state: stateForStage(.finalizing)
            )
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingCaption) {
            ProgressView(value: state.progress, total: 1.0)
                .progressViewStyle(.linear)
                .animation(.default, value: state.progress)
            HStack {
                Text(estimateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private var failureBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
            HStack(spacing: DesignTokens.spacingStandard) {
                SFIcon("exclamationmark.triangle.fill", style: .paneTab, color: IconColor.red)
                Text(String(localized: "library.migration.failure.title"))
                    .font(.headline)
                    .foregroundStyle(.red)
            }
            Text(state.lastError)
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
            if let backupPath = state.backupPath {
                HStack(spacing: DesignTokens.spacingCaption) {
                    SFIcon("externaldrive.badge.checkmark", style: .inlineSmall, color: IconColor.secondary)
                    Text(backupPath.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            Spacer(minLength: 0)
            if state.stage == .failed {
                if state.retryCount < 3 {
                    Button(String(localized: "library.migration.retry")) {
                        state.resetForRetry()
                        onRetry()
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    .controlSize(.large)
                }
                Button(String(localized: "library.migration.exit")) {
                    onExit()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Helpers

    private enum RowState { case pending, active, done }

    private func stateForStage(_ target: LibraryMigrationState.Stage) -> RowState {
        switch state.stage {
        case .idle:
            return .pending
        case .preparing:
            return target == .preparing ? .active : .pending
        case .executing:
            switch target {
            case .preparing: return .done
            case .executing: return .active
            case .finalizing: return .pending
            case .idle, .completed, .failed: return .pending
            }
        case .finalizing:
            return target == .finalizing ? .active : .done
        case .completed:
            return .done
        case .failed:
            return .pending
        }
    }

    @ViewBuilder
    private func stageRow(index: Int, label: String, icon: String, state rowState: RowState) -> some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            ZStack {
                switch rowState {
                case .pending:
                    SFIcon("circle", style: .paneTab, color: IconColor.tertiary)
                case .active:
                    ProgressView()
                        .controlSize(.small)
                case .done:
                    SFIcon("checkmark.circle.fill", style: .paneTab, color: IconColor.green)
                }
            }
            .frame(width: 24)
            SFIcon(icon, style: .inlineSmall, color: IconColor.secondary)
            Text(label)
                .font(.callout)
                .foregroundStyle(rowState == .pending ? .secondary : .primary)
            Spacer(minLength: 0)
        }
    }

    private var estimateLabel: String {
        switch state.stage {
        case .completed:
            return String(localized: "library.migration.estimate.done")
        case .failed:
            return String(localized: "library.migration.estimate.failed")
        case .idle:
            return String(localized: "library.migration.estimate.idle")
        default:
            if state.estimatedSecondsRemaining >= 0 {
                return String(
                    localized: "library.migration.estimate.active.with_seconds"
                ).replacingOccurrences(
                    of: "{seconds}",
                    with: "\(state.estimatedSecondsRemaining)"
                )
            }
            return String(localized: "library.migration.estimate.active.pending")
        }
    }
}
