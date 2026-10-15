import Foundation
import Testing
@testable import WenshuApp

@Suite("Segmented control icon configuration")
struct LabelSegmentedControlIconConfigurationTests {
    @Test("segmented symbols use the central toolbar style before AppKit rendering")
    func segmentedSymbolsUseCentralToolbarStyle() throws {
        let sourceURL = try Self.repositoryURL(
            relativePath: "Sources/WenshuApp/UI/Segmented/LabelSegmentedControl.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("pointSize: iconStyle.pointSize"))
        #expect(source.contains("weight: symbolWeight"))
        #expect(source.contains("scale: .medium"))
    }

    private static func repositoryURL(relativePath: String) throws -> URL {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while current.path != "/" {
            if FileManager.default.fileExists(
                atPath: current.appendingPathComponent("Package.swift").path
            ) {
                return current.appendingPathComponent(relativePath)
            }
            current.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
