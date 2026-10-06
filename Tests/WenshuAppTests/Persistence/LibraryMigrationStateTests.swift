//
//  Persistence/LibraryMigrationStateTests.swift
//
//  Unit tests for the LibraryMigrationState observable (= 003 ticket).
//
//  These tests cover the lifecycle the user actually experiences
//  during the macOS system-upgrade-style library upgrade:
//    - default state is idle
//    - begin() transitions to preparing with progress = 0
//    - beginExecuting() / beginFinalizing() move progress along the
//      0.2 -> 0.85 -> 1.0 curve
//    - complete() pins progress at 1.0
//    - fail() rolls progress back to 0 (= boss OOB 2026-10-06:
//      'progress bar rolls back to zero on failure')
//    - resetForRetry() bumps retryCount + returns stage to preparing
//      + clears lastError (= the user can press 重试 up to 3 times)
//    - updateEstimatedSecondsRemaining clamps negatives to 0
//
//  No SwiftData / no disk I/O; = pure state machine. Run time < 1s.
//
//  Swift Testing framework (= @Suite + @Test) matches the rest of
//  WenshuAppTests. @MainActor isolation matches the production
//  class (= @MainActor @Observable on LibraryMigrationState).

import Foundation
import Testing
@testable import WenshuApp

@Suite("LibraryMigrationState (lifecycle + failure semantics)")
@MainActor
struct LibraryMigrationStateTests {

    @Test("initial state is idle with zero progress")
    func initialStateIsIdle() {
        let state = LibraryMigrationState()
        #expect(state.stage == .idle)
        #expect(state.progress == 0)
        #expect(state.retryCount == 0)
        #expect(state.lastError.isEmpty)
        #expect(state.estimatedSecondsRemaining == -1)
        #expect(state.backupPath == nil)
    }

    @Test("begin transitions to preparing and resets progress")
    func beginTransitionsToPreparing() {
        let state = LibraryMigrationState()
        state.begin()
        #expect(state.stage == .preparing)
        #expect(state.progress == 0)
        #expect(state.lastError.isEmpty)
    }

    @Test("beginExecuting sets progress in the executing range")
    func beginExecutingSetsProgress() {
        let state = LibraryMigrationState()
        state.begin()
        state.beginExecuting()
        #expect(state.stage == .executing)
        #expect(state.progress > 0)
        #expect(state.progress < 1.0)
    }

    @Test("beginFinalizing sets progress in the finalizing range")
    func beginFinalizingSetsProgress() {
        let state = LibraryMigrationState()
        state.begin()
        state.beginExecuting()
        state.beginFinalizing()
        #expect(state.stage == .finalizing)
        #expect(state.progress > 0.5)
        #expect(state.progress < 1.0)
    }

    @Test("complete pins progress to 1 and clears the estimate")
    func completePinsProgressTo1() {
        let state = LibraryMigrationState()
        state.begin()
        state.beginExecuting()
        state.beginFinalizing()
        state.complete()
        #expect(state.stage == .completed)
        #expect(state.progress == 1.0)
        #expect(state.estimatedSecondsRemaining == 0)
    }

    @Test("fail rolls progress back to zero and stores the error")
    func failRollsProgressBackToZero() {
        let state = LibraryMigrationState()
        state.begin()
        state.beginExecuting()
        state.beginFinalizing()
        // Reach near completion first (= proves that fail really
        // resets progress even after finalizing has begun).
        #expect(state.progress > 0.5)
        state.fail("SwiftData store is corrupt")
        // Boss OOB 2026-10-06: progress rolls back to zero on
        // failure (= the red failure block resets the bar).
        #expect(state.progress == 0)
        #expect(state.stage == .failed)
        #expect(state.lastError == "SwiftData store is corrupt")
        #expect(state.estimatedSecondsRemaining == -1)
    }

    @Test("resetForRetry increments retryCount and returns to preparing")
    func resetForRetryIncrementsCount() {
        let state = LibraryMigrationState()
        state.begin()
        state.beginExecuting()
        state.fail("transient")
        #expect(state.retryCount == 0)
        state.resetForRetry()
        #expect(state.retryCount == 1)
        #expect(state.stage == .preparing)
        #expect(state.progress == 0)
        #expect(state.lastError.isEmpty)
        #expect(state.backupPath == nil)
    }

    @Test("three retries are observed in retryCount")
    func threeRetriesAreObserved() {
        let state = LibraryMigrationState()
        for _ in 0..<3 {
            state.begin()
            state.beginExecuting()
            state.fail("x")
            state.resetForRetry()
        }
        #expect(state.retryCount == 3)
        #expect(state.stage == .preparing)
    }

    @Test("updateEstimatedSecondsRemaining clamps negatives to zero")
    func updateEstimatedSecondsRemainingClampsNegatives() {
        let state = LibraryMigrationState()
        state.begin()
        state.updateEstimatedSecondsRemaining(5)
        #expect(state.estimatedSecondsRemaining == 5)
        state.updateEstimatedSecondsRemaining(-1)
        #expect(state.estimatedSecondsRemaining == 0)
    }

    @Test("recordBackup stores the backup URL")
    func recordBackupStoresURL() {
        let state = LibraryMigrationState()
        state.begin()
        let url = URL(fileURLWithPath: "/tmp/wenshu-migration/v1-2026-10-06.store")
        state.recordBackup(at: url)
        #expect(state.backupPath == url)
    }
}
