//
//  ComposerPanelTests.swift · Wenshu · v0.19 ticket 16
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ComposerViewModel (Obsidian replica, 前端先不接入)")
struct ComposerPanelTests {

    @Test("init 默认空")
    @MainActor
    func initDefault() {
        let vm = ComposerViewModel()
        #expect(vm.lastOperation.isEmpty)
        #expect(vm.lastResult.isEmpty)
    }

    @Test("rename 简单")
    @MainActor
    func renameSimple() {
        let vm = ComposerViewModel()
        vm.rename(oldName: "林黛玉", newName: "黛玉", content: "[[林黛玉]]")
        #expect(vm.lastOperation.contains("林黛玉"))
        #expect(vm.lastResult.contains("[[黛玉]]"))
    }
}
