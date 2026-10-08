import Foundation
import Testing
@testable import WenshuApp

@Suite("Sidebar icon uniformity")
struct SidebarIconUniformityTests {
    @Test("SFLabelRow uses the central icon factory and a fixed row slot")
    func sidebarRowUsesCentralFactoryAndFixedSlot() throws {
        let source = try Self.source("Sources/WenshuApp/UI/IconStyles.swift")
        #expect(source.contains("SFIcon(\n                systemImage,\n                style: iconStyle"))
        #expect(source.contains("padding(.horizontal, iconStyle.sidebarInset)"))
        #expect(source.contains("width: iconStyle.sidebarWidth"))
        #expect(!source.contains("height: iconStyle.sidebarHeight"))
        #expect(source.contains(".symbolRenderingMode(.hierarchical)"))
        #expect(source.contains(".foregroundStyle(.tint)"))
        #expect(source.contains(".opacity(iconOpacity)"))
        let rowSource = try Self.sourceSlice(
            from: "struct SFLabelRow: View {",
            to: "// MARK: - SFStatusBadge"
        )
        #expect(!rowSource.contains("Image(systemName: systemImage)"))
    }

    private static func sourceSlice(from start: String, to end: String) throws -> String {
        let source = try source("Sources/WenshuApp/UI/IconStyles.swift")
        guard let startRange = source.range(of: start),
              let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }

    private static func source(_ relativePath: String) throws -> String {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while current.path != "/" {
            let package = current.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                return try String(contentsOf: current.appendingPathComponent(relativePath), encoding: .utf8)
            }
            current.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
