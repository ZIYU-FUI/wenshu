//
//  WenshuAppDelegateSwiftDataMigration.swift
//
//  SwiftData migration helper static funcs extracted from
//  WenshuAppDelegate.swift (= §6.6 god-class split: the
//  4 SwiftData migration funcs = attemptSwiftDataMigrationIfNeeded
//  + runSwiftDataMigrationPipeline + writeMigrationBackup +
//  bumpSchemaVersion = ~130 LOC moved out of the main
//  delegate class).
//
//  Why extracted (= §6.6 god-class split): the main
//  `final class WenshuAppDelegate: NSObject, NSApplicationDelegate`
//  is 612 LOC = 1.02x the 600-LOC cap. The 4 SwiftData
//  migration funcs are a logical group (= they all read +
//  write the .ws Info.plist's WSSchemaVersion key).
//
//  Concurrency: The `enum WenshuAppDelegateSwiftDataMigration`
//  is `@MainActor`-isolated. The 4 funcs read/write
//  `WenshuAppDelegate.sharedMigrationState` +
//  `sharedMigrationRetry` + `sharedAppState` +
//  `openWindowAction` (= all `@MainActor` static vars on
//  the class). The class is implicitly @MainActor via
//  `NSApplicationDelegate`; = the cross-file access from
//  the namespace is @MainActor-isolated too.
//

import AppKit
import SwiftUI
import WenshuData
import os

private let swiftDataMigrationLogger = Logger(subsystem: "com.wenshu", category: "wenshuappdelegate-migration")

/// Namespace container for the 4 SwiftData migration helper static funcs.
@MainActor
enum WenshuAppDelegateSwiftDataMigration {
    static func attemptSwiftDataMigrationIfNeeded(wsRoot: URL) {
        guard let info = try? LibraryInfoReader.read(from: wsRoot) else {
            // Could not read the .ws Info.plist (= LibraryInfo throws on missing or
            // malformed plist). LibraryMigrator would heal this on the
            // next LibraryLifecycleHook call, but that is the onboarding-
            // time hook (= not the launch path). Skip the migration panel
            // for this launch; = the user sees the normal main window and
            // the next lifecycle hook will run when they re-enter the app.
            return
        }
        guard info.needsMigration else { return }

        // Construct the state machine + populate the static accessors that the Window
        // scene body reads (= see AppRootScene Window with id
        // WindowID.libraryMigration).
        let state = LibraryMigrationState()
        WenshuAppDelegate.sharedMigrationState = state

        // Set the AppState flag (= the bridge that LibraryRootView reads to render an
        // empty main window). WenshuAppDelegate holds the AppState reference
        // via AppState.shared (= the canonical singleton injected into the
        // .environment chain by AppRootScene); = the AppState is reachable
        // here.
        if let appState = WenshuAppDelegate.sharedAppState {
            appState.migrationInFlight = true
        }

        // Single retry closure (= captures wsRoot + state). The panel's onRetry callback
        // invokes it (= after state.resetForRetry() has rolled progress back
        // to 0 and bumped retryCount).
        let runPipeline: () -> Void = {
            runSwiftDataMigrationPipeline(wsRoot: wsRoot, state: state)
        }
        WenshuAppDelegate.sharedMigrationRetry = runPipeline
        state.begin()

        // Open the panel window (= single-instance; = bringing an already-open panel to
        // front if it exists). openWindow resolves the Window by id.
        if let openWindow = WenshuAppDelegate.openWindowAction {
            openWindow(id: WindowID.libraryMigration)
        } else {
            // No openWindow handle (= shouldn't happen because AppRootScene injects it
            // via .environment; = defensive log so a future ticket can
            // diagnose if the panel fails to show).
            swiftDataMigrationLogger.info("[wenshu.migration] openWindow action unavailable; panel not opened")
        }

        // Drive the pipeline asynchronously (= the panel shows preparing state
        // immediately; = the executing ModelContainer init happens on a Task
        // so the panel's animations stay smooth).
        Task { @MainActor in
            runPipeline()
        }
    }


    /// Run one attempt of the migration pipeline. Drives state through
    /// preparing / executing / finalizing; = on exception, state.fail(err)
    /// rolls progress back to 0 (see OOB.md #2026-10-06).
    static func runSwiftDataMigrationPipeline(wsRoot: URL, state: LibraryMigrationState) {
        do {
            // Stage 1: preparing (= back up the user's store).
            let preparedAt = Date()
            let backup = try writeMigrationBackup(wsRoot: wsRoot)
            state.recordBackup(at: backup)
            let preparingElapsed = Date().timeIntervalSince(preparedAt)
            state.beginExecuting()
            state.updateEstimatedSecondsRemaining(
                max(1, Int(preparingElapsed * 4))
            )

            // Stage 2: executing (= SwiftData ModelContainer init with the plan in
            // place). This is where the lightweight migration actually
            // runs; = SwiftData throws if the migration cannot complete (=
            // the panel will surface the error string in the red failure
            // block).
            let storeURL = wsRoot.appendingPathComponent("WenshuStore.store")
            _ = try WSPersistenceContainer.makeContainer(at: storeURL)
            state.beginFinalizing()
            state.updateEstimatedSecondsRemaining(1)

            // Stage 3: finalizing (= write the new WSSchemaVersion to Info.plist).
            // LibraryMigrator already wrote 1 when the .ws was first
            // migrated to v0.26; = we now bump to 2 (= the new
            // application-layer schema version that matches
            // ModelsSchemaV2's versionIdentifier).
            try bumpSchemaVersion(wsRoot: wsRoot, newVersion: 2)
            state.complete()

            // Clear the bridge state so a subsequent launch sees a clean AppDelegate (=
            // the migration is one-shot per session).
            WenshuAppDelegate.sharedMigrationState = nil
            WenshuAppDelegate.sharedMigrationRetry = nil
            WenshuAppDelegate.sharedAppState?.migrationInFlight = false
        } catch {
            // Roll back to 0 (see OOB.md #2026-10-06). The user then sees the red failure
            // block with the error string and the backup path; = they can
            // press 重试 (= up to 3 times; = the panel hides the 重试 button
            // after 3 failures and only 退出 remains) or 退出 (=
            // NSApp.terminate).
            state.fail(String(describing: error))
            // Leave migrationInFlight = true (= the main window stays empty while the
            // user decides whether to 重试 or 退出). Only clear on success or
            // on the user's 退出 path (= NSApp.terminate kills the process
            // anyway).
        }
    }


    /// Back up the user's .ws/WenshuStore.store to
    /// .ws/migration-backups/v<old>-<ts>.store. Idempotent: if the source store
    /// does not exist (= the .ws was just created and SwiftData has not written
    /// the store yet), this returns a placeholder path without copying anything
    /// (= the user has nothing to back up).
    static func writeMigrationBackup(wsRoot: URL) throws -> URL {
        let fm = FileManager.default
        let storeURL = wsRoot.appendingPathComponent("WenshuStore.store")
        let backupDir = wsRoot.appendingPathComponent("migration-backups", isDirectory: true)
        if !fm.fileExists(atPath: backupDir.path) {
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = backupDir.appendingPathComponent("v1-\(timestamp).store")
        if fm.fileExists(atPath: storeURL.path) {
            try fm.copyItem(at: storeURL, to: backupURL)
        }
        return backupURL
    }


    /// Bump the application-layer schema version stored in the .ws Info.plist
    /// (= the WSSchemaVersion key that LibraryInfo.needsMigration reads on
    /// every launch). The SwiftData ModelsSchemaV2 versionIdentifier is 2.0.0;
    /// = bumping the Info.plist to 2 keeps them in lockstep.
    static func bumpSchemaVersion(wsRoot: URL, newVersion: Int) throws {
        let infoPlistURL = wsRoot.appendingPathComponent("Info.plist")
        let fm = FileManager.default
        var plist: [String: Any] = [:]
        if fm.fileExists(atPath: infoPlistURL.path),
           let data = try? Data(contentsOf: infoPlistURL),
           let existing = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            plist = existing
        }
        plist["WSSchemaVersion"] = newVersion
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: infoPlistURL)
    }

}
