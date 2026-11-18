//
//  ChatUserBubbleReadabilityTests.swift
//
//  The user's own message must be readable in BOTH appearances, and the
//  bubble must stay visually distinct from the assistant's flat text.
//
//  The chat transcript's own bubble surface is Apple's Liquid Glass
//  (= `.glassEffect`), so its legibility is Apple's own: what this
//  suite holds is the WIRING (= the bubble wears Apple's glass, = the
//  text on it is the appearance-aware body tier) and the colour
//  relationship of the surfaces the app still owns (= the inspector's
//  output bubble).
//
//  These assertions run on the resolved style values (= the text tier and
//  the surface colour) and on the production source, not on a screenshot.
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

    /// The INSPECTOR's output words must not render as text on a field
    /// of the same tone (= the defect: dark text on a dark bubble in the
    /// dark appearance, so the output read as missing).
    @Test func inspector_output_text_is_readable_against_its_own_surface() {
        for (name, appearance) in appearances {
            let surface = resolve(ChatUserBubblePalette.inspectorOutputSurface, appearance)
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

    /// The inspector's surface must separate from the chat panel
    /// background in both appearances (= the bubble stays a distinct
    /// surface, not a hole in the panel).
    @Test func inspector_output_surface_separates_from_the_chat_panel_background() {
        for (name, appearance) in appearances {
            let surface = resolve(ChatUserBubblePalette.inspectorOutputSurface, appearance)
            let panel = panelBackground(appearance)
            #expect(
                surface != panel,
                "\(name) appearance: the bubble surface and the chat panel background resolve to the same colour"
            )
        }
    }

    /// The inspector's surface must be appearance-aware (= a different
    /// value in the light and the dark appearance), so the fix cannot be
    /// a constant that happens to work in one appearance only.
    @Test func inspector_output_surface_differs_between_appearances() throws {
        let light = try #require(NSAppearance(named: .aqua))
        let dark = try #require(NSAppearance(named: .darkAqua))
        #expect(
            resolve(ChatUserBubblePalette.inspectorOutputSurface, light)
                != resolve(ChatUserBubblePalette.inspectorOutputSurface, dark)
        )
    }

    /// The role distinction survives the material change: the user's
    /// bubble keeps a surface (= Apple's glass), the assistant reply
    /// stays flat text with no surface.
    @Test func role_distinction_survives() throws {
        #expect(ChatUserBubblePalette.inspectorOutputSurface != .clear)
        let source = try SourceLocator.read("Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift")
        #expect(source.contains("private var isOutgoing: Bool { message.source == .user }"))
        #expect(source.contains(".modifier(UserGlassCardModifier(isOutgoing: isOutgoing))"))
        // The assistant row stays flat text: no bubble surface is applied
        // outside the outgoing branch.
        #expect(source.contains("if isOutgoing {"))
    }

    /// The user's bubble wears Apple's OWN Liquid Glass, applied with
    /// the canonical API (= `.glassEffect`): the app paints no surface of
    /// its own behind the words, and nobody re-implements a glass by
    /// hand.
    ///
    /// The variant is the regular one (= Apple's own words: it "blurs and
    /// adjusts the luminosity of background content to maintain
    /// legibility of text and other foreground elements") and the shape
    /// is the shared chat-surface shape, so the bubble and the composer
    /// field are the same material in the same shape.
    ///
    /// The surface is applied BEFORE the width cap: the cap is a
    /// bound and not a width, so the glass is laid on the words
    /// themselves. Measured (the review's own mutation of this
    /// claim): short = long = 360.0 PT inside a 723 PT column, so
    /// the bubble never spans the chat column.
    @Test func the_outgoing_bubble_wears_apples_liquid_glass() throws {
        let source = try SourceLocator.read("Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift")
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
            bubbleModifier.contains(".glassEffect(.regular, in: ChatSurfaceShape())"),
            "The outgoing bubble must wear Apple's Liquid Glass through the canonical API"
        )
        // The app paints no surface of its own behind the words: a
        // hand-drawn fill would sit under Apple's glass and defeat it.
        #expect(
            !bubbleModifier.contains(".fill("),
            "The outgoing bubble must not paint a fill of its own: Apple's glass IS its surface"
        )
        #expect(
            !bubbleModifier.contains("ChatUserBubblePalette.inspectorOutputSurface"),
            "The outgoing bubble must not wear the inspector's surface"
        )
        // The glass is applied before the width cap, so it hugs the
        // words instead of taking the cap's full width.
        let glassIndex = try #require(bubbleModifier.range(of: ".glassEffect("))
        let capIndex = try #require(bubbleModifier.range(of: ".frame(maxWidth: DesignTokens.chatBubbleMaxWidth"))
        #expect(
            glassIndex.lowerBound < capIndex.lowerBound,
            "The glass must be applied before the width cap, or the bubble stops hugging its words (= a fixed 360 PT cap-wide bubble in a 723 PT column)"
        )
        // The words on the glass wear the appearance-aware body tier.
        #expect(
            bubbleModifier.contains(".foregroundStyle(ChatUserBubblePalette.text)"),
            "The bubble's words must wear the palette's text tier"
        )
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
        let source = try SourceLocator.read("Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift")
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
        let source = try SourceLocator.readGroup(prefixed: "ChatView")
        #expect(source.contains("LazyVStack(alignment: .leading, spacing: DesignTokens.spacingStandard"))
        #expect(source.contains(".padding(.vertical, DesignTokens.spacingStandard)"))
        // No raw numeric padding survives in the transcript's vertical rhythm.
        let rawVerticalPadding = source.contains(".padding(.vertical, 10)")
        #expect(!rawVerticalPadding)
    }

    /// The outgoing bubble draws no stroke OF ITS OWN: Apple's glass
    /// brings its own edge, so a stroke drawn on top of it would read as
    /// a rim over Apple's shape rather than as the shape's own boundary.
    /// The composer field, which wears the same `ChatSurfaceShape`, is
    /// borderless, so the two surfaces agree by construction only while
    /// both are borderless.
    @Test func outgoing_bubble_draws_no_stroke() throws {
        let source = try SourceLocator.read("Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift")
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
            "The outgoing bubble must draw no stroke: Apple's glass paints its own edge, so the app draws no border"
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
        let palette = try SourceLocator.read("Sources/WenshuApp/Features/Chat/View/ChatUserBubblePalette.swift")
        #expect(
            !palette.contains("static let border"),
            "The bubble palette must not offer a border colour"
        )
        // The palette holds the INSPECTOR's surface, not the chat
        // bubble's: the chat bubble's surface is Apple's glass.
        #expect(palette.contains("static let inspectorOutputSurface: NSColor = .unemphasizedSelectedTextBackgroundColor"))
    }
}
