//
//  RuntimeCWDDisplayChip.swift · Wenshu · v0.37 Batch 2.4 sub-step 1
//
//  UI chip for displaying the current runtime CWD in the editor zone
//  toolbar (= per v0.37-full-translation-plan.md Batch 2.4 = wire
//  RuntimeCWD to UI).
//
//  Shows:
//  - "Library: /path/to/library.ws" (default = library path)
//  - "Override: /tmp/work" (when override is set)
//  - "Unset" (when neither is configured)
//
//  Per 老板 cadence 2026-09-03 '继续' (= auto-pilot continue per
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
//  v0.37 plan) + 'PO 全链路方法论执行,不要跳步骤' + '翻译这个事做完
//  一起验视觉和前端流程' + '1 RULE 1 commit'.
//
//  Per ADR-0008 + iron rule 6: no magic numbers; uses DesignTokens for
//  padding + corner radius.
//

import SwiftUI

/// Display chip showing the current runtime CWD (= for editor zone toolbar).
///
/// Reads the RuntimeCWD actor on appear + refreshes every time the
/// override changes (= via RuntimeCWD.didChangeCWD notification).
public struct RuntimeCWDDisplayChip: View {
    @State private var displayLabel: String = "CWD: …"
    @State private var lastRefresh: Date = .distantPast

    private let runtimeCWD: RuntimeCWD

    public init(runtimeCWD: RuntimeCWD = RuntimeCWD()) {
        self.runtimeCWD = runtimeCWD
    }

    public var body: some View {
        HStack(spacing: DesignTokens.chromePaddingMicro) {
            Image(systemName: "folder")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(displayLabel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, DesignTokens.chromePaddingSmall)
        .padding(.vertical, DesignTokens.badgePaddingVertical)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip)
                .fill(Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip)
                .stroke(Color.secondary.opacity(0.2), lineWidth: DesignTokens.surfaceInactiveBorderWidth)
        )
        .task {
            await refreshLabel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .runtimeCWDDidChange)) { _ in
            Task { await refreshLabel() }
        }
    }

    private func refreshLabel() async {
        let label = await runtimeCWD.displayLabel()
        await MainActor.run {
            self.displayLabel = label
            self.lastRefresh = Date()
        }
    }
}

