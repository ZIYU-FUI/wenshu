//
//  ChatToolDiffPreview.swift · wenshu · chat-diff-preview 2026-09-28
//
//  Unified-diff preview card. Mirrors the hermes `a61baa9615
//  feat(desktop): PR-style file diffs in chat` API surface:
//    - color by line: removed = red, added = green, context = neutral
//    - header = filename + +N/-N character counts (= the boss-facing
//      metric for "how much did the LLM want to change")
//    - body = unified diff lines, git-noise header stripped, the
//      +/-/space gutter stripped so changes read by color alone
//      (Cursor / T3 per-edit review style).
//
//  Used by `ChatToolResultPartView` when a tool result carries
//  `kind: "diff"` (= the LLM patch / write-file / edit-file tool
//  surface in hermes = write_file, edit_file, patch). 1:1 with
//  hermes 0.21.5 `MessageTextContent` being reused for file-edit
//  tool results — wenshu reuses the same surface (= 1 diff
//  pipeline across chat + kanban + (future) BackgroundReview).
//
//  Apple HIG: no custom chrome, no shadow, no rounded-rect wrapper.
//  The card uses the same `Quinary` background + `RoundedRectangle`
//  stroke as `ChatToolResultPartView` for visual continuity.
//

import SwiftUI

struct ChatToolDiffPreview: View {
    let diff: String
    let filename: String

    /// Stripped diff ready for rendering (= git preamble gone).
    private var display: String { Self.stripFileHeaders(diff) }

    private var stats: LineStats { Self.countLineStats(display) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
            header
            diffBody
        }
        // Mirror ChatToolResultPartView's card chrome so the preview
        // reads as the same surface family.
        .padding(.horizontal, DesignTokens.chromePaddingSmall)
        .padding(.vertical, DesignTokens.chromePaddingMicro)
        .background(
            AnyShapeStyle(.quinary.opacity(0.5)),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator, lineWidth: 1)
        )
        .frame(maxWidth: 360)
    }

    private var header: some View {
        HStack(spacing: DesignTokens.chromePaddingSmall) {
            Image(systemName: "doc.text")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            Text(filename)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            statsLabel
        }
    }

    private var statsLabel: some View {
        HStack(spacing: 4) {
            Text("+\(stats.addedChars)")
                .foregroundStyle(Color(nsColor: .systemGreen))
            Text("−\(stats.removedChars)")
                .foregroundStyle(Color(nsColor: .systemRed))
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private var diffBody: some View {
        // Stream the diff into red/green/neutral lines. Cursor /
        // T3 style = strip the leading +/-/space gutter; = the color
        // carries the meaning.
        let lines = display.split(separator: "\n", omittingEmptySubsequences: false)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(Self.present(line: String(line)))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Self.color(for: String(line)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignTokens.chromePaddingMicro)
            }
        }
    }

    // MARK: - Pure helpers (= testable in isolation)

    /// Line and character counts for the rendered diff (= header metric).
    /// Excludes git-noise lines (`---`, `+++`, hunk headers `@@`).
    struct LineStats: Equatable, Sendable {
        let addedLines: Int
        let removedLines: Int
        let addedChars: Int
        let removedChars: Int
    }

    /// Drop the leading +/-/space gutter char (= cursor-style: color
    /// carries the meaning; = no `+`/`-` glyph prefix on rendered lines).
    nonisolated static func present(line: String) -> String {
        guard !line.isEmpty else { return line }
        if line.hasPrefix("@@") { return line }
        if line.hasPrefix("+++") || line.hasPrefix("---") { return line }
        if line.hasPrefix("+") || line.hasPrefix(" ") {
            return String(line.dropFirst())
        }
        if line.hasPrefix("-") {
            return String(line.dropFirst())
        }
        return line
    }

    /// Color for a diff line (Apple HIG semantic colors, light + dark).
    nonisolated static func color(for line: String) -> Color {
        if line.hasPrefix("@@") { return .secondary }
        if line.hasPrefix("+++") || line.hasPrefix("---") { return .secondary.opacity(0.6) }
        if line.hasPrefix("+") { return Color(nsColor: .systemGreen) }
        if line.hasPrefix("-") { return Color(nsColor: .systemRed) }
        return .primary
    }

    /// Strip the git preamble (= file headers, arrow header lines) up to
    /// the first `@@` hunk header. Pure helper (= unit-testable).
    nonisolated static func stripFileHeaders(_ diff: String) -> String {
        let headerPrefixes = [
            "diff --git",
            "index ",
            "--- ",
            "+++ ",
            "similarity ",
            "rename ",
            "new file",
            "deleted file"
        ]
        let lines = diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var start = 0
        for (i, line) in lines.enumerated() {
            if line.hasPrefix("@@") { start = i; break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // arrow-header: "<src>" → "<dst>"
            if trimmed.contains("→") && !line.hasPrefix("+") && !line.hasPrefix("-") && !line.hasPrefix("@") {
                continue
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            if headerPrefixes.contains(where: { line.hasPrefix($0) }) {
                continue
            }
            // First real hunk line that doesn't match a header prefix —
            // bail out so we don't drop content.
            start = i
            break
        }
        return lines[start...].joined(separator: "\n")
    }

    /// Count +N added / -M removed lines + characters (= header metric).
    /// Lines / chars from `+++` / `---` headers + `@@` hunk headers are
    /// excluded (= git preamble never counts).
    nonisolated static func countLineStats(_ diff: String) -> LineStats {
        var addedLines = 0
        var removedLines = 0
        var addedChars = 0
        var removedChars = 0
        for raw in diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if raw.hasPrefix("@@") { continue }
            if raw.hasPrefix("+++") || raw.hasPrefix("---") { continue }
            if raw.hasPrefix("+") {
                addedLines += 1
                let body = String(raw.dropFirst())
                addedChars += body.count
            } else if raw.hasPrefix("-") {
                removedLines += 1
                let body = String(raw.dropFirst())
                removedChars += body.count
            }
        }
        return LineStats(
            addedLines: addedLines,
            removedLines: removedLines,
            addedChars: addedChars,
            removedChars: removedChars
        )
    }
}
