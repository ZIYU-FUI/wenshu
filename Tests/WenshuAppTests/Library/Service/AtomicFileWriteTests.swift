// AtomicFileWriteTests.swift
//
// The write path the storage layer shares: a write that cannot land
// leaves the previous file intact and leaves no temporary file behind.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Atomic file write")
struct AtomicFileWriteTests {
    private func makeRoot() -> URL {
        URL(fileURLWithPath: "/tmp/wenshu-atomic-write-\(UUID().uuidString)", isDirectory: true)
    }

    private func names(in root: URL) -> [String] {
        let fm = FileManager.default
        return ((try? fm.contentsOfDirectory(atPath: root.path)) ?? []).sorted()
    }

    @Test("a write to a new path creates the file and leaves no temporary file")
    func writeCreatesFile() throws {
        let fm = FileManager.default
        let root = makeRoot()
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let dest = root.appendingPathComponent("chapter.md")
        try AtomicFileWrite.write(Data("v1".utf8), to: dest)

        #expect(try String(contentsOf: dest, encoding: .utf8) == "v1")
        #expect(names(in: root) == ["chapter.md"])
    }

    @Test("a write over an existing file replaces its content")
    func writeReplacesContent() throws {
        let fm = FileManager.default
        let root = makeRoot()
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let dest = root.appendingPathComponent("chapter.md")
        try Data("v1".utf8).write(to: dest)

        try AtomicFileWrite.write(Data("v2".utf8), to: dest)

        #expect(try String(contentsOf: dest, encoding: .utf8) == "v2")
        #expect(names(in: root) == ["chapter.md"])
    }

    @Test("a write that cannot replace the file leaves the previous content intact")
    func failedWriteKeepsPreviousContent() throws {
        let fm = FileManager.default
        let root = makeRoot()
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let dest = root.appendingPathComponent("chapter.md")
        try Data("v1".utf8).write(to: dest)

        // The destination refuses to be replaced (= the immutable flag),
        // so the swap fails while the previous content is still there.
        try fm.setAttributes([.immutable: true], ofItemAtPath: dest.path)
        defer { try? fm.setAttributes([.immutable: false], ofItemAtPath: dest.path) }

        #expect(throws: (any Error).self) {
            try AtomicFileWrite.write(Data("v2".utf8), to: dest)
        }

        #expect(try String(contentsOf: dest, encoding: .utf8) == "v1")
        #expect(names(in: root) == ["chapter.md"])
    }
}
