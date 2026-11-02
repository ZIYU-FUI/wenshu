import Foundation
import Testing
@testable import WenshuApp

@Suite("Apple split-view automatic bounds")
struct AppleSplitViewAutomaticBoundsTests {
    @Test("NavigationSplitView retains Apple's automatic column sizing")
    func navigationColumnsUseAutomaticWidth() throws {
        let source = try Self.source(
            "Sources/WenshuApp/Shared/UI/LibraryRootView.swift"
        )
        #expect(source.components(separatedBy: ".navigationSplitViewColumnWidth(").count == 3)
        #expect(source.contains("min: 200"))
        #expect(source.contains("ideal: 240"))
        #expect(source.contains("max: 320"))
        #expect(source.contains("min: 240"))
        #expect(source.contains("ideal: 300"))
        #expect(source.contains("max: 340"))
    }

    @Test("editor and chat use Apple automatic lower, preferred, and upper bounds")
    func editorAndChatUseAutomaticBounds() throws {
        // The controller was ONE file and was split under the tree's
        // 600-LOC cap, so its source is read across the five files it
        // now lives in (= a move is not a disappearance).
        let source = try Self.controllerSource()
        #expect(source.components(separatedBy: "minimumThickness = NSSplitViewItem.unspecifiedDimension").count == 3)
        #expect(source.components(separatedBy: "preferredThicknessFraction = 1.0 / 2.0").count == 3)
        #expect(source.contains("item.maximumThickness = available"))
        #expect(source.contains("guard available > 0 else { return }"))
        #expect(source.contains("updateAutomaticThicknessBounds()"))
    }

    /// The controller's source, across the five files it lives in.
    private static let controllerSourceFiles = [
        "Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift",
        "Sources/WenshuApp/Features/Editor/View/EditorChatNSController+Lifecycle.swift",
        "Sources/WenshuApp/Features/Editor/View/EditorChatNSController+Divider.swift",
        "Sources/WenshuApp/Features/Editor/View/EditorChatNSController+Layout.swift",
        "Sources/WenshuApp/Features/Editor/View/EditorChatSplitHost.swift",
    ]

    private static func controllerSource() throws -> String {
        try controllerSourceFiles
            .map { try Self.source($0) }
            .joined(separator: "\n")
    }

    private static func source(_ relativePath: String) throws -> String {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while current.path != "/" {
            let package = current.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                return try String(
                    contentsOf: current.appendingPathComponent(relativePath),
                    encoding: .utf8
                )
            }
            current.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
