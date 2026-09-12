// LayoutEditBar.swift · Wenshu () · v0.28 ticket 028-007
//
// Floating TreeEditBar that appears when layout edit mode is on
// (= hermes `edit-bar.tsx:25-108` port). Hosts the LayoutPicker
// inside (= PresetCard grid + new-grid button + save-current
// button). Header doubles as drag handle; the user can move the
// palette around the screen with `.gesture(DragGesture())`.
//
// The bar is overlaid on the WorkspaceView (via `.overlay`) and
// shows only when `LayoutEditMode.isEnabled == true`.
//
// Per ticket 028-007 §"Out of scope": the ZoneEditor full-screen
// grid (= 028-008) and animated transitions between presets are
// future work. This ticket ships the palette UI + preset selection
// + save-current-as-preset.
//
import SwiftUI

/// LayoutEditBar — the floating palette container. Shows the
/// LayoutPicker inside (= 4 builtin preset cards + a "+ gridlayout"
/// dashed button + a save-current-as-preset button at the bottom).
///
/// Per ticket 028-007 §"Acceptance criteria": the bar is 26rem wide,
/// centered, has a draggable header, and shows the "reset" (ghost)
/// + "complete" (outline) buttons in the header.
///
/// Position state is per-session @State (= hermes `lastPalettePos`
/// pattern); first show resets to center.
struct LayoutEditBar: View {
    @ObservedObject var store: LayoutTreeStore
    @Bindable var editMode: LayoutEditMode

    /// Palette position (= per-session @State). Persists within a
    /// session; resets to center on first show.
    @State private var palettePosition: CGPoint = .zero

    /// Whether the palette has been positioned yet (= false = use
    /// center as default; true = use the persisted offset).
    @State private var hasPositioned: Bool = false

    /// Drag offset accumulator (= same pattern as NativeSplitter's
    /// per-step delta).
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            header
            LayoutPicker(
                store: store,
                currentPresetID: store.currentPresetID,
                onSelectPreset: { preset in
                    store.loadPreset(preset)
                }
            )
        }
        .frame(width: 26 * 16)  // 26rem (= 26 * 16 PT in macOS 1x)
        // v0.28 followup Boss UX round 19 (Boss 2026-08-29 OOB '
        // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
        // regiontop bar, bottom bar, background, color, canLiquid Glass'):
        // v0.40 boss real-device test 2026-09-07: removed
        // .regularMaterial (= the Liquid Glass translucent
        // capsule); now uses Color.clear (= no background =
        // shows the underlying zone chrome).
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.clear)
        )
        .overlay(
            // v0.28 followup Boss UX round 19: 1 PT Apple .separator stroke
            // (= canonical Liquid Glass separator, macOS 26 Tahoe)
            // replaces Color(nsColor: .separatorColor) (= solid NSColor).
            // v0.28 followup Boss UX round 26: confirm .separator style
            // (= matches all other 1 PT splitters across the app).
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        .offset(x: palettePosition.x + dragOffset.width, y: palettePosition.y + dragOffset.height)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    // Commit the final position (= single @State
                    // write; no per-frame persistence).
                    palettePosition.x += value.translation.width
                    palettePosition.y += value.translation.height
                    dragOffset = .zero
                    hasPositioned = true
                }
        )
        .onAppear {
            if !hasPositioned {
                // First show: center the palette. SwiftUI can't
                // easily compute the center without a GeometryReader
                // here (= the offset coordinate space is the parent
                // overlay's center); we leave it at zero (= centered
                // by default in an .overlay). The user can drag it
                // anywhere.
                hasPositioned = true
            }
        }
    }

    /// Header (= drag handle + title + reset/done buttons).
    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(WenshuI18n.t("auto.layouteditbar.l112.h90106758"))
                    .font(.body.weight(.semibold))
                HStack(spacing: 4) {
                    Text(WenshuI18n.t("layout_edit_bar.empty_hint"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(HotkeyFormatter.editModeCombo)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.chromePaddingMicro)
                        .padding(.vertical, DesignTokens.chromePaddingHotkeyVertical)
                        // v0.32 boss 2026-09-02 OOB (' apple api
                        // default'): use bare Apple Material catalog
                        // directly (= the canonical SwiftUI .thin
                        // Material from the Material enum). The
                        // previous RegionHoverWashStyle wrapper
                        // added an extra type with no semantic value.
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.clear)
                        )
                }
            }
            Spacer()
            Button(WenshuI18n.t("auto2.layouteditbar.l136.h66133888")) {
                store.resetToDefault()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            Button(WenshuI18n.t("auto2.layouteditbar.l141.h65113621")) {
                editMode.set(false)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, DesignTokens.chromePaddingMedium)
        .padding(.vertical, DesignTokens.chromePaddingVertical)
        // v0.40 boss real-device test 2026-09-07: removed
        // .regularMaterial (= Liquid Glass background); now uses
        // Color.clear (= no background).
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.clear)
        )
        // The header is the drag handle; the rest of the palette
        // (= LayoutPicker) is non-draggable.
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    // Forward the global-space translation to the
                    // outer DragGesture's per-step path.
                    dragOffset = CGSize(
                        width: value.translation.width - (palettePosition.x == 0 && !hasPositioned ? 0 : 0),
                        height: value.translation.height
                    )
                }
                .onEnded { value in
                    palettePosition.x += value.translation.width
                    palettePosition.y += value.translation.height
                    dragOffset = .zero
                    hasPositioned = true
                }
        )
    }
}