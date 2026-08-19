//
//  BaseParserTests.swift · Wenshu · v0.19 ticket 18
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BaseParser (Obsidian replica)")
struct BaseParserTests {

    @Test("空文档")
    func empty() throws {
        let doc = try BaseParser.parse("")
        #expect(doc.viewCount == 0)
        #expect(doc.formulas.isEmpty)
    }

    @Test("formulas 简单 key: value")
    func formulasSimple() throws {
        let yaml = """
        formulas:
          formatted_price: 'if(price, price.toFixed(2) + " dollars")'
          ppu: "(price / age).toFixed(2)"
        """
        let doc = try BaseParser.parse(yaml)
        #expect(doc.formulas.count == 2)
        #expect(doc.formulas[0].name == "formatted_price")
        #expect(doc.formulas[0].expression.contains("price"))
        #expect(doc.formulas[1].name == "ppu")
    }

    @Test("encode → decode round-trip")
    func encodeDecodeRoundTrip() throws {
        let original = BaseDocument(
            formulas: [BaseFormula(name: "test", expression: "price.toFixed(2)")],
            viewCount: 1
        )
        let encoded = BaseParser.encode(original)
        let decoded = try BaseParser.parse(encoded)
        #expect(decoded.viewCount == 1)
        #expect(decoded.formulas.count == 1)
        #expect(decoded.formulas[0].name == "test")
    }

    @Test("comments 忽略")
    func commentsIgnored() throws {
        let yaml = """
        # 这是注释
        formulas:
          # nested comment
          x: "value"
        """
        let doc = try BaseParser.parse(yaml)
        #expect(doc.formulas.count == 1)
    }

    @Test("空行忽略")
    func blankLinesIgnored() throws {
        let yaml = """

        formulas:

          x: "value"

        """
        let doc = try BaseParser.parse(yaml)
        #expect(doc.formulas.count == 1)
    }
}
