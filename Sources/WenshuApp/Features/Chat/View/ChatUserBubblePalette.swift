//
//  ChatUserBubblePalette.swift
//
//  The two colours the user's own message bubble wears (= the
//  surface the words sit on, the text tier on top). One place, so
//  the bubble and the text on it cannot drift apart.
//

import AppKit
import SwiftUI

/// Colour relationship of the user bubble (= the surface the user's own
/// words sit on, and the text tier on top of it).
///
/// The surface is an Apple semantic colour: it resolves to a different
/// value in the light and the dark appearance, so the bubble separates
/// from the chat panel background in both, and the body text tier on top
/// of it stays readable in both. (= the panel background is the window's
/// translucent root material; = the bubble must not collapse into it in
/// either appearance.)
///
/// The surface wears no hairline: its own solid colour is its edge.
@MainActor
enum ChatUserBubblePalette {
    /// Bubble fill (= the macOS inactive-selection surface: = the
    /// neutral raised surface Apple uses for a selected-but-unfocused
    /// item; = lighter than the panel in the dark appearance and
    /// darker in the light one).
    static let surface: NSColor = .unemphasizedSelectedTextBackgroundColor
    /// Text tier on the bubble (= the four-tier ladder's body tier).
    static let text: HierarchicalShapeStyle = DesignTokens.textBody
}
