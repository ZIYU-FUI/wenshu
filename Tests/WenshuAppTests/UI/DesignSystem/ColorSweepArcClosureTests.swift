//
//  ColorSweepArcClosureTests.swift · Wenshu
//
//  Where a color may come from. This suite allows three sources and no
//  others: a SwiftUI semantic style (`.secondary`, `.tint`,
//  `.windowBackground`, `.tertiary`, `.quaternary`), a system semantic
//  color (`.red`, `.green`, `.orange`, `.blue`), or an AppKit color that
//  SwiftUI cannot reach any other way — `Color(nsColor:)` behind an
//  NSButton, a `cgColor` for a canvas, an `AnyShapeStyle` where a
//  hierarchical style has no opacity overload.
//
//  A raw RGB, gray, hue or hex literal is none of those, and it fails
//  here.

import Testing
import SwiftUI
import AppKit
import Foundation
@testable import WenshuApp

@Suite("Color sweep arc closure")
struct ColorSweepArcClosureTests {

    @Test("Zero raw RGB Color(red:green:blue:) literals")
    func zeroRawRGBColorLiterals() throws {
        let root = SourceLocator.repoRoot
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
        let root = SourceLocator.repoRoot
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
        let root = SourceLocator.repoRoot
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
        let root = SourceLocator.repoRoot
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
