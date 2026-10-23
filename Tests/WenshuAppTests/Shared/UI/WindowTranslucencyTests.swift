//
//  WindowTranslucencyTests.swift
//
//  The window reads what is behind it: one behind-window material at the
//  window's root, transparent containers inside it, and no flat opaque
//  fill painted under any column.
//
//  The editor's document body is one of those transparent containers. It
//  paints no fill of its own, so the root material shows through it and
//  the editor column and the chat column read as ONE surface.
//
//  The editor's assertions are MEASURED, not read out of the source: the
//  editor body is rendered over a known backdrop and the rendered pixels
//  are sampled. Two properties are checked that way:
//
//  1. The body paints no flat opaque fill. The ground under it is
//     sampled from two renders over two different known backdrops; an
//     opaque fill would make the ground identical in both, a
//     transparent body makes it track the backdrop.
//
//  2. The document text stays readable on the material it lands on. The
//     production arrangement is reproduced (= a material ground over a
//     known backdrop, the editor body transparent on top of it, the
//     document text on top of that), the text pixel and the ground pixel
//     are sampled from the rendered bitmap, and their WCAG contrast is
//     computed.
//
//  The other assertions read the source of the named files, because the
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

    /// The flat opaque colour is gone from the editor's document body
    /// too: the token that carried it no longer exists, so no container
    /// can paint it any more.
    @Test func the_flat_opaque_editor_reading_surface_is_gone() throws {
        let tokens = try source("Sources/WenshuApp/DesignTokens.swift")
        #expect(
            !tokens.contains("editorReadingSurface"),
            "The flat opaque editor reading surface must be deleted"
        )
        let canvas = try source("Sources/WenshuApp/Features/Editor/View/EditorPaperCanvas.swift")
        #expect(
            !canvas.contains("editorReadingSurface"),
            "The editor's document body must not paint the flat opaque reading surface"
        )
    }

    /// The window-list observer must listen for a notification AppKit
    /// ACTUALLY posts, or every window opened after launch (the kanban
    /// window, the library-migration window) keeps its opaque background.
    ///
    /// This one is a RUNTIME fact, not a source fact: the code's name is
    /// compared against the SDK's own symbol, so a hand-written literal
    /// for a notification AppKit never posts fails here even though it
    /// compiles and even though the source reads plausibly.
    @Test func the_window_list_observer_uses_a_real_appkit_notification() throws {
        let delegate = try source("Sources/WenshuApp/App/WenshuAppDelegate.swift")
        #expect(
            delegate.contains("NSApplication.didUpdateNotification"),
            "The observer must use the SDK's notification symbol"
        )
        // Check the CODE, not the prose: the comment beside the observer
        // deliberately quotes the wrong name to explain the pitfall, and a
        // naive whole-file search would match its own explanation.
        let code = delegate
            .split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(
            !code.contains("NSApplicationDidUpdateWindowsNotification"),
            """
            AppKit has no "NSApplicationDidUpdateWindowsNotification": the real \
            name is NSApplicationDidUpdateNotification (= NSApplication.didUpdateNotification). \
            A literal for a notification AppKit never posts leaves every window \
            opened after launch opaque.
            """
        )
        // The SDK symbol's raw value is the ground truth: the name the
        // code listens for must equal it, or the observer never fires.
        #expect(
            NSApplication.didUpdateNotification.rawValue
                == "NSApplicationDidUpdateNotification",
            "The SDK's notification name changed; re-check the observer"
        )
    }

    // MARK: - The editor's document body (measured)

    /// WCAG AA minimum for body text.
    private static let minimumBodyContrast: Double = 4.5

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

    /// The document body, rendered over a known backdrop.
    ///
    /// The structure is the production one: a material ground (the
    /// window's root material) over the backdrop, the editor's document
    /// body transparent on top of it, and the document text on top of
    /// that. The text colour is the engine's own (= `labelColor`, the
    /// body tier of the semantic ladder).
    ///
    /// The document body FILLS the frame, exactly as the engine's
    /// `NSTextView` fills it in the app. That detail is load-bearing: a
    /// body that only covered the text's own bounds would let a fill
    /// hide in the empty margin, and the measurement would report a
    /// transparent body for a body that paints one.
    private func renderEditorBody(
        over backdrop: Color,
        appearance: NSAppearance,
        text: String = "Readable body text"
    ) -> NSBitmapImageRep? {
        let root = ZStack {
            backdrop
            Rectangle().fill(.regularMaterial)
            EditorPaperCanvas {
                Text(text)
                    .font(.body)
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 320, height: 120)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = appearance
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        host.layoutSubtreeIfNeeded()

        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            window.orderOut(nil)
            return nil
        }
        bitmap.size = host.bounds.size
        host.cacheDisplay(in: host.bounds, to: bitmap)
        window.orderOut(nil)
        return bitmap
    }

    private func pixel(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
        guard let color = bitmap.colorAt(x: x, y: y) else { return (0, 0, 0) }
        return (
            Int(color.redComponent * 255),
            Int(color.greenComponent * 255),
            Int(color.blueComponent * 255)
        )
    }

    /// The ground = the colour most of a TEXT-FREE band of the render
    /// carries (= the surface the document sits on). The text = the
    /// pixel furthest from that ground in luminance (= a glyph's core,
    /// not an antialiased edge).
    ///
    /// The band is the lower half of the render, where the top-aligned
    /// document text does not reach. Sampling the ground from a band
    /// the text does not touch is what makes the two numbers
    /// independent: the ground is the surface, and the text is a glyph.
    private func sampleGroundAndText(
        _ bitmap: NSBitmapImageRep
    ) -> (ground: (r: Int, g: Int, b: Int), text: (r: Int, g: Int, b: Int))? {
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard width > 0, height > 0 else { return nil }

        let textBand = 0..<(height / 2)
        let groundBand = (height / 2)..<height

        var counts: [String: Int] = [:]
        var colors: [String: (r: Int, g: Int, b: Int)] = [:]
        for y in groundBand {
            for x in 0..<width {
                let p = pixel(bitmap, x, y)
                let key = "\(p.r),\(p.g),\(p.b)"
                counts[key, default: 0] += 1
                colors[key] = p
            }
        }
        guard let modalKey = counts.max(by: { $0.value < $1.value })?.key,
              let ground = colors[modalKey]
        else { return nil }

        let groundLuminance = luminance(ground)
        var text = ground
        var largest = 0.0
        for y in textBand {
            for x in 0..<width {
                let p = pixel(bitmap, x, y)
                let delta = abs(luminance(p) - groundLuminance)
                if delta > largest {
                    largest = delta
                    text = p
                }
            }
        }
        return (ground, text)
    }

    /// The editor's document body paints NO flat opaque fill: the ground
    /// under it tracks the backdrop it is rendered over.
    ///
    /// The measurement is a differential one (= the same view, the same
    /// machine, the same render path, over two different known
    /// backdrops). A flat opaque fill would cover the backdrop and make
    /// the ground identical in both renders; a transparent body lets the
    /// ground change with it.
    @Test func editor_body_paints_no_flat_opaque_fill() throws {
        let appearances: [(String, NSAppearance)] = [
            ("light", NSAppearance(named: .aqua)!),
            ("dark", NSAppearance(named: .darkAqua)!)
        ]
        for (name, appearance) in appearances {
            let overDark = try #require(
                renderEditorBody(over: .black, appearance: appearance),
                "\(name) appearance: the editor body did not render"
            )
            let overLight = try #require(
                renderEditorBody(over: .white, appearance: appearance),
                "\(name) appearance: the editor body did not render"
            )
            let dark = try #require(
                sampleGroundAndText(overDark),
                "\(name) appearance: the editor body's ground could not be sampled"
            )
            let light = try #require(
                sampleGroundAndText(overLight),
                "\(name) appearance: the editor body's ground could not be sampled"
            )

            #expect(
                dark.ground != light.ground,
                """
                \(name) appearance: the editor body's ground reads \(dark.ground) over a \
                black backdrop and \(light.ground) over a white backdrop. The ground does \
                not follow the backdrop, so the body paints a fill of its own.
                """
            )
        }
    }

    /// The document text stays readable on the material it lands on, in
    /// both appearances.
    ///
    /// The text pixel and the ground pixel are sampled from the rendered
    /// production arrangement, and their WCAG contrast is compared
    /// against the body-text minimum.
    @Test func document_text_is_readable_on_the_material() throws {
        let appearances: [(String, NSAppearance)] = [
            ("light", NSAppearance(named: .aqua)!),
            ("dark", NSAppearance(named: .darkAqua)!)
        ]
        // The backdrop the material is measured over: the neutral mid
        // grey a desktop sits behind a window. The material's own tint
        // dominates the ground, so the measurement is the material's
        // ground and not the backdrop's.
        let backdrop = Color(white: 0.5)
        for (name, appearance) in appearances {
            let bitmap = try #require(
                renderEditorBody(over: backdrop, appearance: appearance),
                "\(name) appearance: the editor body did not render"
            )
            let sample = try #require(
                sampleGroundAndText(bitmap),
                "\(name) appearance: the document's ground could not be sampled"
            )
            let ratio = contrast(sample.text, sample.ground)
            #expect(
                ratio >= Self.minimumBodyContrast,
                """
                \(name) appearance: the document text reads \(sample.text) on a ground of \
                \(sample.ground), a contrast of \(ratio), below the body minimum of \
                \(Self.minimumBodyContrast).
                """
            )
        }
    }
}
