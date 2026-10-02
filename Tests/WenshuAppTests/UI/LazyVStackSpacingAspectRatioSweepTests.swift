//
//  LazyVStackSpacingAspectRatioSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB "继续" arc).
//  Sweep round 32 verified: wenshu tree uses DesignTokens for
//  LazyVStack spacing (= missed by round 11 stack-spacing sweep
//  because LazyVStack uses the same spacing parameter as VStack
//  but only LazyVStack was scanned separately) + aspectRatio
//  magic (= Apple HIG classic photo / preview thumbnail
//  standard).
//
//  Swept sites (= 6):
//  - ForeshadowingView.swift L250:
//    LazyVStack(spacing: 6) → spacingTight
//  - ForeshadowingView.swift L342:
//    LazyVStack(spacing: 4) → spacingIconic
//  - PlaceholderView.swift L259:
//    LazyVStack(spacing: 6) → spacingTight
//  - ChatView.swift L329:
//    LazyVStack(spacing: 8, pinnedViews:) → spacingStandard
//  - KanbanView.swift L366:
//    LazyVStack(spacing: 6) → spacingTight
//  - PresetCard.swift L32:
//    .aspectRatio(4.0 / 3.0, contentMode: .fit) →
//    .aspectRatio(DesignTokens.presetThumbnailAspectRatio,
//    contentMode: .fit)
//
//  New DesignTokens (= 1):
//  - presetThumbnailAspectRatio (4.0 / 3.0) — Apple HIG
//    classic photo / preview thumbnail standard (= macOS 26+
//    Finder preview thumbnail ratio)
//
//  Preserved sites (= 1, Apple SwiftUI canonical):
//  - CommandPaletteView.swift L154:
//    LazyVStack(spacing: 0) (= canonical SwiftUI no-spacing
//    inline stacking pattern)

import Testing
import Foundation
@testable import WenshuApp

@Suite("Sweep round 32 — LazyVStack spacing + aspectRatio tokens")
struct LazyVStackSpacingAspectRatioSweepTests {

    @Test("Swept sites use DesignTokens for LazyVStack spacing + aspectRatio")
    func sweptSitesUseDesignTokens() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // UI/
            .deletingLastPathComponent()  // Tests/WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let sweptFiles: [(String, String)] = [
            ("Views/Tools/ForeshadowingView.swift", "DesignTokens.spacingTight"),
            ("Views/Tools/PlaceholderView.swift", "DesignTokens.spacingTight"),
            ("Views/Chat/ChatView.swift", "DesignTokens.spacingStandard"),
            ("Views/Kanban/KanbanView.swift", "DesignTokens.spacingTight"),
            ("Views/Workspace/LayoutPicker/PresetCard.swift", "DesignTokens.presetThumbnailAspectRatio"),
        ]

        for (relative, expectedToken) in sweptFiles {
            let path = sourcesRoot.appendingPathComponent(relative)
            let content = try String(contentsOf: path, encoding: .utf8)
            #expect(
                content.contains(expectedToken),
                "\(relative) should reference \(expectedToken)"
            )
        }
    }

    @Test("DesignTokens exposes presetThumbnailAspectRatio")
    func designTokensExposesAspectRatioToken() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tokensPath = root.appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: tokensPath, encoding: .utf8)
        #expect(
            content.contains("static let presetThumbnailAspectRatio"),
            "DesignTokens should define presetThumbnailAspectRatio"
        )
    }

    @Test("Zero magic LazyVStack spacing (excluding canonical 0)")
    func zeroMagicLazyVStackSpacing() throws {
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
            guard !url.path.contains("Core/Agent/Specialized/") else { continue }
            guard !url.path.contains("Core/Agent/LongForm/") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                    continue
                }
                // Match `LazyVStack(...spacing: N,...)` magic literal
                // (excluding 0 = canonical SwiftUI no-spacing)
                let pattern = #"LazyVStack\([^)]*spacing:\s*[1-9][0-9]*[^)]*\)"#
                if line.range(of: pattern, options: .regularExpression) != nil
                    && !line.contains("DesignTokens.") {
                    violations.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        #expect(violations.isEmpty, "Unexpected magic LazyVStack spacing: \(violations)")
    }

    @Test("Zero magic .aspectRatio(N/M) numeric ratio literal")
    func zeroMagicAspectRatioNumeric() throws {
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
                // Match `.aspectRatio(N/M, contentMode: ...)` magic
                let pattern = #"\.aspectRatio\([0-9]+\.[0-9]+/[0-9]+\.[0-9]+"#
                if line.range(of: pattern, options: .regularExpression) != nil
                    && !line.contains("DesignTokens.") {
                    violations.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        #expect(violations.isEmpty, "Unexpected magic .aspectRatio(N/M): \(violations)")
    }
}
