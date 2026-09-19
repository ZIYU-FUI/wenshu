//
//  ToolResultClassification.swift · Wenshu · P2-TOOL-RESULT-CLASSIFICATION-HERMES-PORT (2026-09-19)
//
//  Shared helpers for classifying tool result payloads.
//  Faithful 1:1 port of hermes
//  `agent/tool_result_classification.py` (26 LOC Python).
//
//  Per AGENTS.md §11.3 wenshu-side wins:
//
//  Hermes centralizes the "did this tool result actually land
//  a file mutation on disk" check (= so the trajectory-normalize
//  layer can record the exact set of files the run touched).
//  Hermes has 2 specific tools that count as file-mutating
//  (`write_file` + `patch`) and the success criterion differs per
//  tool (= `write_file` returns a `bytes_written` field;
//  `patch` returns a `success: true` field).
//
//  Wenshu-side wins per AGENTS.md §11.3:
//  - wenshu's FileTools.swift owns the actual file mutation
//    layer (= hermes's `write_file` + `patch` tools map to
//    wenshu's `FileTools.writeFile` + `FileTools.patchFile`).
//  - The hermes tool name set `FILE_MUTATING_TOOL_NAMES =
//    {"write_file", "patch"}` is preserved 1:1 (= wenshu's
//    FileTools uses the same canonical names).
//  - The JSON parsing + `error` field check (= hermes
//    `data.get("error")` = the result indicates an error)
//    is preserved.
//  - The result-shape contract (= `bytes_written` for write_file,
//    `success: true` for patch) is preserved 1:1.
//
//  Per AGENTS.md §11 hard rule: Apple Foundation only. No
//  third-party imports.
//

import Foundation

// MARK: - File-mutating tool names

/// Set of wenshu tool names that count as file-mutating
/// (= hermes `FILE_MUTATING_TOOL_NAMES` at
/// `agent/tool_result_classification.py` L9).
///
/// Wenshu-side wins: the wenshu FileTools surface uses these
/// exact canonical names (= `FileTools.writeFile` + 
/// `FileTools.patchFile` in `Core/Tools/FileTools.swift`).
public let fileMutatingToolNames: Set<String> = ["write_file", "patch"]

// MARK: - Public API

/// Pure-function: return true when a file mutation result proves
/// the write landed (= hermes `file_mutation_result_landed` at
/// `agent/tool_result_classification.py` L12-L25).
///
/// - Parameters:
///   - toolName: The tool that produced the result.
///   - result: The tool result payload (= typically a JSON
///     string from the tool executor).
/// - Returns: true when the tool was a file-mutating tool AND
///   the result indicates the mutation succeeded (= for
///   `write_file`: a `bytes_written` field is present and no
///   `error` field; for `patch`: `success: true` and no
///   `error` field).
///
/// Wenshu-side wins: tool names are wenshu's canonical names
/// (= match the names registered in `Core/Tools/FileTools.swift`).
public func fileMutationResultLanded(toolName: String, result: Any) -> Bool {
    guard fileMutatingToolNames.contains(toolName) else {
        return false
    }
    guard let resultString = result as? String else {
        return false
    }
    guard let data = try? JSONSerialization.jsonObject(
        with: Data(resultString.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    ) as? [String: Any] else {
        return false
    }
    if data["error"] != nil {
        return false
    }
    switch toolName {
    case "write_file":
        return data["bytes_written"] != nil
    case "patch":
        return data["success"] as? Bool == true
    default:
        return false
    }
}
