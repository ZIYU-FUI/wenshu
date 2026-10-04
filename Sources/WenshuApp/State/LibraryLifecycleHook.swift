// Sources/WenshuApp/State/LibraryLifecycleHook.swift
//
// Strategy: instead of touching App.swift (the v0.25.1 streak touched
// it 41+ times; = high regression risk), this file introduces the
// launch sequence (= LibraryMigrator + LibraryBootstrapper + store
// construction) without invasive `@Environment` rewrites.

import Foundation
import SwiftUI
import Observation

struct LibraryLifecycleHook: Sendable {
    let wsRoot: URL

    func runLaunch() throws -> LibraryLaunchResult {
        NSLog("[wenshu.library.lifecycle] runLaunch start wsRoot=%@", wsRoot.path)
        let migrator = LibraryMigrator(wsRoot: wsRoot)
        try migrator.migrateIfNeeded()
        NSLog("[wenshu.library.lifecycle] runLaunch: migrateIfNeeded done")
        let bootstrapper = LibraryBootstrapper(wsRoot: wsRoot)
        try bootstrapper.ensureValidStructure()
        NSLog("[wenshu.library.lifecycle] runLaunch: ensureValidStructure done")
        let stores = try constructStores(wsRoot: wsRoot)
        NSLog("[wenshu.library.lifecycle] runLaunch: constructStores done; shelvesRoot=%@", stores.shelvesRoot.path)
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

    /// Construct per-book FileSystemEntityStore (= unified v2.3 entity
    /// storage; = replaces the v2.0 WorldStoring + CharacterStoring
    /// pair with a single kind-discriminated store). v0.27 follows
    /// the standard "data source switch" pattern (= Apple HIG
    /// canonical for app-level stores).
    func makeBookStores(for bookDirectory: URL) -> PerBookStores {
        PerBookStores(entityStore: FileSystemEntityStore(bookDirectory: bookDirectory))
    }
}

struct PerBookStores: Sendable {
    let entityStore: FileSystemEntityStore
}

struct LibraryLaunchResult: Sendable {
    let stores: LibraryStores
}

// MARK: - BookStore construction

extension LibraryLaunchResult {
    /// Build the singleton `BookStore` (= the canonical wiring).
    /// This is the one place that constructs the @Observable; App.swift
    /// wiring (= WiredShell in LibraryRootView) passes it to LayoutShellView [no longer defined post-v0.72 — AppRootScene + NavigationSplitView; = ADR-0007 pending ADR-0010; = type references kept as historical landmarks pending 老板 拍]
    /// via .environment(bookStore).
    @MainActor
    func makeBookStore() -> BookStore {
        BookStore(stores: stores)
    }
}
