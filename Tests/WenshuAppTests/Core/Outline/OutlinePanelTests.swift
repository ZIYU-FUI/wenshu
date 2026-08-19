//
//  OutlinePanelTests.swift · Wenshu · v0.19 ticket 21
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("OutlineViewModel (Obsidian replica, 前端先不接入)")
struct OutlinePanelTests {

    @Test("init 默认空")
    @MainActor
    func initDefault() {
        let vm = OutlineViewModel()
        #expect(vm.items.isEmpty)
        #expect(vm.tree.isEmpty)
    }

    @Test("update 解析")
    @MainActor
    func updateParse() {
        let vm = OutlineViewModel()
        vm.update(content: "# H1\n## H2")
        #expect(vm.items.count == 2)
        #expect(vm.tree.count == 1)
    }
}
