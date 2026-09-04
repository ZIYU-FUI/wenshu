// CronScheduleParserTests.swift · Wenshu · v0.28
//
// Hermes-port validation tests for CronScheduleParser.swift
// (= wenshu M6 ticket 20 = hermes-port batch 3 tenth and final ticket).
//
// Tests cover:
// - CronField.parse wildcards, lists, ranges, steps
// - CronField aliases (month + day-of-week names)
// - CronExpression.parse validation
// - CronExpression.matches for date components
// - CronExpression.nextFireTime computation
// - Cronjob extension: parsedSchedule + nextFireTime

import Foundation
import Testing
@testable import WenshuApp

@Suite("CronScheduleParser (hermes verbatim port — M6 ticket 20)")
struct CronScheduleParserTests {

    // MARK: - CronField.parse

    @Test("parse wildcard '*' returns full range")
    func parseWildcard() {
        let field = CronField.parse("*", range: 0...59)
        #expect(field.allowedValues.count == 60)
        #expect(field.matches(0))
        #expect(field.matches(30))
        #expect(field.matches(59))
    }

    @Test("parse step '*/15' returns {0, 15, 30, 45}")
    func parseStep() {
        let field = CronField.parse("*/15", range: 0...59)
        #expect(field.allowedValues == Set([0, 15, 30, 45]))
        #expect(field.matches(0))
        #expect(field.matches(15))
        #expect(!field.matches(10))
    }

    @Test("parse list '1,3,5' returns {1, 3, 5}")
    func parseList() {
        let field = CronField.parse("1,3,5", range: 0...59)
        #expect(field.allowedValues == Set([1, 3, 5]))
        #expect(field.matches(1))
        #expect(field.matches(5))
        #expect(!field.matches(2))
    }

    @Test("parse range '1-5' returns {1, 2, 3, 4, 5}")
    func parseRange() {
        let field = CronField.parse("1-5", range: 0...59)
        #expect(field.allowedValues == Set([1, 2, 3, 4, 5]))
    }

    @Test("parse range with step '1-30/2' returns odd values up to 29")
    func parseRangeWithStep() {
        let field = CronField.parse("1-30/2", range: 0...59)
        #expect(field.matches(1))
        #expect(field.matches(3))
        #expect(field.matches(29))
        #expect(field.matches(30) == false)  // 30 = end, excluded by step=2
        #expect(!field.matches(2))
    }

    @Test("parse single value '0' returns {0}")
    func parseSingle() {
        let field = CronField.parse("0", range: 0...59)
        #expect(field.allowedValues == Set([0]))
        #expect(field.matches(0))
        #expect(!field.matches(1))
    }

    // MARK: - Aliases

    @Test("parse month alias 'jan' returns {1}")
    func parseMonthAlias() {
        let field = CronField.parse("jan", range: 1...12, aliases: CronExpression.monthAliases)
        #expect(field.allowedValues == Set([1]))
    }

    @Test("parse day-of-week alias 'mon' returns {1}")
    func parseDayOfWeekAlias() {
        let field = CronField.parse("mon", range: 0...6, aliases: CronExpression.dayOfWeekAliases)
        #expect(field.allowedValues == Set([1]))
    }

    @Test("parse alias is case-insensitive")
    func parseAliasCaseInsensitive() {
        let field = CronField.parse("MON", range: 0...6, aliases: CronExpression.dayOfWeekAliases)
        #expect(field.matches(1))
    }

    // MARK: - CronExpression.parse

    @Test("parse valid 5-field expression")
    func parseValid() throws {
        let expr = try CronExpression.parse("0 9 * * 1-5")
        #expect(expr.minute.allowedValues == Set([0]))
        #expect(expr.hour.allowedValues == Set([9]))
        #expect(expr.dayOfMonth.allowedValues.count == 31)  // *
        #expect(expr.month.allowedValues.count == 12)  // *
        #expect(expr.dayOfWeek.allowedValues == Set([1, 2, 3, 4, 5]))
    }

    @Test("parse rejects wrong field count")
    func parseRejectsBadCount() {
        #expect(throws: CronParseError.self) {
            try CronExpression.parse("0 9 * *")  // only 4 fields
        }
    }

    @Test("parse accepts common cron schedules")
    func parseCommonSchedules() throws {
        _ = try CronExpression.parse("*/5 * * * *")      // every 5 minutes
        _ = try CronExpression.parse("0 0 * * *")         // daily at midnight
        _ = try CronExpression.parse("0 0 1 * *")         // first of every month
        _ = try CronExpression.parse("30 2 * * sun")      // 2:30am every Sunday
        _ = try CronExpression.parse("0 9-17 * * 1-5")    // hourly during business hours
    }

    // MARK: - CronExpression.matches

    @Test("matches accepts midnight on weekdays")
    func matchesWeekdayMidnight() throws {
        let expr = try CronExpression.parse("0 0 * * 1-5")
        // 2026-09-01 (Tuesday) at 00:00 — Foundation weekday = 3 (Sun=1) → cron 2
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 1
        components.hour = 0
        components.minute = 0
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!
        #expect(expr.matches(date: date, calendar: calendar) == true)
    }

    @Test("matches rejects midnight on Saturday")
    func matchesRejectsSaturday() throws {
        let expr = try CronExpression.parse("0 0 * * 1-5")
        // 2026-09-05 (Saturday)
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 5
        components.hour = 0
        components.minute = 0
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!
        #expect(expr.matches(date: date, calendar: calendar) == false)
    }

    // MARK: - nextFireTime

    @Test("nextFireTime finds the next minute matching the expression")
    func nextFireTimeDaily() throws {
        let expr = try CronExpression.parse("30 9 * * *")
        // Anchor at 2026-09-01 08:00:00 — next fire should be same day 09:30
        var anchorComponents = DateComponents()
        anchorComponents.year = 2026
        anchorComponents.month = 9
        anchorComponents.day = 1
        anchorComponents.hour = 8
        anchorComponents.minute = 0
        let calendar = Calendar(identifier: .gregorian)
        let anchor = calendar.date(from: anchorComponents)!
        let next = expr.nextFireTime(after: anchor, calendar: calendar)!
        let nextComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next)
        #expect(nextComponents.hour == 9)
        #expect(nextComponents.minute == 30)
    }

    @Test("nextFireTime returns nil if no match in horizon")
    func nextFireTimeNotFound() throws {
        let expr = try CronExpression.parse("0 0 30 2 *")  // Feb 30 (= impossible)
        var anchorComponents = DateComponents()
        anchorComponents.year = 2026
        anchorComponents.month = 1
        anchorComponents.day = 1
        let calendar = Calendar(identifier: .gregorian)
        let anchor = calendar.date(from: anchorComponents)!
        #expect(expr.nextFireTime(after: anchor, calendar: calendar) == nil)
    }

    // MARK: - Cronjob extension

    @Test("Cronjob.parsedSchedule returns nil for empty schedule")
    func cronjobEmptySchedule() {
        let job = Cronjob(name: "x", schedule: "", command: "ls")
        #expect(job.parsedSchedule == nil)
    }

    @Test("Cronjob.parsedSchedule returns nil for wildcard schedule")
    func cronjobWildcardSchedule() {
        let job = Cronjob(name: "x", schedule: "* * * * *", command: "ls")
        #expect(job.parsedSchedule == nil)
    }

    @Test("Cronjob.parsedSchedule returns expression for valid schedule")
    func cronjobValidSchedule() {
        let job = Cronjob(name: "x", schedule: "0 9 * * *", command: "ls")
        #expect(job.parsedSchedule != nil)
    }

    @Test("Cronjob.nextFireTime delegates to CronExpression")
    func cronjobNextFireTime() {
        let job = Cronjob(name: "backup", schedule: "0 3 * * *", command: "run-backup")
        let anchor = Date(timeIntervalSince1970: 0)  // 1970-01-01 00:00:00 UTC
        let next = job.nextFireTime(after: anchor)
        #expect(next != nil)
    }
}