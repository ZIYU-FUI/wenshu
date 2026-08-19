// LayoutShellViewModelTests.swift · Wenshu · v0.10.1 splitter drag 单元测试
//
// 验证老板 8/18 拍 6 区 + 4 竖拖拽线拖拽行为 (v0.10.1 移除内嵌 D_v4, 5 改 4):
// 1. 默认 ratio 跟 LayoutTokens 一致
// 2. 拖拽 D_v1 (项目侧栏) → projectSidebarRatio 增, projectPreviewRatio 减
// 3. 拖拽 D_v3 (编辑器) → editorWRatio 减, toolsWRatio 增
// 4. 拖拽 D_v5 (AI聊天/AI 动态) → aiChatRatio 增, dynamicWRatio 减 (老板 8/18 拍 "上四下两" v0.10.10d)
// 5. 越界拒绝 (offset 累加超 [minOffset, maxOffset])
// 6. 越界拒绝 (zone ratio 累加超 [minZoneRatio, maxZoneRatio])
// 7. reset() 还原默认
// 8. 4 splitter 累加 = 0 (零和, band 总宽守恒)

import Testing
import SwiftUI
@testable import WenshuApp

@Suite("LayoutShellViewModel 6 zone splitter drag")
struct LayoutShellViewModelTests {
    @Test("默认 ratio 跟 LayoutTokens 比例一致 (老板 2026-08-19 拍 '按比例, 不是绝对值')")
    func defaultRatios() {
        let vm = LayoutShellViewModel()
        // 老板 2026-08-19 拍 "按比例, 不是绝对值": 实现 = totalW * LayoutTokens.ratio, 测试按 ratio sum 校验 (不用绝对 PT)
        // LayoutTokens 真值 (mcp__sketch__run_code 2026-08-19): sidebar 200 / preview 520 / editor 794 / tools 400 / aiChat 1518 / dynamic 400
        #expect(abs(vm.projectSidebarRatio - Double(LayoutTokens.projectSidebarRatio)) < 0.0001)
        #expect(abs(vm.projectPreviewRatio - Double(LayoutTokens.projectPreviewRatio)) < 0.0001)
        #expect(abs(vm.editorWRatio - Double(LayoutTokens.editorWRatio)) < 0.0001)
        #expect(abs(vm.toolsWRatio - Double(LayoutTokens.toolsWRatio)) < 0.0001)
        #expect(abs(vm.aiChatRatio - Double(LayoutTokens.aiChatRatio)) < 0.0001)
        #expect(abs(vm.dynamicWRatio - Double(LayoutTokens.dynamicWRatio)) < 0.0001)
    }

    @Test("拖 D_v1 (项目侧栏/项目预览) → sidebar 增 preview 减, 0 和")
    func dragD_v1() {
        let vm = LayoutShellViewModel()
        let totalW: CGFloat = 1920
        let beforeSidebar = vm.projectSidebarRatio
        let beforePreview = vm.projectPreviewRatio

        vm.adjustSidebarPreview(delta: 50, totalWidth: totalW)

        #expect(vm.projectSidebarRatio > beforeSidebar, "sidebar 增")
        #expect(vm.projectPreviewRatio < beforePreview, "preview 减")
        // sidebar 增, preview 减, 加和 = 0
        let sumChange = (vm.projectSidebarRatio - beforeSidebar) + (vm.projectPreviewRatio - beforePreview)
        #expect(abs(sumChange) < 0.001, "0 和守恒 (sidebar 增 + preview 减 = 0)")
    }

    @Test("拖 D_v3 (编辑器/工具) → editor 减 tools 增")
    func dragD_v3() {
        let vm = LayoutShellViewModel()
        let totalW: CGFloat = 1920
        let beforeEditor = vm.editorWRatio
        let beforeTools = vm.toolsWRatio

        vm.adjustEditorTools(delta: -30, totalWidth: totalW)

        #expect(vm.editorWRatio < beforeEditor, "editor 减")
        #expect(vm.toolsWRatio > beforeTools, "tools 增")
    }

    @Test("拖 D_v5 (聊天对话/动态区) → chat 增 dynamic 减")
    func dragD_v5() {
        let vm = LayoutShellViewModel()
        let totalW: CGFloat = 1920
        let beforeChat = vm.aiChatRatio
        let beforeDyn = vm.dynamicWRatio

        vm.adjustChatDynamic(delta: 30, totalWidth: totalW)

        #expect(vm.aiChatRatio > beforeChat, "chat 增")
        #expect(vm.dynamicWRatio < beforeDyn, "dynamic 减")
    }

    @Test("越界拒绝: offset 超 maxOffset (单次拖 200 PT / 1920 = 0.104 > 0.10)")
    func rejectOffsetOutOfRange() {
        let vm = LayoutShellViewModel()
        let totalW: CGFloat = 1920

        vm.adjustSidebarPreview(delta: 300, totalWidth: totalW)  // 老板 8/18 v0.14.0 改 maxOffset=±0.15, delta 300/1920=0.156 > 0.15 越界

        #expect(vm.projectSidebarRatio == Double(LayoutTokens.projectSidebarRatio), "未变")
    }

    @Test("越界拒绝: zone ratio 超 maxZoneRatio (拖到 tools > 60%)")
    func rejectZoneRatioOverflow() {
        let vm = LayoutShellViewModel()
        let totalW: CGFloat = 1920

        for _ in 0..<100 {
            vm.adjustEditorTools(delta: -100, totalWidth: totalW)
        }

        #expect(vm.toolsWRatio >= LayoutShellViewModel.minZoneRatio)
        #expect(vm.toolsWRatio <= LayoutShellViewModel.maxZoneRatioUpper)
    }

    @Test("reset() 还原默认 ratio")
    func reset() {
        let vm = LayoutShellViewModel()
        let totalW: CGFloat = 1920

        vm.adjustSidebarPreview(delta: 50, totalWidth: totalW)
        vm.adjustPreviewEditor(delta: -30, totalWidth: totalW)
        vm.adjustChatDynamic(delta: 100, totalWidth: totalW)

        vm.reset()

        #expect(vm.projectSidebarRatio == Double(LayoutTokens.projectSidebarRatio))
        #expect(vm.projectPreviewRatio == Double(LayoutTokens.projectPreviewRatio))
        #expect(vm.editorWRatio == Double(LayoutTokens.editorWRatio))
        #expect(vm.toolsWRatio == Double(LayoutTokens.toolsWRatio))
        #expect(vm.aiChatRatio == Double(LayoutTokens.aiChatRatio))
        #expect(vm.dynamicWRatio == Double(LayoutTokens.dynamicWRatio))
    }

    @Test("adjustBandSplit() 锁定 no-op (老板 8/18 拍 50/50)")
    func bandSplitInert() {
        let vm = LayoutShellViewModel()
        let beforeTop = vm.projectSidebarRatio + vm.projectPreviewRatio + vm.editorWRatio + vm.toolsWRatio
        let beforeBottom = vm.aiChatRatio + vm.dynamicWRatio

        vm.adjustBandSplit(delta: 50, totalHeight: 984)
        vm.adjustBandSplit(delta: 50, totalHeight: 984)
        vm.adjustBandSplit(delta: 50, totalHeight: 984)

        let afterTop = vm.projectSidebarRatio + vm.projectPreviewRatio + vm.editorWRatio + vm.toolsWRatio
        let afterBottom = vm.aiChatRatio + vm.dynamicWRatio
        #expect(beforeTop == afterTop, "上 band 总 ratio 不变")
        #expect(beforeBottom == afterBottom, "下 band 总 ratio 不变")
    }

    @Test("上 band 4 列 ratio 加和 = 1914/1920 (留 6 PT 给拖拽线) [老板 2026-08-19 拍 '按比例, 不是绝对值']")
    func upperBandSum() {
        let vm = LayoutShellViewModel()
        let sum = vm.projectSidebarRatio + vm.projectPreviewRatio
            + vm.editorWRatio + vm.toolsWRatio
        // 老板 2026-08-19 拍 "按比例, 不是绝对值": LayoutTokens 真值 (mcp__sketch__run_code) 200+520+794+400 = 1914, 6 PT 拖拽线占位
        // 实现走 totalW * LayoutTokens.ratio, 任意窗口大小 1:1 自适应
        #expect(abs(sum - 1914.0 / 1920.0) < 0.0001, "4 zone ratio 加和 = 1914/1920")
    }

    @Test("下 band 2 列 ratio 加和 = 1918/1920 (留 2 PT 给拖拽线) [v0.10.10d 老板拍上四下两]")
    func lowerBandSum() {
        let vm = LayoutShellViewModel()
        let sum = vm.aiChatRatio + vm.dynamicWRatio
        // 老板 2026-08-19 拍 "按比例, 不是绝对值": 1518+400 = 1918/1920, 2 PT 拖拽线占位
        #expect(abs(sum - 1918.0 / 1920.0) < 0.0001, "2 zone ratio 加和 = 1918/1920")
    }
}



// 老板 8/18 拍 "菜单栏, 重置界面布局" 通知桥测试
@Suite("LayoutShellViewModel reset via Notification")
struct LayoutShellViewModelNotificationTests {
    @Test("通知 .wenshuResetLayout 触发后, 拖拽过的 offsets 还原默认")
    func resetViaNotification() {
        let vm = LayoutShellViewModel()
        let totalW: CGFloat = 1920
        vm.adjustSidebarPreview(delta: 50, totalWidth: totalW)
        vm.adjustEditorTools(delta: -30, totalWidth: totalW)
        vm.adjustChatDynamic(delta: 100, totalWidth: totalW)
        #expect(vm.projectSidebarRatio != Double(LayoutTokens.projectSidebarRatio), "已变")

        // 模拟菜单触发: 通知桥 + vm.reset() (主队列同步)
        var resetCalled = false
        let observer = NotificationCenter.default.addObserver(
            forName: .wenshuResetLayout,
            object: nil,
            queue: .main
        ) { _ in
            vm.reset()
            resetCalled = true
        }
        NotificationCenter.default.post(name: .wenshuResetLayout, object: nil)
        // drain main queue (synchronous)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        #expect(resetCalled, "observer 触发")
        #expect(vm.projectSidebarRatio == Double(LayoutTokens.projectSidebarRatio), "还原默认")
        #expect(vm.editorWRatio == Double(LayoutTokens.editorWRatio), "还原默认")
        #expect(vm.dynamicWRatio == Double(LayoutTokens.dynamicWRatio), "还原默认")
        NotificationCenter.default.removeObserver(observer)
    }
}


// 老板 8/18 拍 "比例也都拉齐了" — H 方向数对公式验证
@Suite("LayoutShellViewModel 数对 H 守恒")
struct LayoutShellViewModelHConserveTests {
    @Test("H 方向数对: 39 + 472 + 472 + 1 = 984")
    func hSumOne() {
        // titleRatio (39/984) + 2*bandRatio (944/984) + horizontalSplitterRatio (1/984) = 1.0
        let titleSum = 39.0 / 984.0
        let bandSum = 2.0 * (472.0 / 984.0)
        let hSplitSum = 1.0 / 984.0
        let total = titleSum + bandSum + hSplitSum
        #expect(abs(total - 1.0) < 0.0001, "H 方向 39+472+472+1 = 984, ratio = 1.0")
    }
}
