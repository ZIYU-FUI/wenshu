// LayoutPicker.swift · Wenshu (文枢) · v0.28 ticket 028-007
//
// Inner picker UI (= hermes `layout-picker.tsx:111-203` port). Shows
// the 4 builtin preset cards in a 4-column grid (= or however many
// the active preset list contains, including user-saved presets).
// Below the grid is a "+ 新建网格布局" dashed button and a
// "将当前排列保存为模板" reveal-to-input button at the bottom.
// Active preset card has an accent border + active background
// fill. Custom (non-built-in) preset cards show a delete (×)
// button on hover; built-in presets have no delete button.
//
import SwiftUI

/// LayoutPicker — the inner UI of the floating palette (= shown
/// inside LayoutEditBar). Displays the 4 builtin presets + any
/// user-saved presets as thumbnail cards in a grid.
///
/// Per ticket 028-007 §"Acceptance criteria" #1: lives in
/// `Sources/WenshuApp/Views/Workspace/LayoutPicker/` alongside
/// `LayoutEditBar`, `PresetCard`, `PresetThumbnail`, and
/// `SaveCurrentLayoutButton`.
struct LayoutPicker: View {
    @ObservedObject var store: WorkspaceStore
    /// The currently-active preset's ID (= for the accent-border
    /// highlighting per spec §"Acceptance criteria" #10).
    let currentPresetID: UUID?
    /// Callback when the user selects a preset card (= dispatched
    /// from LayoutEditBar; the bar holds the @State for the save-
    /// current-as-preset input reveal so the picker can stay pure).
    var onSelectPreset: (LayoutPreset) -> Void

    /// Local state for the "+ 新建网格布局" button (= the future
    /// ticket 028-008 will wire this into the ZoneEditor).
    @State private var showingNewGridHint: Bool = false

    /// Local state for opening the ZoneEditor sheet (= v0.28
    /// ticket 028-008c integration).
    @State private var showingZoneEditor: Bool = false

    /// Local state for the pending delete confirmation (= v0.28
    /// ticket 028-009: deleting a user-saved preset requires a
    /// .confirmationDialog before the destructive action).
    @State private var pendingDeletePreset: LayoutPreset? = nil

    /// Local state for the save-current-as-preset input reveal.
    @State private var showingSaveInput: Bool = false
    @State private var newPresetName: String = ""

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Built-in templates section (= 4 builtin presets = the
            // hermes `layout-picker.tsx:117-118` filter).
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.presets.filter { $0.isBuiltIn }) { preset in
                    PresetCard(
                        preset: preset,
                        isActive: preset.id == currentPresetID,
                        onSelect: {
                            onSelectPreset(preset)
                        },
                        onDelete: nil  // built-ins have no delete button
                    )
                }
            }
            .padding(.horizontal, DesignTokens.chromePaddingMedium)
            .padding(.top, DesignTokens.chromePaddingMedium)

            // Custom presets section (= user-saved = NOT built-in;
            // hidden if empty per spec §"Acceptance criteria" #4).
            let customPresets = store.presets.filter { !$0.isBuiltIn }
            if !customPresets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("自定义")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.chromePaddingMedium)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(customPresets) { preset in
                            PresetCard(
                                preset: preset,
                                isActive: preset.id == currentPresetID,
                                onSelect: {
                                    onSelectPreset(preset)
                                },
                                onDelete: {
                                    pendingDeletePreset = preset
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DesignTokens.chromePaddingMedium)
                }
            }

            // "+ 新建网格布局" button (= v0.28 ticket 028-008c
            // integration: opens the ZoneEditor sheet on tap).
            Button(action: {
                showingZoneEditor = true
            }) {
                HStack(spacing: 6) {
                    LucideIconSystemFallback("plus", size: 12)
                    Text("新建网格布局")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.chromePaddingVertical)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.tertiary)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignTokens.chromePaddingMedium)
            .sheet(isPresented: $showingZoneEditor) {
                ZoneEditor(store: store)
            }

            Divider().padding(.horizontal, DesignTokens.chromePaddingMedium)

            // Save-current-as-preset input reveal (= the button
            // shows initially; on click it expands into a text
            // field + save / cancel buttons).
            if showingSaveInput {
                saveCurrentLayoutInput
            } else {
                Button(action: {
                    withAnimation {
                        showingSaveInput = true
                    }
                }) {
                    HStack(spacing: 6) {
                        LucideIconSystemFallback("square.and.arrow.down", size: 12)
                        Text("将当前排列保存为模板")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.chromePaddingVertical)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.quaternary)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignTokens.chromePaddingMedium)
                .padding(.bottom, DesignTokens.chromePaddingMedium)
            }
        }
        .frame(width: 26 * 16)
        // v0.28 ticket 028-009: confirmation dialog for deleting
        // a user-saved preset (= .confirmationDialog with
        // presenting: the preset; macOS-standard destructive /
        // cancel role buttons). Lives at the body level so it's
        // not nested inside the conditional view that contains
        // the preset grid (= SwiftUI ViewModifier inference
        // needs the dialog to be at the same level as the
        // .sheet it pairs with).
        .confirmationDialog(
            "删除 \u{201c}\(pendingDeletePreset?.name ?? "")\u{201d}?",
            isPresented: Binding(
                get: { pendingDeletePreset != nil },
                set: { if !$0 { pendingDeletePreset = nil } }
            ),
            presenting: pendingDeletePreset
        ) { preset in
            Button("删除", role: .destructive) {
                store.deletePreset(preset)
                pendingDeletePreset = nil
            }
            Button("取消", role: .cancel) {
                pendingDeletePreset = nil
            }
        } message: { preset in
            Text("删除后无法撤销。模板 \"\(preset.name)\" 会从所有设备上移除。")
        }
    }

    /// Reveal-state input for "save current layout as preset".
    private var saveCurrentLayoutInput: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField("模板名称", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .onSubmit { commitSave() }
                Button("保存") {
                    commitSave()
                }
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
                Button("取消") {
                    withAnimation {
                        showingSaveInput = false
                        newPresetName = ""
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, DesignTokens.chromePaddingMedium)
            Text("保存后会出现在上面的预设网格中")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignTokens.chromePaddingMedium)
                .padding(.bottom, DesignTokens.chromePaddingMedium)
        }
    }

    private func commitSave() {
        let trimmed = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        _ = store.saveAsPreset(name: trimmed)
        withAnimation {
            showingSaveInput = false
            newPresetName = ""
        }
    }
}