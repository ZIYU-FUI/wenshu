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
/// value in the light and the dark appearance, so the words on a band
/// stay readable in both. (= the chat transcript's own band wears the
/// app's content-area material, = the surface the content cards wear;
/// = the inspector's output bubble wears the macOS inactive-selection
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
    /// The CHAT transcript's own band does NOT read this: it wears the
    /// app's content-area material (= `ContentAreaMaterial.surface`, =
    /// the surface the content cards wear), so the band is a row of the
    /// transcript rather than a second selection colour in the column.
    static let inspectorOutputSurface: NSColor = .unemphasizedSelectedTextBackgroundColor
    /// Text tier on the bubble (= the four-tier ladder's body tier).
    static let text: HierarchicalShapeStyle = DesignTokens.textBody
}
