//
//  ReferenceLibraryLayerLayoutTests.swift · Wenshu
//
//  Pins the on-disk layout of the reference library against the
//  layer enum.
//
//  The reference library's layers are named by `ReferenceLayer`, and
//  the two derived layers (abstracts / indexes) went with the
//  llm_wiki tool that wrote them. The directories are created in two
//  places: the bootstrapper (= every launch) and the migrator (= a
//  library that is not at the current schema version, which is every
//  freshly created library). Each of them had its own copy of the
//  layer list, so a removal in one place left the other creating
//  directories the enum can no longer name.
//
//  These tests run both creation paths over a library that has no
//  schema version (= the shape a newly created library has) and
//  assert that the directories on disk are exactly the ones the enum
//  names.
//
//  swift test --filter ReferenceLibraryLayerLayoutTests
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Reference library layer layout")
struct ReferenceLibraryLayerLayoutTests {

    /// A library as `LibraryOnboardingView.createWenshuWorkspace` writes
    /// it: the package directory, its subdirectories, and an Info.plist
    /// with no `WSSchemaVersion` key (= the migrator's step 1 does not
    /// recognise it, so the migration path runs).
    private func makeFreshLibrary() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("reflib-layout-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.wenshu.test",
            "CFBundleName": "test",
            "CFBundlePackageType": "WSPC",
            "CFBundleShortVersionString": "0.24.0",
            "CFBundleVersion": "1",
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
        try data.write(to: root.appendingPathComponent("Info.plist"))
        return root
    }

    private func referenceLibraryLayout(of root: URL) throws -> [String] {
        let referenceRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: referenceRoot.path)
        return names.sorted()
    }

    @Test("the migration path creates exactly the layers the enum names")
    func migratorCreatesTheEnumLayers() throws {
        let root = try makeFreshLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        try LibraryMigrator(wsRoot: root).migrateIfNeeded()

        let expected = ReferenceLayer.allCases.map(\.directoryName).sorted()
        #expect(try referenceLibraryLayout(of: root) == expected,
                "the migrator must create the layers the enum names, and no others")
    }

    @Test("the bootstrap path creates exactly the layers the enum names")
    func bootstrapperCreatesTheEnumLayers() throws {
        let root = try makeFreshLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        try LibraryBootstrapper(wsRoot: root).ensureValidStructure()

        let expected = ReferenceLayer.allCases.map(\.directoryName).sorted()
        #expect(try referenceLibraryLayout(of: root) == expected,
                "the bootstrapper must create the layers the enum names, and no others")
    }

    @Test("a fresh library holds no directory the enum cannot name")
    func freshLibraryHasNoUnnamedLayerDirectory() throws {
        let root = try makeFreshLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        try LibraryMigrator(wsRoot: root).migrateIfNeeded()
        try LibraryBootstrapper(wsRoot: root).ensureValidStructure()

        let expected = Set(ReferenceLayer.allCases.map(\.directoryName))
        let onDisk = Set(try referenceLibraryLayout(of: root))
        let unnamed = onDisk.subtracting(expected).sorted()
        #expect(unnamed.isEmpty,
                "the library grew directories no layer names: \(unnamed)")
    }
}
