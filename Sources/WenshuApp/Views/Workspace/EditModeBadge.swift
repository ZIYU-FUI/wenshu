// Sources/WenshuApp/Views/Workspace/EditModeBadge.swift
//
// The smallest + most self-contained view left after the
// format-toolbar / paragraph-AI extractions (= 33 LOC +
// 1 `@Binding`, otherwise stateless).
//
// One view per file (Apple HIG). `EditModeBadge` has 1 `@Binding`
// (`isEnabled: Bool`) and otherwise = pure stateless presentation.
//  Already uses DesignTokens.spacingModerate + .regularMaterial
//  (= Apple macOS 27 Liquid Glass canonical pattern per
//  apple-self-check §2 row F). Already uses WenshuI18n.t
//  for the label (= "workspace.layoutEditMode").
//
//  Only call site = WorkspaceView's top-bar layout; invoked
//  as `EditModeBadge(isEnabled: $bindableAppState.editMode.isEnabled)`.
//  Extracting it does not change any caller signature.
//

import SwiftUI

struct EditModeBadge: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Button(action: { isEnabled.toggle() }) {
            HStack(spacing: DesignTokens.spacingTight) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: DesignTokens.indicatorSizeSmall, height: DesignTokens.indicatorSizeSmall)
                Text(WenshuI18n.t("workspace.layoutEditMode"))
                    .font(.caption.weight(.medium))
                Text(HotkeyFormatter.editModeCombo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignTokens.spacingModerate)
            .padding(.vertical, DesignTokens.spacingTight)
            // followup UX round 24: .regularMaterial
            // replaces the solid Color.secondary.opacity(0.15) tint
            // for the edit-mode badge background (= the floating
            // badge that shows when ⌘⇧\ edit mode is on).
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard)
                    .stroke(.tint.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
