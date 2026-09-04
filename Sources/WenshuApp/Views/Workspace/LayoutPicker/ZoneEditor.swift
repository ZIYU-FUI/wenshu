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

    // AC#9: rubber-band drag state (= rectangle in canvas coordinates
    // that the user is dragging to select a region).
    @State private var dragStart: CGPoint? = nil
    @State private var dragEnd: CGPoint? = nil
    @State private var selectedZones: Set<Int> = []

    // AC#11: edge drag state (= which resizer is being dragged).
    @State private var draggingResizerIndex: Int? = nil
    @State private var resizerDragStart: CGPoint? = nil

    // Track the event modifiers flag (= SHIFT held during click for AC#8 SHIFT-flip).
    @State private var eventModifiers: EventModifiers = []

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
            // AC#10: Merge button (= visible iff >= 2 zones selected).
            Button("Merge (\(selectedZones.count))") {
                mergeSelectedZones()
            }
            .buttonStyle(.bordered)
            .disabled(!hasMultiSelection)
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

    /// Grid canvas (= translucent numbered zones + rubber-band overlay +
/// edge-resizer handles).
    private var gridCanvas: some View {
        GeometryReader { geo in
            ZStack {
                // Background.
                Rectangle().fill(.quaternary)
                // Zones.
                ForEach(modelToZones(model) ?? []) { zone in
                    zoneView(for: zone, in: geo.size)
                }
                // AC#11: edge resizer handles (= invisible hit-area rects
                // along shared boundaries that the user can drag).
                ForEach(Array(modelToResizers(model).enumerated()), id: \.offset) { idx, resizer in
                    resizerHandleView(for: resizer, index: idx, in: geo.size)
                }
                // AC#9: rubber-band drag rectangle.
                if let start = dragStart, let end = dragEnd {
                    rubberBandView(from: start, to: end)
                }
                // AC#9: capture the drag gesture at the canvas level.
                // (individual zones still receive their own .onTapGesture.)
                canvasGestureLayer(in: geo.size)
            }
        }
    }

    /// Canvas-level gesture layer for AC#9 rubber-band + AC#10 selection
    /// clearing. The drag gesture starts the rubber-band; the tap clears
    /// the selection (= per hermes pattern: tap on canvas deselects all).
    @ViewBuilder
    private func canvasGestureLayer(in size: CGSize) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                selectedZones.removeAll()
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        dragStart = value.startLocation
                        dragEnd = value.location
                        // Update selection (= zones intersecting the rubber-band).
                        let band = rubberBandRect(start: value.startLocation, end: value.location)
                        selectedZones = Set((modelToZones(model) ?? [])
                            .filter { zone in
                                let z = zoneRect(zone: zone, in: size)
                                return z.intersects(band)
                            }
                            .map { $0.index })
                    }
                    .onEnded { _ in
                        dragStart = nil
                        dragEnd = nil
                    }
            )
    }

    /// Compute the rubber-band rectangle (= normalized to top-left +
    /// width + height regardless of drag direction).
    private func rubberBandRect(start: CGPoint, end: CGPoint) -> CGRect {
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let w = abs(end.x - start.x)
        let h = abs(end.y - start.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Render the rubber-band selection rectangle (= blue dashed border).
    @ViewBuilder
    private func rubberBandView(from start: CGPoint, to end: CGPoint) -> some View {
        let rect = rubberBandRect(start: start, end: end)
        Rectangle()
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4]))
            .background(.quaternary)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    /// AC#11: render an edge resizer handle (= invisible hit area along
    /// the boundary, with a thin visible line for affordance).
    @ViewBuilder
    private func resizerHandleView(for resizer: GridResizer, index: Int, in size: CGSize) -> some View {
        // Compute the screen-space edge.
        let edgeRect = resizerRect(for: resizer, in: size)
        ZStack {
            // Visible thin line (= 2pt wide for vertical, 2pt tall for horizontal).
            Rectangle()
                .fill(.tint.opacity(0.4))
                .frame(
                    width: resizer.orientation == .vertical ? 2 : edgeRect.width,
                    height: resizer.orientation == .horizontal ? 2 : edgeRect.height
                )
                .position(x: edgeRect.midX, y: edgeRect.midY)
            // Invisible larger hit area for dragging (= 16pt).
            Rectangle()
                .fill(Color.clear)
                .frame(
                    width: resizer.orientation == .vertical ? 16 : edgeRect.width,
                    height: resizer.orientation == .horizontal ? 16 : edgeRect.height
                )
                .contentShape(Rectangle())
                .position(x: edgeRect.midX, y: edgeRect.midY)
                .onHover { hovering in
                    if hovering {
                        if resizer.orientation == .vertical {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.resizeUpDown.push()
                        }
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if draggingResizerIndex == nil {
                                draggingResizerIndex = index
                                resizerDragStart = value.startLocation
                            }
                            // Apply the delta to the model.
                            let start = resizerDragStart ?? value.startLocation
                            let delta: Int
                            if resizer.orientation == .vertical {
                                delta = Int((value.location.x - start.x) / size.width * CGFloat(MULTIPLIER))
                            } else {
                                delta = Int((value.location.y - start.y) / size.height * CGFloat(MULTIPLIER))
                            }
                            if delta != 0 {
                                model = dragResizer(model, resizerIndex: index, delta: delta)
                                resizerDragStart = value.location
                            }
                        }
                        .onEnded { _ in
                            draggingResizerIndex = nil
                            resizerDragStart = nil
                            NSCursor.pop()
                        }
                )
        }
    }

    /// Compute the screen-space edge rectangle for a resizer.
    private func resizerRect(for resizer: GridResizer, in size: CGSize) -> CGRect {
        // For vertical resizer: edge runs between the leftmost negative-side
        // column's right boundary and the rightmost positive-side column's left
        // boundary. For horizontal: analogous but in the y direction.
        if resizer.orientation == .vertical {
            // Sum columnPercents up to the leftmost negative-side column.
            let colPercents = model.columnPercents
            let left = colPercents.prefix(resizer.negativeSideIndices.first ?? 0).reduce(0, +)
            let x = CGFloat(left) / CGFloat(MULTIPLIER) * size.width
            let h = size.height
            return CGRect(x: x - 8, y: 0, width: 16, height: h)
        } else {
            // Horizontal resizer = between rows.
            let rowPercents = model.rowPercents
            let top = rowPercents.prefix(resizer.negativeSideIndices.first ?? 0).reduce(0, +)
            let y = CGFloat(top) / CGFloat(MULTIPLIER) * size.height
            let w = size.width
            return CGRect(x: 0, y: y - 8, width: w, height: 16)
        }
    }

    /// Whether the current selection has >= 2 zones (= AC#10 Merge button enabled).
    private var hasMultiSelection: Bool {
        selectedZones.count >= 2
    }

    /// AC#10: merge the currently-selected zones into one.
    private func mergeSelectedZones() {
        guard selectedZones.count >= 2 else { return }
        let indices = Array(selectedZones).sorted()
        model = mergeClosureIndices(model, indices: indices)
        selectedZones.removeAll()
    }

    /// Single zone view (= translucent gray rectangle with
    /// centered number label + click-to-split gesture).
    @ViewBuilder
    private func zoneView(for zone: GridZone, in size: CGSize) -> some View {
        let frame = zoneRect(zone: zone, in: size)
        ZStack {
            Rectangle().fill(.tint.opacity(0.15))
            Text("\(zone.index + 1)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
        .overlay(
            Rectangle()
                .stroke(.tint.opacity(0.4), lineWidth: 1)
        )
        // AC#8 click-to-split: click on a zone selects it for split,
        // holding SHIFT flips the orientation (= insert horizontal
        // split instead of the default vertical split). Mirrors hermes
        // `zone-editor.tsx` onZoneClick with event.shiftKey check.
        .onTapGesture {
            // Find which axis the zone occupies and split perpendicular.
            let zoneHeight = zone.bottom - zone.top
            let zoneWidth = zone.right - zone.left
            let splitHorizontally = eventModifiers.contains(.shift)
                ? zoneHeight > zoneWidth  // SHIFT-flip: split perpendicular
                : zoneHeight < zoneWidth
            if splitHorizontally {
                // Split at the zone's vertical midpoint.
                let midY = (zone.top + zone.bottom) / 2
                model = splitAtRow(model, atPercent: midY)
            } else {
                // Default vertical split at the zone's horizontal midpoint.
                let midX = (zone.left + zone.right) / 2
                model = splitAtColumnAt(model, atPercent: midX)
            }
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
                        LucideIconSystemFallback("plus", size: 14)
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