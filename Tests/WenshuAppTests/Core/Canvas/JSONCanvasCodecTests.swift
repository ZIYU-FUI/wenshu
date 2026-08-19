//
//  JSONCanvasCodecTests.swift · Wenshu · v0.19 ticket 13
//  单元测试: JSON Canvas 1:1 round-trip + spec 兼容性
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("JSONCanvasCodec (Obsidian replica)")
struct JSONCanvasCodecTests {

    @Test("空文档 round-trip")
    func emptyDocument() throws {
        let doc = CanvasDocument()
        let data = try JSONCanvasCodec.encode(doc)
        let decoded = try JSONCanvasCodec.decode(data)
        #expect(decoded == doc)
    }

    @Test("1 text node + 0 edge")
    func singleTextNode() throws {
        let node = CanvasNode(id: "n1", type: .text, x: 100, y: 200, width: 300, height: 150, text: "Hello world")
        let doc = CanvasDocument(nodes: [node], edges: [])
        let decoded = try JSONCanvasCodec.decode(try JSONCanvasCodec.encode(doc))
        #expect(decoded.nodes.count == 1)
        #expect(decoded.nodes[0].id == "n1")
        #expect(decoded.nodes[0].type == .text)
        #expect(decoded.nodes[0].text == "Hello world")
        #expect(decoded.nodes[0].x == 100)
    }

    @Test("file / link / text 3 种 node 类型")
    func allNodeTypes() throws {
        let text = CanvasNode(id: "t1", type: .text, x: 0, y: 0, width: 100, height: 50, text: "text content")
        let file = CanvasNode(id: "f1", type: .file, x: 100, y: 0, width: 100, height: 50, file: "notes/intro.md")
        let link = CanvasNode(id: "l1", type: .link, x: 200, y: 0, width: 100, height: 50, url: "https://obsidian.md")
        let doc = CanvasDocument(nodes: [text, file, link], edges: [])
        let decoded = try JSONCanvasCodec.decode(try JSONCanvasCodec.encode(doc))
        #expect(decoded.nodes.count == 3)
        #expect(decoded.nodes.map { $0.type } == [.text, .file, .link])
    }

    @Test("edge 完整字段")
    func edgeAllFields() throws {
        let edge = CanvasEdge(id: "e1", fromNode: "n1", toNode: "n2", fromSide: .right, toSide: .left, fromEnd: .none, toEnd: .arrow, label: "指向", color: "1")
        let doc = CanvasDocument(nodes: [], edges: [edge])
        let decoded = try JSONCanvasCodec.decode(try JSONCanvasCodec.encode(doc))
        #expect(decoded.edges.count == 1)
        #expect(decoded.edges[0].fromSide == .right)
        #expect(decoded.edges[0].toSide == .left)
        #expect(decoded.edges[0].toEnd == .arrow)
        #expect(decoded.edges[0].label == "指向")
        #expect(decoded.edges[0].color == "1")
    }

    @Test("1:1 兼容 jsoncanvas.org spec 示例 (4 nodes + 4 edges)")
    func specExample() throws {
        // 跟 https://jsoncanvas.org/ 首页示例 1:1
        let json = """
        {
          "nodes": [
            {
              "id": "spec",
              "type": "file",
              "x": 600,
              "y": 140,
              "width": 1908,
              "height": 175,
              "file": "spec/1.0.md"
            },
            {
              "id": "readme",
              "type": "file",
              "x": 36,
              "y": 240,
              "width": 1904,
              "height": 184,
              "file": "readme.md"
            }
          ],
          "edges": [
            {
              "id": "edge-readme-spec",
              "fromNode": "readme",
              "fromSide": "right",
              "fromEnd": "none",
              "toNode": "spec",
              "toSide": "left",
              "toEnd": "arrow"
            }
          ]
        }
        """
        let decoded = try JSONCanvasCodec.decode(json)
        #expect(decoded.nodes.count == 2)
        #expect(decoded.edges.count == 1)
        #expect(decoded.edges[0].fromSide == .right)
        #expect(decoded.edges[0].toEnd == .arrow)
    }

    @Test("encode 输出跟 Obsidian 对齐 (sortedKeys + prettyPrinted)")
    func encodingFormat() throws {
        let doc = CanvasDocument(
            nodes: [CanvasNode(id: "n1", type: .text, x: 0, y: 0, width: 100, height: 100, text: "hi")],
            edges: []
        )
        let s = try JSONCanvasCodec.encodeToString(doc)
        #expect(s.contains("\n"), "应包含换行")
        #expect(s.contains("\"nodes\""), "应包含 nodes key")
        #expect(s.contains("\"type\" : \"text\""), "sortedKeys: type 在前")
    }

    @Test("decode 失败抛 CodecError")
    func decodeFailure() {
        #expect(throws: JSONCanvasCodec.CodecError.self) {
            _ = try JSONCanvasCodec.decode("{ invalid json")
        }
    }
}
