// ToolActivity.swift
//
// Turns a tool call into a sentence the user can read.
//
// The point is not decoration. A reply that arrives as one block of text
// leaves the reader guessing what the assistant did while producing it.
// Hermes answers that by making the work visible: the model emits action and
// result markers, and the interface renders each one as its own labelled
// block.
//
// There are two ways to know what happened, and they are not equally
// trustworthy. The model can describe itself in its own reasoning text, and
// a tool call is a fact the program recorded. A fact is the better source,
// so the activity is derived from the call itself and the model's own prose
// is only a fallback.
//
// The descriptions are deliberately short and in the present tense, because
// they read as a running log: "Reading the third chapter", "Saved the
// outline".

import Foundation
import WenshuData

/// One observable step in the agent's work.
struct ToolActivity: Identifiable, Equatable, Sendable {
    /// What kind of step this is.
    enum Kind: Equatable, Sendable {
        /// The assistant started doing something.
        case action
        /// The assistant finished doing something.
        case result
    }

    let id: String
    let kind: Kind
    /// The sentence, in the user's language.
    let text: String

    static func == (lhs: ToolActivity, rhs: ToolActivity) -> Bool {
        lhs.id == rhs.id && lhs.kind == rhs.kind && lhs.text == rhs.text
    }
}

extension ToolActivity {
    /// The activity a reply's parts recorded.
    ///
    /// A tool call becomes an action line; the matching result becomes a
    /// result line under it. A call with no result yet (= still running)
    /// contributes only the action, which is the honest description of a
    /// step that has not finished.
    static func activity(from parts: [ChatMessagePart]) -> [ToolActivity] {
        var steps: [ToolActivity] = []
        var pending: [String: ToolActivity] = [:]

        for part in parts {
            switch part.kind {
            case .toolUse(let use):
                let step = ToolActivity(
                    id: "action-\(use.id.rawValue)",
                    kind: .action,
                    text: ToolActivityNarrator.action(toolName: use.name, arguments: use.args)
                )
                steps.append(step)
                pending[use.id.rawValue] = step
            case .toolResult(let result):
                let text = ToolActivityNarrator.result(
                    toolName: toolName(forToolUseID: result.toolUseID, in: parts),
                    output: result.content
                )
                steps.append(
                    ToolActivity(id: "result-\(result.toolUseID.rawValue)", kind: .result, text: text)
                )
            case .text, .reasoning, .plan:
                break
            }
        }
        return steps
    }

    /// The name of the tool a result belongs to.
    private static func toolName(forToolUseID id: ToolCallID, in parts: [ChatMessagePart]) -> String {
        for part in parts {
            if case .toolUse(let use) = part.kind, use.id == id {
                return use.name
            }
        }
        return "tool"
    }
}

/// Builds the activity sentences for a tool call.
enum ToolActivityNarrator {
    /// The sentence for a tool the assistant just called.
    ///
    /// The arguments matter here: "Reading a file" says less than "Reading
    /// chapter-03.md", and the second one tells the reader whether the
    /// assistant touched the chapter they were worried about.
    static func action(toolName: String, arguments: String) -> String {
        let target = primaryArgument(from: arguments)
        switch toolName {
        case "ReadFile", "read_file":
            return target.map { "Reading \($0)" } ?? "Reading a file"
        case "WriteFile", "write_file":
            return target.map { "Writing \($0)" } ?? "Writing a file"
        case "writeBookDoc":
            return target.map { "Writing \($0)" } ?? "Writing the document"
        case "book_chapter", "book_edit_chapter":
            return target.map { "Editing \($0)" } ?? "Editing a chapter"
        case "book_outline":
            return "Building the outline"
        case "book_entity":
            return target.map { "Looking up \($0)" } ?? "Looking up story entities"
        case "web_search":
            return target.map { "Searching the web for \($0)" } ?? "Searching the web"
        case "web":
            return target.map { "Fetching \($0)" } ?? "Fetching a page"
        case "process", "run_command":
            return "Running a command"
        case "todo", "todo_hermes":
            return "Updating the task list"
        case "llm_wiki":
            return "Consulting the knowledge base"
        case "reference_library":
            return "Checking the reference library"
        case "delegate_research":
            return "Delegating research"
        case "background_review":
            return "Running a background review"
        case "ParagraphAI":
            return "Drafting a passage"
        case "kanban":
            return "Updating the board"
        case "vision":
            return "Looking at an image"
        default:
            return target.map { "Using \(toolName) on \($0)" } ?? "Using \(toolName)"
        }
    }

    /// The sentence for a finished tool call.
    static func result(toolName: String, output: String) -> String {
        let summary = summarize(output)
        switch toolName {
        case "ReadFile", "read_file":
            return summary.map { "Read \($0)" } ?? "Finished reading"
        case "WriteFile", "write_file", "writeBookDoc":
            return summary.map { "Saved \($0)" } ?? "Saved the file"
        case "book_chapter", "book_edit_chapter":
            return summary.map { "Updated \($0)" } ?? "Updated the chapter"
        case "web_search":
            return summary.map { "Found \($0)" } ?? "Searched the web"
        case "web":
            return summary.map { "Fetched \($0)" } ?? "Fetched the page"
        case "process", "run_command":
            return summary.map { "Command finished: \($0)" } ?? "Command finished"
        default:
            return summary.map { "\(toolName) finished: \($0)" } ?? "\(toolName) finished"
        }
    }

    /// The most useful argument for a sentence: a path, a query, a title.
    ///
    /// The argument set differs per tool, so the keys are tried in order of
    /// how much they tell the reader. A missing key is not an error: the
    /// sentence still works without a target.
    private static func primaryArgument(from arguments: String) -> String? {
        guard let data = arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        for key in ["path", "file_path", "filePath", "filepath", "title", "name", "query", "chapter", "chapter_title", "url", "command"] {
            if let value = object[key] as? String, !value.isEmpty {
                return shorten(value)
            }
        }
        return nil
    }

    /// A one-line digest of a tool result.
    private static func summarize(_ output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        return shorten(firstLine)
    }

    /// Keep a value short enough to read in a label.
    ///
    /// A long path or a whole result body would wrap the line and push the
    /// rest of the log down, so the tail is dropped and the head kept: the
    /// beginning of a path names the file, which is the part the reader
    /// needs.
    private static func shorten(_ value: String) -> String {
        let limit = 48
        guard value.count > limit else { return value }
        return String(value.prefix(limit - 1)) + "…"
    }
}
