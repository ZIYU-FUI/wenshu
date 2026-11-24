//
//  LazyVStackSpacingAspectRatioSweepTests.swift · Wenshu
//
//  `LazyVStack` takes the same spacing parameter as `VStack` and has to be
//  scanned on its own, because a lazy stack is the one a long list builds
//  row by row and its spacing is the figure a reader would otherwise
//  re-type per row. Its spacing comes from the spacing tokens; a
//  thumbnail's aspect ratio comes from
//  `DesignTokens.presetThumbnailAspectRatio`, Apple's preview-thumbnail
//  ratio.
//
//  `LazyVStack(spacing: 0)` is the canonical no-gap stack and stays a
//  literal.
import Testing
import Foundation
@testable import WenshuApp

@Suite("LazyVStack spacing + aspectRatio tokens")
struct LazyVStackSpacingAspectRatioSweepTests {

    @Test("Swept sites use DesignTokens for LazyVStack spacing + aspectRatio")
    func sweptSitesUseDesignTokens() throws {
        let root = SourceLocator.repoRoot
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let sweptFiles: [(String, String)] = [
            ("Features/Chat/View/ChatView.swift", "DesignTokens.spacingStandard"),
            ("Features/Kanban/View/KanbanView.swift", "DesignTokens.spacingTight"),
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
        let root = SourceLocator.repoRoot
        let tokensPath = root.appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: tokensPath, encoding: .utf8)
        #expect(
            content.contains("static let presetThumbnailAspectRatio"),
            "DesignTokens should define presetThumbnailAspectRatio"
        )
    }

    @Test("Zero magic LazyVStack spacing (excluding canonical 0)")
    func zeroMagicLazyVStackSpacing() throws {
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
