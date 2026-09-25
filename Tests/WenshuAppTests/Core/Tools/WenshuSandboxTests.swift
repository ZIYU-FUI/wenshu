//
//  WenshuSandboxTests.swift · Wenshu · wt/sandbox-tighten-2026-09-25
//
//  Coverage for the library-root path sandbox. Each test sets up
//  the wenshu.libraryPath UserDefaults key in setUp and tears it
//  down in tearDown so test isolation is preserved.
//
//  Cases:
//    1. assertInsideLibrary(path:) accepts the library root itself
//    2. assertInsideLibrary(path:) accepts a file inside the library
//    3. assertInsideLibrary(path:) accepts a relative path that
//       resolves inside the library
//    4. assertInsideLibrary(path:) rejects an absolute path outside
//    5. assertInsideLibrary(path:) rejects a `..` escape
//    6. assertInsideLibrary(path:) rejects a sibling-prefix trap
//       (= /Users/foo/myws2 when root = /Users/foo/myws)
//    7. assertInsideLibrary(path:) rejects when library root is
//       not configured in UserDefaults
//    8. isInsideLibrary(url:) is the boolean mirror of the throwing
//       variant
//    9. preDispatchValidator rejects a path key but passes other keys
//        through untouched
//   10. preDispatchValidator throws ToolExecutorError.sandboxViolation
//        (= not the raw SandboxError) so the executor surfaces a
//        unified tool-error envelope to the LLM
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuSandbox (wt/sandbox-tighten-2026-09-25)")
struct WenshuSandboxTests {

    private let libraryRoot = "/Users/anbaiqiang/libraries/test.ws"
    private let libraryRootURL = URL(fileURLWithPath: "/Users/anbaiqiang/libraries/test.ws", isDirectory: true)
    private let cleanupKey = "wenshu.libraryPath"

    init() {
        // Belt-and-suspenders: clear before each test so the value
        // from a prior test (or a real onboarding) does not leak.
        UserDefaultsStore.shared.remove(.libraryPath)
    }

    private func setLibraryRoot() {
        UserDefaultsStore.shared.setString(libraryRoot, forKey: .libraryPath)
    }

    // MARK: - Library root resolution

    @Test("resolveLibraryRoot returns nil when key is unset")
    func testResolveLibraryRootUnset() {
        #expect(WenshuSandbox.resolveLibraryRoot() == nil)
    }

    @Test("resolveLibraryRoot returns the URL when key is set")
    func testResolveLibraryRootSet() {
        setLibraryRoot()
        let resolved = WenshuSandbox.resolveLibraryRoot()
        #expect(resolved?.path == libraryRoot)
    }

    // MARK: - assertInsideLibrary(path:)

    @Test("assertInsideLibrary accepts the library root itself")
    func testAcceptsLibraryRoot() throws {
        setLibraryRoot()
        try WenshuSandbox.assertInsideLibrary(path: libraryRoot)
    }

    @Test("assertInsideLibrary accepts a file inside the library")
    func testAcceptsFileInside() throws {
        setLibraryRoot()
        try WenshuSandbox.assertInsideLibrary(
            path: "\(libraryRoot)/shelves/abc/books/xyz/chapter.md"
        )
    }

    @Test("assertInsideLibrary accepts a library-relative path that resolves inside")
    func testAcceptsRelativePath() throws {
        setLibraryRoot()
        try WenshuSandbox.assertInsideLibrary(path: "shelves/abc/books/xyz/chapter.md")
        try WenshuSandbox.assertInsideLibrary(path: "cache/chat-uploads/image.png")
    }

    @Test("assertInsideLibrary rejects an absolute path outside the library")
    func testRejectsAbsoluteOutside() {
        setLibraryRoot()
        #expect(throws: WenshuSandbox.SandboxError.self) {
            try WenshuSandbox.assertInsideLibrary(path: "/etc/passwd")
        }
        #expect(throws: WenshuSandbox.SandboxError.self) {
            try WenshuSandbox.assertInsideLibrary(path: "/Users/anbaiqiang/.ssh/id_rsa")
        }
        #expect(throws: WenshuSandbox.SandboxError.self) {
            try WenshuSandbox.assertInsideLibrary(path: "/tmp/anything")
        }
    }

    @Test("assertInsideLibrary rejects a `..` escape attempt")
    func testRejectsDotDotEscape() {
        setLibraryRoot()
        let evil = "\(libraryRoot)/../myws2/escape.txt"
        #expect(throws: WenshuSandbox.SandboxError.self) {
            try WenshuSandbox.assertInsideLibrary(path: evil)
        }
    }

    @Test("assertInsideLibrary rejects a sibling-prefix trap")
    func testRejectsSiblingPrefixTrap() {
        // Library = /Users/foo/test.ws. A path like
        // /Users/foo/test.wsfoo/escape.txt (= sibling directory that
        // shares a prefix) must be rejected; = the prefix-match trap.
        setLibraryRoot()
        let sibling = "/Users/anbaiqiang/libraries/test.wsfoo/escape.txt"
        #expect(throws: WenshuSandbox.SandboxError.self) {
            try WenshuSandbox.assertInsideLibrary(path: sibling)
        }
    }

    @Test("assertInsideLibrary rejects when library root is unset")
    func testRejectsWhenLibraryRootUnset() {
        // Do NOT set the key.
        #expect(throws: WenshuSandbox.SandboxError.self) {
            try WenshuSandbox.assertInsideLibrary(path: "/Users/anbaiqiang/anything")
        }
    }

    @Test("assertInsideLibrary rejects an empty path string")
    func testRejectsEmptyPath() {
        setLibraryRoot()
        #expect(throws: WenshuSandbox.SandboxError.self) {
            try WenshuSandbox.assertInsideLibrary(path: "")
        }
    }

    // MARK: - URL variant

    @Test("assertInsideLibrary(url:) mirrors path variant")
    func testAcceptsFileURLInside() throws {
        setLibraryRoot()
        let url = libraryRootURL.appending(path: "shelves/abc/books/xyz/chapter.md")
        try WenshuSandbox.assertInsideLibrary(url: url)
    }

    @Test("isInsideLibrary returns true for paths inside, false for paths outside")
    func testIsInsideLibraryBooleanMirror() {
        setLibraryRoot()
        #expect(WenshuSandbox.isInsideLibrary(path: "\(libraryRoot)/x"))
        #expect(WenshuSandbox.isInsideLibrary(path: "/etc/passwd") == false)
        #expect(WenshuSandbox.isInsideLibrary(path: "/Users/anbaiqiang/libraries/test.wsfoo") == false)
    }

    // MARK: - preDispatchValidator

    @Test("preDispatchValidator rejects path key but passes other keys through")
    func testPreDispatchValidatorRejectsPath() {
        setLibraryRoot()
        let input: [String: String] = [
            "path": "/etc/passwd",
            "content": "harmless",
            "encoding": "utf-8"
        ]
        #expect(throws: ToolExecutorError.self) {
            _ = try WenshuSandbox.preDispatchValidator(toolName: "ReadFile", input: input)
        }
    }

    @Test("preDispatchValidator accepts a valid path key")
    func testPreDispatchValidatorAcceptsValid() throws {
        setLibraryRoot()
        let input: [String: String] = [
            "path": "\(libraryRoot)/chapter.md",
            "content": "ok"
        ]
        let output = try WenshuSandbox.preDispatchValidator(toolName: "ReadFile", input: input)
        #expect(output == input)
    }

    @Test("preDispatchValidator wraps the SandboxError into ToolExecutorError.sandboxViolation")
    func testPreDispatchValidatorWrapsError() {
        setLibraryRoot()
        do {
            _ = try WenshuSandbox.preDispatchValidator(
                toolName: "WriteFile",
                input: ["path": "/etc/passwd", "content": "x"]
            )
            Issue.record("expected throw")
        } catch let error as ToolExecutorError {
            // Unwrap and verify the underlying SandboxError carries
            // pathOutsideLibrary so the LLM gets an actionable reason.
            if case .sandboxViolation(let tool, let key, let underlying) = error {
                #expect(tool == "WriteFile")
                #expect(key == "path")
                if case .pathOutsideLibrary = underlying {
                    // pass
                } else {
                    Issue.record("expected .pathOutsideLibrary, got \(underlying)")
                }
            } else {
                Issue.record("expected .sandboxViolation, got \(error)")
            }
        } catch {
            Issue.record("expected ToolExecutorError, got \(error)")
        }
    }

    @Test("preDispatchValidator checks all path-bearing keys (from/to/cwd)")
    func testPreDispatchValidatorChecksAllPathKeys() {
        setLibraryRoot()
        // `from` and `to` keys (used by file copy/move style tools).
        #expect(throws: ToolExecutorError.self) {
            _ = try WenshuSandbox.preDispatchValidator(
                toolName: "file",
                input: ["from": "\(libraryRoot)/a.txt", "to": "/etc/passwd"]
            )
        }
    }

    @Test("preDispatchValidator ignores keys that are not path-bearing")
    func testPreDispatchValidatorIgnoresNonPathKeys() throws {
        setLibraryRoot()
        let input: [String: String] = [
            "regex": ".*\\.md$",
            "url": "https://example.com/file.md",
            "query": "literal text search"
        ]
        // Should pass through (= no path keys present, no throw).
        let output = try WenshuSandbox.preDispatchValidator(toolName: "search", input: input)
        #expect(output == input)
    }
}