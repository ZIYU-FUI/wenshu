//
//  InspectorFormatPageRenderTests.swift · Wenshu
//
//  The inspector column's format page, rendered.
//
//  The format page is the BOOK's style sheet now: = the three commands
//  a novel uses inline, = and then the style page, = which names the
//  book's twelve styles and the five knobs it is fine-tuned with. = This
//  suite proves what the page does NOT carry any more:
//
//  1. The heading menu and the link field are GONE (= the page asks
//     for no value: = a book sets both once, = in its style sheet).
//  2. The three commands that survive share ONE row (= Pages' shape).
//  3. The page draws no card behind its rows.
//  4. The page carries no readout of the DOCUMENT's selection (= the
//     engine publishes no current-value getters, = so a readout would
//     be a value the app invented).
//
//  (= The commands a book sets once are gone too, = and that check
//  lives with the style page's suite, = because the style sheet is
//  where those commands went.)
//
//  The tree is read through the ACCESSIBILITY SYSTEM (= the route the
//  layout probe reads a running app's tree through), because a SwiftUI
//  button publishes itself to that system and never appears in AppKit's
//  view hierarchy.
//
//  swift test --filter InspectorFormatPageRenderTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Inspector column format page, rendered", .serialized)
struct InspectorFormatPageRenderTests {
    /// The page, rendered, and the accessibility tree it painted.
    ///
    /// The tree is read from the window the page drew, so the
    /// assertions are about what the page actually painted (= not about
    /// what its source says it draws).
    ///
    /// The window is KEYED, because a SwiftUI view publishes itself to
    /// the accessibility system only once its window is on screen; and
    /// the suite is SERIALIZED, because only the key window publishes
    /// and parallel tests would take that key from each other.
    private func renderedPage() -> RenderedPage {
        let host = NSHostingView(rootView: AnyView(
            InspectorFormatPageView()
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

    /// The page, rendered, and held open (= so the tree can be read
    /// back from the same window).
    @MainActor
    private struct RenderedPage {
        let host: NSHostingView<AnyView>
        let window: NSWindow

        /// The elements the page paints.
        func elements() -> [InspectorAXTree.Element] {
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            return InspectorAXTree.elements(of: host)
        }

        func close() {
            window.orderOut(nil)
        }
    }

    /// The library the page reads (= the book whose sheet it shows).
    private var store: BookStore {
        BookStore(stores: Self.makeStores())
    }

    /// The workspace state the page reads (= the sidebar's selection).
    private var workspace: WorkspaceUIState {
        let suiteName = "wenshu-format-page-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        return WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
    }

    /// A library of its own (= its own folders, = so the suite never
    /// touches the user's own library).
    private static func makeStores() -> LibraryStores {
        let tmpRoot = URL(
            fileURLWithPath: "/tmp/wenshu-format-page-\(UUID().uuidString)",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = tmpRoot.appendingPathComponent("reference-library", isDirectory: true)
        return LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        )
    }

    @Test("the page asks for no heading level and no link target")
    func thePageAsksForNoValues() {
        let rendered = renderedPage()
        defer { rendered.close() }
        let elements = rendered.elements()
        // The link command's target field (= the request carries a URL).
        let fields = elements.filter { $0.role == "AXTextField" }
        #expect(
            fields.isEmpty,
            "the page must offer no link target (= a book sets its links once, = in its style sheet)"
        )
        // The heading command's menu (= the level is chosen there).
        let menus = elements.filter { $0.role == "AXMenuButton" || $0.role == "AXPopUpButton" }
        #expect(
            menus.allSatisfy { $0.label != EditorFormatAction.heading.localizedAccessibilityLabel },
            "the page must offer no heading level (= a book sets its headings once, = in its style sheet)"
        )
        #expect(
            menus.count == 7,
            "the page's only menus are the five knobs and the two sets (= a style is a row, = not a menu): \(menus.map(\.label))"
        )
    }

    @Test("the page draws its related commands on one row (= Pages' shape)")
    func thePageDrawsRelatedCommandsOnOneRow() throws {
        let code = try InspectorAXTree.code(of: String(
            contentsOf: Self.pageSourceURL(),
            encoding: .utf8
        ))
        // Pages puts the related controls of one kind on ONE row, in one
        // block (= its bold / italic / underline). So the character
        // commands are one row, not three rows of one command each.
        #expect(
            code.contains("InspectorFormatCommandStrip(actions: [.bold, .italic, .highlight])"),
            "the character commands must share one row (= Pages draws its related controls side by side)"
        )
    }

    @Test("the page hosts the book's style sheet")
    func thePageHostsTheStyleSheet() throws {
        let code = try InspectorAXTree.code(of: String(
            contentsOf: Self.pageSourceURL(),
            encoding: .utf8
        ))
        #expect(
            code.contains("InspectorStylePageView()"),
            "the format page must carry the book's style sheet (= the style page)"
        )
    }

    @Test("the page draws no card behind its rows (= Pages' column has none)")
    func thePageDrawsNoCardBehindItsRows() throws {
        let source = try String(
            contentsOf: Self.pageSourceURL(),
            encoding: .utf8
        )
        // Measured on the running Pages app: its inspector's controls sit
        // directly on the column's background, in rounded blocks. A card
        // behind a row would be a plate Pages does not draw.
        //
        // The check reads the CODE (= the comments stripped), because a
        // comment that NAMES a type is not a use of it (= this page's own
        // header explains the choice and names the card the other pages
        // use).
        #expect(
            !InspectorAXTree.code(of: source).contains("InspectorCard"),
            "the format page must not draw a card behind its rows (= Pages' inspector column has no card)"
        )
    }

    @Test("the page carries no current-value readout")
    func thePageCarriesNoCurrentValueReadout() {
        // A readout would publish the DOCUMENT's CURRENT format (= is
        // the selection bold?). The engine publishes no public
        // current-value getters, so any such label on this page would
        // be a value the app invented. (= The values the page DOES show
        // are the book's own, = and those the app reads.)
        let rendered = renderedPage()
        defer { rendered.close() }
        let readouts = rendered.elements().filter { element in
            let text = [element.label, element.title, element.value].joined(separator: " ")
            return text.localizedCaseInsensitiveContains("current")
                || text.localizedCaseInsensitiveContains("selected format")
        }
        #expect(
            readouts.isEmpty,
            "the format page must carry the book's own values only (= a current-value readout would be a value the app cannot read): \(readouts.map(\.label))"
        )
    }

    /// The page's own source file (= where its rows are written).
    private static func pageSourceURL() -> URL {
        root()
            .appendingPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorFormatPageView.swift")
    }

    /// The worktree's root (= where the sources live).
    private static func root() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
    }
}
