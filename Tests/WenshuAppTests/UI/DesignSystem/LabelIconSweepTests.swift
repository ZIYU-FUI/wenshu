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
//    ContentUnavailableView is sweep exception) — REMOVED in
//    commit 65ae2d2b6 (2026-10-03) when ShellPlaceholder.swift
//    was deleted (= 26-line duplicate of EmptyStateView).
//    EmptyStateView has no Image(systemName:) in any Label slot,
//    so the sweep invariant holds without a ShellPlaceholder check.
//    ContentUnavailableView uses 38 PT glyph = the system default). The
//    v3.0 sweep SKIPS this case (= outside the central SFIcon factory
//    scope; = Apple first-party surface).
//
//  Sweep files (= the files that hold a Label icon slot today, = 5 slots
//    across 3 call-site files):
//    PromptCacheStatusView (3)
//    ChatPlanPartView (1)
//    SettingView (1)
//
//  InspectorView held a fourth (= the inspector toggle's own Label,
//  = removed on 2026-11-10 when the toggle button itself went: = the
//  column's visibility is now the section switch's job alone).
//
//  The `SFLabelRow` factory's own slot (= `IconStylesViews.swift`) is
//  NOT one of the swept files: the factory draws the slot's frame and
//  the call site supplies the glyph, so its `icon: { }` block carries
//  no call-site glyph to count.
//
//  The list was REBUILT on 2026-11-02 from the tree, because the old
//  list named `KanbanView.swift`, which holds no Label icon slot at all
//  (= its one `icon:` is `EmptyStateView`'s String parameter, and
//  `EmptyStateView` renders that through `SFIcon(icon, style:
//  .emptyStateHero, ...)` itself). The invariant the sweep protects did
//  not change; only the file that carried it moved.
//

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Label icon slot sweep (= 5 slots across 3 call-site files, all to SFIcon)")
struct LabelIconSlotSweepTests {

    /// The files that hold a Label icon slot, and how many slots each holds.
    ///
    /// `IconStylesViews.swift` is the `SFLabelRow` factory itself (= the
    /// slot it renders), so it is not a call-site file: the factory draws
    /// the slot's frame, and the call site supplies the glyph.
    static let sweptFiles: [(path: String, sites: Int)] = [
        ("Sources/WenshuApp/Features/Agent/View/PromptCacheStatusView.swift", 3),
        ("Sources/WenshuApp/Features/Chat/View/ChatPlanPartView.swift", 1),
        ("Sources/WenshuApp/Features/Settings/View/SettingView.swift", 1),
    ]

    @Test("Label icon slot sweep — every Label icon slot dropped `Image(systemName: x).imageScale(.small)`")
    func allFilesDroppedImageScaleSmallInLabelIconSlot() throws {
        for entry in Self.sweptFiles {
            let url = SourceLocator.url(entry.path)
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

    @Test("Label icon slot sweep — every Label icon slot is filled by the SFIcon factory with a semantic colour token")
    func totalSitesConsistent() throws {
        var totalSlots = 0
        for entry in Self.sweptFiles {
            let url = SourceLocator.url(entry.path)
            let content = try String(contentsOf: url, encoding: .utf8)
            // Every `icon: { ... }` slot in this file must be filled by an
            // `SFIcon(...)` call (= the factory), never by a naked
            // `Image(systemName:)`. The style and the colour vary per slot
            // (= `.inlineSmall` + `.secondary` for the status rows, `.tint`
            // for the primary plan action, `.paneTab` for the inspector
            // toggle, `.sidebar` for the settings pane), because the
            // factory's per-call arguments ARE the policy: what must not
            // come back is a glyph that bypasses the factory.
            //
            // The COLOUR argument is checked separately, because it is the
            // argument that carries the semantic colour token policy the
            // sweep exists to enforce (= this file's header names it). A
            // slot filled with `SFIcon(..., color: Color.gray)` is still
            // the factory, but it is a raw colour, so the token policy is
            // gone. So the colour must be an `IconColor` token.
            let lines = content.components(separatedBy: "\n")
            var slotsInFile = 0
            for (index, line) in lines.enumerated() {
                guard line.contains("icon: {") else { continue }
                // The slot's body is the first CODE line after the slot's
                // opening brace (= the brace is usually followed by a
                // newline and the glyph sits on the next line).
                var body = ""
                for follower in lines[(index + 1)...] {
                    let trimmed = follower.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty || trimmed.hasPrefix("//") {
                        continue
                    }
                    body = trimmed
                    break
                }
                guard !body.isEmpty else { continue }
                slotsInFile += 1
                #expect(body.contains("SFIcon("),
                        "\(entry.path): a Label icon slot must be filled by SFIcon(= the factory), found: \(body)")
                #expect(body.contains("color: IconColor."),
                        "\(entry.path): a Label icon slot must give the factory a semantic IconColor token (= the colour token policy), found: \(body)")
            }
            #expect(slotsInFile == entry.sites,
                    "\(entry.path) holds \(entry.sites) Label icon slot(s), found \(slotsInFile)")
            totalSlots += slotsInFile
        }
        #expect(totalSlots == 5,
                "the call-site files hold 5 Label icon slots in total, found \(totalSlots)")
    }
}
