// DefaultLayoutService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Defaults
// Responsibilities: LayoutService 委派实现 — 透传到 LayoutShellViewModel.shared
// Inputs: PanelID、Double ratio
// Outputs: [PanelID: Double]
// Dependencies: LayoutShellViewModel.shared (红线 #3)
// Threading: @MainActor (LayoutShellViewModel 是 @MainActor)

import Foundation

/// B+ 重 (沿 DECISION §4.2 #1 + 红线 #3): 委派不替代。 layout
/// ratios 由 LayoutShellViewModel 内部管,B+ 重协议层暴露 read-only
/// snapshot 给其他组件(等后续派单真用)。
@MainActor
struct DefaultLayoutService: LayoutService {
    private let vm: LayoutShellViewModel

    init(vm: LayoutShellViewModel) {
        self.vm = vm
    }

    var panelRatios: [PanelID: Double] {
        get async {
            let ratios = vm.snapshot.ratios
            let ids: [PanelID] = [.topLeft, .topCenter, .topRight, .bottomLeft, .bottomRight]
            return Dictionary(uniqueKeysWithValues: zip(ids, ratios))
        }
    }

    func setRatio(panel: PanelID, ratio: Double) async {
        _ = ratio
    }

    func resetLayout() async {
        await vm.resetToDefaults()
    }
}
