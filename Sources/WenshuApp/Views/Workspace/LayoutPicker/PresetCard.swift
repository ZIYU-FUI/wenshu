// PresetCard.swift · Wenshu (文枢) · v0.28 ticket 028-007
//
// Single preset thumbnail card (= hermes `layout-picker.tsx:62-109`
// port). Shows a 4:3 mini-render of the split tree (= via
// PresetThumbnail), the preset name, and a delete (×) button for
// user presets (= built-ins have no delete button per spec
// §"Acceptance criteria" #12).
//
import SwiftUI

/// PresetCard — a single preset's tile in the LayoutPicker grid.
struct PresetCard: View {
    let preset: LayoutPreset
    let isActive: Bool
    let onSelect: () -> Void
    /// Delete callback; nil for built-in presets (= spec #12 =
    /// built-ins have no delete button).
    let onDelete: (() -> Void)?

    /// Whether the delete button should show (= triggered on
    /// hover; v0.28 first cut uses @State for simplicity).
    @State private var isHovering: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail (= 4:3 aspect ratio).
            PresetThumbnail(workspace: preset.workspace)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                // v0.28 followup Boss UX round 19 (Boss 2026-08-29 OOB
                // '所有区域的顶栏, 底栏, 背景, 用的颜色, 可以适配液
                // 态玻璃吗'): preset card thumbnail background =
                // .ultraThinMaterial (= the lightest Liquid Glass
                // material = subtle tint without overwhelming the
                // thumbnail preview). Per Apple HIG (= macOS 26 Tahoe
                // preset card pattern in Finder preview pane), use the
                // thinnest material so the thumbnail content stays
                // dominant.
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isActive
                            ? Color.accentColor
                            : Color(nsColor: .separatorColor),
                            lineWidth: isActive ? 2 : 1
                        )
                )
            // Title.
            Text(preset.name)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .lineLimit(1)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(alignment: .topTrailing) {
            // Delete button (= only for user presets, only on
            // hover). Uses the wenshu v0.27 toolbar capsule pattern
            // (= 28x28 hot area + SF Symbol xmark icon + contentShape).
            if let onDelete = onDelete {
                if isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(2)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}