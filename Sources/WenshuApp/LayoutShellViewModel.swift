// LayoutShellViewModel.swift · Wenshu · v0.10.1 6 zone splitter drag state
//
// macOS-only state (= Package.swift .macOS(.v27)). Single source of truth for
// splitter drag offsets. 老板 8/18 拍 6 区 + 6 master 组件化, 5 个 ratio offset
// 累加 (5 竖拖拽线 + 1 横拖拽线, 横拖拽线 v0.10.1 锁 0.4797 上下 band 50/50 不动).
//
// 6 zone 真值 (v0.10.0 比例换算后):
//   LayoutTokens.projectSidebarRatio   (0.1042, 项目侧栏 / 项目预览 之间 D_v1)
//   LayoutTokens.projectPreviewRatio   (0.2901, 项目预览 / 编辑器之间 D_v2)
//   LayoutTokens.editorWRatio          (0.3943, 编辑器 / 工具之间 D_v3)
//   LayoutTokens.aiChatRatio      (0.1042, 聊天侧栏 / 聊天对话之间 D_v4)
//   LayoutTokens.aiChatRatio     (0.6823, 聊天对话 / 动态区之间 D_v5)
//   横拖拽线 D_h 锁定 bandRatio=0.4797 (老板 8/18 拍 50/50)
//
// VM 只存 5 个竖拖拽线 ratio offset (累加在 default ratio 上). 横拖拽线 inert.
//
// 老板 19:00 fix: 拖拽走 AppKit NSEvent pipeline (NativeSplitterView), 不走
// SwiftUI render pipeline, 无闪烁. dragStep 在 NSView 内部算 (deltaX/totalW),
// VM 接收 ratio step 累加, view 重新读 vm.ratios 算 zone 宽度.

import SwiftUI
import Observation

@Observable
final class LayoutShellViewModel {
    /// 5 个竖拖拽线 ratio 累加 (基于 LayoutTokens 默认 ratio). 0 = 还原默认.
    /// offsets[0] = D_v1 项目侧栏 / 项目预览 (调整 projectSidebarRatio)
    /// offsets[1] = D_v2 项目预览 / 编辑器   (调整 projectPreviewRatio)
    /// offsets[2] = D_v3 编辑器 / 工具       (调整 editorWRatio)
    /// offsets[3] = D_v4 聊天侧栏 / 聊天对话 (调整 chatSidebarRatio)
    /// offsets[4] = D_v5 聊天对话 / 动态区   (调整 chatDialogueRatio)
    /// 5 个竖拖拽线 ratio 累加 (v0.10.3 老板 8/18 拍下 band 3 区, D_v4 内嵌重接)
    /// offsets[0] = D_v1 项目侧栏 / 项目预览 (调整 projectSidebarRatio)
    /// offsets[1] = D_v2 项目预览 / 编辑器   (调整 projectPreviewRatio)
    /// offsets[2] = D_v3 编辑器 / 工具       (调整 editorWRatio)
    /// offsets[3] = D_v4 聊天侧栏 / 聊天对话 (调整 chatSidebarRatio) [v0.10.3 新接]
    /// offsets[4] = D_v5 聊天对话 / 动态区   (调整 chatDialogueRatio)
    var offsets: [Double] = [0, 0, 0, 0, 0]

    /// 拖拽边界
    static let minOffset: Double = -0.15
    static let maxOffset: Double = +0.15

    // v0.24 boss验收fix (Boss 8/25 tenth OOB ticket 015.023): zone visibility
    // state for 4 toggle zones (= projectSidebar, specializedTools, aiChat,
    // aiDynamic). Editor zone NOT toggleable per Boss spec.
    // @AppStorage for persistence across launches (= Boss 8/24 'tab selection
    // state per zone needs to persist' pattern).
    // v0.24 boss验收fix: @ObservationIgnored prevents conflict with @ObservationTracked
    // (LayoutShellViewModel is @Observable, but @AppStorage already provides
    // its own reactive storage via UserDefaults notifications).
    // v0.24 fix (Boss 8/25 59th OOB '4 toggles clicks have no effect'):
    // restore @ObservationIgnored annotation. Per SwiftUI Observation
    // framework (@Observable), removing @ObservationIgnored causes
    // macro conflict ('invalid redeclaration of synthesized property
    // _projectSidebarVisible') because @AppStorage has its own backing
    // storage that conflicts with @Observable's auto-synthesized
    // storage.
    // Real fix = toggleZone bumps the @ObservationTracked revisionToken
    // (= see below) to trigger objectWillChange, which makes SwiftUI
    // re-render. Initial attempt to call objectWillChange.send()
    // directly failed because @Observable hides that method.
    @ObservationIgnored @AppStorage("wenshu.zoneVisible.projectSidebar") var projectSidebarVisible: Bool = true
    @ObservationIgnored @AppStorage("wenshu.zoneVisible.specializedTools") var specializedToolsVisible: Bool = true
    @ObservationIgnored @AppStorage("wenshu.zoneVisible.aiChat") var aiChatVisible: Bool = true
    @ObservationIgnored @AppStorage("wenshu.zoneVisible.aiDynamic") var aiDynamicVisible: Bool = true
    // v0.24 fix (Boss 8/25 59th OOB '4 toggles clicks have no effect'):
    // bumpable trigger token. @ObservationTracked so any change forces
    // SwiftUI to re-render (= required because @AppStorage flags are
    // @ObservationIgnored). toggleZone bumps this token before + after
    // flag flip.
    @ObservationTracked var revisionToken: UInt64 = 0

    /// v0.24 boss验收fix (Boss 8/25 tenth OOB ticket 015.023): query helper.
    /// Returns visibility for given slot. Editor zone always true (= Boss拍
    /// '编辑器永远不能隐藏').
    func isZoneVisible(slot: ZoneSlot) -> Bool {
        switch slot {
        case .projectSidebar: return projectSidebarVisible
        case .projectPreview: return true  // editor = always visible
        case .editor: return true
        case .specializedTools: return specializedToolsVisible
        case .aiChat: return aiChatVisible
        case .aiDynamic: return aiDynamicVisible
        }
    }

    /// v0.24 boss acceptance fix (Boss 8/25 60th OOB 'corresponding
    /// functionality should be implemented in menu bar'):
    /// init() listens for wenshuToggleZone NotificationCenter posts from
    /// menu bar CommandGroup buttons (= menu bar is primary command
    /// surface per Apple HIG Rule 3). Notification posts the ZoneSlot,
    /// listener calls toggleZone (= same code path as toolbar buttons).
    init() {
        NotificationCenter.default.addObserver(
            forName: .wenshuToggleZone,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let slot = notification.object as? ZoneSlot {
                self?.toggleZone(slot: slot)
            }
        }
    }

    /// v0.24 boss acceptance fix (Boss 8/25 tenth OOB ticket 015.023):
    /// toggle visibility for given slot. Editor zone toggle is a no-op
    /// (= Boss spec).
    /// v0.24 fix (Boss 8/25 59th OOB '4 toggles clicks have no effect'):
    /// bump revisionToken before flag flip so SwiftUI @Observable
    /// re-renders the view (= @ObservationTracked revisionToken change
    /// triggers objectWillChange). The @AppStorage flag is
    /// @ObservationIgnored so flag flip alone doesn't trigger
    /// re-render.
    func toggleZone(slot: ZoneSlot) {
        // Notify SwiftUI views to re-render BEFORE changing state
        revisionToken &+= 1
        switch slot {
        case .projectSidebar: projectSidebarVisible.toggle()
        case .projectPreview: break  // editor = always visible, no-op
        case .editor: break  // always visible, no-op
        case .specializedTools: specializedToolsVisible.toggle()
        case .aiChat: aiChatVisible.toggle()
        case .aiDynamic: aiDynamicVisible.toggle()
        }
        // Bump again after flag flip so views re-render with new flag value
        revisionToken &+= 1
        NSLog("[wenshu.layout] toggleZone: slot=%@ visible=%d", String(describing: slot), isZoneVisible(slot: slot) ? 1 : 0)
    }

    /// v0.24 boss验收fix (Boss 8/25 tenth OOB ticket 015.023): placeholder for
    /// e-book export (= Boss拍 '最右加一个导出功能, 用于导出市面上常见的电子书格式').
    /// Real format conversion logic deferred to future ticket (= PDF/EPUB/MOBI/TXT).
    func exportEbook(format: String = "epub") {
        NSLog("[wenshu.layout] exportEbook: format=%@ (placeholder; real conversion future ticket)", format)
    }
    static let minBandOffset: Double = -1.0
    static let maxBandOffset: Double = +1.0
    static let minZoneRatio: Double = 0.04
    static let maxZoneRatioUpper: Double = 0.60  // 上 band 4 zone max 60%
    static let maxZoneRatioLower: Double = 0.95  // 下 band 2 zone max 95% (chat 79% 默认)

    // MARK: - 计算属性 (默认 ratio + offset)

    var projectSidebarRatio: Double {
        Double(LayoutTokens.projectSidebarRatio) + offsets[0]
    }
    var projectPreviewRatio: Double {
        Double(LayoutTokens.projectPreviewRatio) - offsets[0] + offsets[1]
    }
    var editorWRatio: Double {
        Double(LayoutTokens.editorWRatio) - offsets[1] + offsets[2]
    }
    var toolsWRatio: Double {
        Double(LayoutTokens.toolsWRatio) - offsets[2]
    }
    /// 老板 8/18 拍 "上四下两" = 下 band 1 区 (AI 聊天) + 1 区 (AI 动态), 1 拖拽线 D_v5
    /// 整宽 AI 聊天 = base 1519 - D_v5 offset
    var aiChatRatio: Double {
        Double(LayoutTokens.aiChatRatio) + offsets[4]
    }
    /// AI 动态 = base 400 + D_v5 offset
    var dynamicWRatio: Double {
        Double(LayoutTokens.dynamicWRatio) - offsets[4]
    }

    /// v0.24 boss验收fix (Boss 8/25 eleventh OOB ticket 015.024 '红框中,
    /// 出现了两条拖拽线'): return true when right-most ZONE widths
    /// (= specializedTools upper + aiDynamic lower) match (= Boss spec
    /// '宽度是一模一样的'). At initial state (offsets=0),
    /// toolsWRatio = dynamicWRatio = 400/1920. After user drags D_v3
    /// or D_v5, they diverge. Used by UpperBandZone to conditionally
    /// render D_v3 splitter (= prevents double-line visual at right
    /// edge when aligned).
    func areRightSplittersAligned() -> Bool {
        let tolerance: Double = 0.0001  // ~0.2 PT at 1920 PT width
        return abs(toolsWRatio - dynamicWRatio) < tolerance
    }

    // MARK: - 拖拽回调 (老板 8/18 拍 D_v1~D_v5 1 PT 黑线, 6 PT hit area, 增量拖拽)

    /// D_v1: 项目侧栏 / 项目预览 (vertical, deltaX 增量)
    func adjustSidebarPreview(delta: CGFloat, totalWidth: CGFloat) {
        adjust(0, delta: delta, totalWidth: totalWidth)
    }

    /// D_v2: 项目预览 / 编辑器
    func adjustPreviewEditor(delta: CGFloat, totalWidth: CGFloat) {
        adjust(1, delta: delta, totalWidth: totalWidth)
    }

    /// D_v3: 编辑器 / 专用工具
    func adjustEditorTools(delta: CGFloat, totalWidth: CGFloat) {
        adjust(2, delta: delta, totalWidth: totalWidth)
    }

    /// D_v4 移除 (老板 8/18 拍 "上四下两", 下 band 1 拖拽线 D_v5)
    /// D_v5: AI 聊天 / AI 动态 (索引 4)
    func adjustChatDynamic(delta: CGFloat, totalWidth: CGFloat) {
        adjust(4, delta: delta, totalWidth: totalWidth)
    }

    /// D_h 横拖拽线可拖 (老板 2026-08-19 拍 "初始 50:50, 但要能拖动")
    /// bandOffset 累加 [minOffset, maxOffset] = [-0.10, +0.10]
    /// v0.15 ticket 014: bandOffset 跟 totalHeight 联动, resize 响应 (不用 designH 写死)
    func adjustBandSplit(delta: CGFloat, totalHeight: CGFloat) {
        guard totalHeight > 0 else { return }
        let step = Double(delta / totalHeight)
        let newOffset = bandOffset + step
        guard newOffset >= Self.minBandOffset, newOffset <= Self.maxBandOffset else { return }
        bandOffset = newOffset
    }

    /// 运行时 bandH (受 D_h 横拖拽线影响, 上/下 band 反方向守恒 = totalHeight × (0.5 + bandOffset × 0.5))
    /// bandOffset 范围 ±1.0 对应 ±50% totalH (上 band 可从 0% 拖到 100%)
    func upperBandH(totalHeight: CGFloat) -> CGFloat {
        totalHeight * (0.5 + CGFloat(bandOffset) * 0.5)
    }
    func lowerBandH(totalHeight: CGFloat) -> CGFloat {
        totalHeight * (0.5 - CGFloat(bandOffset) * 0.5)
    }

    /// D_h 横拖拽线 (老板 8/18 拍 "初始 50:50, 但要能拖动")
    /// bandOffset 累积范围 [-0.10, +0.10] (跟 5 竖拖拽线同边界)
    var bandOffset: Double = 0

    /// 重置 (开发用, 还原默认 ratio)
    func reset() {
        offsets = [0, 0, 0, 0, 0]
        bandOffset = 0
    }

    // MARK: - Internal

    /// 共享拖拽数学: offset[index] 累加 delta/totalWidth, 校验所有 zone ratio
    /// 仍在 [minZoneRatio, maxZoneRatio] 范围内, 否则拒绝 (splitter 不会越界).
    /// v0.15 ticket 006: private → internal 让 VSplitter 表驱动调用 (P3-3 Shotgun Surgery 修法)
    func adjust(_ index: Int, delta: CGFloat, totalWidth: CGFloat) {
        guard totalWidth > 0 else { return }
        let step = Double(delta / totalWidth)
        let newOffset = offsets[index] + step
        guard newOffset >= Self.minOffset, newOffset <= Self.maxOffset else { return }

        offsets[index] = newOffset
        // 上 band zone 用 maxZoneRatioUpper, 下 band zone 用 maxZoneRatioLower
        let upperRatios = [projectSidebarRatio, projectPreviewRatio, editorWRatio, toolsWRatio]
        let lowerRatios = [aiChatRatio, dynamicWRatio]
        let upperOK = upperRatios.allSatisfy { $0 >= Self.minZoneRatio && $0 <= Self.maxZoneRatioUpper }
        let lowerOK = lowerRatios.allSatisfy { $0 >= Self.minZoneRatio && $0 <= Self.maxZoneRatioLower }
        if !upperOK || !lowerOK {
            offsets[index] -= step
        }
    }

}
