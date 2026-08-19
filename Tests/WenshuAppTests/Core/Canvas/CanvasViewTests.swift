//
//  CanvasViewTests.swift · Wenshu · v0.19 ticket 13
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("CanvasViewModel (Obsidian replica, 前端先不接入)")
struct CanvasViewTests {

    @Test("init 默认空文档")
    @MainActor
    func initDefault() {
        let vm = CanvasViewModel()
        #expect(vm.document.nodes.isEmpty)
        #expect(vm.document.edges.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @Test("loadFromString 有效 JSON")
    @MainActor
    func loadFromStringValid() {
        let vm = CanvasViewModel()
        vm.loadFromString(#"{"nodes":[{"id":"n1","type":"text","x":0,"y":0,"width":100,"height":50,"text":"hi"}],"edges":[]}"#)
        #expect(vm.error == nil)
        #expect(vm.document.nodes.count == 1)
    }

    @Test("loadFromString 无效 JSON 抛错")
    @MainActor
    func loadFromStringInvalid() {
        let vm = CanvasViewModel()
        vm.loadFromString("{ invalid")
        #expect(vm.error != nil)
        #expect(vm.document.nodes.isEmpty)
    }
}
