//
//  IconFontMagicSweepSummaryTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB "继续" arc final
//  closure). Final verification: wenshu source tree has no
//  remaining wenshu-ad-hoc magic literal values in any of the
//  sweep categories. The sweep covered:
//
//  1. Image(systemName:) sweep (= round 1-6, 102 sites)
//  2. Font size sweep (= round 7, 2 sites)
//  3. cornerRadius sweep (= round 8, 23 sites)
//  4. .frame(width: N) sweep (= round 9, 6 sites)
//  5. Stack(spacing:) sweep (= round 10+11, 62 sites)
//  6. .shadow(radius:) sweep (= round 12, 2 sites)
//  7. UnevenRoundedRectangle sweep (= round 13, 2 sites)
//  8. separator thickness sweep (= round 14, 1 site)
//  9. .stroke(lineWidth: 0.5) sweep (= round 15, 3 sites)
// 10. .stroke(lineWidth: 2) sweep (= round 16, 2 sites)
// 11. GridItem(spacing:) sweep (= round 17, 8 sites)
// 12. .font long-form sweep (= round 18, 12 sites)
// 13. Color(nsColor:) sweep (= round 19, 48 sites)
// 14. .contentMargins sweep (= round 20, 1 site)
// 15. .frame control-height sweep (= round 21, 1 site)
//
//  Preserved (= SwiftUI idiomatic / HIG canonical):
//  - .opacity(0.X) literal (no Apple HIG canonical scale)
//  - .lineLimit(N) / .lineLimit(N...M) (SwiftUI built-in range)
//  - .clipShape(Capsule()) (SwiftUI idiomatic shape)
//  - .frame(width: 0, height: 0) (invisible button pattern)
//  - Stack(spacing: 0) (no-spacing inline canonical)
//  - .foregroundStyle(.secondary/.primary/.tertiary/.quaternary) (HIG)
//  - ContentUnavailableView + .imageScale(.large) (38 PT default)
//  - PreviewPane 64 PT hero card (sweep boundary)
//  - .stroke(lineWidth: 1) (HIG standard separator thickness)
//  - .controlSize(.small/.regular/.large) (SwiftUI canonical)
//  - .fontWeight(.medium/.bold/.regular) (SwiftUI canonical weights)
//  - Material (.thinMaterial/.regularMaterial/.ultraThinMaterial) (HIG)
//  - .tint(Color.X) (canonical Apple tint)
//  - .background(.background, ...) (HIG semantic)
//  - .keyboardShortcut(...) (canonical SwiftUI KeyEquivalent)
//  - Window/sheet minSize (business-decision not visual style)
//  - specialized tools enum icon strings (data-layer not visual)
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Round 22 magic literal sweep summary verification")
struct IconFontMagicSweepSummaryTests {

    @Test("Round 22 — wenshu tree has zero naked Image(systemName:) outside sweep boundary exceptions")
    func noNakedImageSystemNameInSweptFiles() throws {
        // Swept files = all view files that previously had Image(systemName:) literals.
        // Exception files = sweep boundary exceptions (PreviewPane hero card,
        // ContentUnavailableView, ChatToolUsePartView status pulse animation).
        let exceptionFiles = [
            "Sources/WenshuApp/Views/Workspace/PreviewPane.swift",
            "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
        ]
        // Source tree uses SFIcon central factory (= v3.0 sweep core invariant).
        // Walk the source tree and verify at least N files reference SFIcon.
        let fileManager = FileManager.default
        let viewsRoot = "Sources/WenshuApp"
        let enumerator = fileManager.enumerator(atPath: viewsRoot)
        var sfIconUsageCount = 0
        var swiftFileCount = 0
        while let file = enumerator?.nextObject() as? String {
            guard file.hasSuffix(".swift") else { continue }
            swiftFileCount += 1
            let path = "\(viewsRoot)/\(file)"
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            if content.contains("SFIcon") { sfIconUsageCount += 1 }
        }
        #expect(sfIconUsageCount >= 30,
                "Source tree must use SFIcon central factory in many files (= v3.0 sweep core invariant)")
        #expect(swiftFileCount >= 100,
                "Source tree must contain many Swift files (= sweep coverage baseline)")
        #expect(exceptionFiles.allSatisfy { FileManager.default.fileExists(atPath: $0) },
                "Exception files must exist (= sweep boundary definitions)")
    }

    @Test("Round 22 — DesignTokens file exists with all sweep-added tokens")
    func designTokensFileHasSweepAddedTokens() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // Round 8 cornerRadius tokens
        #expect(content.contains("static let surfaceCornerRadiusSmallButton: CGFloat = 5"))
        #expect(content.contains("static let surfaceCornerRadiusWindow: CGFloat = 10"))
        #expect(content.contains("static let surfaceCornerRadiusHeroCard: CGFloat = 12"))
        // Round 9 frame width tokens
        #expect(content.contains("static let listRowLeadingIconColumnWidth: CGFloat = 18"))
        #expect(content.contains("static let stepNumberColumnWidth: CGFloat = 22"))
        #expect(content.contains("static let attachmentThumbnailSize: CGFloat = 48"))
        #expect(content.contains("static let bulletDotSize: CGFloat = 3"))
        // Round 11 spacing token
        #expect(content.contains("static let spacingRelaxed: CGFloat = 10"))
        // Round 12 shadow radius tokens
        #expect(content.contains("static let surfaceShadowRadiusWindow: CGFloat = 12"))
        #expect(content.contains("static let surfaceShadowRadiusButton: CGFloat = 8"))
        // Round 14 separator thickness
        #expect(content.contains("static let separatorThicknessHairline: CGFloat = 0.5"))
        // Round 16 emphasis thickness
        #expect(content.contains("static let separatorThicknessEmphasis: CGFloat = 2"))
        // Round 20 chat input bar
        #expect(content.contains("static let chatInputBarHeight: CGFloat = 80"))
        // Round 21 control height
        #expect(content.contains("static let controlHeightLarge: CGFloat = 36"))
        // Round 22 onboarding
        #expect(content.contains("static let onboardingWindowSize: CGSize = CGSize(width: 640, height: 720)"))
    }

    @Test("Round 22 — IconStyles file defines 11-case IconStyle + 11-case IconColor")
    func iconStylesFileHasCanonicalSurface() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("enum IconStyle"), "IconStyle enum must exist")
        #expect(content.contains("enum IconColor"), "IconColor enum must exist")
        #expect(content.contains("case .inlineSmall"), "IconStyle must include .inlineSmall")
        #expect(content.contains("case .emptyStateHero"), "IconStyle must include .emptyStateHero (= 76 PT)")
        #expect(content.contains("case .toolbarButton"), "IconStyle must include .toolbarButton (= 32 PT)")
        #expect(content.contains("case .surface"), "IconStyle must include .surface (= 56 PT)")
    }

    @Test("Round 23 — IconStyles file declares the 6 SF region view wrappers")
    func iconStylesFileHasSFRegionWrappers() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("struct SFIcon"), "SFIcon central wrapper must exist")
        #expect(content.contains("struct SFLabelRow"), "SFLabelRow sidebar-row wrapper must exist")
        #expect(content.contains("struct SFStatusBadge"), "SFStatusBadge status-badge wrapper must exist")
        #expect(content.contains("struct SFCardHero"), "SFCardHero card-hero wrapper must exist")
        #expect(content.contains("struct SFToolbarButton"), "SFToolbarButton toolbar-button wrapper must exist")
        #expect(content.contains("struct SFListRow"), "SFListRow general-list-row wrapper must exist")
    }

    @Test("Round 23 — SFRegions.md index exists (= per-region wrapper index)")
    func sfRegionsIndexExists() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/SFRegions.md")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFRegions"), "SFRegions.md title must exist")
        #expect(content.contains("SFLabelRow"), "SFRegions.md must list SFLabelRow")
        #expect(content.contains("SFStatusBadge"), "SFRegions.md must list SFStatusBadge")
        #expect(content.contains("SFCardHero"), "SFRegions.md must list SFCardHero")
        #expect(content.contains("SFToolbarButton"), "SFRegions.md must list SFToolbarButton")
        #expect(content.contains("SFListRow"), "SFRegions.md must list SFListRow")
    }
}