// PresetCardTests.swift · Wenshu · v0.87 ticket 004
//
// Source-level structural tests for PresetCard (= a single preset's
// tile in the LayoutPicker grid; = shows a 4:3 mini-render via
// PresetThumbnail + the preset name + an optional delete button).
//
// Per boss 2026-09-14 OOB '按优先级推' + 'A': extend item 10
// (= WorkspaceView test coverage expansion). v0.87 ticket 001 =
// PreviewTabBackground, ticket 002 = EditorEditContent, ticket 003 =
// EditorExpandShrinkTrailingButton, ticket 004 = this (PresetCard).
//
// PresetCard uses @State (= isHovering Bool) + several DesignTokens
// references + LucideIconSystemFallback. ViewInspector v0.10.3 can
// structurally inspect the view body (= v0.82 pattern: tap() doesn't
// propagate @State-owned @Binding writeback, so behavior assertions
// skipped in favor of source-level structural assertions).

import SwiftUI
import Testing
@testable import WenshuApp

@Suite("PresetCard (v0.87 — single preset tile in LayoutPicker grid)")
struct PresetCardTests {

    @Test("source imports SwiftUI")
    func importsSwiftUI() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("import SwiftUI"),
                "must import SwiftUI for View + @State + .overlay + .hoverWash")
    }

    @Test("struct conforms to View")
    func conformsToView() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("struct PresetCard: View"),
                "struct must conform to View")
    }

    @Test("declares 4 let params (preset + isActive + onSelect + optional onDelete)")
    func declaresLetParams() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("let preset: LayoutPreset"),
                "must declare LayoutPreset parameter")
        #expect(source.contains("let isActive: Bool"),
                "must declare isActive parameter (= for selected stroke)")
        #expect(source.contains("let onSelect: () -> Void"),
                "must declare onSelect callback (= tap-to-activate)")
        #expect(source.contains("let onDelete: (() -> Void)?"),
                "must declare optional onDelete callback (= nil for built-ins per spec #12)")
    }

    @Test("declares @State for hover tracking (= the v0.28 first cut per header comment)")
    func declaresStateForHover() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("@State private var isHovering: Bool = false"),
                "must use @State for hover tracking (= per v0.28 first cut)")
    }

    @Test("body uses PresetThumbnail (= the 4:3 mini-render)")
    func usesPresetThumbnail() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("PresetThumbnail(workspace: preset.workspace)"),
                "body must instantiate PresetThumbnail (= the 4:3 mini-render per header)")
        #expect(source.contains(".aspectRatio(4.0 / 3.0, contentMode: .fit)"),
                "thumbnail must use 4:3 aspect ratio (= per the header spec)")
    }

    @Test("uses .ultraThinMaterial for thumbnail background (= Apple HIG macOS 26 Tahoe canonical)")
    func usesUltraThinMaterial() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains(".ultraThinMaterial"),
                "thumbnail background must use .ultraThinMaterial (= canonical Liquid Glass material per v0.28 followup)")
    }

    @Test("uses .hoverWash() (= shared helper from v0.34 multi-layer audit)")
    func usesHoverWash() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains(".hoverWash()"),
                "must use the .hoverWash() helper (= per v0.34 boss audit)")
    }

    @Test("uses .onTapGesture for onSelect")
    func usesOnTapGesture() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains(".onTapGesture"),
                "card must trigger onSelect via .onTapGesture (= per the v0.28 first cut)")
    }

    @Test("delete button conditional on onDelete != nil AND isHovering")
    func deleteButtonConditional() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("if let onDelete = onDelete"),
                "delete button must only render when onDelete is non-nil (= spec #12: built-ins have no delete)")
        #expect(source.contains("if isHovering"),
                "delete button must only render when hovering (= per the v0.28 hover-gating UX)")
    }

    @Test("uses LucideIconSystemFallback for xmark (= Lucide only per wenshu v0.27)")
    func usesLucideXmark() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("LucideIconSystemFallback(\"xmark\""),
                "delete button must use LucideIconSystemFallback with xmark (= per wenshu v0.27 Lucide-only mandate)")
    }

    @Test("strokeOverlay helper has 2 branches (active vs inactive separator)")
    func strokeOverlayHasTwoBranches() throws {
        let sourcePath = "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("private func strokeOverlay(isActive: Bool)"),
                "must define private strokeOverlay helper (= per the Color/ShapeStyle ternary workaround)")
        #expect(source.contains("Color.accentColor, lineWidth: 2"),
                "active stroke must be Color.accentColor 2 PT (= per v0.28 spec)")
        #expect(source.contains(".separator as SeparatorShapeStyle"),
                "inactive stroke must be Apple .separator (= canonical Liquid Glass separator)")
    }
}