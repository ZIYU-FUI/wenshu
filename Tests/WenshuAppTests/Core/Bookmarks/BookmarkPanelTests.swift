//
//  BookmarkPanelTests.swift · Wenshu · v0.19 ticket 22
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookmarkViewModel (Obsidian replica, 前端先不接入)")
struct BookmarkPanelTests {

    @Test("init 默认空")
    @MainActor
    func initDefault() {
        let vm = BookmarkViewModel()
        #expect(vm.bookmarks.isEmpty)
        #expect(vm.error == nil)
    }

    @Test("无 store 时 load 返回空")
    @MainActor
    func loadWithoutStore() async {
        let vm = BookmarkViewModel()
        await vm.load()
        #expect(vm.bookmarks.isEmpty)
        #expect(vm.error == nil)
    }
}
