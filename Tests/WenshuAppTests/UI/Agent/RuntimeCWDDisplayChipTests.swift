//
//  RuntimeCWDDisplayChipTests.swift · Wenshu · v0.37 Batch 2.4 sub-step 2
//
//  Tests for the RuntimeCWDDisplayChip UI component.
//
//  Per cadence 2026-09-03 'resume' + 'PO execute,don't'
//  + 'when done, verify visual and frontend flow together' + '1 RULE 1 commit'.
//
//  Migration (= v2.10 aligned with the ActiveLibrary single-source
//  migration; = the legacy 'wenshu.libraryPath' UserDefaults key
//  was retired): tests now seed the library via
//  `ActiveLibrary.overrideForTesting` (= the canonical test seam
//  added when ActiveLibrary became the single source of truth for
//  the active library URL). The `RuntimeCWD.libraryPathKey` helper
//  was removed (= it was just a thin alias over the deleted
//  WenshuDefaultsKey.libraryPath.rawValue).
//

import Testing
import Foundation
import SwiftUI
@testable import WenshuApp

@MainActor
@Suite("RuntimeCWDDisplayChip (= Batch 2.4 UI component)", .serialized)
struct RuntimeCWDDisplayChipTests {

    @Test("RuntimeCWDDisplayChip: instantiates without crash")
    func instantiate() {
        let chip = RuntimeCWDDisplayChip()
        // Verify the chip body builds (= view graph construction succeeds)
        _ = chip.body
    }

    @Test("RuntimeCWD: displayLabel returns 'Unset' when no library + no override")
    func displayLabelUnset() async {
        let prevActiveLibrary = ActiveLibrary.overrideForTesting
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            ActiveLibrary.overrideForTesting = prevActiveLibrary
            if let prevCwdOverride {
                UserDefaults.standard.set(prevCwdOverride, forKey: RuntimeCWD.cwdOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
            }
        }
        // Clear both bindings to ensure clean state
        ActiveLibrary.overrideForTesting = nil
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        let cwd = RuntimeCWD()
        let label = await cwd.displayLabel()
        #expect(label.contains("Unset") || label.contains("unset"))
    }

    @Test("RuntimeCWD: displayLabel shows 'Library:' prefix when library path is set")
    func displayLabelLibrary() async {
        let prevActiveLibrary = ActiveLibrary.overrideForTesting
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            ActiveLibrary.overrideForTesting = prevActiveLibrary
            if let prevCwdOverride {
                UserDefaults.standard.set(prevCwdOverride, forKey: RuntimeCWD.cwdOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
            }
        }
        let tempPath = "/tmp/wenshu-test-library-\(UUID().uuidString).ws"
        ActiveLibrary.overrideForTesting = tempPath
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        let cwd = RuntimeCWD()
        let label = await cwd.displayLabel()
        #expect(label.contains("Library"))
        #expect(label.contains(tempPath))
    }

    @Test("RuntimeCWD: displayLabel shows 'Override:' prefix when override is set")
    func displayLabelOverride() async {
        let prevActiveLibrary = ActiveLibrary.overrideForTesting
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            ActiveLibrary.overrideForTesting = prevActiveLibrary
            if let prevCwdOverride {
                UserDefaults.standard.set(prevCwdOverride, forKey: RuntimeCWD.cwdOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
            }
        }
        let overridePath = "/tmp/wenshu-override-\(UUID().uuidString)"
        ActiveLibrary.overrideForTesting = nil
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        UserDefaults.standard.set(overridePath, forKey: RuntimeCWD.cwdOverrideKey)
        let cwd = RuntimeCWD()
        let label = await cwd.displayLabel()
        #expect(label.contains("Override"))
        #expect(label.contains(overridePath))
        // Cleanup override so we don't leak state to other tests
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
    }

    @Test("RuntimeCWD: setCWD override takes precedence over library path")
    func setCWDOverride() async throws {
        let prevActiveLibrary = ActiveLibrary.overrideForTesting
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            ActiveLibrary.overrideForTesting = prevActiveLibrary
            if let prevCwdOverride {
                UserDefaults.standard.set(prevCwdOverride, forKey: RuntimeCWD.cwdOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
            }
        }
        let libraryPath = "/tmp/wenshu-library-\(UUID().uuidString).ws"
        let overridePath = "/tmp/wenshu-override-\(UUID().uuidString)"
        ActiveLibrary.overrideForTesting = libraryPath
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        let cwd = RuntimeCWD()

        // Set override
        try await cwd.setCWD(URL(fileURLWithPath: overridePath))
        let label = await cwd.displayLabel()
        #expect(label.contains("Override"))
        #expect(label.contains(overridePath))
        #expect(!label.contains(libraryPath))

        // Reset to library
        try await cwd.resetToLibraryPath()
        let labelAfterReset = await cwd.displayLabel()
        #expect(labelAfterReset.contains("Library"))

        // Cleanup override
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
    }

    @Test("RuntimeCWD: resolve(relativePath) uses current CWD")
    func resolveRelativePath() async throws {
        let prevActiveLibrary = ActiveLibrary.overrideForTesting
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            ActiveLibrary.overrideForTesting = prevActiveLibrary
            if let prevCwdOverride {
                UserDefaults.standard.set(prevCwdOverride, forKey: RuntimeCWD.cwdOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
            }
        }
        let overridePath = "/tmp/wenshu-resolve-\(UUID().uuidString)"
        ActiveLibrary.overrideForTesting = nil
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        UserDefaults.standard.set(overridePath, forKey: RuntimeCWD.cwdOverrideKey)
        let cwd = RuntimeCWD()

        // Relative path resolves against CWD
        let resolved = await cwd.resolve(relativePath: "book.md")
        #expect(resolved != nil)
        #expect(resolved?.path.contains(overridePath) ?? false)

        // Absolute path returns unchanged
        let absolute = "/absolute/path.md"
        let absResolved = await cwd.resolve(relativePath: absolute)
        #expect(absResolved?.path == absolute)

        // Cleanup override
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
    }

    @Test("RuntimeCWD: setCWD posts runtimeCWDDidChange notification")
    func setCWDPostsNotification() async throws {
        let prevActiveLibrary = ActiveLibrary.overrideForTesting
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            ActiveLibrary.overrideForTesting = prevActiveLibrary
            if let prevCwdOverride {
                UserDefaults.standard.set(prevCwdOverride, forKey: RuntimeCWD.cwdOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
            }
        }
        let cwd = RuntimeCWD()
        var receivedNotification = false
        let observer = NotificationCenter.default.addObserver(
            forName: .runtimeCWDDidChange,
            object: nil,
            queue: .main
        ) { _ in
            receivedNotification = true
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        try await cwd.setCWD(URL(fileURLWithPath: "/tmp/wenshu-notif-\(UUID().uuidString)"))
        // Give the notification a moment to fire
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(receivedNotification)
    }
}