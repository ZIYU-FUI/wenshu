// LayoutShellViewModel.swift · 文枢 (Wenshu) · v0.05.0 B+ 拆主控 (t_1831ad61)
//
// Doc-Role: ViewModels/LayoutShellViewModel (主 VM 类)
// Responsibilities: 5 区 layout 主 VM — snapshot/visibility/collapse 持久化 + 调整
// Inputs: PanelID、splitter delta、totalWidth/Height
// Outputs: snapshot、visibility、isLoaded
// Dependencies: WenshuStoreActor (loadLayoutState/saveLayoutState)
// Threading: @MainActor
//
// 拆 (沿 DECISION §4.2 #4): PanelID / PanelVisibilityState /
// PanelStatesEnvelope / LayoutMetrics → Views/Layout/LayoutShellTypes.swift。
// Models/LayoutState.swift (172 行) 保留不动。 LayoutShellViewModel.shared

import Foundation
import SwiftUI

@MainActor
@Observable
final class LayoutShellViewModel {
    static let shared = LayoutShellViewModel()

    private(set) var snapshot: LayoutSnapshot = .default
    private(set) var visibility: PanelVisibilityState = PanelVisibilityState()
    private(set) var isLoaded: Bool = false

    private let store: WenshuStoreActor
    private var saveTask: Task<Void, Never>?

    init(store: WenshuStoreActor = .shared) { self.store = store }

    func load() async {
        do {
            if let raw = try await store.loadLayoutState() {
                let states = PanelStatesEnvelope.decode(raw.panelStatesJSON)
                snapshot = LayoutSnapshot(collapsed: states.collapsed,
                    ratios: LayoutSnapshot.decodeRatios(raw.panelRatiosJSON))
                visibility = states.visible
            }
        } catch {
            FileHandle.standardError.write(Data("LayoutShellViewModel.load: \(error)\n".utf8))
        }
        isLoaded = true
    }

    func toggle(_ panel: PanelID) {
        var snap = snapshot
        switch panel {
        case .topLeft: snap.collapsed.topLeft.toggle()
        case .topCenter: snap.collapsed.topCenter.toggle()
        case .topRight: snap.collapsed.topRight.toggle()
        case .bottomLeft: snap.collapsed.bottomLeft.toggle()
        case .bottomRight: snap.collapsed.bottomRight.toggle()
        }
        snapshot = snap
        scheduleSave()
    }

    @discardableResult
    func adjustUpperColumn(splitterIndex: Int, delta: CGFloat, totalWidth: CGFloat) -> Bool {
        guard splitterIndex == 0 || splitterIndex == 1 else { return false }
        let left = splitterIndex, right = splitterIndex + 1
        let available = totalWidth - 2 * LayoutSnapshot.splitterPixels
        guard available > 0 else { return false }
        let deltaRatio = Double(delta / available)
        var snap = snapshot
        let sum = snap.ratios[left] + snap.ratios[right]
        guard sum > 0 else { return false }
        let pL = snap.ratios[left] + deltaRatio
        let cL = max(0.05, min(0.95, pL))
        let cR = max(0.05, min(0.95, sum - cL))
        snap.ratios[left] = cL
        snap.ratios[right] = cR
        let applied = abs(pL - cL) < 0.0001 && abs((sum - cL) - cR) < 0.0001
        snapshot = snap
        scheduleSave()
        return applied
    }

    @discardableResult
    func adjustBottomHeight(delta: CGFloat, totalHeight: CGFloat) -> Bool {
        guard totalHeight > 0 else { return false }
        let proposed = snapshot.ratios[3] - Double(delta / totalHeight)
        let clamped = max(0.10, min(0.90, proposed))
        var snap = snapshot
        snap.ratios[3] = clamped
        let applied = abs(proposed - clamped) < 0.0001
        snapshot = snap
        scheduleSave()
        return applied
    }

    @discardableResult
    func adjustLowerColumn(delta: CGFloat, totalWidth: CGFloat) -> Bool {
        let available = totalWidth - LayoutSnapshot.splitterPixels
        guard available > 0 else { return false }
        let proposed = snapshot.ratios[4] + Double(delta / available)
        let clamped = max(0.05, min(0.95, proposed))
        var snap = snapshot
        snap.ratios[4] = clamped
        let applied = abs(proposed - clamped) < 0.0001
        snapshot = snap
        scheduleSave()
        return applied
    }

    func togglePanelVisibility(_ panel: PanelID) {
        guard panel.isDismissible else { return }
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

    func isVisible(_ panel: PanelID) -> Bool { visibility.isVisible(panel) }
    func toggleBottomBand() {
        togglePanelVisibility(.bottomLeft)
        togglePanelVisibility(.bottomRight)
    }
    func isBottomBandVisible() -> Bool { visibility.bottomLeft && visibility.bottomRight }
    func showAllPanels() { visibility = PanelVisibilityState(); scheduleSave() }

    func resetToDefaults() async {
        snapshot = .default
        visibility = PanelVisibilityState()
        await saveImmediately()
    }

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
                panelStatesJSON: PanelStatesEnvelope.encode(collapsed: snapshot.collapsed, visible: visibility),
                panelRatiosJSON: LayoutSnapshot.encodeRatios(snapshot.ratios))
        } catch {
            FileHandle.standardError.write(Data("LayoutShellViewModel.saveImmediately: \(error)\n".utf8))
        }
    }
}

extension LayoutShellViewModel: LayoutShellViewModelProtocol {}
