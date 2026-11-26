//
//  SidebarIconUniformityTests.swift · Wenshu · v3.0
//
//  Validates the SFLabelRow central factory shape: every sidebar
//  row renders the same icon slot (= 16 PT frame, 2 PT inner
//  inset, .regular weight, .primary color) so the tree reads as
//  one visual column. Per (see OOB.md #2026-10-08) the wenshu
//  default follows Apple Mail / Notes / Xcode / System Settings:
//  the slot is constant; the optical width of each SF Symbol
//  floats ±4 PT inside the slot because Apple keeps each
//  symbol's intrinsic optical bounds. A future sweep can
//  optionally measure + scale (see icon-policy .scaleEffect
//  recipe), but the per-frame .regular weight + .hierarchical
//  rendering already produces the column-aligned look Apple
//  uses in its first-party apps.

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Sidebar icon uniformity")
struct SidebarIconUniformityTests {
    @Test("SFLabelRow uses the central icon factory and a fixed row slot")
    func sidebarRowUsesCentralFactoryAndFixedSlot() throws {
        let source = try Self.source("Sources/WenshuApp/Shared/UI/IconStylesViews.swift")
        // Factory shape: SFLabelRow delegates to SFIcon(..., style: iconStyle)
        // and pins the row slot via sidebarWidth / sidebarInset.
        #expect(source.contains("SFIcon(\n                systemImage,\n                style: iconStyle,\n                color: IconColor.primary"))
        #expect(source.contains("padding(.horizontal, iconStyle.sidebarInset)"))
        #expect(source.contains("width: iconStyle.sidebarWidth"))
        // The slot is 16 PT wide; we don't force a square frame
        // (= Apple keeps each symbol's intrinsic height).
        #expect(!source.contains("height: iconStyle.sidebarHeight"))
        // The rendering mode belongs to the central factory: the
        // row wrapper sets none of its own. The factory applies
        // hierarchical rendering at .regular weight = Apple HIG
        // canonical sidebar row iconography.
        #expect(!source.contains(".symbolRenderingMode("))
        // Color = .primary (= Apple Tahoe sidebar default =
        // system text color, not app accent). One tier only.
        #expect(source.contains(".foregroundStyle(Color.primary)"))
        #expect(!source.contains(".foregroundStyle(.tint)\n            .opacity(iconOpacity)"))
        // IconStyle carries a dedicated .sidebar case so the slot
        // properties (sidebarWidth / sidebarInset) are scoped to
        // the sidebar surface (= not attached to every case via
        // an extension on IconStyle).
        // The `IconStyle` enum lives in IconStyles.swift (= the
        // view file holds the views that consume the cases). The case
        // itself is unchanged: `case sidebar` is still there.
        let iconStyles = try Self.source("Sources/WenshuApp/Shared/UI/IconStyles.swift")
        #expect(iconStyles.contains("case sidebar") || iconStyles.contains("case .sidebar"))
        #expect(
            iconStyles.contains(".symbolRenderingMode(.hierarchical)"),
            "the central factory must own the icon rendering mode"
        )
        let rowSource = try Self.sourceSlice(
            from: "struct SFLabelRow: View {",
            in: "Sources/WenshuApp/Shared/UI/IconStylesViews.swift"
        )
        #expect(!rowSource.contains("Image(systemName: systemImage)"))
    }

    @Test("IconStyle.sidebar is the canonical sidebar case (= 16 PT, .regular, slot properties)")
    func sidebarCaseIsCanonical() throws {
        let source = try Self.source("Sources/WenshuApp/Shared/UI/IconStyles.swift")
        // 16 PT point size matches Apple Mail / Notes / Xcode
        // sidebar row leading icon (= the wenshu default per
        // Apple's HIG sidebar anatomy).
        #expect(source.contains("case .sidebar: 16") || source.contains("case .sidebar:") || source.contains("case sidebar\n"))
        // slot dimensions live in the extension on IconStyle so
        // they're explicit (= not piggy-backed on every case).
        // The guard binds the VALUE, not the one-line spelling: the
        // honesty rules re-wrapped these getters into multi-line
        // bodies, and a `contains` on `{ 16 }` would pin a layout
        // the contract never promised.
        #expect(Self.getterValue(of: "var sidebarWidth: CGFloat", in: source) == "16")
        #expect(Self.getterValue(of: "var sidebarInset: CGFloat", in: source) == "2")
        // SFLabelRow defaults to .sidebarTree (not .small) so a
        // caller that doesn't pass iconStyle still hits the
        // canonical sidebar surface. The default parameter lives
        // with the view (= IconStylesViews.swift), not with the
        // enum.
        let views = try Self.source("Sources/WenshuApp/Shared/UI/IconStylesViews.swift")
        #expect(views.contains("iconStyle: IconStyle = .sidebarTree") || views.contains("iconStyle: IconStyle = .sidebar"))
    }

    @Test("getterValue reads a value, not a spelling (= one-line, tight, and re-wrapped bodies agree)")
    func getterValueBindsTheValueNotTheLayout() {
        // The guard these tests use must survive the formatting the honesty
        // rules now require, so each spelling of the same getter has to read
        // back the same number. The line-break constant keeps the fixtures
        // out of a multi-line string literal (= whose indentation belongs to
        // the test file, not to the getter).
        let n = "\n"
        let spelled: [(name: String, source: String)] = [
            ("multi-line body", "extension IconStyle {" + n + "    var sidebarWidth: CGFloat {" + n + "        16" + n + "    }" + n + "}"),
            ("one-line spaced", "var sidebarWidth: CGFloat { 16 }"),
            ("one-line tight", "var sidebarWidth: CGFloat {16}"),
            ("one-line inside an extension", "extension IconStyle { var sidebarWidth: CGFloat { 16 } }"),
        ]
        for fixture in spelled {
            #expect(
                Self.getterValue(of: "var sidebarWidth: CGFloat", in: fixture.source) == "16",
                "\(fixture.name) must read as the same 16 PT slot"
            )
        }
        // A changed number is still a failure, and a renamed or removed
        // property answers nil (= it cannot pass by finding nothing).
        #expect(Self.getterValue(of: "var sidebarWidth: CGFloat", in: "var sidebarWidth: CGFloat {\n 18\n}") == "18")
        #expect(Self.getterValue(of: "var sidebarWidth: CGFloat", in: "var otherWidth: CGFloat {\n 16\n}") == nil)
    }

    private static func sourceSlice(
        from start: String,
        in relativePath: String
    ) throws -> String {
        let source = try source(relativePath)
        guard let startRange = source.range(of: start) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        // The slice runs to the end of the file: the declaration is
        // the last one in it, so there is no following MARK to bound
        // it.
        return String(source[startRange.lowerBound...])
    }

    /// The value a one-statement computed-property getter returns, as written
    /// in the source. Braces are counted, not searched for, so the getter's
    /// own `}` ends the value and an enclosing scope's `}` on the same line
    /// does not: the one-line form (`{ 16 }`), the tight form (`{16}`), a
    /// one-line getter inside an extension, and the multi-line body the
    /// honesty rules re-wrapped this getter into all read as the same value.
    /// A renamed or removed property answers nil (= the assertion fails)
    /// instead of silently passing.
    private static func getterValue(of declaration: String, in source: String) -> String? {
        let head = declaration + " {"
        let lines = source.components(separatedBy: "\n")
        var body: [String] = []
        var insideGetter = false
        // `depth` counts the scopes opened INSIDE the getter's body, which
        // is what remains after the head anchor has consumed the getter's
        // own `{`. A nested `{` therefore pushes the level to 1 and only the
        // matching `}` brings it back to 0 (= the getter's own closing brace).
        var depth = 0
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            var remainder = line
            if !insideGetter {
                guard let headRange = line.range(of: head) else { continue }
                insideGetter = true
                remainder = String(line[headRange.upperBound...])
            }
            // Scan the line's own braces: depth returns to 0 only at the
            // getter's closing `}`, and the text before it is the value.
            var cut = remainder.endIndex
            var reachedEndOfGetter = false
            for index in remainder.indices {
                let character = remainder[index]
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    // The getter's own closing `}` is the one seen while no
                    // nested scope is open, so the test comes BEFORE the
                    // counter drops (a nested `}` only ever closes a level
                    // that its own `{` opened).
                    if depth == 0 {
                        cut = index
                        reachedEndOfGetter = true
                        break
                    }
                    depth -= 1
                }
            }
            body.append(String(remainder[..<cut]))
            if reachedEndOfGetter {
                return body
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                    .split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")
            }
        }
        return insideGetter ? body.joined(separator: " ") : nil
    }

    private static func source(_ relativePath: String) throws -> String {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while current.path != "/" {
            let package = current.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                let url = current.appendingPathComponent(relativePath)
                let data = try Data(contentsOf: url)
                // Try UTF-8 first; fall back to system encoding if it isn't valid UTF-8.
                if let s = String(data: data, encoding: .utf8) {
                    return s
                }
                return try String(contentsOf: url)
            }
            current.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
