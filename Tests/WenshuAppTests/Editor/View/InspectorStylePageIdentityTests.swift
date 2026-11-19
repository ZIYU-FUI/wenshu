//
//  InspectorStylePageIdentityTests.swift · Wenshu
//
//  WHICH BOOK the format page acts on, measured on the hosted page: the
//  book the open document belongs to (= not the one a sidebar click happened
//  to name last), and no controls at all rather than a rebound one when no
//  book is named.
//
//  WHY IT IS ITS OWN FILE
//
//  These cases host the page the way `InspectorStylePageRenderTests` does,
//  = and that file reached the 600-line ceiling with them inside it
//  (= AGENTS.md 6.6). The identity is a different question from what the page
//  paints, so it reads as its own door.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Inspector style page — which book the page writes", .serialized)
@MainActor
struct InspectorStylePageIdentityTests {
    /// THE BOOK THE PAGE WRITES IS THE BOOK OF THE OPEN DOCUMENT.
    ///
    /// THE DEFECT THIS HOLDS
    ///
    /// Nothing but an outline click in the sidebar ever named a book, = so
    /// a session that opened a manuscript from the card grid (= or one that
    /// merely restarted) had a format page with no target: = every click
    /// returned early, = nothing was written, = and the switcher sprang back
    /// to the set it was already showing. = The boss's words were that the
    /// preset switch would not hold and sprang back to Print on every click.
    ///
    /// WHY IT GOES THROUGH THE REAL OPEN PATH
    ///
    /// A test that sets `selectedBookId` by hand cannot fail for a product
    /// path that never sets it (= and every page test in this file before it
    /// did exactly that).
    @Test("the book of the open document is the book the page writes")
    func theOpenDocumentsBookIsWhatThePageWrites() throws {
        let (store, plain, _) = try InspectorStylePageFixture.makeStore()
        let workspace = InspectorStylePageFixture.makeWorkspace()
        //  A session that never touched the outline: = no book named.
        store.selectedBookId = nil
        let appState = AppState()
        let opened = CardOpenOps.openTab(
            triad: CardOpenOps.CardTriad(
                path: "/tmp/wenshu-identity-\(UUID().uuidString).md",
                content: "# Chapter\n\nA page of the manuscript.",
                title: "Chapter one"
            ),
            previewScope: .bookScope(bookId: plain.id, folderName: nil),
            appState: appState
        )
        #expect(opened.openedTabId != nil, "the document did not open (= so nothing names a book)")
        #expect(
            appState.activeBookId == plain.id,
            "the tab the user opened names no book (= the card grid's own scope never reached the tab)"
        )
        //  The one line `LibraryRootView` runs on every tab change.
        store.adoptActiveBook(appState.activeBookId)
        #expect(store.selectedBookId == plain.id)

        let rendered = InspectorStylePageFixture.renderPage(store: store, workspace: workspace)
        defer { rendered.close() }
        let control = try #require(rendered.segmentedSwitcher())
        #expect(control.isEnabled, "a page that has a book must not be switched off")
        let general = try #require(
            BookStyleSelection.choices.firstIndex(of: .preset(.general))
        )
        control.selectedSegment = general
        let action = try #require(control.action)
        let target = try #require(control.target)
        #expect(NSApp.sendAction(action, to: target, from: control))
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        let written = try #require(store.books.first { $0.id == plain.id })
        #expect(
            BookStyleSelection.select(sheet: written.effectiveStyleSheet) == .preset(.general),
            "opening a book's document must be enough for the page to be able to set that book"
        )
        //  The keys the writer actually uses (see `ActiveBookIdentityTests`).
        UserDefaults.standard.removeObject(forKey: WenshuDefaultsKey.openTabs.rawValue)
        UserDefaults.standard.removeObject(forKey: WenshuDefaultsKey.activeTabId.rawValue)
    }

    /// NO BOOK = THE CONTROLS SAY SO (= they are off), = not a click that
    /// repaints and writes nothing.
    @Test("with no book named the switcher is off rather than springing back")
    func noBookNamedSwitchesTheChoicesOff() throws {
        let (store, _, _) = try InspectorStylePageFixture.makeStore()
        let workspace = InspectorStylePageFixture.makeWorkspace()
        store.selectedBookId = nil
        let rendered = InspectorStylePageFixture.renderPage(store: store, workspace: workspace)
        defer { rendered.close() }
        let control = try #require(rendered.segmentedSwitcher())
        #expect(
            !control.isEnabled,
            "with no book to write, a live switcher is a promise the page cannot keep"
        )
        #expect(
            !rendered.popupButtons().isEmpty,
            "the fixture must have hosted the knobs"
        )
        #expect(
            rendered.popupButtons().allSatisfy { !$0.isEnabled },
            "a knob must be off for the same reason the switcher is"
        )
    }

    /// THE SEGMENT THE READER CLICKS IS THE SEGMENT THAT STAYS LIT.
    ///
    /// THE DEFECT THIS HOLDS
    ///
    /// The place a book sits used to be read off its sheet alone. = A book
    /// at the general set HAS the general set's sheet, = so a click on
    /// Custom was answered "General", = the segment went back under the
    /// finger, = and the reader had no door into his own tuning at all. =
    /// The boss's ruling of 2026-11-19 is the opposite shape: = Custom is
    /// entered first, = and tuned afterwards.
    ///
    /// WHY THE CLICK IS FIRED AT THE CONTROL
    ///
    /// Calling the write-back and reading the store proves the data, = and
    /// the symptom is the CONTROL in the window that stayed open. = So the
    /// segment is set and the control's own action is sent (= the path a
    /// finger takes, = since `LabelSegmentedControl` wires target/action
    /// onto its coordinator), = and the same control is read back after the
    /// page has had its layout pumps. = A write that does not move the
    /// model leaves the control on the segment the model says, = which is
    /// exactly what this case cannot tolerate.
    @Test("a click on Custom stays on Custom")
    func clickingCustomStaysOnCustom() throws {
        let (store, plain, _) = try InspectorStylePageFixture.makeStore()
        let workspace = InspectorStylePageFixture.makeWorkspace()
        store.selectedBookId = plain.id
        _ = try BookStyleSheetWriteBack.apply(
            selection: .preset(.general),
            to: plain.id,
            store: store
        )
        let rendered = InspectorStylePageFixture.renderPage(store: store, workspace: workspace)
        defer { rendered.close() }

        let order = BookStyleSelection.choices
        let generalIndex = try #require(order.firstIndex(of: .preset(.general)))
        let customIndex = try #require(order.firstIndex(of: .custom))

        let control = try #require(rendered.segmentedSwitcher())
        #expect(
            control.selectedSegment == generalIndex,
            "the book starts at the general set (= got \(control.selectedSegment))"
        )

        let action = try #require(control.action)
        let target = try #require(control.target)
        control.selectedSegment = customIndex
        NSApp.sendAction(action, to: target, from: control)

        let written = try #require(store.books.first(where: { $0.id == plain.id }))
        #expect(
            written.styleSelection == .custom,
            "the click the reader made is the place the book records (= got \(String(describing: written.styleSelection)))"
        )
        #expect(
            rendered.segmentedSwitcher()?.selectedSegment == customIndex,
            "the switcher in the open window stayed where the reader left it (= got \(String(describing: rendered.segmentedSwitcher()?.selectedSegment)))"
        )
    }
}
