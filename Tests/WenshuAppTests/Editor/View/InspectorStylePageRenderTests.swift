//
//  InspectorStylePageRenderTests.swift · Wenshu
//
//  The inspector column's style page, rendered.
//
//  The style page is the BOOK's style sheet: = the twelve styles a
//  novel uses, = and the five knobs the book is fine-tuned with. = This
//  suite renders the real page and reads the rendered accessibility tree
//  back, so the facts a source read cannot reach are measured on the
//  page itself:
//
//  1. The page carries the twelve roles and the five knobs.
//  2. Each row shows the face, = the size and = the leading the book's
//     own sheet gives that role.
//  3. The knobs show the SELECTED BOOK's positions, = and two books
//     with different sheets show their own.
//  4. Changing the book changes what the page shows.
//  5. The commands a book sets once (= the strike, = the inline code,
//     = the headings, = the lists, = the quote, = the code block, = the
//     rule and = the link) = are gone from the page.
//  6. Nothing on the page writes the sheet back.
//
//  The tree is read through the ACCESSIBILITY SYSTEM (= the route the
//  layout probe reads a running app's tree through), because a SwiftUI
//  button publishes itself to that system and never appears in AppKit's
//  view hierarchy.
//
//  swift test --filter InspectorStylePageRenderTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Inspector column style page, rendered", .serialized)
struct InspectorStylePageRenderTests {
    /// The page carries the twelve roles and the five knobs.
    @Test("the page carries the twelve styles and the five knobs")
    func thePageCarriesTheStylesAndTheKnobs() {
        let model = InspectorStylePageModel(sheet: .default)
        #expect(
            model.rows.count == 12,
            "the style table names the twelve roles a novel uses"
        )
        #expect(
            model.rows.map(\.role) == [
                .body, .quote, .note,
                .headingOne, .headingTwo, .headingThree,
                .bookTitle, .figureCaption, .tableCaption,
                .image, .rule, .monospace,
            ],
            "the style table names the twelve roles in the order a book is made of"
        )
        #expect(
            model.knobs.map(\.id) == [
                "bodySize", "lineSpacing", "firstLineIndent", "segmentSpacing", "bodyFamily",
            ],
            "the page carries the five knobs a book is set with"
        )
    }

    /// Each row shows what the sheet gives it.
    @Test("each row shows the face, the size and the leading the sheet gives it")
    func eachRowShowsWhatTheSheetGivesIt() {
        let sheet = BookStyleSheet(
            bodySize: .large,
            lineSpacing: .loose,
            firstLineIndent: .none,
            segmentSpacing: .halfCharacter,
            bodyFamily: .kai,
            quoteFamily: .heiti,
            headingLadder: .generous
        )
        let model = InspectorStylePageModel(sheet: sheet)
        let body = model.rows.first { $0.role == .body }
        #expect(body?.family == .kai, "the body is set in the body's own face")
        #expect(body?.size == 14, "the body's size is the sheet's body size")
        #expect(body?.spacing == 1.70, "the body runs at the sheet's leading")
        let quote = model.rows.first { $0.role == .quote }
        #expect(quote?.family == .heiti, "the quote is set in the quote's own face")
        #expect(quote?.size == 12.5, "the quote's size is the sheet's quote size")
        let heading = model.rows.first { $0.role == .headingOne }
        #expect(
            heading?.family == .kai,
            "the headings follow the body's own heading face (= the sheet names it)"
        )
        #expect(heading?.size == 18, "the heading's size comes from the sheet's ladder")
        let image = model.rows.first { $0.role == .image }
        #expect(image?.family == nil, "the sheet names no face for the image")
        #expect(
            image?.cells == [InspectorAXTree.unsetName],
            "a role the sheet names nothing for shows a dash (= the print standard's own table writes one)"
        )
    }

    /// The knobs show the selected book's own positions.
    @Test("the knobs show the selected book's own positions")
    func theKnobsShowTheSelectedBooksPositions() throws {
        let (store, plain, _) = try makeStore()
        let workspace = makeWorkspace()
        workspace.sidebarSelection = .book(plain.id)
        let rendered = renderPage(store: store, workspace: workspace)
        defer { rendered.close() }
        let labels = rendered.menuLabels()
        #expect(
            labels.count == 5,
            "the page carries five knobs (= the five a book is set with): \(labels)"
        )
        for key in [
            "inspector.style.bodySize.medium",
            "inspector.style.lineSpacing.standard",
            "inspector.style.firstLineIndent.twoCharacters",
            "inspector.style.segmentSpacing.none",
            "inspector.style.family.songti",
        ] {
            #expect(
                labels.contains(InspectorAXTree.positionName(key)),
                "the knob for \(key) must show the book's own position"
            )
        }
    }

    /// Two books with different sheets show their own.
    @Test("two books with different sheets show their own")
    func twoBooksWithDifferentSheetsShowTheirOwn() throws {
        let (store, plain, other) = try makeStore()
        let workspace = makeWorkspace()
        workspace.sidebarSelection = .book(plain.id)
        let rendered = renderPage(store: store, workspace: workspace)
        defer { rendered.close() }
        let plainLabels = rendered.menuLabels()
        workspace.sidebarSelection = .book(other.id)
        let otherLabels = rendered.menuLabels()
        #expect(
            plainLabels != otherLabels,
            "two books with different sheets must show their own positions: \(plainLabels) vs \(otherLabels)"
        )
        for key in [
            "inspector.style.bodySize.large",
            "inspector.style.lineSpacing.loose",
            "inspector.style.firstLineIndent.none",
            "inspector.style.segmentSpacing.halfCharacter",
            "inspector.style.family.kai",
        ] {
            #expect(
                otherLabels.contains(InspectorAXTree.positionName(key)),
                "the second book's own position must show: \(key)"
            )
        }
    }

    /// Changing the book changes what the page shows.
    @Test("changing the book changes what the page shows")
    func changingTheBookChangesWhatThePageShows() throws {
        let (store, plain, other) = try makeStore()
        let workspace = makeWorkspace()
        workspace.sidebarSelection = .book(plain.id)
        let rendered = renderPage(store: store, workspace: workspace)
        defer { rendered.close() }
        let before = rendered.menuLabels()
        #expect(
            before.contains(InspectorAXTree.positionName("inspector.style.bodySize.medium")),
            "the first book's own body size must show"
        )
        workspace.sidebarSelection = .book(other.id)
        let after = rendered.menuLabels()
        #expect(
            after.contains(InspectorAXTree.positionName("inspector.style.bodySize.large")),
            "the second book's own body size must show after the selection changes"
        )
        #expect(
            before != after,
            "the page must follow the selection"
        )
    }

    /// The commands a book sets once are not on the page.
    @Test("the commands a book sets once are not on the page")
    func theCommandsABookSetsOnceAreNotOnThePage() throws {
        let code = try InspectorAXTree.code(of: String(
            contentsOf: Self.formatPageSourceURL(),
            encoding: .utf8
        ))
        let styleCode = try InspectorAXTree.code(of: String(
            contentsOf: Self.stylePageSourceURL(),
            encoding: .utf8
        ))
        // The commands that are left are the three a novel uses inline.
        let dropped = EditorFormatAction.allCases.filter {
            $0 != .bold && $0 != .italic && $0 != .highlight
        }
        let offenders = dropped.filter { action in
            Self.names(action, in: code) || Self.names(action, in: styleCode)
        }
        #expect(
            offenders.isEmpty,
            "these commands are still on the page (= a book sets them once, = in its style sheet): \(offenders.map(\.rawValue))"
        )
    }

    /// Whether the code names the command (= `.heading` and = not
    /// `.headingSize`, = because the command's own name ends there).
    private static func names(_ action: EditorFormatAction, in code: String) -> Bool {
        code.range(of: "\\.\(action.rawValue)\\b", options: .regularExpression) != nil
    }

    /// The knobs are read-only.
    @Test("the page writes nothing back (= the write-back is the engine card's work)")
    func thePageWritesNothingBack() throws {
        let code = try InspectorAXTree.code(of: String(
            contentsOf: Self.stylePageSourceURL(),
            encoding: .utf8
        ))
        #expect(
            code.contains("effectiveStyleSheet"),
            "the page reads the book's own sheet"
        )
        #expect(
            !code.contains("sidebarSaveBook"),
            "this card writes nothing back (= the engine card owns the write-back)"
        )
        #expect(
            !code.contains("styleSheet ="),
            "this card writes nothing back (= the engine card owns the write-back)"
        )
    }

    /// Every role and knob name is in the catalog.
    @Test("every role, knob and position is in the catalog")
    func everyRoleKnobAndPositionIsInTheCatalog() throws {
        let catalog = try InspectorAXTree.catalog(at: Self.catalogURL())
        var missing: [String] = []
        for role in InspectorStyleRole.allCases {
            missing.append("inspector.style.role.\(role.rawValue)")
        }
        for key in [
            "inspector.style.group.styles",
            "inspector.style.group.tuning",
            "inspector.style.knob.bodySize",
            "inspector.style.knob.lineSpacing",
            "inspector.style.knob.firstLineIndent",
            "inspector.style.knob.segmentSpacing",
            "inspector.style.knob.bodyFamily",
            "inspector.style.bodySize.small",
            "inspector.style.bodySize.medium",
            "inspector.style.bodySize.large",
            "inspector.style.lineSpacing.tight",
            "inspector.style.lineSpacing.standard",
            "inspector.style.lineSpacing.loose",
            "inspector.style.firstLineIndent.none",
            "inspector.style.firstLineIndent.twoCharacters",
            "inspector.style.segmentSpacing.none",
            "inspector.style.segmentSpacing.halfCharacter",
            "inspector.style.family.songti",
            "inspector.style.family.heiti",
            "inspector.style.family.kai",
            "inspector.style.family.pingFang",
            "inspector.style.size",
            "inspector.style.leading",
            "inspector.style.unset",
        ] {
            missing.append(key)
        }
        #expect(
            missing.filter { catalog[$0] == nil }.isEmpty,
            "these names are not in the catalog: \(missing.filter { catalog[$0] == nil })"
        )
    }

    // MARK: - The fixture

    /// A book store with two books that carry different sheets.
    private func makeStore() throws -> (BookStore, Book, Book) {
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
    private func makeWorkspace() -> WorkspaceUIState {
        let suiteName = "wenshu-style-page-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        return WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
    }

    /// The style page, rendered in a window of its own.
    private func renderPage(
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

    /// The page, rendered, and held open (= so a change can be read
    /// back from the same window).
    @MainActor
    private struct RenderedPage {
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
    }

    /// The format page's own source file (= where its rows are written).
    private static func formatPageSourceURL() -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        return root
            .appendingPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorFormatPageView.swift")
    }

    /// The style page's own source file (= where its rows are written).
    private static func stylePageSourceURL() -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        return root
            .appendingPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorStylePageView.swift")
    }

    /// The string catalog (= where the names live).
    private static func catalogURL() -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        return root
            .appendingPathComponent("Sources/WenshuApp/Resources/Localizable.xcstrings")
    }
}

// MARK: - The rendered tree

/// The rendered accessibility tree of a hosted view.
///
/// The tree is read through the ACCESSIBILITY PROTOCOL, because a
/// SwiftUI control publishes itself there (= it never becomes an
/// AppKit view), and the walk goes all the way down (= the page's rows
/// sit under the scroll area's content).
///
/// The measurements this rests on (= measured in the app's own
/// process): = a SwiftUI `Menu` publishes an `AXMenuButton` AND its
/// label; = a `Text` publishes NOTHING; = a `TextField` publishes an
/// `AXTextField`. = So the knobs (= the only values on the page that
/// have to be read back) = are menus, = and their labels are the
/// book's own positions.
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
