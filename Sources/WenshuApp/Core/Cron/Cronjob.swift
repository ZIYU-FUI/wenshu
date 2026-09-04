//
//  Cronjob.swift · Wenshu · v0.18 ticket 21 (hermes replica)
//
//  本地 Cron 任务管理 (复刻 hermes cronjob 真值简化版).
//  老板 2026-08-19 拍 "全模块复刻, Apple 体系实现" + "不符合文枢定位的可以复刻".
//
//  wenshu 定位 = SwiftUI 桌面写作 app. Cronjob 写作用 (定时自动保存 / 提醒 / 备份).
//  Apple HIG 真值: macOS LaunchAgent (launchd 真值).
//

import Foundation

/// Cron 任务真值
public struct Cronjob: Equatable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var schedule: String  // cron expression: "0 * * * *" 之类
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

/// Cronjob 存储 (in-memory, 简化版; 实际集成 LaunchAgent 是后续 ticket)
public actor CronjobStore {
    private var jobs: [String: Cronjob] = [:]
    private let plistPath: URL

    public init() {
        // macOS LaunchAgent 路径真值: ~/Library/LaunchAgents/wenshu.cronjob.<id>.plist
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

    /// parseSchedule: 验证 cron expression 真值 (简化版: 5 字段)
    /// 字段: 分 时 日 月 周 (cron 5 字段)
    public static func parseSchedule(_ schedule: String) -> Bool {
        let parts = schedule.split(separator: " ")
        return parts.count == 5
    }

    /// nextRun: 估算下次运行 (简化版, 不真算 cron)
    public static func nextRun(schedule: String, after date: Date = Date()) -> Date? {
        guard parseSchedule(schedule) else { return nil }
        // Simplified: Add 1 hour (actual cron parser)
        return date.addingTimeInterval(3600)
    }
}