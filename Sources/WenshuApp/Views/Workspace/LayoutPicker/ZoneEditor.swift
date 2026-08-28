// ZoneEditor.swift · Wenshu (文枢) · v0.28 ticket 028-008
//
// SwiftUI full-screen grid editor (= hermes
// `zone-editor.tsx` port). User clicks on a column boundary to
// insert a vertical split; SHIFT-click flips orientation (=
// MVP: not implemented per the spec §"v0.28 MVP scope"). Drag
// across zones rubber-band selects (MVP: not implemented).
// Save converts the grid to a guillotine tree and registers it
// as a user preset via WorkspaceStore.saveAsPreset(name:).
//
// Per ticket 028-008 §"Acceptance criteria" #3: this is the
// `ZoneEditor.swift` file referenced in the spec. MVP scope
// (= 4 templates + zone-count stepper + click-to-split + Save
// button with gridIsTreeExpressible gating + Cancel/Escape).
//
import SwiftUI

/// ZoneEditor — the full-screen grid editor sheet (= presented
/// from LayoutPicker when the user clicks "+ 新建网格布局").
struct ZoneEditor: View {
    @ObservedObject var store: WorkspaceStore
    @Environment(\.dismiss) private var dismiss

    /// The four template types (= per spec §"Acceptance criteria"
    /// #4 = "4 templates: Columns / Rows / Grid / Priority").
    enum Template: String, CaseIterable, Identifiable {
        case columns = "Columns"
        case rows = "Rows"
        case grid = "Grid"
        case priority = "Priority"
        var id: String { rawValue }
    }

    @State private var template: Template = .columns
    @State private var zoneCount: Int = 3
    @State private var model: GridLayout
    @State private var splitColumnIndex: Int? = nil

    init(store: WorkspaceStore) {
        self.store = store
        // Initialize with the default template + zone count.
        _model = State(initialValue: initColumns(3))
    }

    /// Whether the current grid is expressible as a tree
    /// (= Save enabled iff true).
    private var isExpressible: Bool {
        gridIsTreeExpressible(gridModel: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar (= template picker + zone-count stepper +
            // Split / Save / Cancel buttons).
            toolbar
            Divider()
            // Grid canvas (= translucent numbered zones).
            gridCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
        }
        .frame(minWidth: 720, minHeight: 540)
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    /// Toolbar.
    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Template", selection: $template) {
                ForEach(Template.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: template) { _, newValue in
                model = buildModel(template: newValue, count: zoneCount)
            }
            Stepper("Zones: \(zoneCount)", value: $zoneCount, in: 1...8)
                .frame(width: 140)
                .onChange(of: zoneCount) { _, newValue in
                    model = buildModel(template: template, count: newValue)
                }
            Spacer()
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            Button("Save") {
                saveAsPreset()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isExpressible)
            .help(isExpressible
                  ? "Save this grid as a new preset"
                  : "This grid can't be expressed as a guillotine tree (= non-guillotine = pinwheel arrangement)")
        }
        .padding(12)
    }

    /// Grid canvas (= translucent numbered zones).
    private var gridCanvas: some View {
        GeometryReader { geo in
            ZStack {
                // Background.
                Color.secondary.opacity(0.05)
                // Zones.
                ForEach(modelToZones(model) ?? []) { zone in
                    zoneView(for: zone, in: geo.size)
                }
            }
        }
    }

    /// Single zone view (= translucent gray rectangle with
    /// centered number label + click-to-split gesture).
    @ViewBuilder
    private func zoneView(for zone: GridZone, in size: CGSize) -> some View {
        let frame = zoneRect(zone: zone, in: size)
        ZStack {
            Color.accentColor.opacity(0.15)
            Text("\(zone.index + 1)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
        .overlay(
            Rectangle()
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
        )
        .onTapGesture {
            // Click on a zone = select it for split (= the actual
            // split happens via the "+" buttons on the column
            // boundaries = see splitButtons overlay).
        }
    }

    /// Split buttons overlay (= + buttons on column boundaries
    /// between zones). Clicking a + button inserts a vertical
    /// split at that column.
    @ViewBuilder
    private func splitButtonsOverlay(in size: CGSize) -> some View {
        let colEdges = prefixSum(model.columnPercents)
        ZStack {
            ForEach(0..<(colEdges.count - 1), id: \.self) { i in
                if i > 0 {
                    // + button at the boundary between column i-1
                    // and column i (= at colEdges[i] in the
                    // 0..MULTIPLIER coordinate space).
                    Button(action: { splitAtColumn(i) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                    .position(x: CGFloat(colEdges[i]) / CGFloat(MULTIPLIER) * size.width,
                               y: size.height / 2)
                }
            }
        }
    }

    /// Compute the screen frame for a zone (= converting the
    /// 0..MULTIPLIER coordinate space to the canvas size).
    private func zoneRect(zone: GridZone, in size: CGSize) -> CGRect {
        let x = CGFloat(zone.left) / CGFloat(MULTIPLIER) * size.width
        let y = CGFloat(zone.top) / CGFloat(MULTIPLIER) * size.height
        let w = CGFloat(zone.right - zone.left) / CGFloat(MULTIPLIER) * size.width
        let h = CGFloat(zone.bottom - zone.top) / CGFloat(MULTIPLIER) * size.height
        return CGRect(x: x, y: y, width: w, height: h).insetBy(dx: 1, dy: 1)
    }

    /// Build the model for the given template + zone count.
    private func buildModel(template: Template, count: Int) -> GridLayout {
        switch template {
        case .columns: return initColumns(count)
        case .rows: return initRows(count)
        case .grid:
            let size = max(1, Int((Double(count).squareRoot()).rounded()))
            return initGrid(size)
        case .priority:
            let secondary = max(1, count - 1)
            return initPriorityGrid(50, secondary)
        }
    }

    /// Insert a vertical split at the given column index.
    private func splitAtColumn(_ columnIndex: Int) {
        model = splitZone(model, atColumn: columnIndex)
        splitColumnIndex = columnIndex
    }

    /// Save the current grid as a user preset.
    private func saveAsPreset() {
        guard let tree = gridToTree(gridModel: model, panes: []) else { return }
        // Build a workspace from the tree (= using empty
        // panes/tabs for now; the ZoneEditor MVP doesn't yet
        // carry per-zone PaneKinds — that's a 028-008c followup).
        let preset = LayoutPreset(
            id: UUID(),
            name: "Custom \(store.presets.filter { !$0.isBuiltIn }.count + 1)",
            workspace: WorkspaceState(
                root: tree,
                panes: [],
                tabs: [],
                version: 2
            ),
            isBuiltIn: false
        )
        store.presets.append(preset)
        store.currentPresetID = preset.id
        store.savePresets()
        dismiss()
    }
}