//
//  InspectorAXTree.swift  (the accessibility-tree reader the format page's
//  and the style page's suites share)
//
//  It is its own file because the style page's suite grew past the cap
//  (AGENTS.md 6.6) = and the helper is read by BOTH suites, = so it
//  belongs to neither of them.
//

import AppKit
import Foundation
import SwiftUI

enum InspectorAXTree {
    /// One element of the rendered accessibility tree.
    struct Element {
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
    @MainActor
    static func elements(of view: NSView) -> [Element] {
        var found: [Element] = []
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
        into found: inout [Element],
        visited: inout Set<ObjectIdentifier>
    ) {
        guard depth < 16 else { return }
        let identifier = ObjectIdentifier(view)
        guard visited.insert(identifier).inserted else { return }

        if view.isAccessibilityElement() {
            found.append(oneElement(from: view))
        }
        for child in view.accessibilityChildren() ?? [] {
            collect(child, depth: depth + 1, into: &found, visited: &visited)
        }
        for subview in view.subviews {
            collect(subview, depth: depth + 1, into: &found, visited: &visited)
        }
    }

    /// One published child (= an AppKit view, = or a SwiftUI accessibility
    /// object that is not one), = and whatever it publishes under it.
    ///
    /// THE BLIND SPOT THIS CLOSES
    ///
    /// A control SwiftUI draws itself (= a `Picker`, = and a `Button`) is
    /// NO AppKit view at all: = it exists only as an accessibility object
    /// = nested under another accessibility object. = A walk that read one
    /// level of those and then looked only for views among their children
    /// dropped the control itself, = so a page whose drop-downs are
    /// SwiftUI's read as a page with none.
    @MainActor
    private static func collect(
        _ child: Any,
        depth: Int,
        into found: inout [Element],
        visited: inout Set<ObjectIdentifier>
    ) {
        if let view = child as? NSView {
            collect(view, depth: depth, into: &found, visited: &visited)
            return
        }
        guard let ax = child as? NSAccessibilityProtocol else { return }
        let identifier = ObjectIdentifier(ax as AnyObject)
        guard visited.insert(identifier).inserted else { return }
        found.append(oneElement(from: ax))
        for nested in ax.accessibilityChildren() ?? [] {
            collect(nested, depth: depth + 1, into: &found, visited: &visited)
        }
    }

    /// One accessibility element, as the strings it publishes.
    @MainActor
    private static func oneElement(from view: NSView) -> Element {
        Element(
            role: view.accessibilityRole()?.rawValue ?? "",
            label: view.accessibilityLabel() ?? "",
            title: view.accessibilityTitle() ?? "",
            help: view.accessibilityHelp() ?? "",
            value: stringValue(view.accessibilityValue()),
            placeholder: view.accessibilityPlaceholderValue() ?? ""
        )
    }

    /// One accessibility element, as the strings it publishes.
    @MainActor
    private static func oneElement(from ax: NSAccessibilityProtocol) -> Element {
        Element(
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

    /// A position's name, as the page reads it (= the same lookup the
    /// page makes, = so the two cannot drift apart).
    static func positionName(_ key: String) -> String {
        NSLocalizedString(
            key,
            comment: "The position a knob of a book's style sheet can take"
        )
    }

    /// The dash that stands for a value the sheet does not name.
    static var unsetName: String {
        NSLocalizedString(
            "inspector.style.unset",
            comment: "The dash that stands for a value the book's style sheet does not name"
        )
    }

    /// The catalog's keys (= the names the page draws).
    static func catalog(at url: URL) throws -> [String: Int] {
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = object["strings"] as? [String: Any]
        else {
            throw CatalogShapeError()
        }
        return strings.mapValues { value in
            (value as? [String: Any])?.count ?? 0
        }
    }

    /// The source's code (= its comments stripped, = so a comment that
    /// names a type is not read as a use of it).
    static func code(of source: String) -> String {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") {
                    return ""
                }
                return String(line.replacingOccurrences(
                    of: #"(?<!:)//.*$"#,
                    with: "",
                    options: .regularExpression
                ))
            }
            .joined(separator: "\n")
    }

    /// The catalog's shape was not what the reader expected.
    struct CatalogShapeError: Error {}
}
