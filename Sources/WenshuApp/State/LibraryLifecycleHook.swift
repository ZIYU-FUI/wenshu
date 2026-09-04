// LibraryLifecycleHook.swift · Wenshu (文枢) · v0.27 (FCP library replica wiring)
//
// v0.27-01 = App.swift wiring deferred from v0.26 ticket 019.
//
// Strategy: instead of touching App.swift (v0.25.1 streak touched it
// 41+ times; high regression risk), this file introduces the launch
// sequence (= LibraryMigrator + LibraryBootstrapper + store
// construction) without invasive @Environment rewrites.

import Foundation
import SwiftUI
import Observation

struct LibraryLifecycleHook: Sendable {
    let wsRoot: URL

    func runLaunch() throws -> LibraryLaunchResult {
        let migrator = LibraryMigrator(wsRoot: wsRoot)
        try migrator.migrateIfNeeded()
        let bootstrapper = LibraryBootstrapper(wsRoot: wsRoot)
        try bootstrapper.ensureValidStructure()
        let stores = try constructStores(wsRoot: wsRoot)
        return LibraryLaunchResult(stores: stores)
    }

    private func constructStores(wsRoot: URL) throws -> LibraryStores {
        let shelves = wsRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = wsRoot.appendingPathComponent("reference-library", isDirectory: true)
        let referenceStore = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        return LibraryStores(
            shelvesRoot: shelves,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: referenceStore
        )
    }
}

struct LibraryStores: Sendable {
    let shelvesRoot: URL
    let referenceLibraryRoot: URL
    let referenceStore: ReferenceStoring

    /// Construct per-book WorldStoring + CharacterStoring for a given
    /// book directory. v0.27 follows the standard "data source switch"
    /// pattern (= Apple HIG canonical for app-level stores).
    func makeBookStores(for bookDirectory: URL) -> PerBookStores {
        PerBookStores(
            worldStore: FileSystemWorldStore(bookDirectory: bookDirectory),
            characterStore: FileSystemCharacterStore(bookDirectory: bookDirectory)
        )
    }
}

struct PerBookStores: Sendable {
    let worldStore: WorldStoring
    let characterStore: CharacterStoring
}

struct LibraryLaunchResult: Sendable {
    let stores: LibraryStores
}

// MARK: - BookStore construction

extension LibraryLaunchResult {
    /// Build the singleton BookStore (= v0.27 ticket 027-01 wiring).
    /// This is the one place that constructs the @Observable; App.swift
    /// wiring (= WiredShell in LibraryRootView) passes it to LayoutShellView
    /// via .environment(bookStore).
    @MainActor
    func makeBookStore() -> BookStore {
        BookStore(stores: stores)
    }
}