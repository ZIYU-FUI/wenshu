// Cronjob.swift
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
