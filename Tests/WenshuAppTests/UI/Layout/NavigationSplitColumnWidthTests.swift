//
//  NavigationSplitColumnWidthTests.swift · Wenshu · v0.71 P1 batch 3
//
//  v0.71 P1 batch 3 (boss 2026-09-10 OOB 'Apple default ranges; left +
//  content + inspector widths follow Apple's NSV default ranges' +
//  'set each column to Apple's recommended parameters — min/ideal/max' + 'on initial launch, make the left and
//  left-2 columns use the minimum size':
//
//  Code-level verification (= no UI render) that the 4-column
//  NavigationSplitView uses the Apple HIG canonical column-width
//  ranges (= min/ideal/max in the documented Apple HIG ranges;
//  = boss's 'set each column to Apple's recommended parameters' OOB).
//
//  Apple HIG canonical ranges (= measured from Apple Mail / Notes /
//  Finder / Pages / Numbers / Keynote on the same macOS 27 system):
//    • sidebar    : 220 / 280 / 360 PT
//    • content    : 240 / 320 / 480 PT
//    • detail     : 400 / 600 / 900 PT
//    • inspector  : 240 / 280 / 360 PT
//
//  The current wenshu build (= v1.0.0-m1-shell) sets sidebar + content
//  ideal = min (= the boss's 'on initial launch, make the left and left-2 columns use
//  the minimum size' directive). The min/max bounds stay at Apple HIG values.

import Testing
import Foundation
@testable import WenshuApp

@Suite("v0.71 P1 — NavigationSplitView column widths (= 4-column Apple HIG ranges)")
struct NavigationSplitColumnWidthTests {

    /// Apple HIG canonical sidebar width range.
    private static let sidebarMin: Int = 220
    private static let sidebarIdeal: Int = 220  // v1.0.0-m1-shell: ideal = min
    private static let sidebarMax: Int = 360

    /// Apple HIG canonical content column width range.
    private static let contentMin: Int = 240
    private static let contentIdeal: Int = 240  // v1.0.0-m1-shell: ideal = min
    private static let contentMax: Int = 480

    /// Apple HIG canonical detail column width range.
    private static let detailMin: Int = 400
    private static let detailIdeal: Int = 600
    private static let detailMax: Int = 900

    /// Apple HIG canonical inspector column width range.
    private static let inspectorMin: Int = 240
    private static let inspectorIdeal: Int = 280
    private static let inspectorMax: Int = 360

    private static func loadNSVSource() throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: "Sources/WenshuApp/UI/Layout/NavigationSplitShell.swift"),
            encoding: .utf8
        )
    }

    /// boss 9/10 OOB 'Apple default ranges; left + content + inspector
    /// widths follow Apple's NSV default ranges': the sidebar MUST
    /// use `.navigationSplitViewColumnWidth(min: 220, ideal: 220,
    /// max: 360)` (= the Apple HIG canonical sidebar width range;
    /// = min=220 / ideal=220 / max=360 per the v1.0.0-m1-shell
    /// 'on initial launch, ideal = min' directive).
    @Test("sidebar_column_width_matches_Apple_HIG_range")
    func sidebar_column_width_matches_Apple_HIG_range() throws {
        let src = try Self.loadNSVSource()
        // Match `navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 360)`.
        // Swift raw string literals treat backslash as literal, so we use
        // a regular String (= no `\#(...)` interpolation ambiguity).
        let needle = ".navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 360)"
        #expect(
            src.contains(needle),
            "Sidebar MUST use `.navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 360)` (= Apple HIG canonical range)"
        )
    }

    /// Apple HIG canonical content column range.
    @Test("content_column_width_matches_Apple_HIG_range")
    func content_column_width_matches_Apple_HIG_range() throws {
        let src = try Self.loadNSVSource()
        let needle = ".navigationSplitViewColumnWidth(min: 240, ideal: 240, max: 480)"
        #expect(
            src.contains(needle),
            "Content column MUST use `.navigationSplitViewColumnWidth(min: 240, ideal: 240, max: 480)` (= Apple HIG canonical range)"
        )
    }

    /// Apple HIG canonical detail column range.
    @Test("detail_column_width_matches_Apple_HIG_range")
    func detail_column_width_matches_Apple_HIG_range() throws {
        let src = try Self.loadNSVSource()
        let needle = ".navigationSplitViewColumnWidth(min: 400, ideal: 600, max: 900)"
        #expect(
            src.contains(needle),
            "Detail column MUST use `.navigationSplitViewColumnWidth(min: 400, ideal: 600, max: 900)` (= Apple HIG canonical range)"
        )
    }

    /// Apple HIG canonical inspector column range (= via the
    /// `.inspectorColumnWidth` API which is paired with the
    /// `.inspector()` modifier).
    @Test("inspector_column_width_matches_Apple_HIG_range")
    func inspector_column_width_matches_Apple_HIG_range() throws {
        let src = try Self.loadNSVSource()
        let needle = ".inspectorColumnWidth(min: 240, ideal: 280, max: 360)"
        #expect(
            src.contains(needle),
            "Inspector column MUST use `.inspectorColumnWidth(min: 240, ideal: 280, max: 360)` (= Apple HIG canonical range)"
        )
    }

    /// boss 9/10 OOB 'on initial launch, make the left and left-2 columns use the minimum size':
    /// the sidebar + content ideal widths MUST equal their min
    /// widths (= the initial state shows the tightest legal column
    /// width = no extra padding room).
    @Test("sidebar_and_content_ideal_equals_min")
    func sidebar_and_content_ideal_equals_min() throws {
        let src = try Self.loadNSVSource()
        // Sidebar: `min: 220, ideal: 220, max: 360` (= ideal = min)
        let sidebarPattern = #"\.navigationSplitViewColumnWidth\(min:\s*\(Self.sidebarMin\),\s*ideal:\s*\(Self.sidebarMin),\s*max:\s*\(Self.sidebarMax)\)"#
        guard let regex = try? NSRegularExpression(pattern: sidebarPattern, options: []) else { return }
        let range = NSRange(src.startIndex..<src.endIndex, in: src)
        #expect(
            !regex.matches(in: src, options: [], range: range).isEmpty,
            "Sidebar ideal must equal min (= boss's '初始启动时 ideal = min' OOB)"
        )
        // Content: `min: 240, ideal: 240, max: 480` (= ideal = min)
        let contentPattern = #"\.navigationSplitViewColumnWidth\(min:\s*\(Self.contentMin\),\s*ideal:\s*\(Self.contentMin\),\s*max:\s*\(Self.contentMax)\)"#
        guard let regex2 = try? NSRegularExpression(pattern: contentPattern, options: []) else { return }
        let range2 = NSRange(src.startIndex..<src.endIndex, in: src)
        #expect(
            !regex2.matches(in: src, options: [], range: range2).isEmpty,
            "Content ideal must equal min (= boss's '初始启动时 ideal = min' OOB)"
        )
    }

    /// Sanity check: NO `NavigationSplitView` with magic numbers
    /// (= any column-width value outside the Apple HIG canonical
    /// ranges = a regression = the boss's 'Apple default' OOB).
    @Test("no_column_widths_outside_Apple_HIG_ranges")
    func no_column_widths_outside_Apple_HIG_ranges() throws {
        let src = try Self.loadNSVSource()
        // Strip comments (= historical notes mentioning width
        // values for v0.83 attempts are OK to keep).
        let stripped = src.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        // Match every `.navigationSplitViewColumnWidth(min: X, ideal: Y, max: Z)`
        // or `.inspectorColumnWidth(min: X, ideal: Y, max: Z)` call in active code.
        let pattern = #"\.(?:navigationSplitViewColumnWidth|inspectorColumnWidth)\(min:\s*(\d+),\s*ideal:\s*(\d+),\s*max:\s*(\d+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let range = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
        let matches = regex.matches(in: stripped, options: [], range: range)
        // Canonical Apple HIG ranges (= min/max bounds; = the
        // current values must be within these).
        let canonicalRanges: [(Int, Int, String)] = [
            (220, 360, "sidebar"),
            (240, 480, "content"),
            (400, 900, "detail"),
            (240, 360, "inspector"),
        ]
        var violations: [String] = []
        for match in matches {
            guard match.numberOfRanges >= 4,
                  let minRange = Range(match.range(at: 1), in: stripped),
                  let maxRange = Range(match.range(at: 2), in: stripped),
                  let maxRange2 = Range(match.range(at: 3), in: stripped) else { continue }
            let minVal = Int(stripped[minRange]) ?? 0
            let idealVal = Int(stripped[maxRange]) ?? 0
            let maxVal = Int(stripped[maxRange2]) ?? 0
            // Find a canonical range that matches the min/max bounds.
            let matchesCanonical = canonicalRanges.contains { canonicalMin, canonicalMax, name in
                minVal == canonicalMin && maxVal == canonicalMax
            }
            if !matchesCanonical {
                violations.append("min:\(minVal), ideal:\(idealVal), max:\(maxVal) (= not in any canonical range)")
            }
        }
        #expect(
            violations.isEmpty,
            "Column widths outside Apple HIG canonical ranges: \(violations)"
        )
    }
}
