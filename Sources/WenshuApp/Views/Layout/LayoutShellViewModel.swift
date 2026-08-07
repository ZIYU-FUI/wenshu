// LayoutShellViewModel.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01
//
// Owns the in-memory `LayoutSnapshot` for the 5-zone shell + bridges it to
// `WenshuStoreActor` for .ws persistence.
//
// Responsibilities:
// 1. On `.load()` (called from `.task` on first appear): read the saved
//    snapshot from disk and apply it (fall back to defaults if missing
//    or malformed).
// 2. On every user mutation (chevron click, splitter drag): update
//    `snapshot` immediately so SwiftUI re-renders, and debounce a write
//    to disk so the drag gesture doesn't slam CoreData on every pixel.
// 3. The reset button rewrites the canonical default to disk so the next
//    cold launch (装机 user 8/7 实机验) still restores to defaults.
//
// Threading: @MainActor — every published mutation originates here, and
// the View layer reads `snapshot` directly in `body`. Persistence is
// awaited on the actor; we don't block the main thread.

import Foundation
import SwiftUI

@MainActor
final class LayoutShellViewModel: ObservableObject {

    /// LT-01-fix3: the macOS menu bar (`App.swift` `.commands`) and the
    /// shell View both drive the same layout state, but they live in two
    /// disjoint SwiftUI scene graphs — a `@StateObject` inside
    /// `LayoutShellView` is not reachable from a `CommandMenu`. A
    /// MainActor-isolated shared instance is the smallest thing that
    /// makes both sides agree without threading the VM through
    /// `MainView` (which is outside this task's file boundary).
    static let shared = LayoutShellViewModel()

    // MARK: - Published state

    /// Single source of truth that the View layer reads. Always starts
    /// at `.default` so the first paint never reads from disk (cheap +
    /// deterministic; if the disk read returns the same default, no flash).
    @Published private(set) var snapshot: LayoutSnapshot = .default

    /// LT-01-fix3: per-panel show/hide, driven exclusively by the macOS
    /// menu bar's "View" menu (FCP 范式). Distinct from
    /// `snapshot.collapsed`: a *collapsed* panel keeps a gutter/header
    /// strip, a *hidden* panel gets no width at all and its neighbours
    /// absorb the space. Defaults to all-visible.
    @Published private(set) var visibility: PanelVisibilityState = PanelVisibilityState()

    /// `true` after the first `.load()` completes — drives whether the
    /// toolbar shows the "reset to defaults" affordance. We don't gate the
    /// View on this to keep the layout responsive during cold launch.
    @Published private(set) var isLoaded: Bool = false

    // MARK: - Init

    private let store: WenshuStoreActor
    private var saveTask: Task<Void, Never>?

    init(store: WenshuStoreActor = .shared) {
        self.store = store
    }

    // MARK: - Load (cold launch)

    /// Read the persisted snapshot from `.ws`. Caller invokes this from
    /// `.task` — runs once after the first render. Errors fall back to
    /// defaults so a corrupted row never bricks the shell.
    func load() async {
        do {
            if let raw = try await store.loadLayoutState() {
                let states = PanelStatesEnvelope.decode(raw.panelStatesJSON)
                snapshot = LayoutSnapshot(
                    collapsed: states.collapsed,
                    ratios: LayoutSnapshot.decodeRatios(raw.panelRatiosJSON)
                )
                visibility = states.visible
            }
        } catch {
            FileHandle.standardError.write(Data(
                "LayoutShellViewModel.load: \(error)\n".utf8
            ))
        }
        isLoaded = true
    }

    // MARK: - Panel collapse toggle
    //
    // LT-01-fix3 removed the chevron buttons that used to call this
    // (FCP 范式: collapse/expand is a menu-bar concern, not panel chrome).
    // The method + persisted flags stay so old .ws files keep round-
    // tripping and so LT-02/03/04 can re-expose collapse if 装机 user
    // asks for it.

    func toggle(_ panel: PanelID) {
        var snap = snapshot
        switch panel {
        case .topLeft:
            snap.collapsed.topLeft.toggle()
        case .topCenter:
            snap.collapsed.topCenter.toggle()
        case .topRight:
            snap.collapsed.topRight.toggle()
        case .bottomLeft:
            snap.collapsed.bottomLeft.toggle()
        case .bottomRight:
            snap.collapsed.bottomRight.toggle()
        }
        snapshot = snap
        scheduleSave()
    }

    // MARK: - Splitter drag handlers

    /// Splitter at `upperSplitterIndex` (0 or 1) in the upper row was
    /// dragged by `delta` pixels (positive = pulled right). We update
    /// ratios[index] and ratios[index+1] (the two panels left/right of
    /// the splitter) such that their sum is preserved and each stays
    /// within [5%, 95%].
    ///
    /// `totalWidth` is the upper row's full width in points (post-toolbar).
    /// Available width excludes the 2 splitter bars themselves.
    func adjustUpperColumn(splitterIndex: Int, delta: CGFloat, totalWidth: CGFloat) {
        guard splitterIndex == 0 || splitterIndex == 1 else { return }
        let left = splitterIndex
        let right = splitterIndex + 1
        let available = totalWidth - 2 * LayoutSnapshot.splitterPixels
        guard available > 0 else { return }
        let deltaRatio = Double(delta / available)
        var ratios = snapshot.ratios
        let sum = ratios[left] + ratios[right]
        guard sum > 0 else { return }
        let proposed = ratios[left] + deltaRatio
        let clamped = max(0.05, min(0.95, proposed))
        ratios[left] = clamped
        ratios[right] = max(0.05, sum - clamped)
        snapshot.ratios = ratios
        scheduleSave()
    }

    /// The horizontal splitter between upper and lower bands was dragged
    /// by `delta` pixels (positive = pulled down). Updates ratios[3]
    /// (lower band's fraction of total height).
    func adjustBottomHeight(delta: CGFloat, totalHeight: CGFloat) {
        guard totalHeight > 0 else { return }
        let deltaRatio = Double(delta / totalHeight)
        var ratios = snapshot.ratios
        ratios[3] = max(0.10, min(0.90, ratios[3] + deltaRatio))
        snapshot.ratios = ratios
        scheduleSave()
    }

    /// The single horizontal splitter in the lower band (between 下左 and
    /// 下右) was dragged by `delta` pixels (positive = pulled right).
    /// Updates ratios[4] (bottomLeft's fraction of lower-band width).
    func adjustLowerColumn(delta: CGFloat, totalWidth: CGFloat) {
        let available = totalWidth - LayoutSnapshot.splitterPixels
        guard available > 0 else { return }
        let deltaRatio = Double(delta / available)
        var ratios = snapshot.ratios
        let proposed = ratios[4] + deltaRatio
        ratios[4] = max(0.05, min(0.95, proposed))
        snapshot.ratios = ratios
        scheduleSave()
    }

    // MARK: - Panel visibility (macOS "View" menu, LT-01-fix3)

    /// Show/hide one panel. Ratios are deliberately left untouched: the
    /// hidden panel's share is redistributed at render time by
    /// `LayoutMetrics`, so un-hiding restores the exact widths the user
    /// had dragged to. Persisted (debounced) to `.ws`.
    func togglePanelVisibility(_ panel: PanelID) {
        var next = visibility
        switch panel {
        case .topLeft: next.topLeft.toggle()
        case .topCenter: next.topCenter.toggle()
        case .topRight: next.topRight.toggle()
        case .bottomLeft: next.bottomLeft.toggle()
        case .bottomRight: next.bottomRight.toggle()
        }
        visibility = next
        scheduleSave()
    }

    func isVisible(_ panel: PanelID) -> Bool {
        visibility.isVisible(panel)
    }

    /// "全显示" (Cmd+Shift+1) — un-hides every panel without touching
    /// the dragged ratios.
    func showAllPanels() {
        visibility = PanelVisibilityState()
        scheduleSave()
    }

    // MARK: - Reset

    func resetToDefaults() async {
        snapshot = .default
        visibility = PanelVisibilityState()
        await saveImmediately()
    }

    // MARK: - Persistence (debounced)

    /// Debounce writes so a continuous drag gesture (60+ onChanged events
    /// per second) only triggers one CoreData `save()` at the gesture's
    /// tail. Cancels any pending write and starts a fresh 250ms timer.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            await self?.saveImmediately()
        }
    }

    private func saveImmediately() async {
        do {
            try await store.saveLayoutState(
                panelStatesJSON: PanelStatesEnvelope.encode(
                    collapsed: snapshot.collapsed,
                    visible: visibility
                ),
                panelRatiosJSON: LayoutSnapshot.encodeRatios(snapshot.ratios)
            )
        } catch {
            FileHandle.standardError.write(Data(
                "LayoutShellViewModel.saveImmediately: \(error)\n".utf8
            ))
        }
    }
}

// MARK: - Panel identity

/// Stable identifier for a panel slot in the 5-zone shell. Order matches
/// the `ratios` array index layout in `LayoutSnapshot`.
enum PanelID: Hashable, CaseIterable {
    case topLeft
    case topCenter
    case topRight
    case bottomLeft
    case bottomRight

    /// Display title for the gutter / header bar.
    var title: String {
        switch self {
        case .topLeft: return "项目管理"
        case .topCenter: return "文档"
        case .topRight: return "检视"
        case .bottomLeft: return "聊天"
        case .bottomRight: return "状态"
        }
    }

    /// SF Symbol for the empty-state glyph (placeholder content).
    var symbolName: String {
        switch self {
        case .topLeft: return "folder"
        case .topCenter: return "doc.text"
        case .topRight: return "sidebar.right"
        case .bottomLeft: return "bubble.left.and.bubble.right"
        case .bottomRight: return "checklist"
        }
    }

    /// "View" menu keyboard equivalent (Cmd+1 … Cmd+5), FCP 范式.
    var menuShortcut: KeyEquivalent {
        switch self {
        case .topLeft: return "1"
        case .topCenter: return "2"
        case .topRight: return "3"
        case .bottomLeft: return "4"
        case .bottomRight: return "5"
        }
    }
}

// MARK: - Panel visibility (LT-01-fix3)

/// One bool per panel. `true` = the panel participates in the layout;
/// `false` = it's hidden entirely (zero width, no splitter, no gutter).
///
/// Defaults to all-visible, which is also the fallback for any .ws file
/// written before LT-01-fix3 (see `PanelStatesEnvelope.decode`).
struct PanelVisibilityState: Codable, Sendable, Equatable {
    var topLeft: Bool
    var topCenter: Bool
    var topRight: Bool
    var bottomLeft: Bool
    var bottomRight: Bool

    init(
        topLeft: Bool = true,
        topCenter: Bool = true,
        topRight: Bool = true,
        bottomLeft: Bool = true,
        bottomRight: Bool = true
    ) {
        self.topLeft = topLeft
        self.topCenter = topCenter
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    func isVisible(_ panel: PanelID) -> Bool {
        switch panel {
        case .topLeft: return topLeft
        case .topCenter: return topCenter
        case .topRight: return topRight
        case .bottomLeft: return bottomLeft
        case .bottomRight: return bottomRight
        }
    }
}

// MARK: - panel_states JSON envelope

/// LT-01-fix3 widens the `CDLayoutState.panel_states` column payload from
/// a bare `PanelCollapsedState` object to
/// `{"collapsed": {...}, "visible": {...}}`.
///
/// The entity schema is untouched (still one `String` column) — only the
/// JSON *inside* it grew, so this stays on the CC side of AGENTS §5.
///
/// Backwards compatibility: `decode` sniffs for the `"collapsed"` key. A
/// pre-fix3 .ws holds the legacy flat shape and is routed through
/// `LayoutSnapshot.decodeCollapsed`, with visibility defaulting to
/// all-visible. Anything unparseable degrades to defaults rather than
/// throwing (same contract as the rest of LayoutState).
enum PanelStatesEnvelope {
    private struct Payload: Codable {
        var collapsed: PanelCollapsedState
        var visible: PanelVisibilityState
    }

    static func encode(collapsed: PanelCollapsedState, visible: PanelVisibilityState) -> String {
        let payload = Payload(collapsed: collapsed, visible: visible)
        guard let data = try? JSONEncoder().encode(payload),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    static func decode(
        _ string: String
    ) -> (collapsed: PanelCollapsedState, visible: PanelVisibilityState) {
        guard !string.isEmpty, let data = string.data(using: .utf8) else {
            return (PanelCollapsedState(), PanelVisibilityState())
        }
        if let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            return (payload.collapsed, payload.visible)
        }
        // Legacy (pre-LT-01-fix3) flat shape, or garbage → defaults.
        return (LayoutSnapshot.decodeCollapsed(string), PanelVisibilityState())
    }
}

// MARK: - Layout arithmetic

/// Pure geometry for the 5-zone shell. Extracted out of `LayoutShellView`
/// in LT-01-fix3 so the hidden-panel redistribution rule is unit-testable
/// without instantiating SwiftUI.
///
/// Precedence per panel: hidden → 0pt · collapsed → gutter · else →
/// its share of what's left, renormalised against the other *expanded*
/// panels' ratios.
enum LayoutMetrics {

    /// Number of splitter bars actually rendered between `visibleCount`
    /// adjacent panels.
    static func splitterCount(visibleCount: Int) -> Int {
        max(0, visibleCount - 1)
    }

    /// (topLeft, topCenter, topRight) widths in points.
    static func upperWidths(
        totalWidth: CGFloat,
        ratios: [Double],
        collapsed: PanelCollapsedState,
        visibility: PanelVisibilityState
    ) -> (CGFloat, CGFloat, CGFloat) {
        let hidden = [!visibility.topLeft, !visibility.topCenter, !visibility.topRight]
        let isCollapsed = [collapsed.topLeft, collapsed.topCenter, collapsed.topRight]
        let r = ratios.count == 3 || ratios.count == 5
            ? [ratios[0], ratios[1], ratios[2]]
            : [LayoutSnapshot.default.ratios[0],
               LayoutSnapshot.default.ratios[1],
               LayoutSnapshot.default.ratios[2]]

        let visibleCount = hidden.filter { !$0 }.count
        let splitters = CGFloat(splitterCount(visibleCount: visibleCount))
            * CGFloat(LayoutSnapshot.splitterPixels)
        let available = max(0, totalWidth - splitters)

        let gutter = CGFloat(LayoutSnapshot.topCollapsedPixels)
        let collapsedVisibleCount = (0..<3).filter { !hidden[$0] && isCollapsed[$0] }.count
        let forExpanded = max(0, available - CGFloat(collapsedVisibleCount) * gutter)

        let expandedSum = (0..<3)
            .filter { !hidden[$0] && !isCollapsed[$0] }
            .reduce(0.0) { $0 + r[$1] }

        func width(_ i: Int) -> CGFloat {
            if hidden[i] { return 0 }
            if isCollapsed[i] { return gutter }
            guard expandedSum > 0 else { return 0 }
            return forExpanded * CGFloat(r[i] / expandedSum)
        }
        return (width(0), width(1), width(2))
    }

    /// (bottomLeft, bottomRight) widths in points. `ratios[4]` is
    /// bottomLeft's share of the lower band.
    static func lowerWidths(
        totalWidth: CGFloat,
        ratios: [Double],
        collapsed: PanelCollapsedState,
        visibility: PanelVisibilityState
    ) -> (CGFloat, CGFloat) {
        let leftRatio = ratios.count == 5 ? ratios[4] : LayoutSnapshot.default.ratios[4]
        let hidden = [!visibility.bottomLeft, !visibility.bottomRight]
        let isCollapsed = [collapsed.bottomLeft, collapsed.bottomRight]

        let visibleCount = hidden.filter { !$0 }.count
        let splitters = CGFloat(splitterCount(visibleCount: visibleCount))
            * CGFloat(LayoutSnapshot.splitterPixels)
        let available = max(0, totalWidth - splitters)

        // A collapsed lower panel keeps only its header bar; horizontally
        // it still needs a readable strip, so we reuse the upper gutter
        // width as its minimum footprint.
        let strip = CGFloat(LayoutSnapshot.topCollapsedPixels)
        let collapsedVisibleCount = (0..<2).filter { !hidden[$0] && isCollapsed[$0] }.count
        let forExpanded = max(0, available - CGFloat(collapsedVisibleCount) * strip)

        let r = [leftRatio, 1.0 - leftRatio]
        let expandedSum = (0..<2)
            .filter { !hidden[$0] && !isCollapsed[$0] }
            .reduce(0.0) { $0 + r[$1] }

        func width(_ i: Int) -> CGFloat {
            if hidden[i] { return 0 }
            if isCollapsed[i] { return strip }
            guard expandedSum > 0 else { return 0 }
            return forExpanded * CGFloat(r[i] / expandedSum)
        }
        return (width(0), width(1))
    }

    /// Height of the lower band. If every lower panel is hidden the band
    /// collapses to 0 and the upper band takes the whole window (and
    /// vice-versa) — otherwise `ratios[3]` splits them.
    static func lowerBandHeight(
        totalHeight: CGFloat,
        ratios: [Double],
        visibility: PanelVisibilityState
    ) -> CGFloat {
        let lowerVisible = visibility.bottomLeft || visibility.bottomRight
        let upperVisible = visibility.topLeft || visibility.topCenter || visibility.topRight
        if !lowerVisible { return 0 }
        if !upperVisible { return totalHeight }
        let r = ratios.count == 5 ? ratios[3] : LayoutSnapshot.default.ratios[3]
        return totalHeight * CGFloat(r)
    }
}
