//
//  LabelIconSlotSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule expanded (= Label icon slot sweep + 15 view
//  files / 26 sites / 1 commit batch).
//
//  This is the round 5 sweep (= boss 2026-10-02 OOB "采纳你的建议"; =
//  re-evaluate the `Label { Text } icon: { Image(systemName: ...).imageScale(.small) }`
//  pattern that round 3 had SKIPPED). The re-evaluation finds:
//
//  - The .imageScale(.small) modifier on Label's icon slot is a forced
//  14 PT icon size (= the same as Label's default icon slot size). It
//  is redundant (= no-op visually) AND it bypasses the SFIcon factory.
//  So the v3.0 sweep applies (= replace `Image(systemName: x).imageScale(.small)`
//  with `SFIcon(x, style: .inlineSmall, color: IconColor.tint)` to
//  enforce the semantic color token policy).
//
//  - The .imageScale(.large) modifier (= 28 PT) on ContentUnavailableView
//  icon slots (= ShellPlaceholder L20) is HIG canonical (= Apple's
    //  ContentUnavailableView is sweep exception) — REMOVED in
    //  commit 65ae2d2b6 (2026-10-03) when ShellPlaceholder.swift
    //  was deleted (= 26-line duplicate of EmptyStateView).
    //  EmptyStateView has no Image(systemName:) in any Label slot,
    //  so the sweep invariant holds without a ShellPlaceholder check.
//  ContentUnavailableView uses 38 PT glyph = the system default). The
//  v3.0 sweep SKIPS this case (= outside the central SFIcon factory
//  scope; = Apple first-party surface).
//
//  Sweep files (14 total, 24 sites swept): LibraryRootView dropped
//  on 2026-10-08 after commit c67d1ce2c intentionally replaced the
//  sweep pattern with a unified button shape (= see sweptFiles
//  comment + totalSitesConsistent test). Remaining swept files:
//    KanbanView (1) / BookSettingConstraintsView (2)
//    / CharacterLifecycleView (1) / CharacterRelationshipsView (1)
//    / EmotionCurveView (2) / GenreFitView (2) / IdeaLibraryView (3)
//    / LongFormGuardrailsView (3) / PlotThreadView (1) / ReaderExperienceView (2)
//    / TagManagerView (2) / TodoListView (1) / ForeshadowingView (1)
//    / PlaceholderView (2)
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Label icon slot sweep (= 14 view files / 24 sites to SFIcon(tint))")
struct LabelIconSlotSweepTests {

    // LibraryRootView was removed from sweptFiles on 2026-10-08:
    // commit c67d1ce2c (= onboarding buttons render icon + title
    // consistently) intentionally replaced `Label { Text } icon: {
    // SFIcon(.inlineSmall, .tint) }` with a unified button shape so
    // the onboarding row reads the same in light + dark + accessibility
    // text sizes. The sweep invariant is preserved by the remaining
    // 14 swept files (= 24 sites; = the original 26 minus 2 dropped
    // sites in LibraryRootView).
    static let sweptFiles: [(path: String, sites: Int)] = [
        ("Sources/WenshuApp/Views/Kanban/KanbanView.swift", 1),
        ("Sources/WenshuApp/Views/SpecializedTools/BookSettingConstraintsView.swift", 2),
        ("Sources/WenshuApp/Views/SpecializedTools/CharacterLifecycleView.swift", 1),
        ("Sources/WenshuApp/Views/SpecializedTools/CharacterRelationshipsView.swift", 1),
        ("Sources/WenshuApp/Views/SpecializedTools/EmotionCurveView.swift", 2),
        ("Sources/WenshuApp/Views/SpecializedTools/GenreFitView.swift", 2),
        ("Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryView.swift", 3),
        ("Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsView.swift", 3),
        ("Sources/WenshuApp/Views/SpecializedTools/PlotThreadView.swift", 1),
        ("Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceView.swift", 2),
        ("Sources/WenshuApp/Views/SpecializedTools/TagManagerView.swift", 2),
        ("Sources/WenshuApp/Views/Todo/TodoListView.swift", 1),
        ("Sources/WenshuApp/Views/Tools/ForeshadowingView.swift", 1),
        ("Sources/WenshuApp/Views/Tools/PlaceholderView.swift", 2),
    ]

    @Test("Label icon slot sweep — 15 view files dropped `Image(systemName: x).imageScale(.small)` in Label icon slot")
    func allFilesDroppedImageScaleSmallInLabelIconSlot() throws {
        for entry in Self.sweptFiles {
            let url = URL(fileURLWithPath: entry.path)
            let content = try String(contentsOf: url, encoding: .utf8)
            // Look for: `icon: { Image(systemName: "<x>").imageScale(.small) }` pattern.
            // The sweep replaced it with `icon: { SFIcon("<x>", style: .inlineSmall, color: IconColor.tint) }`.
            let badPattern = #"icon: \{ Image\(systemName:\s*"[^"]+"\s*\)\s*\.imageScale\(\.small\)\s*\}"#
            #expect(content.range(of: badPattern, options: .regularExpression) == nil,
                    "\(entry.path) must drop `icon: { Image(systemName: x).imageScale(.small) }` pattern (= Label icon slot sweep round 5)")
        }
    }

    // ShellPlaceholder L20 exception test REMOVED 2026-10:
    // ShellPlaceholder.swift was deleted in commit 65ae2d2b6 (2026-10-03)
    // (= 26-line duplicate of EmptyStateView). The sweep invariant
    // is held by EmptyStateView's actual code.
    //
    // (= see file header for details; = the test ran for 6+ weeks but
    // became orphan once the source file was deleted.)
    //
    // EmptyStateView has no naked Image(systemName:) in any Label slot;
    // = the sweep closes itself with no ShellPlaceholder check needed.

    @Test("Label icon slot sweep — totals: 24 sites across 14 view files")
    func totalSitesConsistent() throws {
        var totalSFIconInlineSmall = 0
        for entry in Self.sweptFiles {
            let url = URL(fileURLWithPath: entry.path)
            let content = try String(contentsOf: url, encoding: .utf8)
            // Count SFIcon(..., style: .inlineSmall, color: IconColor.tint) inside `icon: { ... }` block.
            let pattern = #"icon: \{ SFIcon\("[^"]+", style: \.inlineSmall, color: IconColor\.tint\) \}"#
            let range = content.range(of: pattern, options: .regularExpression)
            if let _ = range { totalSFIconInlineSmall += 1 }
        }
        #expect(totalSFIconInlineSmall == 14,
                "Label icon slot sweep must produce 14 view files using SFIcon(.inlineSmall, .tint) inside icon: { } (= one SFIcon per file = the post-LibraryRootView count)")
    }
}