//
//  ChatUserBubbleReadabilityTests.swift
//
//  The user's own message must be readable in BOTH appearances, and the
//  bubble must stay visually distinct from the assistant's flat text.
//
//  These assertions run on the resolved style values (= the text tier and
//  the surface colour), not on a screenshot.
//

import Testing
import SwiftUI
import AppKit
@testable import WenshuApp

// The palette is MainActor-isolated (= it reads the actor-isolated
// DesignTokens), so the suite runs on the main actor too.
@MainActor
@Suite("Chat user bubble readability")
struct ChatUserBubbleReadabilityTests {

    /// WCAG AA minimum for body text.
    private static let minimumBodyContrast: Double = 4.5

    /// Resolve a semantic colour in one appearance.
    private func resolve(_ color: NSColor, _ appearance: NSAppearance) -> (r: Int, g: Int, b: Int) {
        var out = (r: 0, g: 0, b: 0)
        appearance.performAsCurrentDrawingAppearance {
            guard let srgb = color.usingColorSpace(.sRGB) else { return }
            out = (
                Int(srgb.redComponent * 255),
                Int(srgb.greenComponent * 255),
                Int(srgb.blueComponent * 255)
            )
        }
        return out
    }

    private func luminance(_ c: (r: Int, g: Int, b: Int)) -> Double {
        func channel(_ v: Int) -> Double {
            let x = Double(v) / 255.0
            return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }

    private func contrast(_ a: (r: Int, g: Int, b: Int), _ b: (r: Int, g: Int, b: Int)) -> Double {
        let l1 = luminance(a), l2 = luminance(b)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// The chat panel background, mirrored here so the test can resolve it
    /// per appearance. The panel is now the window's translucent root
    /// material; the flat opaque colour it replaced is the value the
    /// bubble surface must still not collapse into.
    private func panelBackground(_ appearance: NSAppearance) -> (r: Int, g: Int, b: Int) {
        let color = NSColor(name: "wenshu.chat.test.panel") { ap in
            if ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 36.0 / 255.0, green: 36.0 / 255.0, blue: 36.0 / 255.0, alpha: 1.0)
            }
            return NSColor(red: 245.0 / 255.0, green: 245.0 / 255.0, blue: 245.0 / 255.0, alpha: 1.0)
        }
        return resolve(color, appearance)
    }

    private var appearances: [(String, NSAppearance)] {
        [
            ("light", NSAppearance(named: .aqua)!),
            ("dark", NSAppearance(named: .darkAqua)!)
        ]
    }

    /// The user's own words must not render as text on a field of the same
    /// tone (= the defect: dark text on a dark bubble in the dark
    /// appearance, so the user's message read as missing).
    @Test func bubble_text_is_readable_against_its_own_surface() throws {
        for (name, appearance) in appearances {
            let surface = resolve(ChatUserBubblePalette.surface, appearance)
            // The body tier of the ladder (= .primary) resolves to the
            // label colour in the current appearance.
            let text = resolve(.labelColor, appearance)
            #expect(
                surface != text,
                "\(name) appearance: the bubble text and the bubble surface resolve to the same colour"
            )
            #expect(
                contrast(text, surface) >= Self.minimumBodyContrast,
                "\(name) appearance: bubble text contrast is \(contrast(text, surface)), below the body minimum"
            )
        }
    }

    /// The bubble surface must separate from the chat panel background in
    /// both appearances (= the bubble stays a distinct surface, not a hole
    /// in the panel).
    @Test func bubble_surface_separates_from_the_chat_panel_background() throws {
        for (name, appearance) in appearances {
            let surface = resolve(ChatUserBubblePalette.surface, appearance)
            let panel = panelBackground(appearance)
            #expect(
                surface != panel,
                "\(name) appearance: the bubble surface and the chat panel background resolve to the same colour"
            )
        }
    }

    /// The surface must be appearance-aware (= a different value in the
    /// light and the dark appearance), so the fix cannot be a constant that
    /// happens to work in one appearance only.
    @Test func bubble_surface_differs_between_appearances() throws {
        let light = resolve(ChatUserBubblePalette.surface, NSAppearance(named: .aqua)!)
        let dark = resolve(ChatUserBubblePalette.surface, NSAppearance(named: .darkAqua)!)
        #expect(light != dark)
    }

    /// The role distinction survives the colour fix: the user bubble keeps
    /// a surface, the assistant reply stays flat text with no surface.
    @Test func role_distinction_survives() throws {
        #expect(ChatUserBubblePalette.surface != .clear)
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("private var isOutgoing: Bool { message.source == .user }"))
        #expect(source.contains(".modifier(UserGlassCardModifier(isOutgoing: isOutgoing))"))
        // The assistant row stays flat text: no bubble surface is applied
        // outside the outgoing branch.
        #expect(source.contains("if isOutgoing {"))
    }

    /// The bubble's internal padding is unchanged in shape: the 12 PT
    /// horizontal padding stays.
    ///
    /// The 6 PT VERTICAL padding is deliberately gone: the band's
    /// resting height comes from the shared 36 PT floor (= the composer
    /// field's height) instead of from padding stacked on top of it, so
    /// a one-line message reads as the same surface the person typed
    /// into. The horizontal padding is what carries the bubble's
    /// internal inset, and it is unchanged.
    @Test func bubble_internal_padding_unchanged() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains(".padding(.horizontal, DesignTokens.spacingModerate)"))
        // The vertical padding is replaced by the height floor, not
        // stacked on top of it.
        #expect(source.contains("minHeight: DesignTokens.controlHeightLarge"))
        #expect(!source.contains(".padding(.vertical, DesignTokens.spacingTight)"),
                "The bubble must not stack vertical padding on top of the height floor")
    }

    /// The turn spacing is uniform: every transcript row carries the same
    /// vertical band (= the standard spacing token), so the first turn is
    /// not detached from the conversation.
    @Test func transcript_rows_share_one_vertical_band() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Features/Chat/View/ChatView.swift",
            encoding: .utf8
        )
        #expect(source.contains("LazyVStack(alignment: .leading, spacing: DesignTokens.spacingStandard"))
        #expect(source.contains(".padding(.vertical, DesignTokens.spacingStandard)"))
        // No raw numeric padding survives in the transcript's vertical rhythm.
        let rawVerticalPadding = source.contains(".padding(.vertical, 10)")
        #expect(!rawVerticalPadding)
    }

    /// The outgoing bubble wears no hairline: on macOS the filled
    /// surface's own colour IS its edge.
    ///
    /// The bubble's fill is a solid, appearance-aware colour that steps
    /// away from the chat panel behind it, so a stroke drawn on top of
    /// it reads as a rim over the shape rather than as the shape's own
    /// boundary. The composer field, which wears the same
    /// `ChatSurfaceShape`, is borderless, so the two surfaces agree by
    /// construction only while both are fill-only.
    @Test func outgoing_bubble_draws_no_stroke() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift",
            encoding: .utf8
        )
        // The bubble's own modifier is where a stroke would live, so the
        // assertion is scoped to it (= the rest of the file is free to
        // stroke something that is not the bubble).
        let modifierStart = try #require(
            source.range(of: "private struct UserGlassCardModifier"),
            "ChatMessageView.swift no longer declares UserGlassCardModifier"
        )
        let modifierEnd = try #require(
            source.range(of: "private struct StatusPulse"),
            "ChatMessageView.swift no longer declares StatusPulse after the bubble modifier"
        )
        let bubbleModifier = String(source[modifierStart.lowerBound ..< modifierEnd.lowerBound])
        #expect(
            !bubbleModifier.contains(".stroke("),
            "The outgoing bubble must draw no stroke: its solid fill is its edge"
        )
        #expect(
            !bubbleModifier.contains("ChatUserBubblePalette.border"),
            "The outgoing bubble must not read a border colour from the palette"
        )
        // The palette no longer offers a border colour at all, so no
        // other call site can put one back.
        #expect(
            !source.contains("ChatUserBubblePalette.border"),
            "No call site may reference the bubble's border colour"
        )
        let palette = try String(
            contentsOfFile: "Sources/WenshuApp/Features/Chat/View/ChatUserBubblePalette.swift",
            encoding: .utf8
        )
        #expect(
            !palette.contains("static let border"),
            "The bubble palette must not offer a border colour"
        )
        // The fill itself is untouched: it is the edge now.
        #expect(bubbleModifier.contains("ChatUserBubblePalette.surface"))
        #expect(palette.contains("static let surface: NSColor = .unemphasizedSelectedTextBackgroundColor"))
    }
}
