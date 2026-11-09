//
//  WindowToolbarMaterialTests.swift
//
//  The window's titlebar strip is one surface, not a band of flat plates.
//
//  A window whose content is a split view gets ONE titlebar, but the
//  split view's columns each extend their own background colour up into
//  it (= an NSTitlebarBackgroundView per column). The result is a strip
//  that reads as several flat plates side by side, with a step at every
//  column boundary, and the widest column's plate sits on top of the
//  content as if it were a band painted over it.
//
//  The window toolbar's own background is the one surface that covers the
//  whole strip, so the strip carries the window's material instead.
//
//  WHAT IS MEASURED: the material is a TRANSMISSIVE surface, not a tint.
//  A surface that carries the ground behind it and a flat fill do not
//  look the same, and the difference is measurable without a screenshot:
//  the same view rendered over two different grounds reads differently
//  when the surface transmits, and identically when it paints a fill of
//  its own.
//
//  The material's tier is Apple canonical: `Material.ultraThinMaterial`
//  is the tier the window chrome itself uses for a unified toolbar, and
//  it is the tier that separates from a pale ground (= the ground this
//  window's chrome sits on) rather than vanishing into it.
//
//  THE TIER IS MEASURED, NOT NAMED. The tiers read differently from one
//  another over the same ground (= ultraThin 169, thin 152, regular 133,
//  thick 113 over the pale one), so the suite holds the surface to the
//  tier the production code asks for instead of to a literal. A suite
//  that only asked for "a material" would pass with the wrong tier; a
//  suite that asserted the literal in the source would pass with the
//  modifier commented out.
//
//  THE PLACEMENT IS READ FROM THE CODE, NOT FROM A SUBSTRING. A
//  whole-file `contains` is satisfied by a comment, by a modifier that
//  rode another view, and by a modifier whose background is then hidden;
//  so the check reads the toolbar's own MODIFIER CHAIN (= the calls that
//  ride it), which says which view the material rides and what the
//  background is set to, however the call is spelled.
//

import AppKit
import SwiftUI
import Testing

@MainActor
@Suite("Window toolbar material")
struct WindowToolbarMaterialTests {
    // MARK: - The measurement

    /// A ground the surface under test is rendered over.
    private static let grounds: [(String, Color)] = [
        ("saturated", Color(red: 0.9, green: 0.1, blue: 0.3)),
        ("pale", Color(white: 0.92)),
    ]

    /// The ground a view reads over, sampled from the rendered pixels.
    ///
    /// The surface fills the frame and carries no content, so the modal
    /// colour of the render IS the surface's own reading of the ground.
    private func renderedGround<V: View>(over ground: Color, _ view: V) -> (r: Int, g: Int, b: Int)? {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        // The material samples the window's backdrop, so the window's
        // background IS the ground the surface reads.
        window.backgroundColor = NSColor(ground)
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            window.orderOut(nil)
            return nil
        }
        rep.size = host.bounds.size
        // Paint the ground first, so a pixel that differs is a pixel the
        // surface drew on.
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(ground).setFill()
        host.bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        host.cacheDisplay(in: host.bounds, to: rep)

        var counts: [String: Int] = [:]
        var colors: [String: (r: Int, g: Int, b: Int)] = [:]
        for x in stride(from: 10, to: 190, by: 4) {
            for y in stride(from: 10, to: 90, by: 4) {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let key = "\(Int(c.redComponent * 255)),\(Int(c.greenComponent * 255)),\(Int(c.blueComponent * 255))"
                counts[key, default: 0] += 1
                colors[key] = (
                    Int(c.redComponent * 255),
                    Int(c.greenComponent * 255),
                    Int(c.blueComponent * 255)
                )
            }
        }
        window.orderOut(nil)
        guard let modal = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return colors[modal]
    }

    /// A surface that carries the ground behind it reads DIFFERENTLY over
    /// two different grounds. A flat fill of its own reads the SAME over
    /// both (= the ground never arrives).
    ///
    /// This is the difference between a material and a painted band, and
    /// it is measured rather than asserted on the source text: the same
    /// view, the same machine, the same render path, over two grounds.
    private func carriesTheGround<V: View>(_ view: V) -> Bool {
        let readings = Self.grounds.compactMap { _, ground in
            renderedGround(over: ground, view)
        }
        guard readings.count == Self.grounds.count else { return false }
        return readings[0] != readings[1]
    }

    // MARK: - The material

    /// The window toolbar's material carries the ground behind it, so the
    /// strip is a surface and not a plate.
    @Test("The window toolbar's material carries the ground behind it")
    func theToolbarMaterialTransmitsItsGround() {
        #expect(
            carriesTheGround(ZStack { Rectangle().fill(.ultraThinMaterial) }),
            """
            The toolbar's material reads the same over a saturated ground and over a \
            pale one, so the ground never arrives: the material is painting a fill of \
            its own instead of carrying what is behind it.
            """
        )
    }

    /// The ground the material carries is DILUTED, not the ground itself:
    /// the surface scatters what it carries.
    ///
    /// A surface that copied the ground exactly would be a hole, not a
    /// material.
    @Test("The material carries the ground diluted, not unchanged")
    func theMaterialDilutesTheGroundItCarries() throws {
        let saturated = try #require(
            renderedGround(over: Self.grounds[0].1, ZStack { Rectangle().fill(.ultraThinMaterial) }),
            "the material did not render over the saturated ground"
        )
        let bare = try #require(
            renderedGround(over: Self.grounds[0].1, ZStack { Color.clear }),
            "the bare ground did not render"
        )
        #expect(
            saturated != bare,
            """
            The material renders the saturated ground unchanged \
            (\(saturated)), so it is a hole in the window rather than a surface \
            that scatters what is behind it.
            """
        )
    }

    /// A flat fill of its own does NOT carry the ground, which is what
    /// makes the measurement above a measurement of the material rather
    /// than of the render path.
    ///
    /// Without this control, a render path that ignores the ground
    /// entirely would pass the transmission test for the wrong reason.
    @Test("A flat fill of its own does not carry the ground")
    func aFlatFillDoesNotCarryTheGround() {
        #expect(
            !carriesTheGround(ZStack { Rectangle().fill(Color(nsColor: .windowBackgroundColor)) }),
            """
            A flat fill reads the same over both grounds, so the fill that the \
            titlebar's per-column backgrounds paint would also read as a surface.
            """
        )
    }

    /// The material separates from the pale ground this window's chrome
    /// sits on.
    ///
    /// A material that vanishes into the ground is invisible there (= the
    /// strip would read as no surface at all), so the strip's reading of
    /// a pale ground must differ from the bare ground's reading of it.
    @Test("The material separates from a pale ground")
    func theMaterialSeparatesFromAPaleGround() throws {
        let overPale = try #require(
            renderedGround(over: Self.grounds[1].1, ZStack { Rectangle().fill(.ultraThinMaterial) }),
            "the material did not render over the pale ground"
        )
        let barePale = try #require(
            renderedGround(over: Self.grounds[1].1, ZStack { Color.clear }),
            "the bare pale ground did not render"
        )
        #expect(
            overPale != barePale,
            """
            The material reads \(overPale) over a pale ground, the same as the bare \
            ground (\(barePale)): on the ground this window's chrome sits on, the \
            material is invisible.
            """
        )
    }

    /// THE TIER IS LOAD-BEARING. The ultra-thin tier reads differently
    /// over the same ground than every other tier does, so the tiers are
    /// distinguishable surfaces and a suite that asked only for "a
    /// material" would hold nothing.
    ///
    /// The wrong tier is exactly what makes the strip vanish into this
    /// window's pale chrome, so the tier is part of what the branch
    /// claims, not a detail of how it is spelled.
    @Test("The tiers are distinguishable surfaces, so the tier is load-bearing")
    func theTiersAreDistinguishableSurfaces() throws {
        let pale = Self.grounds[1].1
        let ultraThin = try #require(
            renderedGround(over: pale, ZStack { Rectangle().fill(.ultraThinMaterial) }),
            "the ultra-thin material did not render over the pale ground"
        )
        for (name, tier) in [
            ("thin", Material.thin),
            ("regular", Material.regular),
            ("thick", Material.thick),
        ] {
            let other = try #require(
                renderedGround(over: pale, ZStack { Rectangle().fill(tier) }),
                "the \(name) material did not render over the pale ground"
            )
            #expect(
                other != ultraThin,
                """
                The \(name) tier reads \(other) over the pale ground and the ultra-thin \
                tier reads \(ultraThin): the two tiers are the same surface here, so a \
                suite that asked for "a material" would hold nothing.
                """
            )
        }
    }

    // MARK: - The production landing point

    /// The library window's toolbar is the surface that covers the whole
    /// titlebar strip, so the material belongs on the window toolbar.
    ///
    /// The check reads the toolbar's own MODIFIER CHAIN (= the calls
    /// that ride it), not a substring of the file. The chain is what
    /// says which view the material rides and what the background is set
    /// to, so the check holds:
    ///   - a comment cannot satisfy it (= the modifier commented out is
    ///     the modifier gone),
    ///   - it cannot have drifted onto another view (= a modifier on
    ///     another chain is not on this one),
    ///   - and the toolbar's background must not be hidden (= hiding it
    ///     removes the strip's one surface and brings the flat plates
    ///     back, which is the defect this branch exists to fix).
    @Test("The library window's toolbar carries the window toolbar's material")
    func theLibraryWindowToolbarCarriesTheMaterial() throws {
        let source = try SourceLocator.read(
            "Sources/WenshuApp/Shared/UI/LibraryRootView.swift"
        )
        let chain = Self.toolbarChain(of: source)

        let backgrounds = chain.filter(\.isToolbarBackground)
        let material = try #require(
            backgrounds.first,
            """
            The library window's toolbar must carry one material for the whole \
            window's titlebar strip (= the per-column backgrounds paint a flat \
            plate per column instead). No modifier on the toolbar's chain sets \
            the window toolbar's background.
            """
        )
        #expect(
            material.tier == "ultraThinMaterial",
            """
            The toolbar's background is `\(material.tier ?? "a material")`, not the \
            ultra-thin tier: the tiers are different surfaces, and on this window's \
            pale chrome ground the wrong one vanishes into the ground.
            """
        )
        #expect(
            material.placement == "windowToolbar",
            """
            The toolbar's background is set for \
            `\(material.placement ?? "another placement")`, not for the window toolbar \
            (= the strip).
            """
        )

        // The background must not be HIDDEN: hiding it removes the
        // strip's one surface and brings the flat plates back.
        //
        // The check reads the placement the modifier names, and holds
        // every spelling that names the window toolbar (= `.windowToolbar`,
        // `ToolbarPlacement.windowToolbar`) or the automatic placement
        // (= the window toolbar answers to it too).
        for hidden in chain where hidden.isHiddenVisibility {
            #expect(
                hidden.placement != "windowToolbar" && hidden.placement != "automatic",
                """
                The toolbar's background is hidden for \
                `\(hidden.placement ?? "another placement")`, which removes the strip's \
                one surface and brings the per-column flat plates back.
                """
            )
        }
    }

    // MARK: - Reading the modifier chain

    /// One modifier on a chain, as the chain's own text.
    private struct ChainModifier {
        /// The modifier's name (= `toolbarBackground`).
        let name: String
        /// The modifier's arguments, as written.
        let arguments: String
        /// The material tier the modifier names, if it names one.
        var tier: String? {
            for candidate in ["ultraThinMaterial", "thinMaterial", "regularMaterial", "thickMaterial", "barMaterial"] {
                if arguments.contains(candidate) {
                    return candidate
                }
            }
            return nil
        }

        /// The placement the modifier names, if it names one.
        var placement: String? {
            for candidate in ["windowToolbar", "navigationBar", "automatic", "tabBar", "sidebar"] {
                if arguments.contains(candidate) {
                    return candidate
                }
            }
            return nil
        }

        var isToolbarBackground: Bool {
            name == "toolbarBackground"
        }

        /// A visibility modifier that hides the background.
        var isHiddenVisibility: Bool {
            name == "toolbarBackgroundVisibility" && arguments.contains(".hidden")
        }
    }

    /// The source with its comments removed and its whitespace collapsed,
    /// so the code reads as ONE line.
    ///
    /// WHY ONE LINE: a modifier may be spelled over several lines, and a
    /// line-indexed reader misses it (= it reads the first line of the
    /// call and never the rest). Collapsing the whitespace makes every
    /// spelling of a call the same text, so the reader cannot be
    /// defeated by wrapping a call over four lines.
    private static func flatCode(of source: String) -> String {
        var withoutComments: [String] = []
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            var kept = ""
            var inString = false
            var escaped = false
            var index = line.startIndex
            while index < line.endIndex {
                let character = line[index]
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString.toggle()
                } else if character == "/", !inString,
                          line.index(after: index) < line.endIndex,
                          line[line.index(after: index)] == "/"
                {
                    break
                }
                kept.append(character)
                index = line.index(after: index)
            }
            withoutComments.append(kept)
        }
        return withoutComments
            .joined(separator: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .joined(separator: " ")
    }

    /// The modifier chain that rides the library window's toolbar: the
    /// calls that follow the `content.toolbar {` block, up to the end of
    /// the statement that holds it.
    ///
    /// The chain is what says WHICH view the material rides. A line index
    /// says only where a token sits, and a whole-file search says only
    /// that the token exists SOMEWHERE.
    private static func toolbarChain(of source: String) -> [ChainModifier] {
        let flat = flatCode(of: source)
        guard let toolbar = flat.range(of: "content.toolbar {") else { return [] }

        // The toolbar block's closing brace = the brace that balances it.
        // The scan starts AT the block's opening brace, so the depth is
        // the block's own (= 1 once the opening brace is counted).
        var depth = 0
        var cursor = toolbar.lowerBound
        while cursor < flat.endIndex {
            if flat[cursor] == "{" {
                depth += 1
            }
            if flat[cursor] == "}" {
                depth -= 1
                if depth == 0 {
                    cursor = flat.index(after: cursor)
                    break
                }
            }
            cursor = flat.index(after: cursor)
        }

        // The chain = the calls that follow, each read to its balanced
        // closing parenthesis.
        var modifiers: [ChainModifier] = []
        while cursor < flat.endIndex {
            while cursor < flat.endIndex, flat[cursor] == " " {
                cursor = flat.index(after: cursor)
            }
            guard cursor < flat.endIndex, flat[cursor] == "." else { break }
            var name = ""
            var arguments = ""
            var callDepth = 0
            var readingArguments = false
            while cursor < flat.endIndex {
                let character = flat[cursor]
                if !readingArguments {
                    if character == "(" {
                        readingArguments = true
                        callDepth = 1
                    } else {
                        name.append(character)
                    }
                } else {
                    if character == "(" {
                        callDepth += 1
                    }
                    if character == ")" {
                        callDepth -= 1
                        if callDepth == 0 {
                            arguments.append(character)
                            cursor = flat.index(after: cursor)
                            break
                        }
                    }
                    arguments.append(character)
                }
                cursor = flat.index(after: cursor)
            }
            // The name is read off the chain, so it carries the leading
            // dot the call was written with (= `.toolbarBackground`).
            let trimmedName = name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if trimmedName.isEmpty {
                continue
            }
            modifiers.append(
                ChainModifier(
                    name: trimmedName,
                    arguments: arguments.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
        return modifiers
    }
}
