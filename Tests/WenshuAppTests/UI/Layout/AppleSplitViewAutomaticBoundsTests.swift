import Foundation
import Testing
@testable import WenshuApp

@Suite("Apple split-view automatic bounds")
struct AppleSplitViewAutomaticBoundsTests {
    @Test("NavigationSplitView retains Apple's automatic column sizing")
    func navigationColumnsUseAutomaticWidth() throws {
        let source = try Self.source(
            "Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift"
        )
        #expect(source.components(separatedBy: ".navigationSplitViewColumnWidth(").count == 3)
        #expect(source.contains("min: 200"))
        #expect(source.contains("ideal: 240"))
        #expect(source.contains("max: 320"))
        #expect(source.contains("min: 280"))
        #expect(source.contains("ideal: 360"))
        #expect(source.contains("max: 520"))
    }

    @Test("editor and chat use Apple automatic lower, preferred, and upper bounds")
    func editorAndChatUseAutomaticBounds() throws {
        let source = try Self.source(
            "Sources/WenshuApp/UI/Layout/EditorChatNSController.swift"
        )
        #expect(source.components(separatedBy: "minimumThickness = NSSplitViewItem.unspecifiedDimension").count == 3)
        #expect(source.components(separatedBy: "preferredThicknessFraction = 1.0 / 2.0").count == 3)
        #expect(source.contains("item.maximumThickness = available"))
        #expect(source.contains("guard available > 0 else { return }"))
        #expect(source.contains("updateAutomaticThicknessBounds()"))
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
