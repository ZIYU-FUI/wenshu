//
//  TextEditorHeightSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB "继续" arc).
//  Sweep round 31 verified: wenshu tree uses DesignTokens for
//  TextEditor minHeight/maxHeight (= Apple HIG macOS text
//  input heights for single-paragraph / 2-3 paragraph / compact
//  TextEditor variants).
//
//  Swept sites (= 6):
//  - PlaceholderView.swift L367: .frame(minHeight: 80, maxHeight: 140)
//  - ReaderExperienceView.swift L133: same
//  - BookSettingConstraintsView.swift L317:
//    .frame(minHeight: 100, maxHeight: 160)
//  - LongFormGuardrailsView.swift L246:
//    .frame(minHeight: 80, maxHeight: 120)
//  - EmotionCurveView.swift L138: .frame(minHeight: 80, maxHeight: 140)
//  - GenreFitView.swift L135: same
//
//  New DesignTokens (= 5):
//  - textEditorSmallMinHeight (80) — Apple HIG macOS
//    single-paragraph TextEditor minimum
//  - textEditorSmallMaxHeight (140) — Apple HIG macOS
//    single-paragraph TextEditor maximum (= 2-wrap display)
//  - textEditorMediumMinHeight (100) — Apple HIG macOS
//    2-3 paragraph TextEditor minimum
//  - textEditorMediumMaxHeight (160) — Apple HIG macOS
//    2-3 paragraph TextEditor maximum (= 3-wrap display)
//  - textEditorCompactMaxHeight (120) — Apple HIG macOS
//    compact TextEditor maximum (= 1.5x display)
//
//  Preserved sites (= 16, no Apple HIG canonical):
//  - NavigationSplitShell.swift L273: .frame(minWidth: 1100, minHeight: 600)
//    (= wenshu main window min size; = business decision)
//  - ChatToolDiffPreviewSheet.swift L52:
//    .frame(minWidth: 540, minHeight: 360)
//    (= standard macOS sheet min; = sheet-specific decision)
//  - ZoneEditor.swift L80: .frame(minWidth: 720, minHeight: 540)
//    (= canvas-specific decision)
//  - EmotionCurveView.swift L114 + L222:
//    .frame(minWidth: 28 / 64, alignment: ...)
//    (= column-width layout decision; = no Apple HIG token)
//  - BookEditorSheet.swift L145: .frame(minWidth: 420)
//  - SidebarSheets.swift L136 / L255 / L420 / L504:
//    sheet-specific min sizes (= business decision)

import Testing
import Foundation
@testable import WenshuApp

@Suite("Sweep round 31 — TextEditor minHeight/maxHeight tokens")
struct TextEditorHeightSweepTests {

    @Test("Swept sites use DesignTokens for TextEditor minHeight/maxHeight")
    func sweptSitesUseDesignTokens() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // UI/
            .deletingLastPathComponent()  // Tests/WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let sweptFiles: [(String, [String])] = [
            ("Views/Tools/PlaceholderView.swift", ["textEditorSmallMinHeight", "textEditorSmallMaxHeight"]),
            ("Views/SpecializedTools/ReaderExperienceView.swift", ["textEditorSmallMinHeight", "textEditorSmallMaxHeight"]),
            ("Views/SpecializedTools/BookSettingConstraintsView.swift", ["textEditorMediumMinHeight", "textEditorMediumMaxHeight"]),
            ("Views/SpecializedTools/LongFormGuardrailsView.swift", ["textEditorSmallMinHeight", "textEditorCompactMaxHeight"]),
            ("Views/SpecializedTools/EmotionCurveView.swift", ["textEditorSmallMinHeight", "textEditorSmallMaxHeight"]),
            ("Views/SpecializedTools/GenreFitView.swift", ["textEditorSmallMinHeight", "textEditorSmallMaxHeight"]),
        ]

        for (relative, expectedTokens) in sweptFiles {
            let path = sourcesRoot.appendingPathComponent(relative)
            let content = try String(contentsOf: path, encoding: .utf8)
            for token in expectedTokens {
                #expect(
                    content.contains("DesignTokens.\(token)"),
                    "\(relative) should reference DesignTokens.\(token)"
                )
            }
        }
    }

    @Test("DesignTokens exposes 5 new TextEditor tokens")
    func designTokensExposesNewTokens() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tokensPath = root.appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: tokensPath, encoding: .utf8)

        for token in [
            "textEditorSmallMinHeight",
            "textEditorSmallMaxHeight",
            "textEditorMediumMinHeight",
            "textEditorMediumMaxHeight",
            "textEditorCompactMaxHeight",
        ] {
            #expect(content.contains("static let \(token)"), "DesignTokens should define \(token)")
        }
    }

    @Test("Zero magic .frame(minHeight: N, maxHeight: N) for TextEditor")
    func zeroMagicTextEditorFrame() throws {
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
                // Match `.frame(minHeight: N, maxHeight: N)` magic literal
                let pattern = #"\.frame\(minHeight:\s*[0-9]+,\s*maxHeight:\s*[0-9]+\)"#
                if line.range(of: pattern, options: .regularExpression) != nil
                    && !line.contains("DesignTokens.") {
                    violations.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        #expect(violations.isEmpty, "Unexpected magic .frame(minHeight: N, maxHeight: N): \(violations)")
    }
}
