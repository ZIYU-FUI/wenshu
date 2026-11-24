//
//  LabelIconSweepTests.swift · Wenshu
//
//  A `Label`'s icon slot is drawn by the factory, not by a naked
//  `Image(systemName:)` with an `imageScale` chain on it.
//
//  `.imageScale(.small)` is a size nobody named: it equals the slot's own
//  default, so it changes nothing, and it bypasses the semantic colour
//  `SFIcon` applies. The slot's glyph therefore comes in as
//  `SFIcon(name, style:, color:, matchingText:)`, which is the shape this
//  suite reads out of the files that hold a Label icon slot today.
//
//  Two shapes stay outside the rule, on purpose. `ContentUnavailableView`
//  is Apple's first-party surface and draws its own glyph at the system
//  default. `SFLabelRow`'s slot belongs to the factory itself: it draws
//  the frame and the caller supplies the glyph, so there is no call-site
//  glyph to count there.
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
                    "\(entry.path) must draw its Label icon slot through the factory instead of an `imageScale` chain")
        }
    }

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
