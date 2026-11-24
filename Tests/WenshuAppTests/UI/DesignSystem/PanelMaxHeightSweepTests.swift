//
//  PanelMaxHeightSweepTests.swift · Wenshu
//
//  A panel that scrolls inside a fixed band states the band as a token:
//  `panelInlineMaxHeight`, `panelMediumMaxHeight`, `panelLargeMaxHeight`,
//  `kanbanBoardMaxHeight`. Each figure is the height of the row count the
//  panel shows, which is why a site may not invent one: a taller band
//  silently promises rows that are not there, and a shorter one clips
//  content behind a scroll that looks like a bug.
//
//  A site that wants the height of the text editor's band asks for the
//  text editor's token, not a new number that happens to match.
import Testing
import Foundation
@testable import WenshuApp

@Suite("Panel maxHeight tokens")
struct PanelMaxHeightSweepTests {

    @Test("Swept sites use DesignTokens for maxHeight")
    func sweptSitesUseDesignTokens() throws {
        let root = SourceLocator.repoRoot
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let sweptFiles: [(String, String)] = [
            ("Features/Agent/View/ImportSheetHelpers.swift", "DesignTokens.kanbanBoardMaxHeight"),
            ("Features/Library/View/SidebarSheets.swift", "DesignTokens.panelLargeMaxHeight"),
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

    @Test("DesignTokens exposes 4 new panel maxHeight tokens")
    func designTokensExposesNewTokens() throws {
        let root = SourceLocator.repoRoot
        let tokensPath = root.appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: tokensPath, encoding: .utf8)

        for token in [
            "panelMediumMaxHeight",
            "panelLargeMaxHeight",
            "panelInlineMaxHeight",
            "kanbanBoardMaxHeight",
        ] {
            #expect(content.contains("static let \(token)"), "DesignTokens should define \(token)")
        }
    }

    @Test("Zero magic .frame(maxHeight: N) literal in source tree")
    func zeroMagicFrameMaxHeight() throws {
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
                // Match `.frame(maxHeight: N)` magic literal (NOT
                // preceded by DesignTokens.)
                let pattern = #"\.frame\(maxHeight:\s*[0-9]+\)"#
                if line.range(of: pattern, options: .regularExpression) != nil
                    && !line.contains("DesignTokens.") {
                    violations.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        #expect(violations.isEmpty, "Unexpected magic .frame(maxHeight: N): \(violations)")
    }
}
