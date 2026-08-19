//
//  QuickSwitcherWindowTests.swift · Wenshu · v0.19 ticket 19
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("QuickSwitcherViewModel (Obsidian replica, 前端先不接入)")
struct QuickSwitcherWindowTests {

    @Test("init 默认空")
    @MainActor
    func initDefault() {
        let vm = QuickSwitcherViewModel()
        #expect(vm.query.isEmpty)
        #expect(vm.results.isEmpty)
    }

    @Test("addItem + setQuery 搜索")
    @MainActor
    func addAndSearch() {
        let vm = QuickSwitcherViewModel()
        vm.addItem(SwitcherItem(id: "1", title: "林黛玉"))
        vm.setQuery("林")
        #expect(vm.results.count == 1)
    }
}
