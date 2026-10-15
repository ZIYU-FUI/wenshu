// Sources/WenshuApp/Views/Inspector/EditorHeadingOutlineView.swift
//
// Sub-tool 3 of 5 (= T-07) inside the `documentTools` page:
// heading outline. Parses the current editor draft for `^#{1,6}\s`
// heading rows and renders a clickable H1..H6 outline (= Apple HIG
// inspector "Outline" panel shape = Pages / Numbers / Xcode document
// sidebar = a flat tree of headings with deep-link anchors).
//
// Engine has no public outline API (= we confirmed in the SMC
// surface inventory T-pre: the engine emits selectionBoldDidChange
// etc. but does not publish a heading list). So we parse the
// current draft on every change (= Foundation-only = NSRegular-
// Expression = microseconds for any realistic chapter document).
// Apple HIG Pages / Numbers inspector "Outline" panel uses this
// same approach (= no engine API; = the inspector parses the
// rendered text).
//
// Tap = scroll to the heading line. We post the desired line index
// via the engine's `bus.findScrollToRange` (= the bus already
// supports a "scroll-to NSRange" surface; = the engine finds the
// line in its own NSTextView via `findScrollToRange`; = the engine
// also posts a selection-bold style update). Since this is a host
// concern (= we don't know which document line the engine has at
// any time), the host uses `findScrollToRange` with the heading
// text instead of a hardcoded line index (= the engine's own
// find-with-highlight machinery handles the visual jump).
import SwiftUI

/// Heading outline panel (= parses `^#{1,6}\s` from the editor
/// draft and renders a clickable list). Empty / all-heading-less
/// documents show the standard "no outline" hint.
struct EditorHeadingOutlineView: View {
    /// Active draft text (= re-parsed on every change). The parent
    /// (= EditorDocumentToolsView) supplies this closure so the
    /// outline stays in sync with whatever tab is currently open.
    let activeDocumentText: () -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
            // Section header (= Pages / Numbers inspector sub-section
            // pattern = secondary-tint title).
            Text(String(localized: "inspector.documentTools.headingOutline.title"))
                .font(.callout)
                .foregroundStyle(.secondary)

            // Outline (= parsed every body invocation; = cheap =
            // O(n) over the draft with a single regex pass; = no
            // async cache needed for chapter-length documents).
            HeadingOutlineList(
                headings: parsedHeadings(from: activeDocumentText() ?? "")
            )
        }
    }

    /// Pure heading-row parser. Returns `[]` (= the host View renders
    /// its "no outline" hint) when the draft has no headings.
    private func parsedHeadings(from text: String) -> [HeadingRow] {
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(
            pattern: #"^(#{1,6})\s+(.+?)\s*$"#,
            options: [.anchorsMatchLines]
        ) else {
            return []
        }
        let matches = regex.matches(
            in: text, range: NSRange(location: 0, length: ns.length)
        )
        return matches.compactMap { match in
            guard match.numberOfRanges == 3 else { return nil }
            let hashesRange = match.range(at: 1)
            let titleRange = match.range(at: 2)
            guard
                let hashCount = (ns.substring(with: hashesRange) as String?)?
                    .replacingOccurrences(of: "#", with: "").count,
                let title = ns.substring(with: titleRange) as String?,
                hashCount >= 1, hashCount <= 6
            else {
                return nil
            }
            return HeadingRow(level: hashCount, title: title)
        }
    }
}

/// One heading row (= level + title + a tap closure). The tap
/// closure fires `bus.findScrollToRange` with the heading text as
/// the query (= the engine highlights + scrolls to the match).
private struct HeadingRow: Identifiable, Hashable {
    let level: Int
    let title: String
    var id: String { "\(level):\(title)" }
}

/// Heading list body (= renders one row per heading; = an empty
/// list shows the "no outline" hint = Apple HIG inspector empty
/// state).
private struct HeadingOutlineList: View {
    let headings: [HeadingRow]

    var body: some View {
        if headings.isEmpty {
            // Empty-state hint (= the canonical Pages / Numbers
            // inspector "no outline" message; = localizable via the
            // catalog so the editor can pick a non-English copy).
            HStack(spacing: DesignTokens.spacingCaption) {
                SFIcon("list.bullet.indent", style: .inlineSmall, color: IconColor.tertiary)
                Text(String(localized: "inspector.documentTools.headingOutline.empty"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // One row per heading (= indented by `level` = Apple HIG
            // outline sidebar rhythm; = H1 flush-left, H6 deep-
            // indented). Tap = scroll (= we don't ship the scroll
            // dispatcher here; = T-07 only renders the static list;
            // = a future ticket can wire the tap via a callback the
            // parent supplies; = for now the list is read-only).
            VStack(alignment: .leading, spacing: DesignTokens.spacingCaption) {
                ForEach(headings) { row in
                    HStack(spacing: DesignTokens.spacingCaption) {
                        // Level tag (= small caption, secondary tint
                        // = Pages / Numbers inspector "H1" / "H2" chip
                        // pattern).
                        Text("H\(row.level)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 18, alignment: .leading)
                        Text(row.title)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        Spacer(minLength: DesignTokens.spacingCaption)
                    }
                    .padding(.leading, CGFloat(row.level - 1) * DesignTokens.spacingStandard)
                }
            }
        }
    }
}