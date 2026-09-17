//
//  NewLibraryOutlineView+DisclosureState.swift · Wenshu · v1.28 C3.6.1
//
//  v1.28 C3.6.1: extract the disclosure-state codec helpers (= encodeDisclosureStates
//  + decodeDisclosureStates) from NewLibraryOutlineView.swift into a focused
//  extension file.
//
//  Originally at NewLibraryOutlineView.swift:1743-1767 (= 25 LOC: docstrings
//  + 2 functions + bodies). The helpers convert a [UUID: Bool] dictionary
//  (= which shelf is expanded in the outline view) to/from a JSON string
//  for persistence in UserDefaults.
//
//  Behavior preserved (= both helpers unchanged; = same logic; = same
//  return types).
//

import Foundation

extension NewLibraryOutlineView {
    /// Encode a [UUID: Bool] disclosure-state dictionary as a JSON string
    /// for UserDefaults persistence (= the disclosure state needs to
    /// survive across launches; = UserDefaults stores String values).
    func encodeDisclosureStates(_ states: [UUID: Bool]) -> String {
        // Empty string = no entries (= first-launch state). Empty dict
        // would round-trip as `{}` which is non-canonical.
        if states.isEmpty { return "" }
        let mapped: [String: Bool] = states.reduce(into: [:]) { acc, pair in
            acc[pair.key.uuidString] = pair.value
        }
        guard let data = try? JSONEncoder().encode(mapped),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return json
    }

    /// Decode a JSON string back into a [UUID: Bool] disclosure-state
    /// dictionary. Returns an empty dict on any failure (= malformed
    /// JSON, missing keys, wrong types; = the caller treats empty as
    /// "use default disclosure state").
    func decodeDisclosureStates(_ json: String) -> [UUID: Bool] {
        if json.isEmpty { return [:] }
        guard let data = json.data(using: .utf8) else { return [:] }
        guard let mapped = try? JSONDecoder().decode([String: Bool].self, from: data) else {
            return [:]
        }
        var result: [UUID: Bool] = [:]
        for (key, value) in mapped {
            guard let uuid = UUID(uuidString: key) else { continue }
            result[uuid] = value
        }
        return result
    }
}
