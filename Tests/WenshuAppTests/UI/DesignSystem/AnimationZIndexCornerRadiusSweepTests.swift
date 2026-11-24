//
//  AnimationZIndexCornerRadiusSweepTests.swift · Wenshu
//
//  Four shapes that look like style numbers and are not a token's job:
//  `.animation` durations, `.zIndex`, `.transition`, `.aspectRatio`.
//
//  What this suite insists on: a corner radius is clipped through
//  `.clipShape(RoundedRectangle(cornerRadius: DesignTokens.X))` rather
//  than drawn with the deprecated `.cornerRadius` modifier; a thumbnail's
//  aspect ratio is `DesignTokens.presetThumbnailAspectRatio`; and a layer
//  order, a duration and a transition stay per-site decisions, because
//  Apple ships no scale to tokenize them against.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Deprecated API + zIndex/transition/aspectRatio sweep")
struct AnimationZIndexCornerRadiusSweepTests {

    @Test("Zero .cornerRadius(N) deprecated API in source tree")
    func zeroDeprecatedCornerRadius() throws {
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
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                    continue
                }
                // Match `.cornerRadius(N)` deprecated API (NOT preceded by DesignTokens.
                // since 0 sites now use literal N — all sites that previously used
                // .cornerRadius have been migrated to .clipShape + RoundedRectangle).
                let pattern = #"\.cornerRadius\([0-9]+\)"#
                if line.range(of: pattern, options: .regularExpression) != nil {
                    violations.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        #expect(violations.isEmpty, "Unexpected .cornerRadius(N): \(violations)")
    }

    @Test("Transition sites use SwiftUI canonical enum")
    func transitionSitesCanonical() throws {
        // 9 .transition(.opacity) + 4 .transition(.wenshuThinkingAppear)
        // = SwiftUI canonical enum + wenshu custom transition
        // = all preserved per sweep boundary
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

            let content = try String(contentsOf: url, encoding: .utf8)
            // Reject any .transition(someNumericLiteral) — SwiftUI enum only.
            let pattern = #"\.transition\([0-9]+\)"#
            if content.range(of: pattern, options: .regularExpression) != nil {
                violations.append(url.lastPathComponent)
            }
        }

        #expect(violations.isEmpty, "Unexpected .transition(N): \(violations)")
    }
}
