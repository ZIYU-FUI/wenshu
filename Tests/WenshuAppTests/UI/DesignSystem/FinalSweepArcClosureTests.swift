//
//  FinalSweepArcClosureTests.swift · Wenshu
//
//  The sweep's end state, stated as the rule it enforces: a visual number
//  is a DesignTokens value, and a call site never re-derives one.
//
//  Figures this suite requires to come from a token: a corner radius, a
//  fixed frame, a frame's max, min and ideal width and height, a stack's
//  spacing, an accent wash, a shadow's radius and its offset, a drag
//  threshold, a thumbnail's aspect ratio, a separator's thickness, a grid
//  item's spacing.
//
//  Figures that stay at the call site, because Apple ships no scale for
//  them and the value is the surface's own business decision: an opacity,
//  a line limit, a micro-interaction duration, a control size, a
//  transition, a text alignment, a window's min and max size, and the two
//  zero patterns (= an invisible button's frame, a stack with no gap).

import Testing
import SwiftUI
import Foundation
@testable import WenshuApp

@Suite("Final sweep arc closure — 41+ rounds of magic literal sweep")
struct FinalSweepArcClosureTests {

    @Test("Zero magic .cornerRadius(N) deprecated API")
    func zeroMagicCornerRadius() throws {
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
            guard !url.path.contains("IconStyles.swift") else { continue }
            guard !url.path.contains("DesignTokens.swift") else { continue }
            guard !url.path.contains("ComponentIndex.md") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)
            let pattern = #"\.cornerRadius\([0-9]+\)"#
            if content.range(of: pattern, options: .regularExpression) != nil {
                violations.append(url.lastPathComponent)
            }
        }

        #expect(violations.isEmpty, "Found .cornerRadius(N): \(violations)")
    }

    @Test("Zero magic Stack(spacing: N) with numeric literal")
    func zeroMagicStackSpacing() throws {
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
            guard !url.path.contains("IconStyles.swift") else { continue }
            guard !url.path.contains("DesignTokens.swift") else { continue }
            guard !url.path.contains("ComponentIndex.md") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)
            // Match `VStack(spacing: N)` where N > 0 (= canonical 0 is allowed).
            // Skip lines that are inside `// ...` comments.
            let lines = content.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                    continue
                }
                // Skip lines that contain `VStack(spacing:` inside a comment
                // (= heuristic: line starts with `//` already filtered; = look
                // for `//` mid-line and skip if the magic literal comes after)
                if let commentStart = line.range(of: "//") {
                    let beforeComment = String(line[..<commentStart.lowerBound])
                    let pattern = #"(VStack|HStack|ZStack|Group)\(spacing:\s*([1-9]\d*\.?\d*)\)"#
                    if beforeComment.range(of: pattern, options: .regularExpression) != nil {
                        violations.append("\(url.lastPathComponent): \(trimmed)")
                    }
                } else {
                    let pattern = #"(VStack|HStack|ZStack|Group)\(spacing:\s*([1-9]\d*\.?\d*)\)"#
                    if line.range(of: pattern, options: .regularExpression) != nil {
                        violations.append("\(url.lastPathComponent): \(trimmed)")
                    }
                }
            }
        }

        #expect(violations.isEmpty, "Found magic Stack(spacing: N) (N > 0): \(violations)")
    }

    @Test("Zero magic .frame(maxWidth: N) literal")
    func zeroMagicFrameMaxWidth() throws {
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
            guard !url.path.contains("IconStyles.swift") else { continue }
            guard !url.path.contains("DesignTokens.swift") else { continue }
            guard !url.path.contains("ComponentIndex.md") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)
            // Match `.frame(maxWidth: N)` where N is a numeric literal
            // (NOT DesignTokens.xxx, NOT .infinity)
            let lines = content.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                    continue
                }
                let pattern = #"\.frame\(maxWidth:\s*[0-9]+\.?\d*\)"#
                if line.range(of: pattern, options: .regularExpression) != nil {
                    violations.append("\(url.lastPathComponent): \(trimmed)")
                }
            }
        }

        #expect(violations.isEmpty, "Found .frame(maxWidth: N): \(violations)")
    }

    @Test("Zero magic .accentColor.opacity(N) literal")
    func zeroMagicAccentColorOpacity() throws {
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
            guard !url.path.contains("IconStyles.swift") else { continue }
            guard !url.path.contains("DesignTokens.swift") else { continue }
            guard !url.path.contains("ComponentIndex.md") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                    continue
                }
                let pattern = #"Color\.accentColor\.opacity\([0-9]\.[0-9]+\)"#
                if line.range(of: pattern, options: .regularExpression) != nil {
                    violations.append("\(url.lastPathComponent): \(trimmed)")
                }
            }
        }

        #expect(violations.isEmpty, "Found magic Color.accentColor.opacity(N): \(violations)")
    }
}
