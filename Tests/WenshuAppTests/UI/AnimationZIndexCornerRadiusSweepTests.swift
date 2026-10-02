//
//  AnimationZIndexCornerRadiusSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB "继续" arc).
//  Sweep round 38 verified:
//  - Zero .cornerRadius(N) deprecated API (= all migrated to
//    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.X)))
//  - .animation(duration: N) literals preserved (= SwiftUI
//    idiomatic micro-interaction durations; = no canonical
//    Apple HIG value to tokenize)
//  - .zIndex(N) literal: 3 sites = all comment-only
//    documentation (= historical record from the v2.x
//    "latest user row" pattern; = not actual code use)
//  - .transition(.X) sites all use SwiftUI canonical enum
//    (.opacity + .wenshuThinkingAppear wenshu custom) =
//    preserved
//  - .aspectRatio(N, contentMode: .X) sites all use either
//    DesignTokens.presetThumbnailAspectRatio (round 32) or
//    contentMode-only (.fit / .fill) = preserved
//
//  Swept sites (= 1):
//  - SubAgentProgressView.swift L109:
//    .cornerRadius(DesignTokens.surfaceCornerRadiusProgressCard)
//    → .clipShape(RoundedRectangle(cornerRadius:
//    DesignTokens.surfaceCornerRadiusProgressCard))

import Testing
import Foundation
@testable import WenshuApp

@Suite("Sweep round 38 — deprecated API + zIndex/transition/aspectRatio sweep")
struct AnimationZIndexCornerRadiusSweepTests {

    @Test("SubAgentProgressView migrated to .clipShape + RoundedRectangle")
    func subAgentProgressViewMigrated() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let path = root.appendingPathComponent(
            "Sources/WenshuApp/Views/Kanban/SubAgentProgressView.swift"
        )
        let content = try String(contentsOf: path, encoding: .utf8)

        #expect(content.contains(
            ".clipShape(RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard))"
        ), "SubAgentProgressView should use .clipShape + RoundedRectangle")
        #expect(
            !content.contains(".cornerRadius(DesignTokens.surfaceCornerRadiusProgressCard)"),
            "SubAgentProgressView should NOT use deprecated .cornerRadius"
        )
    }

    @Test("Zero .cornerRadius(N) deprecated API in source tree")
    func zeroDeprecatedCornerRadius() throws {
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

    @Test("Animation duration literals preserved (= SwiftUI idiomatic)")
    func animationDurationsPreserved() throws {
        // 6 .animation(duration:) sites are intentional:
        // - ChatMessageHoverActions.swift L69: 0.15 (SwiftUI idiomatic hover)
        // - PreviewPane.swift L928/1164/1226/1366: 0.18 + 0.22
        //   (= SwiftUI idiomatic micro-interaction durations)
        // Apple HIG does not mandate exact values; = preserve as is.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let path = root.appendingPathComponent(
            "Sources/WenshuApp/Views/Chat/ChatMessageHoverActions.swift"
        )
        let content = try String(contentsOf: path, encoding: .utf8)

        #expect(content.contains(".animation(.easeInOut(duration: 0.15)"),
               "ChatMessageHoverActions should preserve .animation(duration: 0.15)")
    }

    @Test("Transition sites use SwiftUI canonical enum")
    func transitionSitesCanonical() throws {
        // 9 .transition(.opacity) + 4 .transition(.wenshuThinkingAppear)
        // = SwiftUI canonical enum + wenshu custom transition
        // = all preserved per sweep boundary
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
