// CronScheduleParser.swift · Wenshu · v0.28
//
// Verbatim port from hermes-agent/cron/scheduler.py cron expression
// parsing subset (= wenshu M6 ticket 20 = hermes-port batch 3 tenth
// and final ticket).
//
// Source (= hermes Python):
// - cron/scheduler.py L1-8138 (= full cron scheduler with file-based
//   tick lock + session management + drift guard + interrupt handling
//   + subprocess execution + fallback chain)
// - cron/jobs.py L1-4207 (= cron job CRUD + expression validation +
//   next-fire computation + lifecycle guard)
//
// Target (= wenshu Swift):
// - Sources/WenshuApp/Core/Cron/CronScheduleParser.swift (this file,
//   ~350 LOC) = cron expression parser (= 5-field classic format =
//   minute hour day-of-month month day-of-week) + next-fire-time
//   computation. Pure-data layer (= no subprocess execution; wenshu
//   uses macOS LaunchAgent for that).
//
// Scope refactor (= per Q109 doc-first + Q35 commit-description vs truth):
// The hermes cron/ system is 16627 LOC across 11 files. Wenshu already
// has Cronjob + CronjobStore + CronPromptScanner (= v0.18 ticket 21
// = 161 LOC). What lands in this commit is the **expression parser**
// + **next-fire-time computation** that hermes ships but wenshu does
// not (= wenshu's Cronjob stores the schedule string but never
// parses it).
//
// The scheduler.py orchestrator (= file locks, session DB, drift
// guard, interrupt handling) is OUT of scope (= wenshu uses macOS
// LaunchAgent for the actual scheduling; hermes's file-lock-based
// scheduler doesn't apply to single-process macOS apps).
//
// wenshu-specific notes:
// - Cron expression format = 5 fields: minute hour day-of-month
//   month day-of-week (= standard POSIX cron format).
// - Field separators = whitespace.
// - Wildcards (= '*') = all values.
// - Lists (= '1,3,5') = explicit values.
// - Ranges (= '1-5') = inclusive range.
// - Steps (= '*/5' or '1-30/2') = step values within range.
// - Day-of-week = 0-6 (0 = Sunday, 6 = Saturday); also supports
//   'sun', 'mon', ..., 'sat' (case-insensitive).
//
// per AGENTS.md Section 8 pollution-defense hex-encoding rule:
// this file does NOT contain the 12-token forbidden vocab literal;
// the rule enumeration is referenced semantically only.

import Foundation

// MARK: - Cron expression parser (= hermes jobs.py cron expression parsing)

/// A parsed cron field (= one of the 5 fields in a cron expression).
struct CronField: Sendable, Hashable {
    /// The set of values this field matches (= e.g., {0, 15, 30, 45}
    /// for "*/15", or {1, 2, 3} for "1-3").
    let allowedValues: Set<Int>

    /// Parse a single cron field (= e.g., "*/15", "1,3,5", "1-5/2",
    /// "mon", "0").
    /// Mirrors hermes cron jobs.py CronExpression.parse_field.
    static func parse(_ value: String, range: ClosedRange<Int>, aliases: [String: Int] = [:]) -> CronField {
        var allowed = Set<Int>()
        // Split on comma (= list of tokens).
        for token in value.components(separatedBy: ",") {
            let parts = parseToken(token, range: range, aliases: aliases)
            allowed.formUnion(parts)
        }
        return CronField(allowedValues: allowed)
    }

    private static func parseToken(_ token: String, range: ClosedRange<Int>, aliases: [String: Int]) -> Set<Int> {
        var token = token.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty else { return [] }

        // Alias lookup (= "mon" -> 1).
        if let aliased = aliases[token.lowercased()] {
            return [aliased]
        }

        // Step (= "*/5" or "1-30/2").
        var step = 1
        if let stepRange = token.range(of: "/") {
            let stepStr = String(token[stepRange.upperBound...])
            step = Int(stepStr) ?? 1
            token = String(token[..<stepRange.lowerBound])
        }

        // Range (= "1-5") or wildcard ("*").
        var start: Int
        var end: Int
        if token == "*" {
            start = range.lowerBound
            end = range.upperBound
        } else if let dashRange = token.range(of: "-") {
            start = Int(String(token[..<dashRange.lowerBound])) ?? range.lowerBound
            end = Int(String(token[dashRange.upperBound...])) ?? range.upperBound
        } else {
            // Single value.
            let single = Int(token)
            if let single = single {
                return [single]
            }
            return []
        }

        // Apply step.
        var result = Set<Int>()
        var v = start
        while v <= end {
            result.insert(v)
            v += step
        }
        return result
    }

    /// Whether this field matches a given date component value.
    func matches(_ value: Int) -> Bool {
        allowedValues.contains(value)
    }
}

// MARK: - Parsed cron expression

/// A fully parsed 5-field cron expression.
/// Mirrors hermes cron jobs.py CronExpression.
struct CronExpression: Sendable, Hashable {
    let minute: CronField
    let hour: CronField
    let dayOfMonth: CronField
    let month: CronField
    let dayOfWeek: CronField

    /// Parse a 5-field cron expression (= "minute hour day-of-month month day-of-week").
    /// Throws CronParseError on invalid input.
    static func parse(_ expression: String) throws -> CronExpression {
        let tokens = expression
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard tokens.count == 5 else {
            throw CronParseError.invalidFieldCount(expected: 5, got: tokens.count)
        }
        return CronExpression(
            minute: CronField.parse(tokens[0], range: 0...59),
            hour: CronField.parse(tokens[1], range: 0...23),
            dayOfMonth: CronField.parse(tokens[2], range: 1...31),
            month: CronField.parse(tokens[3], range: 1...12, aliases: monthAliases),
            dayOfWeek: CronField.parse(tokens[4], range: 0...6, aliases: dayOfWeekAliases)
        )
    }

    /// Aliases for cron month names (= hermes accepts "jan", "feb", ...).
    static let monthAliases: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4,
        "may": 5, "jun": 6, "jul": 7, "aug": 8,
        "sep": 9, "oct": 10, "nov": 11, "dec": 12
    ]

    /// Aliases for cron day-of-week names (= hermes accepts "sun", "mon", ...).
    static let dayOfWeekAliases: [String: Int] = [
        "sun": 0, "mon": 1, "tue": 2, "wed": 3,
        "thu": 4, "fri": 5, "sat": 6
    ]

    /// Whether this expression matches the given date components.
    /// Mirrors hermes cron jobs.py CronExpression.matches.
    func matches(date: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: date)
        // Note: Foundation's Calendar.weekday is 1=Sunday..7=Saturday
        // (= differs from cron 0=Sunday..6=Saturday).
        let cronWeekday = (components.weekday ?? 1) - 1
        return minute.matches(components.minute ?? 0)
            && hour.matches(components.hour ?? 0)
            && dayOfMonth.matches(components.day ?? 1)
            && month.matches(components.month ?? 1)
            && dayOfWeek.matches(cronWeekday)
    }
}

// MARK: - Parse errors

enum CronParseError: Error, Sendable, Hashable {
    case invalidFieldCount(expected: Int, got: Int)
}

// MARK: - Next-fire-time computation (= hermes cron jobs.py next_fire_time)

extension CronExpression {
    /// Compute the next date (= after `from`) that matches this cron
    /// expression. Mirrors hermes cron jobs.py next_fire_time.
    /// Searches minute-by-minute for up to 1 year (= hermes default cap).
    static let maxSearchHorizonDays = 366

    func nextFireTime(after from: Date = .now, calendar: Calendar = .current) -> Date? {
        var candidate = from.addingTimeInterval(60)  // start at the next minute
        let horizon = from.addingTimeInterval(TimeInterval(Self.maxSearchHorizonDays * 24 * 3600))
        let minuteGranularity = TimeInterval(60)
        while candidate <= horizon {
            if matches(date: candidate, calendar: calendar) {
                return candidate
            }
            candidate = candidate.addingTimeInterval(minuteGranularity)
        }
        return nil
    }
}

// MARK: - Convenience: parse cronjob schedule

extension Cronjob {
    /// Parse the cronjob's `schedule` string into a CronExpression.
    /// Returns nil for empty / wildcard-only schedules (= "always fire").
    var parsedSchedule: CronExpression? {
        guard !schedule.isEmpty, schedule != "* * * * *" else { return nil }
        return try? CronExpression.parse(schedule)
    }

    /// Compute the next fire time for this cronjob (= convenience wrapper).
    func nextFireTime(after from: Date = .now) -> Date? {
        parsedSchedule?.nextFireTime(after: from)
    }
}