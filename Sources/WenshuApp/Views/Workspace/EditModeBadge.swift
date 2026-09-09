//
//  EditModeBadge.swift · Wenshu · v0.40 apple-001 Q2 slice 4
//
//  Extracted from WorkspaceView.swift (formerly inline private
// struct at line 2104). Q2 boss split WorkspaceView. Slice 4
//  = the smallest + most self-contained view left after slices 2
//  and 3 (= 33 LOC + 1 @Binding, otherwise stateless).
//
//  Apple HIG = one view per file. EditModeBadge has 1 @Binding
//  (isEnabled: Bool) and otherwise = pure stateless presentation.
//  Already uses DesignTokens.chromePaddingChipHorizontal + .regularMaterial
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
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: DesignTokens.indicatorSizeSmall, height: DesignTokens.indicatorSizeSmall)
                Text(WenshuI18n.t("workspace.layoutEditMode"))
                    .font(.caption.weight(.medium))
                Text(HotkeyFormatter.editModeCombo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignTokens.chromePaddingChipHorizontal)
            .padding(.vertical, DesignTokens.chromePaddingSmall)
            // v0.28 followup Boss UX round 24: .regularMaterial
            // replaces the solid Color.secondary.opacity(0.15) tint
            // for the edit-mode badge background (= the floating
            // badge that shows when ⌘⇧\ edit mode is on).
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.tint.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
