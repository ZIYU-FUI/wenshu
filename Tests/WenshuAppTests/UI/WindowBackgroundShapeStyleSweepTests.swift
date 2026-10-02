//
//  WindowBackgroundShapeStyleSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB "继续" arc).
//  Sweep round 27 verified: wenshu tree uses SwiftUI built-in
//  `.windowBackground` shape-style (= macOS 13+ native) instead
//  of `Color(nsColor: .windowBackgroundColor)` magic literal,
//  except where the AnyShapeStyle + .opacity combination
//  requires the NSColor-backed Color (= Apple SwiftUI limit:
//  HierarchicalShapeStyle.windowBackground has no .opacity
//  overload, so AnyShapeStyle(.windowBackground.opacity(N))
//  fails to type-resolve).
//
//  Swept sites (= 5):
//  - Sources/WenshuApp/Views/CommandPalette/CommandPaletteView.swift
//    L189 (.background { Color.windowBackground } → .background(.windowBackground))
//  - Sources/WenshuApp/Views/Workspace/LayoutPicker/ZoneEditor.swift
//    L96 (.background { Color.windowBackground } → .background(.windowBackground))
//  - Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsView.swift
//    L371 (.background { Color.windowBackground } → .background(.windowBackground))
//  - Sources/WenshuApp/Views/Library/BookEditorSheet.swift
//    L152 (.background { Color.windowBackground } → .background(.windowBackground))
//  - Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift
//    L144 (.containerBackground { Color.windowBackground }
//       → .containerBackground(.windowBackground, for: .window))
//
//  Preserved sites (= 2, Apple SwiftUI limitation):
//  - Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift
//    L163 AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.12))
//  - Sources/WenshuApp/Views/Chat/ChatToolResultPartView.swift
//    L234 AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.12))
//  (= HierarchicalShapeStyle.windowBackground.opacity(N) fails
//   Swift type-check; = Apple SwiftUI idiom requires Color +
//   NSColor.windowBackgroundColor literal in AnyShapeStyle context)

import Testing
import Foundation
@testable import WenshuApp

@Suite("Sweep round 27 — .windowBackground shape-style sweep")
struct WindowBackgroundShapeStyleSweepTests {

    @Test("Swept sites use SwiftUI native .windowBackground shape-style")
    func sweptSitesUseSwiftUINativeShapeStyle() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // UI/
            .deletingLastPathComponent()  // Tests/WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let sweptFiles = [
            "Views/CommandPalette/CommandPaletteView.swift",
            "Views/Workspace/LayoutPicker/ZoneEditor.swift",
            "Views/SpecializedTools/LongFormGuardrailsView.swift",
            "Views/Library/BookEditorSheet.swift",
            "Views/Onboarding/LibraryRootView.swift",
        ]

        for relative in sweptFiles {
            let path = sourcesRoot.appendingPathComponent(relative)
            let content = try String(contentsOf: path, encoding: .utf8)
            // Sweep target: file uses either `.background(.windowBackground)`
            // or `.containerBackground(.windowBackground, for: .window)`
            #expect(
                content.contains(".background(.windowBackground)")
                    || content.contains(".containerBackground(.windowBackground, for: .window)"),
                "\(relative) should use SwiftUI .windowBackground shape-style"
            )
            // No leftover `Color.windowBackground` in .background closure
            #expect(
                !content.contains(".background { Color.windowBackground }"),
                "\(relative) should not contain legacy .background { Color.windowBackground }"
            )
        }
    }

    @Test("AnyShapeStyle sites preserve Color(nsColor: .windowBackgroundColor).opacity(N) (= Apple SwiftUI limitation)")
    func preservedAnyShapeStyleSitesUseColorOpacity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let preservedFiles = [
            "Views/Chat/ChatToolUsePartView.swift",
            "Views/Chat/ChatToolResultPartView.swift",
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
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

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
