//
//  PathGuardTypesTests.swift · Wenshu · wt/path-guard-v2-2026-09-25
//
//  Coverage for LibraryPath + RelativePath + PathGuardInput typed
//  wrappers (= the v1 raw `String` shape was replaced with typed
//  newtypes per design-check §9 Type Boundary + §7 Value Object).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("PathGuardTypes (wt/path-guard-v2-2026-09-25)", .serialized)
struct PathGuardTypesTests {

    // MARK: - LibraryPath

    @Test("LibraryPath(rawValue:) stores the raw string")
    func testLibraryPathStoresRawString() {
        let path = LibraryPath(rawValue: "/Users/foo/lib.ws")
        #expect(path.rawValue == "/Users/foo/lib.ws")
    }

    @Test("LibraryPath(rawValueOrNil:) returns nil for empty string")
    func testLibraryPathRejectsEmpty() {
        let path = LibraryPath(rawValueOrNil: "")
        #expect(path == nil)
    }

    @Test("LibraryPath(rawValueOrNil:) returns nil for whitespace-only string")
    func testLibraryPathRejectsWhitespace() {
        let path = LibraryPath(rawValueOrNil: "   \n  ")
        #expect(path == nil)
    }

    @Test("LibraryPath(rawValueOrNil:) trims whitespace around a non-empty string")
    func testLibraryPathTrimsWhitespace() {
        let path = LibraryPath(rawValueOrNil: "  /Users/foo/lib.ws  ")
        #expect(path?.rawValue == "/Users/foo/lib.ws")
    }

    @Test("LibraryPath conforms to Hashable (equal raw values are equal)")
    func testLibraryPathHashable() {
        let a = LibraryPath(rawValue: "/x/y.ws")
        let b = LibraryPath(rawValue: "/x/y.ws")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("LibraryPath conforms to Sendable (= Swift type system check)")
    func testLibraryPathIsSendable() {
        // The compiler enforces Sendable on the type; this test
        // exists to make the contract explicit (= a future refactor
        // that drops Sendable would break this test).
        let path: any Sendable = LibraryPath(rawValue: "/x")
        #expect(path is LibraryPath)
    }

    @Test("LibraryPath conforms to Codable (JSON round-trip)")
    func testLibraryPathCodable() throws {
        let original = LibraryPath(rawValue: "/Users/foo/lib.ws")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LibraryPath.self, from: encoded)
        #expect(decoded == original)
    }

    @Test("LibraryPath conforms to Comparable")
    func testLibraryPathComparable() {
        let a = LibraryPath(rawValue: "/a")
        let b = LibraryPath(rawValue: "/b")
        #expect(a < b)
    }

    @Test("LibraryPath.canonicalPath resolves symlinks and returns a normalized path")
    func testLibraryPathCanonicalPath() throws {
        // Create a real symlink in the test temp dir to verify that
        // canonicalPath collapses symlink hops. The symlink is local
        // to this test and is removed in the test's cleanup (= a
        // follow-up test could add explicit cleanup if this pattern
        // grows).
        let rawRoot = "/tmp/wenshu-path-guard-test-\(UUID().uuidString.prefix(8))"
        let realDir = "\(rawRoot)-real"
        let symlinkDir = rawRoot
        try FileManager.default.createDirectory(
            atPath: realDir,
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            atPath: symlinkDir,
            withDestinationPath: realDir
        )
        defer {
            try? FileManager.default.removeItem(atPath: symlinkDir)
            try? FileManager.default.removeItem(atPath: realDir)
        }

        let path = LibraryPath(rawValue: symlinkDir)
        let canonical = path.canonicalPath
        #expect(canonical == URL(fileURLWithPath: realDir).resolvingSymlinksInPath().standardizedFileURL.path)
    }

    // MARK: - RelativePath

    @Test("RelativePath stores the raw string")
    func testRelativePathStoresRaw() {
        let path = RelativePath(rawValue: "shelves/abc/chapter.md")
        #expect(path.rawValue == "shelves/abc/chapter.md")
    }

    @Test("RelativePath conforms to Hashable + Sendable + Comparable + Codable")
    func testRelativePathProtocols() throws {
        let a = RelativePath(rawValue: "foo")
        let b = RelativePath(rawValue: "foo")
        let c = RelativePath(rawValue: "bar")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a > c)
        let encoded = try JSONEncoder().encode(a)
        let decoded = try JSONDecoder().decode(RelativePath.self, from: encoded)
        #expect(decoded == a)
        let sendable: any Sendable = a
        #expect(sendable is RelativePath)
    }

    // MARK: - PathGuardInput

    @Test("PathGuardInput.string returns nil for missing key")
    func testPathGuardInputStringMissing() {
        let input = PathGuardInput(raw: ["query": "literal"])
        #expect(input.string(forKey: "path") == nil)
    }

    @Test("PathGuardInput.relativePath returns nil for empty value")
    func testPathGuardInputRelativePathEmpty() {
        let input = PathGuardInput(raw: ["path": ""])
        #expect(input.relativePath(forKey: "path") == nil)
    }

    @Test("PathGuardInput.libraryPath returns nil for empty value")
    func testPathGuardInputLibraryPathEmpty() {
        let input = PathGuardInput(raw: ["rootDir": ""])
        #expect(input.libraryPath(forKey: "rootDir") == nil)
    }

    @Test("PathGuardInput.allKeys returns sorted keys")
    func testPathGuardInputAllKeysSorted() {
        let input = PathGuardInput(raw: ["c": "3", "a": "1", "b": "2"])
        #expect(input.allKeys == ["a", "b", "c"])
    }
}