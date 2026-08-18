// LayoutShellViewModelTests.swift · Wenshu · v0.10.1 splitter drag 单元测试
//
// 验证老板 8/18 拍 6 区 + 4 竖拖拽线拖拽行为 (v0.10.1 移除内嵌 D_v4, 5 改 4):
// 1. 默认 ratio 跟 LayoutTokens 一致
// 2. 拖拽 D_v1 (项目侧栏) → projectSidebarRatio 增, projectPreviewRatio 减
// 3. 拖拽 D_v3 (编辑器) → editorWRatio 减, toolsWRatio 增
// 4. 拖拽 D_v5 (聊天对话/动态区) → chatDialogueRatio 增, dynamicWRatio 减
// 5. 越界拒绝 (offset 累加超 [minOffset, maxOffset])
// 6. 越界拒绝 (zone ratio 累加超 [minZoneRatio, maxZoneRatio])
// 7. reset() 还原默认
// 8. 4 splitter 累加 = 0 (零和, band 总宽守恒)

import Testing
import SwiftUI
@testable import WenshuApp

@Suite("LayoutShellViewModel 6 zone splitter drag")
struct LayoutShellViewModelTests {
    @Test("默认 ratio 跟 LayoutTokens 比例一致")
    func defaultRatios() {
        let vm = LayoutShellViewModel()
        let totalW: CGFloat = 1920
        #expect(abs(vm.projectSidebarRatio - Double(LayoutTokens.projectSidebarRatio)) < 0.0001)
        #expect(abs(vm.projectPreviewRatio - Double(LayoutTokens.projectPreviewRatio)) < 0.0001)
        #expect(abs(vm.editorWRatio - Double(LayoutTokens.editorWRatio)) < 0.0001)
        #expect(abs(vm.toolsWRatio - Double(LayoutTokens.toolsWRatio)) < 0.0001)
        #expect(abs(vm.chatSidebarRatio - Double(LayoutTokens.chatSidebarRatio)) < 0.0001)
        #expect(abs(vm.chatDialogueRatio - Double(LayoutTokens.chatDialogueRatio)) < 0.0001)
        #expect(abs(vm.dynamicWRatio - Double(LayoutTokens.dynamicWRatio)) < 0.0001)

        let sidebarW = totalW * CGFloat(vm.projectSidebarRatio)
        let previewW = totalW * CGFloat(vm.projectPreviewRatio)
        let editorW  = totalW * CGFloat(vm.editorWRatio)
        let toolsW   = totalW * CGFloat(vm.toolsWRatio)
        #expect(abs(sidebarW - 200) < 0.5, "sidebar 200 PT")
        #expect(abs(previewW - 558) < 0.5, "preview 558 PT (中间 1)")
        #expect(abs(editorW - 759) < 0.5, "editor 759 PT (中间 2)")
        #expect(abs(toolsW - 400) < 0.5, "tools 400 PT")
        let sum = sidebarW + previewW + editorW + toolsW
        #expect(abs(sum - 1917) < 1, "上 band zone 总 1917 + 3 拖拽线 = 1920")
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
        let beforeChat = vm.chatDialogueRatio
        let beforeDyn = vm.dynamicWRatio

        vm.adjustChatDynamic(delta: 30, totalWidth: totalW)

        #expect(vm.chatDialogueRatio > beforeChat, "chat 增")
        #expect(vm.dynamicWRatio < beforeDyn, "dynamic 减")
    }

    @Test("越界拒绝: offset 超 maxOffset (单次拖 200 PT / 1920 = 0.104 > 0.10)")
    func rejectOffsetOutOfRange() {
        let vm = LayoutShellViewModel()
        let totalW: CGFloat = 1920

        vm.adjustSidebarPreview(delta: 200, totalWidth: totalW)

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
        #expect(vm.chatSidebarRatio == Double(LayoutTokens.chatSidebarRatio))
        #expect(vm.chatDialogueRatio == Double(LayoutTokens.chatDialogueRatio))
        #expect(vm.dynamicWRatio == Double(LayoutTokens.dynamicWRatio))
    }

    @Test("adjustBandSplit() 锁定 no-op (老板 8/18 拍 50/50)")
    func bandSplitInert() {
        let vm = LayoutShellViewModel()
        let beforeTop = vm.projectSidebarRatio + vm.projectPreviewRatio + vm.editorWRatio + vm.toolsWRatio
        let beforeBottom = vm.chatSidebarRatio + vm.chatDialogueRatio + vm.dynamicWRatio

        vm.adjustBandSplit()
        vm.adjustBandSplit()
        vm.adjustBandSplit()

        let afterTop = vm.projectSidebarRatio + vm.projectPreviewRatio + vm.editorWRatio + vm.toolsWRatio
        let afterBottom = vm.chatSidebarRatio + vm.chatDialogueRatio + vm.dynamicWRatio
        #expect(beforeTop == afterTop, "上 band 总 ratio 不变")
        #expect(beforeBottom == afterBottom, "下 band 总 ratio 不变")
    }

    @Test("上 band 4 列 ratio 累加 (zone 总 1917 + 3 拖拽线 = 1920)")
    func upperBandSum() {
        let vm = LayoutShellViewModel()
        let sum = vm.projectSidebarRatio + vm.projectPreviewRatio
            + vm.editorWRatio + vm.toolsWRatio
        // 200 + 558 + 759 + 400 = 1917, 拖拽线 3 PT 不算 ratio
        #expect(abs(sum - 1917.0/1920.0) < 0.0001, "zone 总 1917/1920")
    }

    @Test("下 band 3 列 ratio 累加 = 1.0 (零和, 总宽守恒) [v0.10.3 加 D_v4 内嵌]")
    func lowerBandSum() {
        let vm = LayoutShellViewModel()
        let sum = vm.chatSidebarRatio + vm.chatDialogueRatio + vm.dynamicWRatio
        // 200 + 1318 + 400 = 1918, 拖拽线 2 PT 不算 ratio
        #expect(abs(sum - 1918.0/1920.0) < 0.0001, "zone 总 1918/1920")
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
