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
            // Preset card grid (= 4 columns × N rows depending on
            // the active preset list).
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.presets) { preset in
                    PresetCard(
                        preset: preset,
                        isActive: preset.id == currentPresetID,
                        onSelect: {
                            onSelectPreset(preset)
                        },
                        onDelete: preset.isBuiltIn ? nil : {
                            store.deletePreset(preset)
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // "+ 新建网格布局" dashed button (= ticket 028-008
            // will wire this into ZoneEditor; for now the button
            // shows a hint tooltip).
            Button(action: {
                showingNewGridHint.toggle()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                    Text("新建网格布局")
                        .font(.system(size: 11))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .help(showingNewGridHint
                  ? "028-008 ZoneEditor feature ticket lands in the v0.28 free-layout chain"
                  : "新建网格布局 (= per-ticket-028-008 ZoneEditor overlay)")
            if showingNewGridHint {
                Text("028-008 ZoneEditor 落地后会接入 (= FancyZones-style overlay drag-to-merge)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }

            Divider().padding(.horizontal, 12)

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
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 11))
                        Text("将当前排列保存为模板")
                            .font(.system(size: 11))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 26 * 16)
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
            .padding(.horizontal, 12)
            Text("保存后会出现在上面的预设网格中")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
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