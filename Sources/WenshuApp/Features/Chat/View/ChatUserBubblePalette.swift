//
//  ChatUserBubblePalette.swift
//
//  The colours the chat's own bubbles wear (= the text tier on the
//  bubble's surface, and the surface the INSPECTOR's output bubble
//  wears). One place, so the bubble and the text on it cannot drift
//  apart.
//

import AppKit
import SwiftUI

/// Colour relationship of the chat's bubbles (= the text tier on the
/// bubble's surface, and the surface the inspector's output bubble
/// wears).
///
/// The TEXT tier is an Apple semantic colour: it resolves to a different
/// value in the light and the dark appearance, so the words on a bubble
/// stay readable in both. (= the chat transcript's own bubble surface is
/// Apple's Liquid Glass, = which Apple renders for legibility; = the
/// inspector's output bubble wears the macOS inactive-selection
/// surface, = an appearance-aware colour that resolves to a different
/// value in each appearance.)
///
/// The inspector's surface wears no hairline: its own solid colour is
/// its edge.
@MainActor
enum ChatUserBubblePalette {
    /// Surface for the INSPECTOR's output bubble (= the macOS
    /// inactive-selection surface: = the neutral raised surface Apple
    /// uses for a selected-but-unfocused item; = lighter than the panel
    /// in the dark appearance and darker in the light one).
    ///
    /// The CHAT transcript's own bubble does NOT read this: it wears
    /// Apple's Liquid Glass (= `.glassEffect`, = the same API the
    /// composer field wears), so the two chat surfaces are Apple's own
    /// material by construction.
    static let inspectorOutputSurface: NSColor = .unemphasizedSelectedTextBackgroundColor
    /// Text tier on the bubble (= the four-tier ladder's body tier).
    static let text: HierarchicalShapeStyle = DesignTokens.textBody
}
