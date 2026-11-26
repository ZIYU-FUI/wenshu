//
//  ChatUserBubbleReadabilityTests.swift
//
//  The user's own message must be readable in BOTH appearances, and it
//  must read as a row of the transcript, not as the assistant's flat
//  text in another colour.
//
//  The band's surface is the app's content-area material
//  (= `ContentAreaMaterial.surface`), the surface the content cards
//  wear; what this suite holds is the WIRING (= the band wears that
//  material, and the text on it is the appearance-aware body tier) and
//  the colour relationship of the surfaces the app still owns (= the
//  inspector's output bubble).
//
//  These assertions run on the resolved style values (= the text tier and
//  the surface colour) and on the production source, not on a screenshot.
//

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

/// The palette is MainActor-isolated (= it reads the actor-isolated
/// DesignTokens), so the suite runs on the main actor too.
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
            ("dark", NSAppearance(named: .darkAqua)!),
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
    /// band keeps a surface (= the app's content-area material), the
    /// assistant reply stays flat text with no surface.
    @Test func role_distinction_survives() throws {
        #expect(ChatUserBubblePalette.inspectorOutputSurface != .clear)
        // The distinction is driven, not grepped: a row built from the
        // reader's own message is outgoing, and a row built from an
        // assistant reply is not. (= This replaces a source-text assertion
        // on the spelling of `isOutgoing`, which reddened when the
        // expression was reformatted while the behaviour never moved.)
        let readerRow = ChatMessageView(
            message: ChatMessage(role: .user, source: .user, content: "what the reader asked")
        )
        let assistantRow = ChatMessageView(
            message: ChatMessage(role: .agent, source: .wenshu, content: "what the assistant answered")
        )
        #expect(readerRow.isOutgoing, "The reader's own message did not render as outgoing")
        #expect(!assistantRow.isOutgoing, "An assistant reply rendered as outgoing")
        let source = try SourceLocator.read("Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift")
        #expect(source.contains(".modifier(UserGlassCardModifier(isOutgoing: isOutgoing))"))
        // The assistant row stays flat text: no bubble surface is applied
        // outside the outgoing branch.
        #expect(source.contains("if isOutgoing {"))
    }

    /// The user's band wears the app's content-area material, applied
    /// with the canonical API (= `ContentAreaMaterial.surface`): the app
    /// paints no colour of its own behind the words, and nobody
    /// re-implements a material by hand.
    ///
    /// The band is a ROW of the transcript. Its surface spans the chat
    /// area between the column's insets and its words start at the
    /// band's leading edge, so a message's length changes its height and
    /// never its width.
    @Test func the_outgoing_bubble_wears_the_right_columns_surface() throws {
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
            bubbleModifier.contains("ContentAreaMaterial.surface"),
            "The band must wear the app's one content-area material (= ContentAreaMaterial.surface, an NSVisualEffectView in the contentBackground state) — the same surface the content cards wear, so the band and the column share one material instead of two depths"
        )
        #expect(
            !bubbleModifier.contains("Color(nsColor: .controlBackgroundColor)"),
            "The band must not paint an opaque controlBackgroundColor fill: that colour has no blur, so a band wearing it reads deeper than the column behind it"
        )
        #expect(
            !bubbleModifier.contains(".glassEffect("),
            "The band must not wear Liquid Glass: a per-row glass surface costs a live backdrop read for every rendered row, which is what the column's frame time was charged to"
        )
        // The band spans the column, and the words sit at its leading edge.
        #expect(
            bubbleModifier.contains(".frame(maxWidth: .infinity, alignment: .leading)"),
            "The outgoing bubble's background must span the chat column, with the words at the leading edge"
        )
        #expect(
            !bubbleModifier.contains(".frame(maxWidth: DesignTokens.chatBubbleMaxWidth"),
            "The outgoing bubble must not keep the old 360 PT trailing cap"
        )
        // The band's outer edge is held 20 PT off the chat area: the
        // transcript stack insets 8 PT (spacingStandard) and the row
        // adds 12 PT (spacingModerate) for outgoing rows only, so the
        // background never bleeds to the pane divider: the chat area's
        // left and right margin for the band is 20 PT.
        #expect(
            source.contains(".padding(.horizontal, isOutgoing ? DesignTokens.spacingModerate : 10)"),
            "The user band must sit 20 PT inside the chat area's left/right edges (8 PT stack + 12 PT row)"
        )
        // The words on the band wear the appearance-aware body tier.
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

    /// The outgoing band draws no stroke OF ITS OWN: the content-area
    /// material brings its own edge, so a stroke drawn on top of it
    /// would read as a rim over the material rather than as the shape's
    /// own boundary. The composer field, which wears the same
    /// `ChatSurfaceShape`, is borderless, so the two surfaces agree by
    /// construction only while both are borderless.
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
            "The band must draw no stroke: the content-area material paints its own edge, so the app draws no border"
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
        // band's: the band's surface is the content-area material.
        #expect(palette.contains("static let inspectorOutputSurface: NSColor = .unemphasizedSelectedTextBackgroundColor"))
    }
}
