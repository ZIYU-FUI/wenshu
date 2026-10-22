//
//  WindowTranslucencyTests.swift
//
//  The window reads what is behind it: one behind-window material at the
//  window's root, transparent containers inside it, and no flat opaque
//  fill painted under the chat column.
//
//  These assertions read the source of the named files, because the
//  property under test is which layer paints what (= a source-level
//  fact, not a runtime colour).
//

import Testing
import SwiftUI
import AppKit
@testable import WenshuApp

// The palette and the design tokens are MainActor-isolated (= they read
// the actor-isolated DesignTokens), so the suite runs on the main actor
// too.
@MainActor
@Suite("Window translucency")
struct WindowTranslucencyTests {

    private func source(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    /// The window must not be opaque, and its background colour must be
    /// cleared: an opaque window paints over the desktop, so no
    /// behind-window material can read it.
    @Test func windows_are_transparent_with_a_cleared_background() throws {
        let delegate = try source("Sources/WenshuApp/App/WenshuAppDelegate.swift")
        #expect(delegate.contains("window.isOpaque = false"))
        #expect(delegate.contains("window.backgroundColor = .clear"))
    }

    /// The window's root carries ONE behind-window material, so the
    /// desktop reads through the chrome. The old opaque
    /// `.windowBackground` container background is gone.
    @Test func window_root_carries_a_behind_window_material() throws {
        let root = try source("Sources/WenshuApp/Shared/UI/LibraryRootView.swift")
        let materials = [".ultraThinMaterial", ".regularMaterial", ".glassEffect"]
        #expect(
            materials.contains { root.contains("containerBackground(\($0), for: .window)") }
                || materials.contains { root.contains("background(\($0))") },
            "The window's root must carry one behind-window material"
        )
        #expect(
            !root.contains("containerBackground(.windowBackground, for: .window)"),
            "The window's root must not paint the opaque window background"
        )
    }

    /// The chat column paints no flat fill of its own: its background
    /// comes from the window's single root material.
    @Test func chat_column_paints_no_flat_opaque_fill() throws {
        for path in [
            "Sources/WenshuApp/Features/Chat/View/ChatZoneView.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatView.swift"
        ] {
            let source = try source(path)
            #expect(
                !source.contains("DesignTokens.sidebarBackground"),
                "\(path) still paints the flat sidebar background"
            )
        }
    }

    /// The flat opaque colour is gone from the whole surface: the token
    /// itself is deleted, so no container can paint it any more.
    @Test func the_flat_opaque_colour_is_gone_from_the_app() throws {
        let tokens = try source("Sources/WenshuApp/DesignTokens.swift")
        #expect(
            !tokens.contains("sidebarBackground"),
            "The flat opaque sidebar colour must be deleted"
        )
        for path in [
            "Sources/WenshuApp/Features/Chat/View/ChatZoneView.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatView.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatUserBubblePalette.swift"
        ] {
            let source = try source(path)
            #expect(
                !source.contains("sidebarBackground"),
                "\(path) still names the flat opaque sidebar colour"
            )
        }
    }

    /// The document body keeps its own near-opaque reading surface: the
    /// engine's text view is transparent (= `backgroundColor = .clear`,
    /// `drawsBackground = false`), so without this fill the wallpaper
    /// would show straight through the text.
    @Test func editor_body_keeps_an_opaque_reading_surface() throws {
        let canvas = try source("Sources/WenshuApp/Features/Editor/View/EditorPaperCanvas.swift")
        #expect(canvas.contains("DesignTokens.editorReadingSurface"))

        let appearances: [(String, NSAppearance)] = [
            ("light", NSAppearance(named: .aqua)!),
            ("dark", NSAppearance(named: .darkAqua)!)
        ]
        let surface = NSColor(DesignTokens.editorReadingSurface)
        for (name, appearance) in appearances {
            var alpha: CGFloat = 0
            appearance.performAsCurrentDrawingAppearance {
                alpha = surface.usingColorSpace(.sRGB)?.alphaComponent ?? 0
            }
            #expect(
                alpha >= 0.85,
                "\(name) appearance: the editor's reading surface is \(alpha), so the wallpaper would show through the text"
            )
        }
    }
}
