//
//  ImportAgentPartEmitter.swift · wenshu
//
//  Turns the agent's stream into the parts the import sheet renders.
//
//  The chat zone already knows how to read a stream: its accumulator
//  coalesces the text and the reasoning into the trailing part of their
//  kind, and keeps the tool calls and the tool results apart (= the
//  reader watches for the boundary between one tool finishing and the
//  next starting). The import sheet reads the same way, so the emitter
//  uses that accumulator and reports the difference each time.
//
//  The tool call's arguments are summarised on the way out: the write
//  tool carries the whole document body as one of its arguments, and
//  showing that verbatim would bury the reply.
//

import Foundation
import WenshuAgent
import WenshuData

/// Collects the agent's stream into the parts the sheet shows.
final class ImportAgentPartEmitter: @unchecked Sendable {

    private let accumulator = StreamingAccumulator()

    /// How many of the accumulator's parts were already reported.
    ///
    /// The tool calls and the tool results are whole parts, so the count
    /// is enough for them.
    private var reportedParts = 0

    /// How much of the trailing text part was already reported.
    private var reportedText = 0

    /// How much of the trailing reasoning part was already reported.
    private var reportedReasoning = 0

    /// Read one stream block and return the parts it produced.
    func consume(_ block: LLMBlock) -> [ImportAgentPart] {
        switch block {
        case .text(let text):
            accumulator.appendText(text)
        case .thinking(let text, _):
            accumulator.appendReasoning(text)
        case .toolUse(let id, let name, let input):
            accumulator.appendPart(
                .toolUse(
                    id: ToolCallID(rawValue: id),
                    name: name,
                    args: Self.summarise(tool: name, input: input)
                )
            )
        case .toolResult(let toolUseID, let output):
            accumulator.appendPart(
                .toolResult(
                    toolUseID: ToolCallID(rawValue: toolUseID),
                    content: output,
                    isError: false
                )
            )
        }
        return drain()
    }

    /// The parts that were produced since the last call.
    private func drain() -> [ImportAgentPart] {
        let parts = accumulator.snapshotParts()
        var out: [ImportAgentPart] = []

        // The whole parts (= the tool calls and the tool results) that
        // were not reported yet.
        if parts.count > reportedParts {
            for part in parts[reportedParts...] {
                if case .text = part.kind { continue }
                if case .reasoning = part.kind { continue }
                out.append(ImportAgentPart(part: part))
            }
            reportedParts = parts.count
        }

        // The trailing text part may have grown.
        if case .text(let text)? = parts.last?.kind, text.count > reportedText {
            out.append(
                ImportAgentPart(
                    kind: .text,
                    text: String(text.dropFirst(reportedText))
                )
            )
            reportedText = text.count
        }

        // The trailing reasoning part may have grown.
        if case .reasoning(let reasoning)? = parts.last?.kind, reasoning.count > reportedReasoning {
            out.append(
                ImportAgentPart(
                    kind: .reasoning,
                    text: String(reasoning.dropFirst(reportedReasoning))
                )
            )
            reportedReasoning = reasoning.count
        }

        return out
    }

    /// The tool's arguments, summarised.
    ///
    /// The write tool's arguments carry the whole document body, so the
    /// summary names the tool and the path it wrote, not the body.
    static func summarise(tool name: String, input: String) -> String {
        guard let data = input.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return name
        }
        var shown: [String] = []
        for key in ["relativePath", "path", "filePath"] {
            if let value = object[key] as? String, !value.isEmpty {
                shown.append(value)
                break
            }
        }
        return shown.isEmpty ? name : "\(name): \(shown.joined(separator: ", "))"
    }
}
