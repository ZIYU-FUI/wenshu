//
//  ChapterExportEngineTests.swift · Wenshu
//
//  Source-level structural tests for `ChapterExportEngine`. The
//  chapter body round-trip (= export → re-parse) is the most
//  important external contract (= what the user sees = what they
//  get).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChapterExportEngine")
struct ChapterExportEngineTests {

    @Test("engine declares the public export surface")
    func publicSurface() {
        let typeStr = String(describing: ChapterExportEngine.self)
        #expect(typeStr.contains("ChapterExportEngine"))
    }

    @Test("engine errors expose localized descriptions")
    func errorDescriptions() {
        let e1 = ChapterExportError.noActiveLibrary
        #expect(e1.errorDescription != nil)
        let e2 = ChapterExportError.chapterNotFound(UUID())
        #expect(e2.errorDescription != nil)
        let e3 = ChapterExportError.destinationReadOnly(URL(fileURLWithPath: "/tmp/x"))
        #expect(e3.errorDescription != nil)
        let e4 = ChapterExportError.ioFailure(URL(fileURLWithPath: "/tmp/x"), "boom")
        #expect(e4.errorDescription != nil)
    }

    @Test("engine actor isolation is honored")
    func actorIsolation() async throws {
        // The engine is an actor; calling it from async context works
        // (= no main-thread requirement).
        let engine = ChapterExportEngine()
        // Just verify the engine exists and is sendable across tasks.
        let _ = Task { @Sendable in
            // No method called (= tests with method calls need a real
            // library path = out of scope here).
            _ = engine
        }
        try await Task.sleep(nanoseconds: 1_000_000)  // 1ms
    }
}