//
//  InspectorStylePageFixture.swift · Wenshu
//
//  The style page's own fixture: = a real library on disk, = two books that
//  carry different sheets, = and the page hosted in a window that stays
//  open so a change can be read back from the SAME window.
//
//  WHY IT IS ITS OWN FILE
//
//  It was split out of `InspectorStylePageRenderTests.swift`, = which passed
//  the 600-line ceiling with the harness inside it (= AGENTS.md 6.6). = The
//  harness is not an assertion: = it is the door every assertion walks
//  through, = and a reader who wants to measure the page a sixth time needs
//  it without first reading five hundred lines of what the page already
//  proves.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
enum InspectorStylePageFixture {
    static func makeStore() throws -> (BookStore, Book, Book) {
        let tmpRoot = URL(
            fileURLWithPath: "/tmp/wenshu-style-page-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = tmpRoot.appendingPathComponent("reference-library", isDirectory: true)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        )
        let store = BookStore(stores: stores)
        let plain = Book(
            title: "Plain",
            shelfId: UUID(),
            styleSheet: BookStyleSheet(
                bodySize: .medium,
                lineSpacing: .standard,
                firstLineIndent: .twoCharacters,
                segmentSpacing: .none,
                bodyFamily: .songti,
                quoteFamily: .kai,
                headingLadder: .printStandard
            )
        )
        let other = Book(
            title: "Other",
            shelfId: UUID(),
            styleSheet: BookStyleSheet(
                bodySize: .large,
                lineSpacing: .loose,
                firstLineIndent: .none,
                segmentSpacing: .halfCharacter,
                bodyFamily: .kai,
                quoteFamily: .songti,
                headingLadder: .generous
            )
        )
        store.books = [plain, other]
        return (store, plain, other)
    }

    /// A workspace state of its own (= its own defaults, = so the
    /// suite never touches the user's own selection).
    static func makeWorkspace() -> WorkspaceUIState {
        let suiteName = "wenshu-style-page-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        return WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
    }

    /// The name each of the five knobs answers with (= the catalog key,
    /// = which is what a test host renders a localized string AS).
    static let knobNameKeys: [String] = [
        "inspector.style.knob.bodySize",
        "inspector.style.knob.lineSpacing",
        "inspector.style.knob.firstLineIndent",
        "inspector.style.knob.segmentSpacing",
        "inspector.style.knob.bodyFamily",
    ]

    /// Every word the page draws that a reader cannot produce by typing: =
    /// the three groups' headings, = the three places the switcher offers,
    /// = and the five knobs.
    static let pageNameKeys: [String] = [
        "inspector.style.group.presets",
        "inspector.style.group.styles",
        "inspector.style.group.tuning",
        "inspector.style.preset.print",
        "inspector.style.preset.general",
        "inspector.style.preset.custom",
    ] + knobNameKeys

    /// The string catalog (= where those names live).
    static func catalogURL() -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        return root
            .appendingPathComponent("Sources/WenshuApp/Resources/Localizable.xcstrings")
    }

    static func renderPage(
        store: BookStore,
        workspace: WorkspaceUIState
    ) -> RenderedPage {
        let host = NSHostingView(rootView: AnyView(
            InspectorStylePageView()
                .environment(store)
                .environment(workspace)
                .frame(width: 276)
        ))
        host.frame = NSRect(x: 0, y: 0, width: 276, height: 900)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        return RenderedPage(host: host, window: window)
    }
}

/// The page, rendered, and held open (= so a change can be read
/// back from the same window).
@MainActor
struct RenderedPage {
    let host: NSHostingView<AnyView>
    let window: NSWindow

    /// The menus the page paints (= the knobs, = whose label is the
    /// book's own position).
    func menuLabels() -> [String] {
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        return InspectorAXTree.elements(of: host)
            .filter { $0.role == "AXMenuButton" || $0.role == "AXPopUpButton" }
            .map(\.label)
    }

    func close() {
        window.orderOut(nil)
    }

    /// The position each knob's button is showing.
    ///
    /// A pop-up button carries the knob's NAME as its accessible name
    /// and the chosen position as its VALUE, = which is the shape Apple
    /// built it for (= HIG, = pop-up-buttons, = alert-date 2023-10-24: =
    /// "the button can update its content to indicate the current
    /// selection"). = So the position is read off the button's own
    /// selected title, = and not off its label.
    func selectedPositions() -> [String] {
        //  The store's own change has to reach the hosting view BEFORE
        //  the buttons are read (= the same two pumps `menuLabels()`
        //  gives the tree: = one for the model to re-render, = one for
        //  the AppKit control to take the new value).
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        return popupButtons().map { $0.titleOfSelectedItem ?? "" }
    }

    /// The set switcher the page drew (= Apple's own segmented control).
    func segmentedSwitcher() -> NSSegmentedControl? {
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        return RenderedPage.firstSegmented(in: host)
    }

    private static func firstSegmented(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        for subview in view.subviews {
            if let found = firstSegmented(in: subview) { return found }
        }
        return nil
    }

    /// The AppKit buttons the page's drop-downs are drawn by.
    ///
    /// `NSPopUpButton` and nothing looser: = the type is searched by
    /// name in the tree below, = and the name that used to match was
    /// `SwiftUIPopupButton` (= the button a SwiftUI `Menu` becomes
    /// under the hosting view), = whose spelling the class this page
    /// now uses does NOT share: = `NSPopUpButton` has a capital U. =
    /// A name test written against one painter silently finds nothing
    /// for the other, = and every read that goes through it comes back
    /// empty (= which is what these cases were doing).
    func popupButtons() -> [NSPopUpButton] {
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        return RenderedPage.popups(in: host)
    }

    private static func popups(in view: NSView) -> [NSPopUpButton] {
        var found: [NSPopUpButton] = []
        for subview in view.subviews {
            if let button = subview as? NSPopUpButton {
                found.append(button)
            }
            found.append(contentsOf: popups(in: subview))
        }
        return found
    }
}