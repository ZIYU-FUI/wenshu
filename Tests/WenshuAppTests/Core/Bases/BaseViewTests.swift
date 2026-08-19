//
//  BaseViewTests.swift · Wenshu · v0.19 ticket 18
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BaseViewModel (Obsidian replica, 前端先不接入)")
struct BaseViewTests {

    @Test("init 默认空")
    @MainActor
    func initDefault() {
        let vm = BaseViewModel()
        #expect(vm.document.viewCount == 0)
        #expect(vm.document.formulas.isEmpty)
        #expect(vm.yamlSource.isEmpty)
        #expect(vm.error == nil)
    }

    @Test("load 有效 YAML")
    @MainActor
    func loadValid() {
        let vm = BaseViewModel()
        vm.load(yaml: """
        formulas:
          price_formatted: 'price.toFixed(2)'
        """)
        #expect(vm.error == nil)
        #expect(vm.document.formulas.count == 1)
    }
}
