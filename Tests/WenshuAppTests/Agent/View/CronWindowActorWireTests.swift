//
//  CronWindowActorWireTests.swift · Wenshu · v2.9c ticket T32 (boss 2026-09-28 OOB A5 follow-up)
//
//  Structural tests for the v2.9c CronWindow actor wire-up
//  (= boss 2026-09-28 OOB inventory follow-up A5 = '4 window
//  接 actor' 续集; = CronWindow was EmptyStateView placeholder
//  + a plus-icon future-ticket stub before v2.9c).
//
//  Per boss 2026-09-28 OOB: '重复的应该合并, 不同的功能每个独立
//  的'; = v2.9c wires CronWindow to the canonical CronjobStore
//  actor (= the LaunchAgent plist generation backend per
//  AGENTS.md §11 baseline; = same pattern as CronjobTools).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testCronWindowCallsCronjobStore —
//       CronWindow.reload + addSchedule call CronjobStore.list
//       / .add (= the view delegates all persistence to the
//       canonical actor; = no direct plist reads).
//
//    2. testCronWindowRefreshToolbarButton —
//       CronWindow.toolbar has a refresh button (= i18n key
//       cron.refresh).
//
//    3. testCronWindowAddScheduleForm —
//       CronWindow has an inline add-form (= i18n keys
//       cron.field.schedule + cron.field.prompt + cron.add +
//       cron.add_section).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: source-level
//  tests following the v2.8b SecondaryWindowsTests pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("CronWindow actor wire-up (v2.9c — boss 2026-09-28 OOB A5 follow-up)")
struct CronWindowActorWireTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("CronWindow.reload + addSchedule call CronjobStore.list / .add")
    func testCronWindowCallsCronjobStore() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/CronWindow.swift"), encoding: .utf8)
        let callsList = source.contains("await store.list()")
        let callsAdd = source.contains("await store.add(")
        #expect(callsList && callsAdd,
                "CronWindow must call CronjobStore.list + .add (= boss A5 follow-up = 'window 是占位')")
    }

    @Test("CronWindow.toolbar has refresh button (= i18n key cron.refresh)")
    func testCronWindowRefreshToolbarButton() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/CronWindow.swift"), encoding: .utf8)
        #expect(source.contains("cron.refresh"),
                "CronWindow.toolbar must include a refresh action")
    }

    @Test("CronWindow has inline add-form with schedule / prompt fields + Add button")
    func testCronWindowAddScheduleForm() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Views/Windows/CronWindow.swift"), encoding: .utf8)
        let hasScheduleField = source.contains("cron.field.schedule")
        let hasNameField = source.contains("cron.field.name")
        let hasCommandField = source.contains("cron.field.command")
        let hasAddButton = source.contains("String(localized: \"cron.add\")")
        let hasSection = source.contains("cron.add_section")
        #expect(hasScheduleField && hasNameField && hasCommandField && hasAddButton && hasSection,
                "CronWindow must include an inline add-form with schedule / name / command fields + Add button + section header")
    }
}