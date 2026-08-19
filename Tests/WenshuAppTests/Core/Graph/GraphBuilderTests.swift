//
//  GraphBuilderTests.swift · Wenshu · v0.19 ticket 14
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("GraphBuilder (Obsidian replica)")
struct GraphBuilderTests {

    actor MockDocumentIndex: DocumentIndexing {
        private var nameToId: [String: String] = [:]
        private var idToName: [String: String] = [:]

        func setMapping(name: String, docId: String) {
            nameToId[name] = docId
            idToName[docId] = name
        }

        nonisolated func docId(forName name: String) async -> String? {
            await self.lookupDocId(forName: name)
        }

        nonisolated func name(forDocId docId: String) async -> String? {
            await self.lookupName(forDocId: docId)
        }

        private func lookupDocId(forName name: String) -> String? { nameToId[name] }
        private func lookupName(forDocId docId: String) -> String? { idToName[docId] }
    }

    @Test("build 空 links 返回空图")
    func buildEmpty() async {
        let index = MockDocumentIndex()
        let graph = await GraphBuilder.build(links: [], documentIndex: index)
        #expect(graph.nodes.isEmpty)
        #expect(graph.edges.isEmpty)
    }

    @Test("build 单边 → 2 节点 + 1 边")
    func buildSingleEdge() async {
        let index = MockDocumentIndex()
        await index.setMapping(name: "林黛玉", docId: "doc-LD")
        let link = Link(sourceDocId: "doc-chapter", targetRef: "林黛玉", targetDocId: "doc-LD", line: 0, offset: 0)
        let graph = await GraphBuilder.build(links: [link], documentIndex: index)
        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)
        #expect(graph.nodes.first { $0.id == "doc-chapter" }?.links == 1)
        #expect(graph.nodes.first { $0.id == "doc-LD" }?.links == 1)
    }

    @Test("build unresolved link 跳过")
    func buildUnresolvedSkipped() async {
        let index = MockDocumentIndex()
        let link = Link(sourceDocId: "doc-A", targetRef: "未创建", targetDocId: nil, line: 0, offset: 0)
        let graph = await GraphBuilder.build(links: [link], documentIndex: index)
        #expect(graph.nodes.isEmpty, "unresolved link 不创建 nodes")
        #expect(graph.edges.isEmpty)
    }

    @Test("build 多边去重")
    func buildMultipleEdgesDedupe() async {
        let index = MockDocumentIndex()
        await index.setMapping(name: "林黛玉", docId: "doc-LD")
        let links = [
            Link(sourceDocId: "doc-A", targetRef: "林黛玉", targetDocId: "doc-LD", line: 0, offset: 0),
            Link(sourceDocId: "doc-A", targetRef: "林黛玉", targetDocId: "doc-LD", line: 1, offset: 0),
            Link(sourceDocId: "doc-B", targetRef: "林黛玉", targetDocId: "doc-LD", line: 0, offset: 0),
        ]
        let graph = await GraphBuilder.build(links: links, documentIndex: index)
        #expect(graph.nodes.count == 3)  // doc-A, doc-B, doc-LD
        #expect(graph.edges.count == 2)  // 2 unique source → doc-LD
    }

    @Test("layout 1 节点原样")
    func layoutSingleNode() {
        let graph = Graph(nodes: [GraphNode(id: "a", label: "A")])
        let layout = GraphBuilder.layout(graph)
        #expect(layout.nodes.count == 1)
    }

    @Test("layout 2 节点分配坐标")
    func layoutTwoNodes() {
        let graph = Graph(
            nodes: [GraphNode(id: "a", label: "A"), GraphNode(id: "b", label: "B")],
            edges: [GraphEdge(id: "a->b", sourceId: "a", targetId: "b")]
        )
        let layout = GraphBuilder.layout(graph, iterations: 100)
        let a = layout.nodes.first { $0.id == "a" }!
        let b = layout.nodes.first { $0.id == "b" }!
        // 坐标应在画布范围内 [0, 1000]
        #expect(a.x >= 0 && a.x <= 1000)
        #expect(b.x >= 0 && b.x <= 1000)
        // 经过 100 次迭代, 坐标应改变 (不再是初始随机)
        // 这里只检查坐标有效
        _ = (a.x, b.x)
    }

    @Test("local graph 1-hop")
    func localGraph() {
        let graph = Graph(
            nodes: [
                GraphNode(id: "a", label: "A"),
                GraphNode(id: "b", label: "B"),
                GraphNode(id: "c", label: "C"),
            ],
            edges: [
                GraphEdge(id: "a->b", sourceId: "a", targetId: "b"),
                GraphEdge(id: "b->c", sourceId: "b", targetId: "c"),
            ]
        )
        let local = GraphBuilder.localGraph(fullGraph: graph, centerId: "a", depth: 1)
        #expect(local.nodes.map { $0.id }.sorted() == ["a", "b"])
        #expect(local.edges.count == 1)
        #expect(local.edges[0].sourceId == "a")
    }

    @Test("local graph 2-hop")
    func localGraphDeep() {
        let graph = Graph(
            nodes: [
                GraphNode(id: "a", label: "A"),
                GraphNode(id: "b", label: "B"),
                GraphNode(id: "c", label: "C"),
                GraphNode(id: "d", label: "D"),
            ],
            edges: [
                GraphEdge(id: "a->b", sourceId: "a", targetId: "b"),
                GraphEdge(id: "b->c", sourceId: "b", targetId: "c"),
                GraphEdge(id: "c->d", sourceId: "c", targetId: "d"),
            ]
        )
        let local = GraphBuilder.localGraph(fullGraph: graph, centerId: "a", depth: 2)
        #expect(local.nodes.map { $0.id }.sorted() == ["a", "b", "c"])
    }
}
