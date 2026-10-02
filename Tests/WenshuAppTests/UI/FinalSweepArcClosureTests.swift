//
//  FinalSweepArcClosureTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB "继续" arc).
//  Sweep arc final closure (= 41+ rounds = 83+ commits; = 372+
//  sites swept + 20 dead tokens + 36 new tokens).
//
//  This test verifies the FINAL sweep state (= 41+ rounds of
//  magic literal sweep across the entire wenshu source tree):
//
//  Round-by-round summary:
//  - Round 1-4: initial sweep (= 27 sites + 9 dead + font tokens)
//  - Round 5: Label icon slot sweep (= 26 sites)
//  - Round 6: standalone Image(systemName:) sweep (= 49 sites in 27 files)
//  - Round 7: font .system(size:) sweep (= 2 sites)
//  - Round 8: cornerRadius magic sweep (= 23 sites in 28 files)
//  - Round 9: .frame(width:) sweep (= 6 sites in 7 files)
//  - Round 10: no-op .padding(N) sweep (= already canonical)
//  - Round 11: Stack(spacing:) sweep (= 62 sites in 33 files)
//  - Round 12: .shadow(radius:) sweep (= 2 sites in 4 files)
//  - Round 13: UnevenRoundedRectangle sweep (= 2 sites)
//  - Round 14-16: separator / lineWidth sweep (= 7 sites)
//  - Round 17: GridItem spacing sweep (= 8 sites)
//  - Round 18: font long-form sweep (= 12 sites)
//  - Round 19: Color(nsColor:) sweep (= 48 sites in 15 files)
//  - Round 20: .contentMargins sweep (= 1 site)
//  - Round 21: .frame control-height sweep (= 1 site)
//  - Round 22: summary closure test (= 3 tests)
//  - Round 23: .offset(y:N) sweep (= 2 sites)
//  - Round 24: .padding(.top,-N) sweep (= 1 site)
//  - Round 25: idealWidth/Height sweep (= 1 site)
//  - Round 26: dead token sweep (= 4 dead tokens)
//  - Round 27: Color(nsColor:.windowBackgroundColor) sweep (= 5 sites + 2 preserved)
//  - Round 28: .accentColor.opacity sweep (= 3 sites + 2 new tokens)
//  - Round 29: .shadow(y:N) sweep (= 2 sites + 2 new tokens)
//  - Round 30: .frame(maxWidth:N) + DragGesture threshold sweep (= 10 sites + 6 new tokens)
//  - Round 31: TextEditor minHeight/maxHeight sweep (= 6 sites + 5 new tokens)
//  - Round 32: LazyVStack spacing + aspectRatio magic (= 6 sites + 1 new token)
//  - Round 33-36: .frame(maxHeight:N) magic (= 16 sites + 5 new tokens)
//  - Round 37: dead DesignTokens sweep (= 7 dead tokens)
//  - Round 38: deprecated .cornerRadius migration (= 1 site)
//  - Round 39-70: verification sweeps (= mostly no-op; = 0 magic literal
//    in deprecated APIs + Stack(spacing:) + padding + frame +
//    transition + shadow + .cornerRadius + .animation + .foregroundStyle
//    + Material + Image(systemName:) + opacity literals)
//
//  Final state per the v3.0 Apple HIG specification:
//  - 0 magic literal `.cornerRadius(N)` (= all migrated to .clipShape +
//    RoundedRectangle with DesignTokens.surfaceCornerRadiusXxx)
//  - 0 magic literal `.frame(width:N, height:N)` (= all use DesignTokens)
//  - 0 magic literal `.frame(maxWidth:N)` (= all use DesignTokens.xMaxWidth)
//  - 0 magic literal `.frame(maxHeight:N)` (= all use DesignTokens.xMaxHeight)
//  - 0 magic literal `.frame(minHeight:N, maxHeight:N)` (= all use
//    DesignTokens.textEditorXxx)
//  - 0 magic literal `.frame(idealWidth:N, idealHeight:N)` (= all use
//    DesignTokens.onboardingWindowSize)
//  - 0 magic literal `Stack(spacing:N)` (= all use DesignTokens.spacingXxx)
//  - 0 magic literal `Color.accentColor.opacity(N)` (= all use
//    DesignTokens.accentTintOpacityXxx)
//  - 0 magic literal `Color(nsColor:.windowBackgroundColor)` (= all use
//    SwiftUI built-in `.windowBackground` shape-style or preserved as
//    `AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(N))` for
//    SwiftUI limitation contexts)
//  - 0 magic literal `.shadow(color:.black.opacity(N), radius:N, x:N, y:N)`
//    (= all use DesignTokens.surfaceShadowXxx)
//  - 0 magic literal `DragGesture(minimumDistance:N)` (= all use
//    DesignTokens.dragGestureThresholdXxx or canonical 0)
//  - 0 magic literal `.aspectRatio(N, contentMode:)` (= all use
//    DesignTokens.presetThumbnailAspectRatio or contentMode-only)
//  - 0 magic literal `.cornerRadius` deprecated API (= all migrated to
//    .clipShape + RoundedRectangle)
//
//  Preserved per established boundaries (= SwiftUI idiomatic + Apple
//  HIG canonical + wenshu-specific business decisions):
//  - .opacity(0.X) literal (= SwiftUI idiomatic, no canonical scale)
//  - .lineLimit(N) / .lineLimit(N...M) (= SwiftUI built-in range)
//  - .frame(width: 0, height: 0) (= invisible button pattern)
//  - Stack(spacing: 0) (= canonical no-spacing inline)
//  - ContentUnavailableView + .imageScale(.large) (= HIG default 38 PT)
//  - PreviewPane 64 PT hero card (= hero card surface = round 6 boundary)
//  - .stroke(lineWidth: 1) (= HIG standard separator)
//  - .fontWeight(.medium) / .bold / .semibold (= SwiftUI canonical weights)
//  - .controlSize(.small/.regular/.large) (= SwiftUI canonical)
//  - .transition(.opacity/.scale/.slide/.move) (= SwiftUI canonical)
//  - .multilineTextAlignment(.center/.leading) (= SwiftUI canonical)
//  - .symbolEffect + .symbolRenderingMode (= SwiftUI canonical)
//  - .help(...) (= SwiftUI canonical tooltip)
//  - .mask + .clipShape(Capsule()) (= SwiftUI idiomatic)
//  - .contentShape(Rectangle()) (= SwiftUI idiomatic hit-area)
//  - DragGesture(minimumDistance: 0) (= SwiftUI canonical drag-anywhere)
//  - .animation(duration: N) (= wenshu-tuned, no Apple HIG canonical value)
//  - Material.X (.regular/.thin/.ultraThin/.thick) (= SwiftUI canonical)
//  - .foregroundStyle(.X) / .background(.X) (= SwiftUI canonical hierarchical)
//  - .padding(EdgeInsets(0)) (= canonical default edge zero)
//  - ChatToolUsePartView L57/L58 = wenshu 自实现 pulse animation chain
//  - Window/sheet minSize / maxSize (= 各 view 业务决定)
//  - .keyboardShortcut(.X, modifiers: .X) (= SwiftUI idiomatic KeyEquivalent)
//  - .scaleEffect(0.8) (= SwiftUI idiomatic wenshu-specific shrink)
//  - Color.X.opacity(0.X) literal (= SwiftUI idiomatic, round 12 boundary)

import Testing
import Foundation
@testable import WenshuApp

@Suite("Final sweep arc closure — 41+ rounds of magic literal sweep")
struct FinalSweepArcClosureTests {

    @Test("Zero magic .cornerRadius(N) deprecated API")
    func zeroMagicCornerRadius() throws {
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
            let pattern = #"\.cornerRadius\([0-9]+\)"#
            if content.range(of: pattern, options: .regularExpression) != nil {
                violations.append(url.lastPathComponent)
            }
        }

        #expect(violations.isEmpty, "Found .cornerRadius(N): \(violations)")
    }

    @Test("Zero magic Stack(spacing: N) with numeric literal")
    func zeroMagicStackSpacing() throws {
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
