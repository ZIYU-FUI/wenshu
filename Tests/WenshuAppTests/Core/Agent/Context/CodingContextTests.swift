//
//  CodingContextTests.swift · Wenshu · HERMES-INTERNAL-002 (2026-09-04)
//
//  Round-trip tests for CodingContext (= hermes coding_context.py port).
//
//  Tests covered:
//    1. testAggregate_swiftFile        — .swift file → CodingContext with imports
//    2. testAggregate_unsupportedExtension — .xyz file → throws
//    3. testAggregate_missingFile      — non-existent path → throws
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("CodingContext (HERMES-INTERNAL-002)")
struct CodingContextTests {

    @Test("aggregate reads a Swift file and extracts its imports")
    func testAggregate_swiftFile() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu_coding_context_\(UUID().uuidString).swift")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let body = """
        // swift file
        import Foundation
        import WenshuApp
        import os

        public struct Demo {}
        """
        try body.write(to: tmp, atomically: true, encoding: .utf8)

        let aggregator = CodingContextAggregator()
        let context = try await aggregator.aggregate(for: tmp.path)
        #expect(context.language == "swift")
        #expect(context.filePath == tmp.path)
        #expect(context.imports.contains("Foundation"))
        #expect(context.imports.contains("WenshuApp"))
        #expect(context.imports.contains("os"))
        #expect(context.snippet != nil)
        #expect(context.snippet?.contains("public struct Demo") ?? false)
    }

    @Test("aggregate throws for an unsupported file extension")
    func testAggregate_unsupportedExtension() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu_coding_context_\(UUID().uuidString).xyz")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try "hello".write(to: tmp, atomically: true, encoding: .utf8)

        let aggregator = CodingContextAggregator()
        await #expect(throws: CodingContextError.self) {
            _ = try await aggregator.aggregate(for: tmp.path)
        }
    }

    @Test("aggregate throws when the file does not exist")
    func testAggregate_missingFile() async throws {
        let aggregator = CodingContextAggregator()
        await #expect(throws: CodingContextError.self) {
            _ = try await aggregator.aggregate(for: "/tmp/does-not-exist-\(UUID().uuidString).swift")
        }
    }
}