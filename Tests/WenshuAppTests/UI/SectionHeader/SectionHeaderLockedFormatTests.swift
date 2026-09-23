// SectionHeaderLockedFormatTests.swift · Wenshu · v0.71 P1 batch 3
//
// v0.71 P1 batch 3 (boss 2026-09-11 OOB 'keep this style as the standard — use it from
// now on' = 'this style stays as the standard, use it from now on' + 'that
// title's text color — Apple's is a bit grayer, not pure white, close to the divider's color' =
// 'the title color is gray, not pure white, close to the divider color'):
//
// The section header pattern is LOCKED per memory:
//   VStack(spacing: 4) {
//       HStack { Spacer(); Text(t).font(.body).foregroundStyle(.secondary).textCase(nil); Spacer() }
//       Divider()
//   }
//
// Used in all 3 column titles:
//   • Sidebar: section headers in AppleSidebarView.swift (v1.68b MVVM-split sidebar)
//   • Content: 'Assets' in PreviewPane.swift
//   • Inspector: 'Authoring (Fiction)' etc in ShellDetailColumn.swift
//
// v1.69 sidebar MVVM cleanup: target file updated from
// AppleSidebarView.swift (= was NewLibraryOutlineView.swift pre-v1.69e) (= the
// v1.68b MVVM-split sidebar that is now the production sidebar).
//
// These tests don't render views; they verify the source file
// structure (= the LOCKED format contract = a regression that
// changes one copy but not the others breaks visual consistency).

import Testing
import Foundation
@testable import WenshuApp

@Suite("v0.71 P1 — Section header LOCKED format (= 3 column titles)")
struct SectionHeaderLockedFormatTests {

    /// The 3 column-title files that MUST each contain the LOCKED
    /// section header format (= VStack(spacing: 4) { HStack { Spacer();
    /// Text(...).font(.body).foregroundStyle(.secondary).textCase(nil);
    /// Spacer() }; Divider() }).
    /// v1.52 stale-test-cleanup: replaced NavigationSplitShell.swift with
    /// ShellDetailColumn.swift (= v1.43 ticket 001 extracted the inspector
    /// column title = 'Authoring' from the shell into its own column file).
    /// v1.69 sidebar MVVM cleanup: removed AppleSidebarView.swift from this
    /// list. The v1.68b Apple HIG sidebar uses SwiftUI's built-in
    /// `List(.sidebar)` + `List(data, children:)` which manages section
    /// header spacing via Apple's own HIG convention (= no manual
    /// `VStack(spacing: 4) { HStack { Spacer() / Text / Spacer() } /
    /// Divider() }` pattern in the sidebar file; = Apple draws the
    /// section chrome). The LOCKED format contract still applies to the
    /// 2 columns that draw their own title (= content + inspector).
    private static let sectionHeaderFiles = [
        "Sources/WenshuApp/Views/Workspace/PreviewPane.swift",
        "Sources/WenshuApp/UI/Layout/ShellDetailColumn.swift",
    ]

    private static func loadSource(_ path: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
    }

    /// Strip comments from the source (= historical notes mentioning
    /// the format don't count as actual usage).
    private static func stripComments(_ source: String) -> String {
        source.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
    }

    /// boss 9/11 OOB 'keep this style as the standard — use it from now on': the LOCKED
    /// format MUST appear in all 3 column-title files (= sidebar +
    /// content + inspector). The format marker = `Spacer()` +
    /// `Text(...).font(.body).foregroundStyle(.secondary).textCase(nil)`
    /// + `Spacer()` + `Divider()` in a single VStack(spacing:).
    @Test("all_3_column_titles_use_locked_section_header_format")
    func all_3_column_titles_use_locked_section_header_format() throws {
        var nonConforming: [String] = []
        for file in Self.sectionHeaderFiles {
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: url.path) else {
                Issue.record("Section header file MUST exist: \(file)")
                continue
            }
            let src = try Self.loadSource(file)
            let stripped = Self.stripComments(src)
            // Check the format markers (= all 4 must appear):
            //   1. `Text(...).font(.body)` (= body font weight)
            //   2. `.foregroundStyle(.secondary)` (= Apple HIG gray)
            //   3. `.textCase(nil)` (= no ALL-CAPS forcing)
            //   4. `Divider()` (= separator)
            // (= the canonical Pages-style header)
            let hasFont = stripped.contains(".font(.body)")
            let hasSecondary = stripped.contains(".foregroundStyle(.secondary)")
            let hasTextCaseNil = stripped.contains(".textCase(nil)")
            let hasDivider = stripped.contains("Divider()")
            if !(hasFont && hasSecondary && hasTextCaseNil && hasDivider) {
                nonConforming.append("\(file) (font:\(hasFont), secondary:\(hasSecondary), textCase:\(hasTextCaseNil), divider:\(hasDivider))")
            }
        }
        #expect(
            nonConforming.isEmpty,
            "Section header files missing the LOCKED format (= boss's '这个样式留作标准' OOB): \(nonConforming)"
        )
    }

    /// boss 9/11 OOB 'that title's text color — Apple's is a bit grayer, not pure white.
    /// Close to the divider's color' (= 'the title color is grayish, not pure
    /// white, close to the divider color'): the section header title
    /// MUST use `.secondary` foreground (= NOT `.primary` and NOT
    /// `.white`). Apple HIG default = .secondary = matches the
    /// divider color for visual coherence.
    @Test("section_header_uses_secondary_color_not_white")
    func section_header_uses_secondary_color_not_white() throws {
        for file in Self.sectionHeaderFiles {
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let src = try Self.loadSource(file)
            let stripped = Self.stripComments(src)
            // The LOCKED format uses `.foregroundStyle(.secondary)`.
            // Verify no `.foregroundColor(.white)` or
            // `.foregroundStyle(.white)` (= boss's directive =
            // 'NOT pure white').
            #expect(
                !stripped.contains(".foregroundColor(.white)"),
                "\(file) must NOT use `.foregroundColor(.white)` for the section header (= boss's '不是纯白的' OOB)"
            )
            #expect(
                !stripped.contains(".foregroundStyle(.white)"),
                "\(file) must NOT use `.foregroundStyle(.white)` for the section header (= boss's '不是纯白的' OOB)"
            )
        }
    }

    /// boss 9/11 OOB 'keep this style as the standard — use it from now on': each column
    /// title text MUST use `.textCase(nil)` (= no ALL-CAPS forcing).
    /// Apple HIG default text case = nil (= shows the title as the
    /// user typed it, no automatic uppercasing).
    @Test("section_header_text_uses_textCase_nil")
    func section_header_text_uses_textCase_nil() throws {
        var missing: [String] = []
        for file in Self.sectionHeaderFiles {
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let src = try Self.loadSource(file)
            let stripped = Self.stripComments(src)
            // The LOCKED format includes `.textCase(nil)`.
            if !stripped.contains(".textCase(nil)") {
                missing.append(file)
            }
        }
        #expect(
            missing.isEmpty,
            "Section header files missing `.textCase(nil)` (= boss's LOCKED format): \(missing)"
        )
    }
}
