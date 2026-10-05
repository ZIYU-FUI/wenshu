//
//  PathGuardTests.swift · Wenshu · wt/path-guard-v2-2026-09-25
//
//  Coverage for the typed allow-list policy PathGuard (= renamed
//  from v1's WenshuSandbox). Covers: resolveLibraryRoot /
//  canonicalization / inside-library assertion / outside-library
//  rejection / relative path handling / empty path / symlink
//  escape (= the v1 missing test case).
//
//  ActiveLibrary.overrideForTesting is a `@TaskLocal` (= Apple
//  HIG canonical pattern for test seams). Tests wrap their body
//  in `ActiveLibrary.$overrideForTesting.withValue(...) { ... }`
//  via the `withLibraryRoot` helper (= per-task scope; = no
//  cross-suite pollution; = no init() reset needed).
//

import Testing
import Foundation
@testable import WenshuApp

@MainActor
@Suite("PathGuard (wt/path-guard-v2-2026-09-25)", .serialized)
struct PathGuardTests {

    private let libraryRoot = "/Users/anbaiqiang/libraries/test.ws"

    /// Run `body` with `ActiveLibrary.overrideForTesting` bound to
    /// `libraryRoot` for the duration of the closure (= Apple HIG
    /// canonical TaskLocal pattern; = no cross-suite pollution; =
    /// automatic scope restoration on closure exit).
    private func withLibraryRoot<R>(_ body: () throws -> R) rethrows -> R {
        try ActiveLibrary.$overrideForTesting.withValue(libraryRoot, operation: body)
    }

    // MARK: - Library root resolution

    @Test("resolveLibraryRoot returns nil when no override is set")
    func testResolveLibraryRootReturnsNilWhenUnset() {
        #expect(PathGuard.resolveLibraryRoot() == nil)
    }

    @Test("resolveLibraryRoot returns LibraryPath when override is set")
    func testResolveLibraryRootReturnsValueWhenSet() {
        let root = withLibraryRoot {
            PathGuard.resolveLibraryRoot()
        }
        #expect(root?.rawValue == libraryRoot)
    }

    @Test("resolveLibraryRootCanonical collapses symlinks")
    func testResolveLibraryRootCanonical() {
        let canonical = withLibraryRoot {
            PathGuard.resolveLibraryRootCanonical()
        }
        #expect(canonical != nil)
    }

    // MARK: - assertInsideLibrary

    @Test("assertInsideLibrary accepts an absolute path inside the library")
    func testAcceptsAbsoluteInside() throws {
        try withLibraryRoot {
            try PathGuard.assertInsideLibrary(path: "\(libraryRoot)/chapter.md")
        }
    }

    @Test("assertInsideLibrary accepts a library-relative path that resolves inside")
    func testAcceptsRelativeInside() throws {
        try withLibraryRoot {
            try PathGuard.assertInsideLibrary(path: "shelves/abc/books/xyz/chapter.md")
            try PathGuard.assertInsideLibrary(path: "cache/chat-uploads/image.png")
        }
    }

    @Test("assertInsideLibrary rejects an empty path string")
    func testRejectsEmptyPath() {
        withLibraryRoot {
            #expect(throws: PathGuard.GuardError.self) {
                try PathGuard.assertInsideLibrary(path: "")
            }
        }
    }

    @Test("assertInsideLibrary rejects an absolute path outside the library")
    func testRejectsAbsoluteOutside() {
        withLibraryRoot {
            #expect(throws: PathGuard.GuardError.self) {
                try PathGuard.assertInsideLibrary(path: "/etc/passwd")
            }
            #expect(throws: PathGuard.GuardError.self) {
                try PathGuard.assertInsideLibrary(path: "/Users/anbaiqiang/.ssh/id_rsa")
            }
        }
    }

    @Test("assertInsideLibrary rejects a `..` escape that lands outside")
    func testRejectsParentEscape() {
        withLibraryRoot {
            #expect(throws: PathGuard.GuardError.self) {
                try PathGuard.assertInsideLibrary(path: "\(libraryRoot)/../escape.txt")
            }
        }
    }

    @Test("assertInsideLibrary rejects a path that PREFIX-matches the root but is actually outside")
    func testRejectsPrefixTrap() {
        let trapRoot = "/Users/anbaiqiang/libraries/test.ws"
        let trapPath = "/Users/anbaiqiang/libraries/test.wsfoo/x.txt"
        withLibraryRoot {
            #expect(throws: PathGuard.GuardError.self) {
                try PathGuard.assertInsideLibrary(path: trapPath)
            }
        }
        #expect(!trapPath.hasPrefix("\(trapRoot)/"))
    }

    @Test("assertInsideLibrary rejects when library root is unset")
    func testRejectsWhenRootUnset() {
        #expect(throws: PathGuard.GuardError.libraryRootUnconfigured) {
            try PathGuard.assertInsideLibrary(path: "/anything/here")
        }
    }

    // MARK: - isInsideLibrary (Boolean variant)

    @Test("isInsideLibrary returns true for paths inside, false for paths outside")
    func testIsInside() {
        withLibraryRoot {
            #expect(PathGuard.isInsideLibrary(path: "\(libraryRoot)/x.txt") == true)
            #expect(PathGuard.isInsideLibrary(path: "/etc/passwd") == false)
            #expect(PathGuard.isInsideLibrary(path: "") == false)
        }
    }

    @Test("isInsideLibrary(LibraryPath) variant accepts typed path")
    func testIsInsideTyped() {
        withLibraryRoot {
            let typed = LibraryPath(rawValue: "\(libraryRoot)/x.txt")
            #expect(PathGuard.isInsideLibrary(path: typed) == true)
            let typedOutside = LibraryPath(rawValue: "/etc/passwd")
            #expect(PathGuard.isInsideLibrary(path: typedOutside) == false)
        }
    }

    // MARK: - Symlink escape (= v1 missing case)

    @Test("assertInsideLibrary resolves symlinks before the prefix check (= no escape via .ws/foo -> /etc)")
    func testRejectsSymlinkEscape() throws {
        let realTarget = "/tmp/wenshu-escape-target-\(UUID().uuidString.prefix(8))"
        let symlinkParent = "\(libraryRoot)/inside"
        let symlink = "\(symlinkParent)/sneaky"
        try FileManager.default.createDirectory(atPath: realTarget, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: symlinkParent, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: symlink, withDestinationPath: realTarget)
        defer {
            try? FileManager.default.removeItem(atPath: realTarget)
            try? FileManager.default.removeItem(atPath: symlinkParent)
        }

        withLibraryRoot {
            #expect(throws: PathGuard.GuardError.self) {
                try PathGuard.assertInsideLibrary(path: symlink)
            }
        }
    }

    // MARK: - preDispatchValidator

    @Test("preDispatchValidator accepts an empty typed input (= no path keys)")
    func testPreDispatchAcceptsEmpty() throws {
        try withLibraryRoot {
            let input = PathGuardInput(raw: ["query": "literal text"])
            let result = try PathGuard.preDispatchValidator(toolName: "search", input: input)
            #expect(result.allKeys == ["query"])
        }
    }

    @Test("preDispatchValidator accepts a path key whose value is inside the library")
    func testPreDispatchAcceptsValidPath() throws {
        try withLibraryRoot {
            let input = PathGuardInput(raw: ["path": "\(libraryRoot)/x.txt"])
            _ = try PathGuard.preDispatchValidator(toolName: "read_file", input: input)
        }
    }

    @Test("preDispatchValidator rejects a path key whose value is outside the library")
    func testPreDispatchRejectsOutsidePath() {
        withLibraryRoot {
            let input = PathGuardInput(raw: ["path": "/etc/passwd"])
            #expect(throws: ToolExecutorError.self) {
                _ = try PathGuard.preDispatchValidator(toolName: "read_file", input: input)
            }
        }
    }

    @Test("preDispatchValidator wraps GuardError into ToolExecutorError.pathGuardViolation")
    func testPreDispatchWrapsError() {
        withLibraryRoot {
            let input = PathGuardInput(raw: ["path": "/etc/passwd"])
            do {
                _ = try PathGuard.preDispatchValidator(toolName: "read_file", input: input)
                Issue.record("expected throw")
            } catch let error as ToolExecutorError {
                guard case let .pathGuardViolation(toolName, key, _) = error else {
                    Issue.record("expected pathGuardViolation case")
                    return
                }
                #expect(toolName == "read_file")
                #expect(key == "path")
            } catch {
                Issue.record("expected ToolExecutorError, got \(error)")
            }
        }
    }

    @Test("preDispatchValidator checks all path-bearing keys (from/to/cwd/rootDir)")
    func testPreDispatchChecksAllPathKeys() {
        withLibraryRoot {
            #expect(throws: ToolExecutorError.self) {
                _ = try PathGuard.preDispatchValidator(
                    toolName: "file",
                    input: PathGuardInput(raw: ["from": "\(libraryRoot)/a.txt", "to": "/etc/passwd"])
                )
            }
            #expect(throws: ToolExecutorError.self) {
                _ = try PathGuard.preDispatchValidator(
                    toolName: "file",
                    input: PathGuardInput(raw: ["op": "search", "rootDir": "/etc", "pattern": "x"])
                )
            }
        }
    }

    @Test("preDispatchValidator ignores keys that are not path-bearing")
    func testPreDispatchIgnoresNonPathKeys() throws {
        try withLibraryRoot {
            let input = PathGuardInput(raw: [
                "command": "ls -la",
                "query": "literal text",
                "pattern": "regex"
            ])
            _ = try PathGuard.preDispatchValidator(toolName: "search", input: input)
        }
    }

    @Test("preDispatchValidator pathKeys includes the v1 path-bearing keys")
    func testPreDispatchPathKeysList() {
        let keys = Set(PathGuard.pathKeys)
        for expected in ["path", "file", "cwd", "from", "to", "rootDir"] {
            #expect(keys.contains(expected))
        }
    }

    // MARK: - Error description (privacy)

    @Test("GuardError.errorDescription does NOT leak the absolute path")
    func testErrorDescriptionHidesAbsolutePath() {
        let root = LibraryPath(rawValue: "/Users/anbaiqiang/libraries/test.ws")
        let resolved = LibraryPath(rawValue: "/Users/anbaiqiang/libraries/test.ws/../escape.txt")
        let error = PathGuard.GuardError.pathOutsideLibrary(resolved: resolved, root: root)
        let description = error.errorDescription ?? ""
        #expect(!description.contains("/Users/anbaiqiang"))
        #expect(description.contains("escape.txt"))
    }

    @Test("GuardError conforms to Equatable (= test assertion ergonomics)")
    func testGuardErrorEquatable() {
        let a = PathGuard.GuardError.libraryRootUnconfigured
        let b = PathGuard.GuardError.libraryRootUnconfigured
        #expect(a == b)
    }
}
