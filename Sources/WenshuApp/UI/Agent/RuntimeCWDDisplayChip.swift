//
//  RuntimeCWDDisplayChip.swift · Wenshu
//
//  UI chip for displaying the current runtime CWD in the editor
//  zone toolbar (= wire RuntimeCWD to UI).
//
//  Shows:
//  - "Library: /path/to/library.ws" (default = library path)
//  - "Override: /tmp/work" (when override is set)
//  - "Unset" (when neither is configured)
//
// Per ADR-0008 + iron rule 6: no magic numbers; uses DesignTokens for
// padding + corner radius.
//

import SwiftUI

/// Display chip showing the current runtime CWD (= for editor zone toolbar).
///
/// Reads the RuntimeCWD actor on appear + refreshes every time the
/// override changes (= via RuntimeCWD.didChangeCWD notification).
struct RuntimeCWDDisplayChip: View {
    @State private var displayLabel: String = "CWD: …"
    @State private var lastRefresh: Date = .distantPast

    private let runtimeCWD: RuntimeCWD

    init(runtimeCWD: RuntimeCWD = RuntimeCWD()) {
        self.runtimeCWD = runtimeCWD
    }

    var body: some View {
        HStack(spacing: DesignTokens.spacingIconic) {
            Image(systemName: "folder").imageScale(.small)
                .font(DesignTokens.runtimeCwdChipFont)
                .foregroundStyle(.secondary)
            Text(displayLabel)
                .font(DesignTokens.runtimeCwdChipFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, DesignTokens.spacingTight)
        .padding(.vertical, DesignTokens.badgePaddingVertical)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip)
                // macOS 27 doc-alignment (audit ticket 8):
                // HierarchicalShapeStyle.tertiary (= Apple semantic
                // ShapeStyle; = auto-adapts dark mode + Liquid Glass).
                .fill(.tertiary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip)
                .stroke(.tertiary.opacity(DesignTokens.surfaceInactiveBorderAlpha), lineWidth: DesignTokens.surfaceInactiveBorderWidth)
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

