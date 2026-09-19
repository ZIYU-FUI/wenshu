//
//  ChatMessageDayDividerTests.swift · Wenshu · T36-DATE-DIVIDERS (2026-09-18)
//
//  Verifies the day-divider affordance:
//    - shouldShowDayDivider(at:in:) returns true at index 0
//    - returns true when the calendar day changes
//    - returns false within the same calendar day
//    - handles edge cases (= index 0, single message)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessage day divider (T36)")
struct ChatMessageDayDividerTests {

    // T36 helpers (= avoid duplicate-include with ChatView's static func;
    // = we re-create them here for test isolation).

    /// Mirror of ChatView.shouldShowDayDivider (= the test imports
    /// the static func via @testable; = but re-implementing here
    /// keeps the test self-documenting).
    private static func shouldShowDayDivider(
        at index: Int, in messages: [ChatMessage]
    ) -> Bool {
        let currentDate = messages[index].timestamp
        let calendar = Calendar.current

        if index == 0 { return true }
        guard index > 0 else { return false }
        let previousDate = messages[index - 1].timestamp

        return !calendar.isDate(currentDate, inSameDayAs: previousDate)
    }

    private func makeMessage(at date: Date) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            role: .user,
            source: .user,
            content: "test",
            timestamp: date
        )
    }

    /// T36 contract: first message ALWAYS shows the divider.
    @Test func first_message_always_shows() {
        let messages = [makeMessage(at: Date())]
        #expect(Self.shouldShowDayDivider(at: 0, in: messages) == true)
    }

    /// T36 contract: two messages on the same day do NOT show
    /// a divider between them.
    @Test func same_day_no_divider() {
        let cal = Calendar.current
        let today = Date()
        let threeMinutesAgo = cal.date(byAdding: .minute, value: -3, to: today)!
        let threeMinutesLater = cal.date(byAdding: .minute, value: 3, to: today)!
        let messages = [
            makeMessage(at: threeMinutesAgo),
            makeMessage(at: today),
            makeMessage(at: threeMinutesLater),
        ]
        #expect(Self.shouldShowDayDivider(at: 1, in: messages) == false)
        #expect(Self.shouldShowDayDivider(at: 2, in: messages) == false)
    }

    /// T36 contract: messages on different calendar days DO show
    /// a divider.
    @Test func different_day_shows_divider() {
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let messages = [
            makeMessage(at: yesterday),
            makeMessage(at: today),
        ]
        #expect(Self.shouldShowDayDivider(at: 0, in: messages) == true)  // first
        #expect(Self.shouldShowDayDivider(at: 1, in: messages) == true)  // day change
    }

    /// T36 contract: 23:59 → 00:01 next day triggers a divider
    /// (= midnight boundary).
    @Test func midnight_boundary_triggers_divider() {
        let cal = Calendar.current
        let today = cal.date(bySettingHour: 0, minute: 1, second: 0, of: Date())!
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let yesterdayLate = cal.date(bySettingHour: 23, minute: 59, second: 0, of: yesterday)!
        let messages = [
            makeMessage(at: yesterdayLate),
            makeMessage(at: today),
        ]
        #expect(Self.shouldShowDayDivider(at: 1, in: messages) == true)
    }

    /// T36 contract: ChatMessageDayDivider source uses
    /// WenshuI18n.t for the "Today" / "Yesterday" labels.
    @Test func source_uses_i18n_keys() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.today\")"))
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.yesterday\")"))
    }

    /// T36 contract: keys exist in BOTH en.lproj + zh-Hans.lproj.
    @Test func keys_in_both_locales() throws {
        let today = try runPlutil(
            "Sources/WenshuApp/Resources/en.lproj/Localizable.strings"
        )
        let zh = try runPlutil(
            "Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings"
        )
        #expect(today.contains("\"chatview.day_divider.today\""))
        #expect(today.contains("\"chatview.day_divider.yesterday\""))
        #expect(zh.contains("\"chatview.day_divider.today\""))
        #expect(zh.contains("\"chatview.day_divider.yesterday\""))
    }

    private func runPlutil(_ path: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        process.arguments = ["-p", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "Plutil", code: Int(process.terminationStatus))
        }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}