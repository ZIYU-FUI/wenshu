//
//  ToolInputParser.swift · Wenshu · v0.35 ticket 001 sub-step 6 followup
//
//  Single source of truth for tool input JSON parsing. Originally
//  each tool hand-rolled a regex-free substring scan (= fragile,
//  duplicated in ReadFileTool + WriteFileTool); extracted here per
//  Standards-axis S3 Duplicated Code smell.
//
//  Uses Apple Foundation JSONSerialization (= wenshu §11 hard rule:
//  Apple stack exclusive; no third-party parser).
//

import Foundation

/// Parses tool input JSON (= e.g. `{"path": "/absolute/path"}`).
public enum ToolInputParser {

    public enum ParseError: Error, CustomStringConvertible {
        case invalidJSON(String)
        case missingKey(String)
        case wrongType(key: String, expected: String, got: String)

        public var description: String {
            switch self {
                case .invalidJSON(let s): return "invalid JSON: \(s)"
                case .missingKey(let k): return "missing key: \(k)"
                case .wrongType(let k, let expected, let got):
                    return "key '\(k)' expected \(expected), got \(got)"
                }
        }
    }

    /// Parse input string into JSON dictionary. Throws ParseError if
    /// input is not a valid JSON object (= any other JSON shape).
    public static func parseDictionary(input: String) throws -> [String: Any] {
        guard let data = input.data(using: .utf8) else {
            throw ParseError.invalidJSON(input)
        }
        let obj: Any
        do {
            obj = try JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            )
        } catch {
            throw ParseError.invalidJSON(input)
        }
        guard let dict = obj as? [String: Any] else {
            throw ParseError.invalidJSON(input)
        }
        return dict
    }

    /// Extract String value for key. Throws if key missing or value not String.
    public static func requireString(_ dict: [String: Any], _ key: String) throws -> String {
        guard let value = dict[key] else {
            throw ParseError.missingKey(key)
        }
        guard let s = value as? String else {
            throw ParseError.wrongType(key: key, expected: "String", got: String(describing: type(of: value)))
        }
        return s
    }

    /// Extract optional String value (= returns nil if missing).
    public static func optionalString(_ dict: [String: Any], _ key: String) throws -> String? {
        guard let value = dict[key] else { return nil }
        guard let s = value as? String else {
            throw ParseError.wrongType(key: key, expected: "String", got: String(describing: type(of: value)))
        }
        return s
    }
}