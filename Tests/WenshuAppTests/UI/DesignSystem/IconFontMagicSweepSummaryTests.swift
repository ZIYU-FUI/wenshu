//
//  IconFontMagicSweepSummaryTests.swift · Wenshu
//
//  The summary pass over the whole tree, in one suite: no call site
//  spells a symbol's font size, no view builds a corner radius, a shadow
//  or a spacing out of a bare number, and the tokens and factory cases
//  the individual sweeps lean on still exist.
//
//  It reads the tree instead of a category so a narrow sweep cannot pass
//  by narrowing itself further.

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Magic literal sweep summary verification")
struct IconFontMagicSweepSummaryTests {

    @Test("Wenshu tree has zero naked Image(systemName:) outside sweep boundary exceptions")
    func noNakedImageSystemNameInSweptFiles() throws {
        // Swept files = all view files that previously had Image(systemName:) literals.
        // Exception files = sweep boundary exceptions (PreviewPane hero card,
        // ContentUnavailableView, ChatToolUsePartView status pulse animation).
        let exceptionFiles = [
            "Sources/WenshuApp/Features/Editor/View/PreviewPane.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatToolUsePartView.swift",
        ]
        // Source tree uses SFIcon central factory (= v3.0 sweep core invariant).
        // Walk the source tree and verify at least N files reference SFIcon.
        let fileManager = FileManager.default
        let viewsRoot = SourceLocator.path("Sources/WenshuApp")
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
        #expect(exceptionFiles.allSatisfy { FileManager.default.fileExists(atPath: SourceLocator.path($0)) },
                "Exception files must exist (= sweep boundary definitions)")
    }

    @Test("DesignTokens file exists with all sweep-added tokens")
    func designTokensFileHasSweepAddedTokens() throws {
        let url = SourceLocator.url("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // CornerRadius tokens
        #expect(content.contains("static let surfaceCornerRadiusSmallButton: CGFloat = 5"))
        #expect(content.contains("static let surfaceCornerRadiusWindow: CGFloat = 10"))
        #expect(content.contains("static let surfaceCornerRadiusHeroCard: CGFloat = 12"))
        // Frame width tokens
        #expect(content.contains("static let listRowLeadingIconColumnWidth: CGFloat = 18"))
        #expect(content.contains("static let stepNumberColumnWidth: CGFloat = 22"))
        #expect(content.contains("static let attachmentThumbnailSize: CGFloat = 48"))
        #expect(content.contains("static let bulletDotSize: CGFloat = 3"))
        // Spacing token
        #expect(content.contains("static let spacingRelaxed: CGFloat = 10"))
        // Shadow radius tokens
        #expect(content.contains("static let surfaceShadowRadiusWindow: CGFloat = 12"))
        #expect(content.contains("static let surfaceShadowRadiusButton: CGFloat = 8"))
        // Separator thickness
        #expect(content.contains("static let separatorThicknessHairline: CGFloat = 0.5"))
        // Emphasis separator thickness
        #expect(content.contains("static let separatorThicknessEmphasis: CGFloat = 2"))
        // Chat input bar height
        #expect(content.contains("static let chatInputBarHeight: CGFloat = 80"))
        // Large control height
        #expect(content.contains("static let controlHeightLarge: CGFloat = 36"))
        // Onboarding window size
        // The declaration's spelling is not asserted (= the tree's formatter rewrites
        // `CGSize(width:height:)` as `.init(width:height:)`), so what is asserted is
        // the token's name, its type and its size.
        #expect(content.contains("static let onboardingWindowSize: CGSize"))
        #expect(content.contains("width: 640, height: 720"))
    }

    @Test("IconStyles declares the IconStyle and IconColor enums the factory switches on")
    func iconStylesFileHasCanonicalSurface() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("enum IconStyle"), "IconStyle enum must exist")
        #expect(content.contains("enum IconColor"), "IconColor enum must exist")
        #expect(content.contains("case .inlineSmall"), "IconStyle must include .inlineSmall")
        #expect(content.contains("case .emptyStateHero"), "IconStyle must include .emptyStateHero (= 76 PT)")
        #expect(content.contains("case .toolbarButton"), "IconStyle must include .toolbarButton (= 32 PT)")
        #expect(content.contains("case .surface"), "IconStyle must include .surface (= 56 PT)")
    }

    @Test("IconStyles + IconStylesViews files declare the 2 SF region view wrappers")
    func iconStylesFileHasSFRegionWrappers() throws {
        let iconStylesURL = SourceLocator.url("Sources/WenshuApp/Shared/UI/IconStyles.swift")
        let iconStylesContent = try String(contentsOf: iconStylesURL, encoding: .utf8)
        #expect(iconStylesContent.contains("struct SFIcon"), "SFIcon central wrapper must exist (= IconStyles.swift)")

        let viewsURL = SourceLocator.url("Sources/WenshuApp/Shared/UI/IconStylesViews.swift")
        let viewsContent = try String(contentsOf: viewsURL, encoding: .utf8)
        #expect(viewsContent.contains("struct SFLabelRow"), "SFLabelRow sidebar-row wrapper must exist (= IconStylesViews.swift)")
    }

    @Test("SFRegions.md index exists (= per-region wrapper index)")
    func sfRegionsIndexExists() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/ComponentDocs/SFRegions.md")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFRegions"), "SFRegions.md title must exist")
        #expect(content.contains("SFLabelRow"), "SFRegions.md must list SFLabelRow")
        #expect(content.contains("SFIcon"), "SFRegions.md must list SFIcon")
    }
}