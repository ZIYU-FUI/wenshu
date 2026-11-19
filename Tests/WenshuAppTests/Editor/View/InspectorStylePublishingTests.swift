//
//  InspectorStylePublishingTests.swift · Wenshu
//
//  What the format page's controls publish, = and what the page's names
//  cost in the catalog.
//
//  WHY A FILE OF ITS OWN
//
//  The render suite measures the page's STATE (= which book's sheet is
//  shown, = in what order the groups come). = These cases measure the
//  page's SURFACE: = the name each control answers with when something
//  asks it who it is, = and the words the page draws its names out of. =
//  Both are things a reader never sees and a screen reader, = a
//  translator, = or the next OS release reads first.
//

import Foundation
@testable import WenshuApp
import SwiftUI
import Testing

@MainActor
struct InspectorStylePublishingTests {
    // MARK: - The names the controls answer with

    /// Every knob answers a question about itself with the knob's own name.
    ///
    /// WHY THIS IS NOT THE LABEL THE PAGE DREW
    ///
    /// A pop-up button's ACCESSIBLE name is answered by its CELL, = not by
    /// the control (= measured: with the control's own `setAccessibilityLabel`
    /// the tree still published an unnamed `AXPopUpButton`), = which is why
    /// `ValuePopUpButton` writes the name on both. = Before that, = the five
    /// knobs published a role and nothing else: = a screen reader walked
    /// this page and heard five unnamed buttons.
    ///
    /// MUTATION: = set the name on the control only = the labels come back
    /// empty and this fails; = set one knob's name to nil = its own slot
    /// fails.
    @Test("the five knobs publish their own name as their accessible label")
    func theKnobsPublishTheirNames() throws {
        let (store, plain, _) = try InspectorStylePageFixture.makeStore()
        store.selectedBookId = plain.id
        let rendered = InspectorStylePageFixture.renderPage(
            store: store,
            workspace: InspectorStylePageFixture.makeWorkspace()
        )
        defer { rendered.close() }

        let labels = rendered.menuLabels()
        #expect(
            labels.count == 5,
            "the five knobs, = and nothing else that drops down: \(labels)"
        )
        for label in labels {
            #expect(
                !label.isEmpty,
                "a knob that answers with nothing is an unnamed control (= the button's cell never got its name)"
            )
        }
        #expect(
            Set(labels).count == labels.count,
            "each knob names itself, = so no two of the five answer with the same word: \(labels)"
        )
        for name in InspectorStylePageFixture.knobNameKeys {
            #expect(
                labels.contains(name),
                "the knob \(name) is not among the names the page publishes: \(labels)"
            )
        }
    }

    // MARK: - The words the page is allowed to use

    /// Every name on this page, = including the switcher's three places, =
    /// is in the catalog, = in BOTH the languages the app ships.
    ///
    /// WHY BOTH LOCALES
    ///
    /// A key that exists only in one language is a control that answers in
    /// the wrong tongue the moment the reader switches (= and the switcher's
    /// names are exactly the kind of copy that gets reworded).
    ///
    /// MUTATION: = delete one locale's value for `inspector.style.preset.custom`
    /// = the second loop fails on that key.
    @Test("the page's names are in the catalog in both languages")
    func thePagesNamesAreInTheCatalogInBothLanguages() throws {
        let catalogURL = InspectorStylePageFixture.catalogURL()
        var missing: [String] = []
        for language in ["en", "zh-Hans"] {
            let strings = StringCatalogReader.strings(language: language)
            for key in InspectorStylePageFixture.pageNameKeys {
                guard let value = strings[key], !value.isEmpty else {
                    missing.append("\(language): \(key)")
                    continue
                }
            }
        }
        #expect(
            missing.isEmpty,
            "these names are not carried by the catalog in both languages: \(missing)"
        )
        //  The catalog the AX tree reads is the same file, = so the three
        //  places have to be in it as keys and not only as strings.
        let shaped = try InspectorAXTree.catalog(at: catalogURL)
        for key in InspectorStylePageFixture.pageNameKeys {
            #expect(
                shaped[key] != nil,
                "the catalog does not carry \(key) at all (= every language is missing)"
            )
        }
    }

    // MARK: - The width the five knobs share

    /// The five knobs are laid out at ONE width, = the widest of them.
    ///
    /// WHY THIS IS MEASURABLE AND WHY IT MATTERS
    ///
    /// The page hands every knob the same `columnWidth`, = worked out once
    /// from the system's own button for every position any knob offers, =
    /// so the five right-hand edges line up (= a column of drop-downs of
    /// five different widths reads as five loose controls rather than one
    /// group). = Offscreen the absolute widths a hosting view reports are
    /// not trustworthy (= see the review card's VISUAL PROOF: = the tree
    /// inflates a control's own ideal width), = so what is claimed here is
    /// the RELATIVE fact the shared width exists to produce: = five equal
    /// widths, = none of them zero.
    ///
    /// MUTATION: = hand each knob its own fitting width instead of the
    /// shared one = the buttons take the width of their own titles, = the
    /// five stop agreeing, = and this fails.
    @Test("the five knobs share one width")
    func theKnobsShareOneWidth() throws {
        let (store, plain, _) = try InspectorStylePageFixture.makeStore()
        store.selectedBookId = plain.id
        let rendered = InspectorStylePageFixture.renderPage(
            store: store,
            workspace: InspectorStylePageFixture.makeWorkspace()
        )
        defer { rendered.close() }

        let widths = rendered.popupButtons().map(\.frame.width)
        #expect(widths.count == 5, "the page drew five pop-ups: \(widths)")
        #expect(
            widths.allSatisfy { $0 > 0 },
            "a pop-up laid out at zero width was never given the column: \(widths)"
        )
        #expect(
            Set(widths).count == 1,
            "the five knobs are laid out at the width they were handed, = not at the width of their own titles: \(widths)"
        )
    }
}
