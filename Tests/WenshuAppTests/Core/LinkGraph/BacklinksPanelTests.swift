//
//  BacklinksPanelTests.swift · Wenshu · v0.19 ticket 12
//  单元测试: BacklinksViewModel 数据通路 (不渲染实际 View, 老板 macOS 验后再补)
//
//  Swift 6 strict concurrency: ViewModel 是 @MainActor, test 用 @MainActor func 跨 actor 安全访问.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BacklinksViewModel (Obsidian replica, 前端先不接入)")
struct BacklinksPanelTests {

    @Test("init 默认空状态")
    @MainActor
    func initDefault() {
        let vm = BacklinksViewModel()
        #expect(vm.docId.isEmpty)
        #expect(vm.backlinks.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @Test("无 resolver 时 load 返回空")
    @MainActor
    func loadWithoutResolver() async {
        let vm = BacklinksViewModel()
        await vm.load(docId: "doc-X")
        #expect(vm.docId == "doc-X")
        #expect(vm.backlinks.isEmpty)
        #expect(vm.error == nil)
    }
}
