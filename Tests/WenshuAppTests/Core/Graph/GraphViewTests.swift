//
//  GraphViewTests.swift · Wenshu · v0.19 ticket 14
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("GraphViewModel (Obsidian replica, 前端先不接入)")
struct GraphViewTests {

    @Test("init 默认空")
    @MainActor
    func initDefault() {
        let vm = GraphViewModel()
        #expect(vm.graph.nodes.isEmpty)
        #expect(vm.graph.edges.isEmpty)
    }

    @Test("setGraph 直接设置")
    @MainActor
    func setGraph() {
        let vm = GraphViewModel()
        let graph = Graph(
            nodes: [GraphNode(id: "a", label: "A")],
            edges: []
        )
        vm.setGraph(graph)
        #expect(vm.graph.nodes.count == 1)
    }
}
