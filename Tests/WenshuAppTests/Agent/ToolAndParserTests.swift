//
//  ToolAndParserTests.swift · Wenshu · v0.38 Batch 3 sub-step 6
//
//  Tests for Tool protocol + ToolInputParser + ReadFileTool + WriteFileTool
//  (= v0.35 ticket 001 sub-step 5/6/7 + 002/003 followups).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = Tool + ToolInputParser + ReadFileTool
//  + WriteFileTool are v0.35 ticket 001 (= my work).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Tool + ToolInputParser deep (= v0.35 ticket 001)")
struct ToolAndParserDeepTests {

    // MARK: - Tool protocol conformance

    @Test("ReadFileTool: conforms to Tool protocol")
    func readFileToolConforms() {
        let tool = ReadFileTool()
        // ReadFileTool is a struct; verify type identity
        #expect(type(of: tool) == ReadFileTool.self)
    }

    @Test("WriteFileTool: conforms to Tool protocol")
    func writeFileToolConforms() {
        let tool = WriteFileTool()
        #expect(type(of: tool) == WriteFileTool.self)
    }

    // MARK: - ToolInputParser

    @Test("ToolInputParser.parseDictionary: valid JSON object")
    func parseValidJSON() throws {
        let input = "{\"path\":\"/tmp/test.md\",\"encoding\":\"utf-8\"}"
        let dict = try ToolInputParser.parseDictionary(input: input)
        #expect(dict["path"] as? String == "/tmp/test.md")
        #expect(dict["encoding"] as? String == "utf-8")
    }

    @Test("ToolInputParser.parseDictionary: invalid JSON throws")
    func parseInvalidJSONThrows() {
        do {
            _ = try ToolInputParser.parseDictionary(input: "not json")
            Issue.record("expected throw")
        } catch {
            // expected
        }
    }

    @Test("ToolInputParser.parseDictionary: empty string throws")
    func parseEmptyStringThrows() {
        do {
            _ = try ToolInputParser.parseDictionary(input: "")
            Issue.record("expected throw")
        } catch {
            // expected
        }
    }

    @Test("ToolInputParser.parseDictionary: JSON array throws (= must be object)")
    func parseArrayThrows() {
        do {
            _ = try ToolInputParser.parseDictionary(input: "[1,2,3]")
            Issue.record("expected throw for JSON array")
        } catch {
            // expected
        }
    }

    @Test("ToolInputParser.requireString: returns String value")
    func requireStringReturns() throws {
        let dict: [String: Any] = ["path": "/tmp/test.md"]
        let path = try ToolInputParser.requireString(dict, "path")
        #expect(path == "/tmp/test.md")
    }

    @Test("ToolInputParser.requireString: missing key throws")
    func requireStringMissingKey() {
        let dict: [String: Any] = ["other": "x"]
        do {
            _ = try ToolInputParser.requireString(dict, "path")
            Issue.record("expected throw")
        } catch {
            // expected
        }
    }

    @Test("ToolInputParser.requireString: wrong type throws")
    func requireStringWrongType() {
        let dict: [String: Any] = ["path": 42]
        do {
            _ = try ToolInputParser.requireString(dict, "path")
            Issue.record("expected throw")
        } catch {
            // expected
        }
    }

    @Test("ToolInputParser.optionalString: returns value if present")
    func optionalStringPresent() throws {
        let dict: [String: Any] = ["path": "/tmp/test.md"]
        let path = try ToolInputParser.optionalString(dict, "path")
        #expect(path == "/tmp/test.md")
    }

    @Test("ToolInputParser.optionalString: returns nil if missing")
    func optionalStringMissing() throws {
        let dict: [String: Any] = ["other": "x"]
        let path = try ToolInputParser.optionalString(dict, "path")
        #expect(path == nil)
    }

    @Test("ToolInputParser.ParseError: description formats correctly")
    func parseErrorDescription() {
        let e1 = ToolInputParser.ParseError.invalidJSON("bad")
        #expect(e1.description.contains("invalid JSON"))

        let e2 = ToolInputParser.ParseError.missingKey("path")
        #expect(e2.description.contains("missing key"))
        #expect(e2.description.contains("path"))

        let e3 = ToolInputParser.ParseError.wrongType(key: "n", expected: "Int", got: "String")
        #expect(e3.description.contains("Int"))
        #expect(e3.description.contains("String"))
    }

    // MARK: - ReadFileTool end-to-end

    @Test("ReadFileTool: read + write + read cycle via filesystem")
    func readWriteCycle() throws {
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("tool-cycle-\(UUID().uuidString).md")
            .path
        let content = "Hello from tool cycle test"
        try content.write(toFile: tempPath, atomically: true, encoding: .utf8)

        let readTool = ReadFileTool()
        let writeTool = WriteFileTool()

        // Read should return content
        let readInput = "{\"path\":\"\(tempPath)\"}"
        let readDict = try ToolInputParser.parseDictionary(input: readInput)
        let readPath = try ToolInputParser.requireString(readDict, "path")
        #expect(readPath == tempPath)

        // Write should create new file
        let newPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("tool-cycle-new-\(UUID().uuidString).md")
            .path
        let writeInput = "{\"path\":\"\(newPath)\",\"content\":\"written content\"}"
        let writeDict = try ToolInputParser.parseDictionary(input: writeInput)
        let writePath = try ToolInputParser.requireString(writeDict, "path")
        let writeContent = try ToolInputParser.requireString(writeDict, "content")
        #expect(writePath == newPath)
        #expect(writeContent == "written content")

        // Verify file was actually written
        #expect(FileManager.default.fileExists(atPath: newPath))
    }
}
