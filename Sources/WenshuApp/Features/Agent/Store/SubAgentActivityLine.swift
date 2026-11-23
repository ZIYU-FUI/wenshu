//
//  SubAgentActivityLine.swift · Wenshu
//
//  The one line that says what a sub-agent just did.
//
//  The card in the right column names the agent, the tool it is calling
//  and the task it was given. That leaves one question a reader asks
//  while watching a crew work: WHAT is the agent doing right now?
//  "Read" does not say WHICH file. This is the line that answers it.
//
//  Hermes' sub-agent row draws the same thing one line under the goal:
//  the child's LAST stream line (= its thinking, or its last tool
//  call), falling back to a waiting label when there is none.
//
//  The rules here are deliberately small:
//
//  - A tool call reads as the tool's name plus the ONE argument a
//    reader wants (= the path, the query, the pattern), = = never the
//    whole JSON blob.
//  - The agent's own words read as the line itself, = = because a
//    sentence it wrote says more about what it is doing than a label
//    could.
//  - A line is ONE line: = = the card's height does not change while
//    the agent runs.
//

import Foundation

/// The text of the card's activity line.
///
/// Pure: = = the caller says what happened, = = this says how it
/// reads. That is why it is a separate type (= = and not a line of
/// string surgery in the runner): = = the rule can be tested without a
/// running agent.
enum SubAgentActivityLine {
    /// The longest argument preview the line carries.
    ///
    /// A path longer than this is already unreadable at the card's
    /// width, = = and a long tail is the difference between "which file"
    /// and "nothing".
    static let maxArgumentCharacters = 48

    /// The line for a tool call.
    ///
    /// The argument's preview is the one argument that says what the
    /// call is about: = = a path, = = a query, = = a pattern, = = a
    /// title. The keys are read in the order a reader would name them
    /// (= = the path first), = = so the line does not depend on the
    /// JSON's key order.
    ///
    /// A call with no argument the line can name reads as the tool's
    /// name alone (= = which is still true, = = and better than
    /// nothing).
    static func text(toolName: String, input: String) -> String {
        let name = readableToolName(toolName)
        guard let argument = argumentPreview(from: input) else {
            return name
        }
        return "\(name) · \(argument)"
    }

    /// The line for the agent's own words.
    ///
    /// The words are taken as they are: = = the agent wrote them, = =
    /// and a reader following the agent wants the sentence, = = not a
    /// summary of it.
    static func text(thinking: String) -> String {
        let trimmed = thinking.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }

    /// The tool's name as the card's tool column already says it (= =
    /// "read_file" reads as "Read File", = = and "delegate_research"
    /// reads as "Delegate Research").
    ///
    /// The same shape the card's tool column already uses (= = so the
    /// two columns name one tool the same way), = = which is why the
    /// naming lives here and is used by both.
    static func readableToolName(_ tool: String) -> String {
        let words = tool
            .split(separator: "_")
            .filter { !$0.isEmpty }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return words.isEmpty ? tool : words.joined(separator: " ")
    }

    /// The one argument worth naming, = = or nil when the call carries
    /// none the line can use.
    ///
    /// The keys are read in the order a reader names them: = = the
    /// path, = = the file, = = the query, = = the pattern, = = the
    /// title, = = the text, = = the name. A call whose arguments are
    /// all numbers (= = a count, = = a line number) says nothing about
    /// what the agent is doing, = = so the line falls back to the
    /// tool's name.
    static func argumentPreview(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let arguments = object as? [String: Any]
        else {
            // Not JSON (= = a bare word): = = it is still the argument.
            return shorten(trimmed)
        }
        for key in argumentKeys {
            guard let value = arguments[key] else { continue }
            guard let text = previewText(for: value) else { continue }
            return shorten(text)
        }
        return nil
    }

    /// The keys that name what a call is about, = = in reading order.
    private static let argumentKeys = [
        "path", "file_path", "filePath", "filename", "file",
        "query", "pattern", "glob", "url", "uri",
        "title", "name", "text", "content", "prompt",
    ]

    /// One argument's text, = = or nil when the value is a number or a
    /// structure the line cannot say in one line.
    private static func previewText(for value: Any) -> String? {
        switch value {
        case let text as String:
            return text
        case let number as NSNumber:
            // A number says nothing about what the call is about (= = a
            // count, = = a limit, = = an offset).
            return nil
        case let list as [Any]:
            // A list of paths is worth naming when it is short (= = the
            // first one), = = and a long list is not.
            guard let first = list.first else { return nil }
            return previewText(for: first)
        default:
            return nil
        }
    }

    /// One line, = = so the card's height does not change while the
    /// agent runs.
    private static func shorten(_ text: String) -> String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flattened.count > maxArgumentCharacters else { return flattened }
        return String(flattened.prefix(maxArgumentCharacters)) + "…"
    }
}
