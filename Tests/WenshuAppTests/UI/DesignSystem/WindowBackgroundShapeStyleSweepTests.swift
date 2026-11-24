//
//  WindowBackgroundShapeStyleSweepTests.swift · Wenshu
//
//  A window's background is SwiftUI's own `.windowBackground` style, not
//  `Color(nsColor: .windowBackgroundColor)`. The style follows the window,
//  whatever sits behind it and whatever the system decides next; the
//  AppKit color is a snapshot of one appearance.
//
//  One case keeps the AppKit-backed form, and the suite allows exactly
//  that and nothing else: `.windowBackground` is a hierarchical style with
//  no `.opacity`, so an `AnyShapeStyle` wash of the window color has to be
//  built from `Color`. That the shorthand fails to type-check is part of
//  what the third test pins.
import Testing
import SwiftUI
import AppKit
import Foundation
@testable import WenshuApp

@Suite(".windowBackground shape-style sweep")
struct WindowBackgroundShapeStyleSweepTests {

    @Test("AnyShapeStyle sites preserve Color(nsColor: .windowBackgroundColor).opacity(N) (= Apple SwiftUI limitation)")
    func preservedAnyShapeStyleSitesUseColorOpacity() throws {
        let sourcesRoot = SourceLocator.url("Sources/WenshuApp")

        let preservedFiles = [
            "Features/Chat/View/ChatToolUsePartView.swift",
            "Features/Chat/View/ChatToolResultPartView.swift",
        ]

        for relative in preservedFiles {
            let path = sourcesRoot.appendingPathComponent(relative)
            let content = try String(contentsOf: path, encoding: .utf8)
            // Preserve: AnyShapeStyle + Color + NSColor.windowBackgroundColor + opacity
            // (= Apple SwiftUI limit: HierarchicalShapeStyle.windowBackground.opacity(N)
            //  fails type-check; = Color(nsColor: .windowBackgroundColor) is the
            //  canonical workaround)
            #expect(
                content.contains("AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.12))"),
                "\(relative) should preserve AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.12)) for Apple SwiftUI limitation"
            )
        }
    }

    @Test("Zero magic Color(nsColor: .windowBackgroundColor) outside AnyShapeStyle")
    func zeroMagicColorNsColorWindowBackground() throws {
        let sourcesRoot = SourceLocator.url("Sources/WenshuApp")

        // Use file manager to recursively collect all .swift files
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
                if line.contains("Color(nsColor: .windowBackgroundColor)")
                    && !line.contains("AnyShapeStyle(") {
                    violations.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        #expect(violations.isEmpty, "Unexpected Color(nsColor: .windowBackgroundColor) outside AnyShapeStyle: \(violations)")
    }
}
