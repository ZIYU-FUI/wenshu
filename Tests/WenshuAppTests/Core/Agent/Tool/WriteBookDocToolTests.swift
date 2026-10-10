//
//  WriteBookDocToolTests.swift · wenshu · round-73 (= boss 2026-10-10)
//
//  Unit tests for WriteBookDocTool. The
//  tool writes to a temp dir (= does NOT
//  touch the user's actual library).
//
//  Coverage:
//    1. Success path: writes the file;
//       returns the canonical path + byte
//       count.
//    2. Absolute path rejected (= must
//       throw invalidInput).
//    3. `..` escape rejected (= must throw
//       pathGuardViolation).
//    4. No active book rejected (= must
//       throw invalidInput).
//

import XCTest
@testable import WenshuApp

final class WriteBookDocToolTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        // Per-test temp dir (= cleaned up
        // in tearDown).
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WriteBookDocToolTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Success

    func testWriteRelativePathSucceeds() async throws {
        let bookPath = tempDir.path
        let tool = WriteBookDocTool(
            bookPathProvider: { bookPath }
        )
        let input = """
        {"path": "world/核心设定.md", "body": "# 核心设定\\n\\ncontent here"}
        """
        let output = try await tool.execute(input: input)
        // Output = JSON: {path, bytes, success: true}.
        let data = output.data(using: .utf8)!
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(dict["success"] as? Bool, true)
        XCTAssertEqual(dict["bytes"] as? Int, 16)
        XCTAssertTrue(
            (dict["path"] as? String ?? "").hasSuffix("/world/核心设定.md")
        )
        // The file must actually exist on
        // disk (= real persistence, not
        // stub).
        let target = tempDir
            .appendingPathComponent("world/核心设定.md")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: target.path),
            "The file must be on disk after tool execution."
        )
        let written = try String(contentsOf: target, encoding: .utf8)
        XCTAssertEqual(written, "# 核心设定\n\ncontent here")
    }

    // MARK: - Absolute path rejection

    func testAbsolutePathIsRejected() async throws {
        let bookPath = tempDir.path
        let tool = WriteBookDocTool(
            bookPathProvider: { bookPath }
        )
        let input = """
        {"path": "/etc/passwd", "body": "sneaky"}
        """
        do {
            _ = try await tool.execute(input: input)
            XCTFail("Expected invalidInput for absolute path, but tool succeeded.")
        } catch {
            guard let err = error as? ToolExecutorError else {
                XCTFail("Expected ToolExecutorError, got \(error)")
                return
            }
            if case let .invalidInput(name, reason) = err {
                XCTAssertEqual(name, "writeBookDoc")
                XCTAssertTrue(reason.contains("relative"))
            } else {
                XCTFail("Expected invalidInput, got \(err)")
            }
        }
    }

    // MARK: - Path escape rejection

    func testParentDirectoryEscapeIsRejected() async throws {
        let bookPath = tempDir.path
        let tool = WriteBookDocTool(
            bookPathProvider: { bookPath }
        )
        let input = """
        {"path": "../escape.md", "body": "escape attempt"}
        """
        do {
            _ = try await tool.execute(input: input)
            XCTFail("Expected pathGuardViolation for `..` escape, but tool succeeded.")
        } catch {
            guard let err = error as? ToolExecutorError else {
                XCTFail("Expected ToolExecutorError, got \(error)")
                return
            }
            if case let .pathGuardViolation(name, _, _) = err {
                XCTAssertEqual(name, "writeBookDoc")
            } else {
                XCTFail("Expected pathGuardViolation, got \(err)")
            }
        }
    }

    // MARK: - No active book

    func testNoActiveBookIsRejected() async throws {
        let tool = WriteBookDocTool(
            bookPathProvider: { nil }
        )
        let input = """
        {"path": "world/核心设定.md", "body": "x"}
        """
        do {
            _ = try await tool.execute(input: input)
            XCTFail("Expected invalidInput when no active book, but tool succeeded.")
        } catch {
            guard let err = error as? ToolExecutorError else {
                XCTFail("Expected ToolExecutorError, got \(error)")
                return
            }
            if case let .invalidInput(name, reason) = err {
                XCTAssertEqual(name, "writeBookDoc")
                XCTAssertTrue(reason.contains("No active book"))
            } else {
                XCTFail("Expected invalidInput, got \(err)")
            }
        }
    }

    // MARK: - Missing required field

    func testMissingBodyFieldIsRejected() async throws {
        let bookPath = tempDir.path
        let tool = WriteBookDocTool(
            bookPathProvider: { bookPath }
        )
        let input = """
        {"path": "world/x.md"}
        """
        do {
            _ = try await tool.execute(input: input)
            XCTFail("Expected throw for missing body field.")
        } catch {
            // Expected (= parse failure or
            // toolFailed).
        }
    }
}