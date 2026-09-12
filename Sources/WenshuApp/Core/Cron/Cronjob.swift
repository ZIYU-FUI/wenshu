//
//  Cronjob.swift · Wenshu · v0.18 ticket 21 (hermes replica)
//
// local Cron task (hermes cronjob).
// 2026-08-19 ", Apple " + "can".
//
// wenshu = SwiftUI app. Cronjob (autosave / / backup).
// Apple HIG: macOS LaunchAgent (launchd).
//

import Foundation

/// Cron task
public struct Cronjob: Equatable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var schedule: String  // cron expression: "0 * * * *"
    public var command: String
    public var enabled: Bool
    public let createdAt: Date

    public init(id: String = UUID().uuidString, name: String, schedule: String, command: String, enabled: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.schedule = schedule
        self.command = command
        self.enabled = enabled
        self.createdAt = createdAt
    }
}

/// Cronjob (in-memory,; LaunchAgent yes ticket)
public actor CronjobStore {
    private var jobs: [String: Cronjob] = [:]
    private let plistPath: URL

    public init() {
        // macOS LaunchAgent path: ~/Library/LaunchAgents/wenshu.cronjob.<id>.plist
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        let agents = support.appendingPathComponent("LaunchAgents", isDirectory: true)
        try? FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        self.plistPath = agents
    }

    public func add(_ job: Cronjob) {
        jobs[job.id] = job
        // Actual plist generation (simplified, unwritten)
    }

    public func get(id: String) -> Cronjob? {
        jobs[id]
    }

    public func list() -> [Cronjob] {
        Array(jobs.values).sorted { $0.createdAt < $1.createdAt }
    }

    public func setEnabled(id: String, enabled: Bool) {
        guard var job = jobs[id] else { return }
        job.enabled = enabled
        jobs[id] = job
    }

    public func delete(id: String) {
        jobs.removeValue(forKey: id)
    }

    /// parseSchedule: verify cron expression (: 5 field)
    /// field: (cron 5 field)
    public static func parseSchedule(_ schedule: String) -> Bool {
        let parts = schedule.split(separator: " ")
        return parts.count == 5
    }

    /// nextRun: run (, cron)
    public static func nextRun(schedule: String, after date: Date = Date()) -> Date? {
        guard parseSchedule(schedule) else { return nil }
        // Simplified: Add 1 hour (actual cron parser)
        return date.addingTimeInterval(3600)
    }
}