//
//  SearchPanelTests.swift · Wenshu · v0.19 ticket 17
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SearchViewModel (Obsidian replica, 前端先不接入)")
struct SearchPanelTests {

    @Test("init 默认空状态")
    @MainActor
    func initDefault() {
        let vm = SearchViewModel()
        #expect(vm.query.isEmpty)
        #expect(vm.results.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @Test("无 search 时 runSearch 返回空")
    @MainActor
    func runSearchWithoutSearch() async {
        let vm = SearchViewModel()
        vm.setQuery("test")
        await vm.runSearch()
        #expect(vm.results.isEmpty)
    }

    @Test("空 query 时 runSearch 不报错")
    @MainActor
    func runSearchEmptyQuery() async {
        let vm = SearchViewModel()
        await vm.runSearch()
        #expect(vm.results.isEmpty)
    }
}
