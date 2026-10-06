//
//  Persistence/LibraryMigrationState.swift
//
//  Observable state machine for the .ws library SwiftData upgrade
//  arc (= boss OOB on 2026-10-06: macOS system-upgrade-style UX with
//  visible progress panel + 3 stages + auto retry up to 3 times).
//
//  Apple SwiftData's SchemaMigrationPlan API does not expose per-
//  stage callbacks, so we cannot read precise progress from the
//  runtime. Per boss OOB on 2026-10-06 (= 'do real progress like
//  Apple system updates'; = no lying timer animations), this state
//  machine breaks the work into 3 real stages driven by the actual
//  SwiftData container init flow:
//
//    1. preparing (= back up the user's on-disk .store to
//       <.ws>/migration-backups/, so a catastrophic migration
//       failure never costs the user their library).
//    2. executing (= ModelContainer init with the plan in place;
//       SwiftData runs the .lightweight V1 to V2 stage internally
//       and either succeeds or throws).
//    3. finalizing (= write the new WSSchemaVersion key to the
//       library's Info.plist so the next launch skips the panel).
//
//  Time-estimate formula (= boss OOB on 2026-10-06: 'time estimate,
//  real'): the first stage's measured elapsed time becomes the
//  reference. Subsequent stages use a 1 : 3 : 1 weight ratio
//  (= preparing / executing / finalizing) so the predicted total
//  converges as preparing finishes. The estimate is intentionally
//  approximate; = it is read by LibraryMigrationPanel purely as a
//  label, never as a deadline.
//
//  Failure semantics (= boss OOB on 2026-10-06: 'progress bar rolls
//  back to zero on failure, then prompt to retry'). On fail():
//    - stage := .failed
//    - progress := 0
//    - lastError := the human-readable error string
//  The UI then shows the red failure panel with a 重试 button.
//  resetForRetry() returns stage to .preparing and bumps retryCount
//  (= the UI caps auto-retry at 3; = see LibraryMigrationPanel).
//
//  Threading: @MainActor because both the SwiftData ModelContainer
//  init (= called from WenshuAppDelegate.applicationDidFinishLaunching)
//  and the SwiftUI panel that consumes this state (= LibraryRootView)
//  live on the main thread. Pure-data class (= no @Model, no disk I/O;
//  = the I/O lives in LibraryMigrator / LibraryBootstrapper; = see
//  Storage/LibraryMigrator.swift for the existing file-system
//  helpers this state machine is the UI bridge for).

import Foundation

@MainActor
@Observable
final class LibraryMigrationState {
    /// Lifecycle of one migration attempt. .idle = no migration
    /// pending (= either fresh install or schema already current);
    /// .completed = last attempt succeeded; = .failed = last
    /// attempt threw and the user has not yet pressed 重试.
    enum Stage: String {
        case idle
        case preparing
        case executing
        case finalizing
        case completed
        case failed
    }

    var stage: Stage = .idle
    /// 0.0 ... 1.0. Rolls back to 0 on fail (= boss OOB 2026-10-06).
    var progress: Double = 0
    /// Predicted seconds remaining for the current stage. -1 when
    /// no estimate is available yet (= first ~100ms before preparing
    /// has measured its baseline).
    var estimatedSecondsRemaining: Int = -1
    /// Path of the backup .store written during preparing. Populated
    /// before executing starts so the failure UI can show it
    /// immediately when executing throws.
    var backupPath: URL?
    /// Human-readable last error from the most recent fail() call.
    /// Empty (= "") when no failure has occurred in this session.
    var lastError: String = ""
    /// Number of failed attempts in this session. Bumped by
    /// resetForRetry (= the UI caps auto-retry at 3 per boss OOB
    /// 2026-10-06 = 'match Apple system upgrade retry behavior').
    var retryCount: Int = 0

    /// Mark the start of a migration attempt. Resets progress and
    /// the last error; = does NOT reset retryCount (= retryCount is
    /// sticky across attempts in one session; = only goes back to
    /// 0 on a fresh process launch).
    func begin() {
        stage = .preparing
        progress = 0
        estimatedSecondsRemaining = -1
        backupPath = nil
        lastError = ""
    }

    /// Move into the executing stage (= the actual SwiftData
    /// ModelContainer init). Sets progress to 0.2 (= the 1/5 share
    /// that preparing owns in the 1:3:1 weight ratio).
    func beginExecuting() {
        stage = .executing
        progress = 0.2
    }

    /// Move into the finalizing stage (= write WSSchemaVersion to
    /// Info.plist). Sets progress to 0.85 (= the executing stage
    /// claimed 0.2 .. 0.85 = the 3/5 share).
    func beginFinalizing() {
        stage = .finalizing
        progress = 0.85
    }

    /// Successful end. Progress = 1.0; = the UI panel dismisses on
    /// observing .completed.
    func complete() {
        stage = .completed
        progress = 1.0
        estimatedSecondsRemaining = 0
    }

    /// Failure end (= boss OOB 2026-10-06 'progress bar rolls back
    /// to zero'). Progress = 0; = the UI shows the red panel with
    /// the 重试 button.
    func fail(_ error: String) {
        stage = .failed
        progress = 0
        estimatedSecondsRemaining = -1
        lastError = error
    }

    /// Reset for a retry attempt (= boss OOB 2026-10-06). Returns
    /// stage to .preparing so the panel re-shows the preparing
    /// progress; = bumps retryCount so the UI can stop showing the
    /// 重试 button once 3 retries have failed (= Apple system
    /// upgrade parity).
    func resetForRetry() {
        stage = .preparing
        progress = 0
        estimatedSecondsRemaining = -1
        backupPath = nil
        lastError = ""
        retryCount += 1
    }

    /// Update the predicted time remaining (= called by the wire-up
    /// layer after each preparing phase measurement). The UI uses
    /// this to render the 「预计还需 X 秒」 label.
    func updateEstimatedSecondsRemaining(_ seconds: Int) {
        estimatedSecondsRemaining = max(seconds, 0)
    }

    /// Record the backup .store path produced during preparing.
    /// Called once per attempt (= the migrator writes a timestamped
    /// file each time, so retry attempts produce distinct backups).
    func recordBackup(at url: URL) {
        backupPath = url
    }
}
