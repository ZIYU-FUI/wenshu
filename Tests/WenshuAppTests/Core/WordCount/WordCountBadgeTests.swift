//
//  WordCountBadgeTests.swift · Wenshu · v0.19 ticket 20
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WordCountViewModel (Obsidian replica, 前端先不接入)")
struct WordCountBadgeTests {

    @Test("init 默认 0")
    @MainActor
    func initDefault() {
        let vm = WordCountViewModel()
        #expect(vm.count.words == 0)
        #expect(vm.count.characters == 0)
    }

    @Test("update 中文")
    @MainActor
    func updateChinese() {
        let vm = WordCountViewModel()
        vm.update(content: "林黛玉进贾府")
        #expect(vm.count.chineseChars == 6)
    }

    @Test("update 英文")
    @MainActor
    func updateEnglish() {
        let vm = WordCountViewModel()
        vm.update(content: "Hello world foo bar")
        #expect(vm.count.words == 4)
    }
}
