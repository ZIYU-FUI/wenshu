// Sources/WenshuApp/State/LibraryLifecycleHook.swift
//
// Strategy: instead of touching App.swift (the v0.25.1 streak touched
// it 41+ times; = high regression risk), this file introduces the
// launch sequence (= LibraryMigrator + LibraryBootstrapper + store
// construction) without invasive `@Environment` rewrites.

import Foundation
import os
import SwiftUI
import Observation

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "librarylifecyclehook")

@MainActor
struct LibraryLifecycleHook: Sendable {
    let wsRoot: URL

    @MainActor
    func runLaunch() throws -> LibraryLaunchResult {
        wenshuLogger.info("[wenshu.library.lifecycle] runLaunch start wsRoot=\(wsRoot.path)")
        let migrator = LibraryMigrator(wsRoot: wsRoot)
        try migrator.migrateIfNeeded()
        wenshuLogger.info("[wenshu.library.lifecycle] runLaunch: migrateIfNeeded done")
        let bootstrapper = LibraryBootstrapper(wsRoot: wsRoot)
        try bootstrapper.ensureValidStructure()
        wenshuLogger.info("[wenshu.library.lifecycle] runLaunch: ensureValidStructure done")
        let stores = try constructStores(wsRoot: wsRoot)
        wenshuLogger.info("[wenshu.library.lifecycle] runLaunch: constructStores done; shelvesRoot=\(stores.shelvesRoot.path) referenceLibraryRoot=\(stores.referenceLibraryRoot.path)")
        return LibraryLaunchResult(stores: stores)
    }

    @MainActor
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
    @MainActor
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
    /// wiring (= WiredShell in LibraryRootView) passes it to AppRootScene
    /// via .environment(bookStore).
    @MainActor
    func makeBookStore() -> BookStore {
        BookStore(stores: stores)
    }
}
