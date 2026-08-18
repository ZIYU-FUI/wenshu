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
    static let minOffset: Double = -0.15  // 老板 8/18 拍 "范围小, 加一些" (D_v5 可拖范围, D_h 同时用 -0.15)
    static let maxOffset: Double = +0.15
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
        Double(LayoutTokens.aiChatRatio) - offsets[4]
    }
    /// AI 动态 = base 400 + D_v5 offset
    var dynamicWRatio: Double {
        Double(LayoutTokens.dynamicWRatio) + offsets[4]
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

    /// D_h 横拖拽线可拖 (老板 8/18 拍 "初始 50:50, 但要能拖动")
    /// bandOffset 累加 [minOffset, maxOffset] = [-0.10, +0.10]
    /// bandH = LayoutTokens.designH * (LayoutTokens.bandRatio + bandOffset)
    func adjustBandSplit(delta: CGFloat, totalHeight: CGFloat) {
        guard totalHeight > 0 else { return }
        let step = Double(delta / totalHeight)
        let newOffset = bandOffset + step
        guard newOffset >= Self.minOffset, newOffset <= Self.maxOffset else { return }
        bandOffset = newOffset
    }

    /// 运行时 bandH (受 D_h 横拖拽线影响, 整体高度不变 = 2 * bandRatio * designH)
    /// 拖动 D_v5 让上 band +offset/2, 下 band -offset/2 (反方向, 整体守恒)
    var upperBandH: CGFloat {
        LayoutTokens.designH * CGFloat(LayoutTokens.bandRatio + bandOffset / 2)
    }
    var lowerBandH: CGFloat {
        LayoutTokens.designH * CGFloat(LayoutTokens.bandRatio - bandOffset / 2)
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
    private func adjust(_ index: Int, delta: CGFloat, totalWidth: CGFloat) {
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
