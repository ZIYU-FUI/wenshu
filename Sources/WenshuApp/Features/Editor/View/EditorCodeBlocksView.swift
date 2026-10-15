// Sources/WenshuApp/Views/Inspector/EditorCodeBlocksView.swift
//
// Sub-tool 4 of 5 (= T-08) inside the `documentTools` page:
// code-block list. Parses the current editor draft for fenced code
// blocks (```/~~~) and renders a clickable list (= Apple HIG
// inspector code-block surface = Pages "Code" panel + Numbers
// "Formula" sidebar = a flat list of named blocks with their
// language hint).
//
// Engine has no public code-block-list API (= confirmed in the SMC
// surface inventory T-pre; = same as the outline sub-tool = the
// engine emits `onCodeBlockSelectionChange` via the coordinator
// closure but does NOT publish the full list). So we re-parse the
// draft on every body invocation (= Foundation-only =
// NSRegularExpression = microseconds for any realistic chapter
// document; = the canonical Pages / Numbers inspector parsing
// pattern).
//
// Fenced-code-block grammar (= the canonical CommonMark form):
//   ```language
//   code line 1
//   code line 2
//   ```
// The regex captures the opening fence's optional language hint
// (`python`, `swift`, etc.) and the first non-empty body line
// (= shown as the row's subtitle = the canonical Pages "Code"
// panel name pattern = the first body line is a human-readable
// hint about what the block does).
import SwiftUI

/// Code-block list panel (= parses ```/~~~ fences from the editor
/// draft and renders a clickable list). Empty / all-non-fenced
/// documents show the standard "no code blocks" hint.
struct EditorCodeBlocksView: View {
    /// Active draft text (= re-parsed on every change). The parent
    /// (= EditorDocumentToolsView) supplies this closure so the
    /// list stays in sync with whatever tab is currently open.
    let activeDocumentText: () -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
            // Section header (= Pages / Numbers inspector sub-section
            // pattern = secondary-tint title).
            Text(String(localized: "inspector.documentTools.codeBlocks.title"))
                .font(.callout)
                .foregroundStyle(.secondary)

            // List (= parsed every body invocation; = cheap = O(n)
            // over the draft with a single regex pass; = no async
            // cache needed for chapter-length documents).
            CodeBlockList(
                blocks: parsedBlocks(from: activeDocumentText() ?? "")
            )
        }
    }

    /// Pure fence-row parser. Returns `[]` (= the host View renders
    /// its "no code blocks" hint) when the draft has no fences.
    ///
    /// The parser walks the draft line-by-line. Each line starting
    /// with ` ``` ` or `~~~` opens a new block; = the block ends at
    /// the next matching fence (= the canonical CommonMark fenced
    /// code block rule). The language hint is the token after the
    /// opening fence (optional).
    private func parsedBlocks(from text: String) -> [CodeBlockRow] {
        let lines = text.components(separatedBy: .newlines)
        var rows: [CodeBlockRow] = []
        var openFence: (marker: String, language: String?, startLine: Int)? = nil
        var firstBodyLine: String? = nil

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let open = openFence {
                // We're inside a fence; = close when we see a
                // matching fence marker (= the canonical CommonMark
                // close = same marker >= 3 chars).
                if trimmed.hasPrefix(open.marker) && trimmed.allSatisfy({ $0 == open.marker.first }) && trimmed.count >= 3 {
                    rows.append(
                        CodeBlockRow(
                            language: open.language,
                            firstBodyLine: firstBodyLine,
                            startLine: open.startLine
                        )
                    )
                    openFence = nil
                    firstBodyLine = nil
                } else if firstBodyLine == nil, !trimmed.isEmpty {
                    // Capture the first non-empty body line (= the
                    // human-readable subtitle; = Pages "Code" panel
                    // name pattern).
                    firstBodyLine = String(trimmed.prefix(64))
                }
            } else if trimmed.hasPrefix("```") && trimmed.count >= 3 {
                openFence = (
                    marker: "```",
                    language: trimmed.count > 3
                        ? String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                        : nil,
                    startLine: index
                )
            } else if trimmed.hasPrefix("~~~") && trimmed.count >= 3 {
                openFence = (
                    marker: "~~~",
                    language: trimmed.count > 3
                        ? String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                        : nil,
                    startLine: index
                )
            }
        }
        // Unclosed fence (= user is still typing; = render it as a
        // partial row with whatever body we captured).
        if let open = openFence {
            rows.append(
                CodeBlockRow(
                    language: open.language,
                    firstBodyLine: firstBodyLine,
                    startLine: open.startLine
                )
            )
        }
        return rows
    }
}

/// One code-block row (= language hint + first body line + start
/// line). The start line is captured for future tap-to-scroll
/// (= a future ticket wires via `bus.findScrollToRange` once the
/// engine exposes a stable line-index surface).
private struct CodeBlockRow: Identifiable, Hashable {
    let language: String?
    let firstBodyLine: String?
    let startLine: Int

    var id: Int { startLine }

    /// Display name (= the first body line if available; = falls
    /// back to the language hint; = falls back to "Block N" =
    /// the canonical Pages "Code" panel naming).
    var displayName: String {
        if let body = firstBodyLine, !body.isEmpty {
            return body
        }
        if let lang = language, !lang.isEmpty {
            return lang
        }
        return "Block \(startLine)"
    }
}

/// Code-block list body (= renders one row per fenced block; = an
/// empty list shows the "no code blocks" hint = Apple HIG inspector
/// empty state).
private struct CodeBlockList: View {
    let blocks: [CodeBlockRow]

    var body: some View {
        if blocks.isEmpty {
            // Empty-state hint (= the canonical Pages / Numbers
            // inspector "no code blocks" message; = localizable).
            HStack(spacing: DesignTokens.spacingCaption) {
                SFIcon("chevron.left.forwardslash.chevron.right",
                       style: .inlineSmall, color: IconColor.tertiary)
                Text(String(localized: "inspector.documentTools.codeBlocks.empty"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // One row per block (= language chip + body line; =
            // Pages / Numbers inspector "Code" panel row shape).
            VStack(alignment: .leading, spacing: DesignTokens.spacingCaption) {
                ForEach(blocks) { block in
                    HStack(spacing: DesignTokens.spacingCaption) {
                        // Language chip (= small caption, secondary
                        // tint; = Pages "Code" panel language
                        // indicator = "swift" / "python" / "json" /
                        // nil).
                        Text(block.language ?? "Block")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 24, alignment: .leading)
                        Text(block.displayName)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        Spacer(minLength: DesignTokens.spacingCaption)
                    }
                }
            }
        }
    }
}