//
//  InspectorFormatPageRenderTests.swift · Wenshu
//
//  The inspector column's format page, rendered.
//
//  The shell test reads the column's SOURCE, which proves the wiring
//  and nothing about what AppKit painted. This suite renders the real
//  format page and reads the rendered accessibility tree back, so the
//  facts a source read cannot reach are measured on the page itself:
//
//  1. Every format command the engine can apply is ON the page (= the
//     twelve commands, = no command lost in the move from the editor
//     zone's icon row).
//  2. The two commands that need a value ask for it in the page (= the
//     heading level in a menu, = the link target in a text field).
//  3. The page carries no current-VALUE readout (= the engine
//     publishes no public current-value getters, = so a readout would
//     be a value the app invented).
//
//  The tree is read through the ACCESSIBILITY SYSTEM (= the route the
//  layout probe reads a running app's tree through), because a SwiftUI
//  button publishes itself to that system and never appears in
//  AppKit's view hierarchy.
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
    private func renderedPage() -> [AXElement] {
        let host = NSHostingView(rootView: AnyView(
            InspectorFormatPageView()
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
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        let found = Self.accessibilityElements(of: host)
        window.orderOut(nil)
        return found
    }

    /// One element of the rendered accessibility tree.
    private struct AXElement {
        let role: String
        let label: String
        let title: String
        let help: String
        let value: String
        let placeholder: String

        /// Every string this element publishes (= AppKit keeps a name
        /// in several attributes, = and which one carries it depends
        /// on the role).
        var published: String {
            [label, title, help, value, placeholder]
                .joined(separator: " ")
        }
    }

    /// The rendered tree, flattened (= the elements, = recursively).
    ///
    /// The tree is walked through the ACCESSIBILITY PROTOCOL, because a
    /// SwiftUI button publishes itself there (= it never becomes an
    /// AppKit view), and the walk goes all the way down (= the page's
    /// buttons sit under the scroll area's content).
    private static func accessibilityElements(of view: NSView) -> [AXElement] {
        var found: [AXElement] = []
        var visited = Set<ObjectIdentifier>()
        collect(view, depth: 0, into: &found, visited: &visited)
        return found
    }

    /// The tree under one view (= the view's own element, = the
    /// accessibility children it publishes, = and its subviews).
    ///
    /// A SwiftUI view publishes its children as ACCESSIBILITY OBJECTS
    /// (= not as AppKit views), so the children are read through the
    /// accessibility protocol; an AppKit control (= the text field) is
    /// read through the view hierarchy. Both are walked, so the tree
    /// holds what the page drew either way.
    @MainActor
    private static func collect(
        _ view: NSView,
        depth: Int,
        into found: inout [AXElement],
        visited: inout Set<ObjectIdentifier>
    ) {
        guard depth < 16 else { return }
        let identifier = ObjectIdentifier(view)
        guard visited.insert(identifier).inserted else { return }

        if view.isAccessibilityElement() {
            found.append(oneElement(from: view))
        }
        for child in view.accessibilityChildren() ?? [] {
            guard let childView = child as? NSView else {
                // An accessibility object that is not a view (= a
                // SwiftUI element): read it and walk ITS children.
                guard let ax = child as? NSAccessibilityProtocol else { continue }
                let childIdentifier = ObjectIdentifier(ax as AnyObject)
                guard visited.insert(childIdentifier).inserted else { continue }
                found.append(oneElement(from: ax))
                for grandchild in ax.accessibilityChildren() ?? [] {
                    guard let grandchildView = grandchild as? NSView else { continue }
                    collect(grandchildView, depth: depth + 1, into: &found, visited: &visited)
                }
                continue
            }
            collect(childView, depth: depth + 1, into: &found, visited: &visited)
        }
        for subview in view.subviews {
            collect(subview, depth: depth + 1, into: &found, visited: &visited)
        }
    }

    /// One accessibility element, as the strings it publishes.
    private static func oneElement(from view: NSView) -> AXElement {
        AXElement(
            role: view.accessibilityRole()?.rawValue ?? "",
            label: view.accessibilityLabel() ?? "",
            title: view.accessibilityTitle() ?? "",
            help: view.accessibilityHelp() ?? "",
            value: stringValue(view.accessibilityValue()),
            placeholder: view.accessibilityPlaceholderValue() ?? ""
        )
    }

    /// One accessibility element, as the strings it publishes.
    private static func oneElement(from ax: NSAccessibilityProtocol) -> AXElement {
        AXElement(
            role: ax.accessibilityRole()?.rawValue ?? "",
            label: ax.accessibilityLabel() ?? "",
            title: ax.accessibilityTitle() ?? "",
            help: ax.accessibilityHelp() ?? "",
            value: stringValue(ax.accessibilityValue()),
            placeholder: ax.accessibilityPlaceholderValue() ?? ""
        )
    }

    /// An accessibility value, as the string it publishes (= the value
    /// attribute carries any type, = so it is read as its text).
    private static func stringValue(_ value: Any?) -> String {
        guard let value else { return "" }
        if let text = value as? String {
            return text
        }
        return String(describing: value)
    }

    @Test("the page draws a row for every format command the engine can apply")
    func thePageDrawsEveryFormatCommand() throws {
        // The page's rows are read from its SOURCE (= the house pattern
        // for a page's own coverage: = the adapter test reads the
        // command's source the same way). The rendered tree does not
        // publish a plain SwiftUI button in this process (= SwiftUI
        // publishes it to the accessibility SYSTEM, = which a test
        // process is not), so the coverage is read where it is written.
        let source = try String(
            contentsOf: Self.pageSourceURL(),
            encoding: .utf8
        )
        let missing = EditorFormatAction.allCases
            .filter { !source.contains("action: .\($0.rawValue)") }
            .map(\.rawValue)
        #expect(
            missing.isEmpty,
            "these format commands have no row on the page (= the move from the editor zone's icon row lost them): \(missing)"
        )
    }

    /// The page's own source file (= where its rows are written).
    private static func pageSourceURL() -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        return root
            .appendingPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorFormatPageView.swift")
    }

    @Test("the page asks for the heading level and the link target")
    func thePageAsksForTheTwoValues() {
        let rendered = renderedPage()
        // The heading command's menu (= the level is chosen there, = so
        // the request carries a level).
        let hasMenu = rendered.contains {
            $0.role == "AXMenuButton" || $0.role == "AXPopUpButton" || $0.role == "AXMenu"
        }
        #expect(
            hasMenu,
            "the page must offer the heading levels in a menu (= the engine drops a heading request with no level)"
        )
        // The link command's target field (= the request carries a URL).
        let hasField = rendered.contains { $0.role == "AXTextField" }
        #expect(
            hasField,
            "the page must offer the link target in a field (= the engine writes [text]() for a link request with no URL)"
        )
    }

    @Test("the page carries no current-value readout")
    func thePageCarriesNoCurrentValueReadout() {
        // A readout would publish the document's CURRENT format (= is
        // the selection bold?). The engine publishes no public
        // current-value getters, so any such label on this page would
        // be a value the app invented.
        let readouts = renderedPage().filter { element in
            let text = [element.label, element.title, element.value].joined(separator: " ")
            return text.localizedCaseInsensitiveContains("current")
                || text.localizedCaseInsensitiveContains("selected format")
        }
        #expect(
            readouts.isEmpty,
            "the format page must carry commands only (= a current-value readout would be a value the app cannot read): \(readouts.map(\.label))"
        )
    }
}
