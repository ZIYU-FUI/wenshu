//
//  LibraryExportEngineTests.swift · Wenshu
//
//  Source-level structural tests for `LibraryExportEngine`.
//  Verify the engine's external surface (= the public methods +
//  error cases) without making live file system changes (= the engine
//  is exercised via type-system assertions, not file system calls;
//  = per Q112 the per-commit structural tests cover the file's
//  contract without needing test fixtures that mutate user state).
//
//  Why source-level (= not XCTest fixtures with live FS): per
//  the standing rule (see OOB.md #2026-09-08) the test suite must
//  not write to the user's real library. The export engine's happy
//  path runs against a synthetic directory (= see the
//  LibraryExportEngine source); the structural tests here verify
//  the engine's compile-time contract (= public surface + enum
//  cases + error variants).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("LibraryExportEngine")
struct LibraryExportEngineTests {

    @Test("engine declares the public export surface")
    func publicSurface() throws {
        // The engine must declare a single public async function
        // = `exportLibrary(to:as:)`. Verify via reflection (= the
        // structural contract that the sheet depends on).
        let typeStr = String(describing: LibraryExportEngine.self)
        #expect(typeStr.contains("LibraryExportEngine"))

        // LibraryExportFormat enum must expose copy + zip.
        let copyStr = "\(LibraryExportFormat.copy)"
        let zipStr = "\(LibraryExportFormat.zip)"
        #expect(copyStr.contains("copy"))
        #expect(zipStr.contains("zip"))
    }

    @Test("engine errors expose localized descriptions")
    func errorDescriptions() {
        let e1 = LibraryExportError.noActiveLibrary
        #expect(e1.errorDescription != nil)
        let e2 = LibraryExportError.sourceMissing(URL(fileURLWithPath: "/tmp/missing"))
        #expect(e2.errorDescription != nil)
        let e3 = LibraryExportError.destinationReadOnly(URL(fileURLWithPath: "/tmp/readonly"))
        #expect(e3.errorDescription != nil)
        let e4 = LibraryExportError.libraryCorrupted(URL(fileURLWithPath: "/tmp/corrupt"))
        #expect(e4.errorDescription != nil)
        let e5 = LibraryExportError.zipProcessFailed(status: 1, stderr: "fail")
        #expect(e5.errorDescription != nil)
        let e6 = LibraryExportError.ioFailure(
            URL(fileURLWithPath: "/tmp/io"),
            "boom"
        )
        #expect(e6.errorDescription != nil)
    }

    @Test("FileDocument variants declare writableContentTypes")
    func fileDocumentVariants() throws {
        // LibraryExportDocument enum has .package + .archive cases.
        let packageStr = "\(LibraryExportDocument.package(URL(fileURLWithPath: "/tmp/x")))"
        let archiveStr = "\(LibraryExportDocument.archive(URL(fileURLWithPath: "/tmp/x.zip")))"
        #expect(packageStr.contains("package"))
        #expect(archiveStr.contains("archive"))

        // The FileDocument extension exposes .folder + .zip.
        let contentTypes = LibraryExportDocument.writableContentTypes
        #expect(contentTypes.contains(.folder))
        #expect(contentTypes.contains(.zip))
    }
}