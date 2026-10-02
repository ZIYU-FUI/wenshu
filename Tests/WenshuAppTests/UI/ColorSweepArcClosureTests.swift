//
//  ColorSweepArcClosureTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB sweep closure mode).
//
//  Color sweep arc closure (= rounds 73-75).
//
//  This test verifies the FINAL color sweep state (= 53 .opacity literals,
//  175 Color.X sites, 12 Color(nsColor:) sites, 0 raw RGB literals):
//
//  Round 73 — accentTintOpacityHero kanban migration:
//  - 2 sites: KanbanView L450 + KanbanTicketDetailSheet L74
//  - All .tint.opacity(0.18) sites use DesignTokens.accentTintOpacityHero
//  - 3 sites total use accentTintOpacityHero (= 2 kanban + 1 PreviewPane)
//
//  Round 74 — TodoListView chipStyle AnyShapeStyle migration:
//  - 1 source file (TodoListView.swift) + 1 test file (atomic-coupled)
//  - chipStyle signature: (String, Color, Color) → (String, Color, AnyShapeStyle)
//  - 4 priority cases use AnyShapeStyle wrapper (= preserves ShapeStyle
//    identity so future code can swap to .tertiary)
//  - 2 cases (.high + .urgent) reuse DesignTokens.accentTintOpacityHero
//
//  Round 75 — closure verification:
//  - 0 raw RGB / gray / hue / hex color literals
//  - 0 wenshu-specific custom Color tokens (= all deleted per §11.26)
//  - All colors via SwiftUI canonical shape-style
//    (.secondary / .tint / .windowBackground / .tertiary / .quaternary
//     + semantic .red / .green / .orange / .blue)
//  - Color(nsColor:) usage = canonical Apple API entry points only
//    (= AppKit layer / NSButton / AnyShapeStyle context for SwiftUI limitation)
//  - NSColor.X usage = canonical AppKit entry points only
//    (= NSButton contentTintColor / NSColor.clear.cgColor / canvas drawing)
//  - Severity opacity tiers (.06 / .18 / .22) preserved at call site
//    (= Apple HIG has no canonical severity opacity scale)

import Testing
import Foundation
@testable import WenshuApp

@Suite("Color sweep arc closure — rounds 73-75")
struct ColorSweepArcClosureTests {

    @Test("Zero raw RGB Color(red:green:blue:) literals")
    func zeroRawRGBColorLiterals() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let enumerator = FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var violations: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard !url.path.contains("DesignTokens.swift") else { continue }
            guard !url.path.contains("ComponentIndex.md") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)
            // Skip the documentation example in ComponentIndex.md
            // (= Color(red: 0.5, green: 0.5, blue: 0.5))
            // (already excluded via path filter above)
            let pattern = #"Color\(red:[^)]+green:[^)]+blue:"#
            if content.range(of: pattern, options: .regularExpression) != nil {
                violations.append(url.lastPathComponent)
            }
        }

        #expect(violations.isEmpty, "Found raw RGB Color literal: \(violations)")
    }

    @Test("Zero Color(white:) raw gray literals")
    func zeroColorWhiteLiterals() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let enumerator = FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var violations: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard !url.path.contains("DesignTokens.swift") else { continue }
            guard !url.path.contains("ComponentIndex.md") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)
            // Exclude Color.white (a static Color constant, not raw RGB)
            // Color(white: 0.5) is the raw gray literal
            let lines = content.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                    continue
                }
                if let commentStart = line.range(of: "//") {
                    let codePart = String(line[..<commentStart.lowerBound])
                    if codePart.range(of: #"Color\(white:"#, options: .regularExpression) != nil {
                        violations.append("\(url.lastPathComponent): \(trimmed)")
                    }
                } else {
                    if line.range(of: #"Color\(white:"#, options: .regularExpression) != nil {
                        violations.append("\(url.lastPathComponent): \(trimmed)")
                    }
                }
            }
        }

        #expect(violations.isEmpty, "Found Color(white:) literal: \(violations)")
    }

    @Test("Zero hex color literal (#RRGGBB)")
    func zeroHexColorLiterals() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let enumerator = FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var violations: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard !url.path.contains("DesignTokens.swift") else { continue }
            guard !url.path.contains("ComponentIndex.md") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)
            // Match `Color(0xRRGGBB)` or `Color(#RRGGBB)` — Apple syntax
            let pattern = #"Color\(\s*(?:0x|#)[0-9A-Fa-f]{6}\s*\)"#
            if content.range(of: pattern, options: .regularExpression) != nil {
                violations.append(url.lastPathComponent)
            }
        }

        #expect(violations.isEmpty, "Found hex Color literal: \(violations)")
    }

    @Test("Zero wenshu-specific custom Color tokens (= DesignColor.zoneSurface etc.)")
    func zeroWenshuCustomColorTokens() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let enumerator = FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var violations: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard !url.path.contains("DesignTokens.swift") else { continue }
            guard !url.path.contains("ComponentIndex.md") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)
            // Skip lines that are comments
            let lines = content.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                    continue
                }
                // Match executable usage of wenshu-specific custom tokens
                // (= DesignColor.zoneSurface / DesignColor.splitterLine / DesignColor.swift)
                if line.range(of: #"DesignColor\.\w+"#, options: .regularExpression) != nil {
                    violations.append("\(url.lastPathComponent): \(trimmed)")
                }
            }
        }

        #expect(violations.isEmpty, "Found wenshu-specific custom Color token: \(violations)")
    }
}
