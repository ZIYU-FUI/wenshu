//
//  RuntimeCWDDisplayChipTests.swift · Wenshu · v0.37 Batch 2.4 sub-step 2
//
//  Tests for the RuntimeCWDDisplayChip UI component.
//
// Per cadence 2026-09-03 'resume' + 'PO execute,don't'
// + 'when done, verify visual and frontend flow together' + '1 RULE 1 commit'.
//

import Testing
import Foundation
import SwiftUI
@testable import WenshuApp

@MainActor
@Suite("RuntimeCWDDisplayChip (= Batch 2.4 UI component)")
struct RuntimeCWDDisplayChipTests {

    @Test("RuntimeCWDDisplayChip: instantiates without crash")
    func instantiate() {
        let chip = RuntimeCWDDisplayChip()
        // Verify the chip body builds (= view graph construction succeeds)
        _ = chip.body
    }

    @Test("RuntimeCWD: displayLabel returns 'Unset' when no library + no override")
    func displayLabelUnset() async {

        // v1.08 ticket 001 (= per Q34 5.4 fix root cause): capture the previous RuntimeCWD UserDefaults state at test start, then defer restoring it. This ensures each test starts with the state left by the previous test (= true hermetic isolation) and ends with the same state (= the next test is unaffected).
        let prevLibraryPath = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey)
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            if let prevLibraryPath {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.set(prevLibraryPath, forKey: RuntimeCWD.libraryPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
            }
            if let prevCwdOverride {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
                UserDefaults.standard.set(prevCwdOverride, forKey: RuntimeCWD.cwdOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
            }
        }
        // Clear any existing defaults to ensure clean state
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        let cwd = RuntimeCWD()
        let label = await cwd.displayLabel()
        #expect(label.contains("Unset") || label.contains("unset"))
    }

    @Test("RuntimeCWD: displayLabel shows 'Library:' prefix when library path is set")
    func displayLabelLibrary() async {

        // v1.08 ticket 001 (= per Q34 5.4 fix root cause): capture the previous RuntimeCWD UserDefaults state at test start, then defer restoring it. This ensures each test starts with the state left by the previous test (= true hermetic isolation) and ends with the same state (= the next test is unaffected).
        let prevLibraryPath = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey)
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            if let prevLibraryPath {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.set(prevLibraryPath, forKey: RuntimeCWD.libraryPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
            }
            if let prevCwdOverride {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
                UserDefaults.standard.set(prevCwdOverride, forKey: RuntimeCWD.cwdOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
            }
        }
        let tempPath = "/tmp/wenshu-test-library-\(UUID().uuidString).ws"
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
        UserDefaults.standard.set(tempPath, forKey: RuntimeCWD.libraryPathKey)
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        let cwd = RuntimeCWD()
        let label = await cwd.displayLabel()
        #expect(label.contains("Library"))
        #expect(label.contains(tempPath))
        // Cleanup
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
    }

    @Test("RuntimeCWD: displayLabel shows 'Override:' prefix when override is set")
    func displayLabelOverride() async {

        // v1.08 ticket 001 (= per Q34 5.4 fix root cause): capture the previous RuntimeCWD UserDefaults state at test start, then defer restoring it. This ensures each test starts with the state left by the previous test (= true hermetic isolation) and ends with the same state (= the next test is unaffected).
        let prevLibraryPath = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey)
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            if let prevLibraryPath {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.set(prevLibraryPath, forKey: RuntimeCWD.libraryPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
            }
            if let prevCwdOverride {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
                UserDefaults.standard.set(prevCwdOverride, forKey: RuntimeCWD.cwdOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
            }
        }
        let overridePath = "/tmp/wenshu-override-\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        UserDefaults.standard.set(overridePath, forKey: RuntimeCWD.cwdOverrideKey)
        let cwd = RuntimeCWD()
        let label = await cwd.displayLabel()
        #expect(label.contains("Override"))
        #expect(label.contains(overridePath))
        // Cleanup
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
    }

    @Test("RuntimeCWD: setCWD override takes precedence over library path")
    func setCWDOverride() async throws {

        // v1.08 ticket 001 (= per Q34 5.4 fix root cause): capture the previous RuntimeCWD UserDefaults state at test start, then defer restoring it. This ensures each test starts with the state left by the previous test (= true hermetic isolation) and ends with the same state (= the next test is unaffected).
        let prevLibraryPath = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey)
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            if let prevLibraryPath {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.set(prevLibraryPath, forKey: RuntimeCWD.libraryPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
            }
            if let prevCwdOverride {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
                UserDefaults.standard.set(prevCwdOverride, forKey: RuntimeCWD.cwdOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
            }
        }
        let libraryPath = "/tmp/wenshu-library-\(UUID().uuidString).ws"
        let overridePath = "/tmp/wenshu-override-\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
        UserDefaults.standard.set(libraryPath, forKey: RuntimeCWD.libraryPathKey)
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

        // Cleanup
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
    }

    @Test("RuntimeCWD: resolve(relativePath) uses current CWD")
    func resolveRelativePath() async throws {

        // v1.08 ticket 001 (= per Q34 5.4 fix root cause): capture the previous RuntimeCWD UserDefaults state at test start, then defer restoring it. This ensures each test starts with the state left by the previous test (= true hermetic isolation) and ends with the same state (= the next test is unaffected).
        let prevLibraryPath = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey)
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            if let prevLibraryPath {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.set(prevLibraryPath, forKey: RuntimeCWD.libraryPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
            }
            if let prevCwdOverride {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
                UserDefaults.standard.set(prevCwdOverride, forKey: RuntimeCWD.cwdOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
            }
        }
        let overridePath = "/tmp/wenshu-resolve-\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
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

        // Cleanup
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
    }

    @Test("RuntimeCWD: setCWD posts runtimeCWDDidChange notification")
    func setCWDPostsNotification() async throws {

        // v1.08 ticket 001 (= per Q34 5.4 fix root cause): capture the previous RuntimeCWD UserDefaults state at test start, then defer restoring it. This ensures each test starts with the state left by the previous test (= true hermetic isolation) and ends with the same state (= the next test is unaffected).
        let prevLibraryPath = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey)
        let prevCwdOverride = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            if let prevLibraryPath {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.set(prevLibraryPath, forKey: RuntimeCWD.libraryPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
            }
            if let prevCwdOverride {
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
                UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
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