//
//  SidebarIconUniformityTests.swift · Wenshu · v3.0
//
//  Validates the SFLabelRow central factory shape: every sidebar
//  row renders the same icon slot (= 16 PT frame, 2 PT inner
//  inset, .regular weight, .primary color) so the tree reads as
//  one visual column. Per (see OOB.md #2026-10-08) the wenshu
//  default follows Apple Mail / Notes / Xcode / System Settings:
//  the slot is constant; the optical width of each SF Symbol
//  floats ±4 PT inside the slot because Apple keeps each
//  symbol's intrinsic optical bounds. A future sweep can
//  optionally measure + scale (see icon-policy .scaleEffect
//  recipe), but the per-frame .regular weight + .hierarchical
//  rendering already produces the column-aligned look Apple
//  uses in its first-party apps.

import Foundation
import Testing
@testable import WenshuApp

@Suite("Sidebar icon uniformity")
struct SidebarIconUniformityTests {
    @Test("SFLabelRow uses the central icon factory and a fixed row slot")
    func sidebarRowUsesCentralFactoryAndFixedSlot() throws {
        let source = try Self.source("Sources/WenshuApp/UI/IconStyles.swift")
        // Factory shape: SFLabelRow delegates to SFIcon(..., style: iconStyle)
        // and pins the row slot via sidebarWidth / sidebarInset.
        #expect(source.contains("SFIcon(\n                systemImage,\n                style: iconStyle"))
        #expect(source.contains("padding(.horizontal, iconStyle.sidebarInset)"))
        #expect(source.contains("width: iconStyle.sidebarWidth"))
        // The slot is 16 PT wide; we don't force a square frame
        // (= Apple keeps each symbol's intrinsic height).
        #expect(!source.contains("height: iconStyle.sidebarHeight"))
        // Hierarchical rendering at .regular weight = Apple HIG
        // canonical sidebar row iconography.
        #expect(source.contains(".symbolRenderingMode(.hierarchical)"))
        // Color = .primary (= Apple Tahoe sidebar default =
        // system text color, not app accent). One tier only.
        #expect(source.contains(".foregroundStyle(Color.primary)"))
        #expect(!source.contains(".foregroundStyle(.tint)\n            .opacity(iconOpacity)"))
        // IconStyle carries a dedicated .sidebar case so the slot
        // properties (sidebarWidth / sidebarInset) are scoped to
        // the sidebar surface (= not attached to every case via
        // an extension on IconStyle).
        #expect(source.contains("case sidebar"))
        let rowSource = try Self.sourceSlice(
            from: "struct SFLabelRow: View {",
            to: "// MARK: - SFStatusBadge"
        )
        #expect(!rowSource.contains("Image(systemName: systemImage)"))
    }

    @Test("IconStyle.sidebar is the canonical sidebar case (= 16 PT, .regular, slot properties)")
    func sidebarCaseIsCanonical() throws {
        let source = try Self.source("Sources/WenshuApp/UI/IconStyles.swift")
        // 16 PT point size matches Apple Mail / Notes / Xcode
        // sidebar row leading icon (= the wenshu default per
        // Apple's HIG sidebar anatomy).
        #expect(source.contains("case .sidebar: 16"))
        // slot dimensions live in the extension on IconStyle so
        // they're explicit (= not piggy-backed on every case).
        #expect(source.contains("var sidebarWidth: CGFloat { 16 }"))
        #expect(source.contains("var sidebarInset: CGFloat { 2 }"))
        // SFLabelRow defaults to .sidebar (not .small) so a
        // caller that doesn't pass iconStyle still hits the
        // canonical sidebar surface.
        #expect(source.contains("iconStyle: IconStyle = .sidebar"))
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
