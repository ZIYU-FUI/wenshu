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
public struct ChatSlashCommandRow: Identifiable, Equatable, Sendable {
    public let id: String  // = command name (= unique)
    public let name: String
    public let description: String
    public let category: String

    public init(command: SkillAdapter.HubCommand) {
        self.id = command.name
        self.name = command.name
        self.description = command.description
        self.category = command.category
    }

    /// Format for display in the popup: "/<name>  <description>"
    /// (= monospaced name + secondary description, matches the
    /// Hermes desktop slash menu).
    public var displayLabel: String {
        return "/\(name)"
    }
}

/// Pure helper (= nonisolated + sendable) that filters the full
/// hub commands list down to a row set matching the user's
/// in-progress slash prefix (= "/rev" -> ["review", "rewrite"]).
///
/// Visible as `static` (= no instance state) so tests can call
/// it without spinning up a SkillAdapter.
public enum ChatSlashCommandAutocompleteEngine {

    /// Filter `allCommands` to those whose `name` starts with
    /// `prefix` (case-insensitive). When `prefix` is empty (= the
    /// user just typed `/`), returns the first 8 (= a sensible
    /// default that prevents the popup from filling the screen).
    /// - Parameter prefix: the text after the leading `/`
    ///   (= without the slash itself). Empty string = show top 8.
    /// - Parameter allCommands: full hub commands list to filter.
    /// - Parameter maxResults: cap on returned rows (= default 8;
    ///   = visible rows fit on a 4-line list at 13 PT).
    public static func filter(
        prefix: String,
        allCommands: [SkillAdapter.HubCommand],
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
    public static func shouldShow(input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("/")
            && !trimmed.contains(" ")  // show only when no args yet
    }

    /// Extract the prefix after `/` (= e.g. "/rev" -> "rev").
    public static func prefixFromInput(_ input: String) -> String {
        guard input.hasPrefix("/") else { return "" }
        return String(input.dropFirst())
    }
}

/// SwiftUI view that renders the autocomplete popup. Designed to
/// be placed in a `.overlay(alignment: .topLeading)` above the
/// chat TextField (= sits flush against the TextField top edge,
/// = the standard "autocomplete popup" pattern).
public struct ChatSlashCommandAutocomplete: View {
    public let rows: [ChatSlashCommandRow]
    public let onSelect: (ChatSlashCommandRow) -> Void

    public init(
        rows: [ChatSlashCommandRow],
        onSelect: @escaping (ChatSlashCommandRow) -> Void
    ) {
        self.rows = rows
        self.onSelect = onSelect
    }

    public var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    Button {
                        onSelect(row)
                    } label: {
                        HStack(spacing: 8) {
                            Text(row.displayLabel)
                                .font(.system(.caption, design: .monospaced))
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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if row.id != rows.last?.id {
                        Divider()
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .frame(maxWidth: 360)
        }
    }
}