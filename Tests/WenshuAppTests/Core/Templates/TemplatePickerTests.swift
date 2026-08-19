//
//  TemplatePickerTests.swift · Wenshu · v0.19 ticket 15
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("TemplateViewModel (Obsidian replica, 前端先不接入)")
struct TemplatePickerTests {

    @Test("init 默认空")
    @MainActor
    func initDefault() {
        let vm = TemplateViewModel()
        #expect(vm.template.isEmpty)
        #expect(vm.rendered.isEmpty)
        #expect(vm.title.isEmpty)
        #expect(vm.error == nil)
    }

    @Test("load + render 简单模板")
    @MainActor
    func loadAndRender() {
        let vm = TemplateViewModel()
        vm.load(template: "Hello {{title}}", title: "World")
        vm.render()
        #expect(vm.rendered == "Hello World")
        #expect(vm.error == nil)
    }
}
