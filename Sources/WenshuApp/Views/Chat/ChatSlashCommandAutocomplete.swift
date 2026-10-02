//
//  ChatSlashCommandAutocomplete.swift · Wenshu · T18-SLASH-AUTOCOMPLETE (2026-09-18)
//
//  Hermes-style slash command autocomplete dropdown. Renders a
//  filtered list of hub commands above the chat TextField when the
//  user types `/` (= filtered by the prefix after `/`).
//
//  Apple HIG convention: inline suggestion popup (= same pattern as
//  macOS Mail / Messages / Slack slash command menus). Hidden when
//  no commands match. Tap a row to insert the full command into
//  the input (= `/commandName ` = trailing space so the user can
//  start typing the remainder immediately).
//
//  Hermes equivalent: the Hermes desktop UI shows a similar popup
//  in the chat composer when the user types `/`. This is the
//  wenshu-side equivalent (= implemented locally because the
//  chat composer's HStack layout is wenshu-owned per ADR-0009).
//

import SwiftUI

/// Per-row model for the autocomplete popup. Bundles the hub
/// command metadata + a stable id (= SwiftUI ForEach requires
/// Identifiable).
struct ChatSlashCommandRow: Identifiable, Equatable, Sendable {
    let id: String  // = command name (= unique)
    let name: String
    let description: String
    let category: String

    init(command: HubCommand) {
        self.id = command.name
        self.name = command.name
        self.description = command.description
        self.category = command.category
    }

    /// Format for display in the popup: "/<name>  <description>"
    /// (= monospaced name + secondary description, matches the
    /// Hermes desktop slash menu).
    var displayLabel: String {
        return "/\(name)"
    }
}

/// Pure helper (= nonisolated + sendable) that filters the full
/// hub commands list down to a row set matching the user's
/// in-progress slash prefix (= "/rev" -> ["review", "rewrite"]).
///
/// Visible as `static` (= no instance state) so tests can call
/// it without spinning up a SkillAdapter.
enum ChatSlashCommandAutocompleteEngine {

    /// Filter `allCommands` to those whose `name` starts with
    /// `prefix` (case-insensitive). When `prefix` is empty (= the
    /// user just typed `/`), returns the first 8 (= a sensible
    /// default that prevents the popup from filling the screen).
    /// - Parameter prefix: the text after the leading `/`
    ///   (= without the slash itself). Empty string = show top 8.
    /// - Parameter allCommands: full hub commands list to filter.
    /// - Parameter maxResults: cap on returned rows (= default 8;
    ///   = visible rows fit on a 4-line list at 13 PT).
    static func filter(
        prefix: String,
        allCommands: [HubCommand],
        maxResults: Int = 8
    ) -> [ChatSlashCommandRow] {
        let trimmed = prefix.trimmingCharacters(in: .whitespaces)
        let all = allCommands.map(ChatSlashCommandRow.init(command:))
        if trimmed.isEmpty {
            return Array(all.prefix(maxResults))
        }
        let lower = trimmed.lowercased()
        return Array(
            all
                .filter { $0.name.lowercased().hasPrefix(lower) }
                .prefix(maxResults)
        )
    }

    /// Whether the autocomplete popup should be visible given the
    /// current input text (= popup appears when the input is a
    /// slash-prefix and there are matching commands).
    /// - Parameter input: full textfield contents (= e.g. "/rev").
    static func shouldShow(input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("/")
            && !trimmed.contains(" ")  // show only when no args yet
    }

    /// Extract the prefix after `/` (= e.g. "/rev" -> "rev").
    static func prefixFromInput(_ input: String) -> String {
        guard input.hasPrefix("/") else { return "" }
        return String(input.dropFirst())
    }
}

/// SwiftUI view that renders the autocomplete popup. Designed to
/// be placed in a `.overlay(alignment: .topLeading)` above the
/// chat TextField (= sits flush against the TextField top edge,
/// = the standard "autocomplete popup" pattern).
struct ChatSlashCommandAutocomplete: View {
    let rows: [ChatSlashCommandRow]
    let onSelect: (ChatSlashCommandRow) -> Void

    init(
        rows: [ChatSlashCommandRow],
        onSelect: @escaping (ChatSlashCommandRow) -> Void
    ) {
        self.rows = rows
        self.onSelect = onSelect
    }

    var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    Button {
                        onSelect(row)
                    } label: {
                        HStack(spacing: DesignTokens.spacingStandard) {
                            Text(row.displayLabel)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                            Text(row.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(row.category)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, DesignTokens.spacingStandard)
                        .padding(.vertical, DesignTokens.spacingIconic)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if row.id != rows.last?.id {
                        Divider()
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .frame(maxWidth: 360)
        }
    }
}