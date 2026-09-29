// Cronjob.swift · WenshuApp · v0.18
//
// Local cron job scheduling (= hermes `cronjob` parity). Uses
// macOS `LaunchAgent` (`launchd`) as the canonical scheduler.

import Foundation

/// Cron task
struct Cronjob: Equatable, Sendable, Identifiable {
    let id: String
    var name: String
    var schedule: String  // cron expression: "0 * * * *"
    var command: String
    var enabled: Bool
    let createdAt: Date

    init(id: String = UUID().uuidString, name: String, schedule: String, command: String, enabled: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.schedule = schedule
        self.command = command
        self.enabled = enabled
        self.createdAt = createdAt
    }
}

/// Cronjob (in-memory,; LaunchAgent yes ticket)
actor CronjobStore {
    private var jobs: [String: Cronjob] = [:]
    private let plistPath: URL

    init() {
        // macOS LaunchAgent path: ~/Library/LaunchAgents/wenshu.cronjob.<id>.plist
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        let agents = support.appendingPathComponent("LaunchAgents", isDirectory: true)
        try? FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        self.plistPath = agents
    }

    func add(_ job: Cronjob) {
        jobs[job.id] = job
        // Actual plist generation (simplified, unwritten)
    }

    func get(id: String) -> Cronjob? {
        jobs[id]
    }

    func list() -> [Cronjob] {
        Array(jobs.values).sorted { $0.createdAt < $1.createdAt }
    }

    func setEnabled(id: String, enabled: Bool) {
        guard var job = jobs[id] else { return }
        job.enabled = enabled
        jobs[id] = job
    }

    func delete(id: String) {
        jobs.removeValue(forKey: id)
    }

    /// parseSchedule: verify cron expression (: 5 field)
    /// field: (cron 5 field)
    static func parseSchedule(_ schedule: String) -> Bool {
        let parts = schedule.split(separator: " ")
        return parts.count == 5
    }

    /// nextRun: run (, cron)
    static func nextRun(schedule: String, after date: Date = Date()) -> Date? {
        guard parseSchedule(schedule) else { return nil }
        // Simplified: Add 1 hour (actual cron parser)
        return date.addingTimeInterval(3600)
    }
}