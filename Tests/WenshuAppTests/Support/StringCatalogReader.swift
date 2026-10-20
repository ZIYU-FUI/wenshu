// StringCatalogReader.swift
//
// Reads Localizable.xcstrings, which is the only localization source
// (Sources/WenshuApp/Resources/{en,zh-Hans}.lproj/Localizable.strings is
// gone; the build compiles the catalog with xcstringstool).
//
// Eight test files needed this and each had grown its own reader: two ran
// plutil against the deleted files, one parsed plutil output with a regex,
// one read the catalog correctly. Four ways to read one file is how they
// drifted apart in the first place.

import Foundation

enum StringCatalogReader {
    /// Key to translated value for one locale.
    ///
    /// A locale with no entry for a key is absent rather than empty, so a test
    /// asserting on a value fails when the translation is missing instead of
    /// passing against an empty string.
    static func strings(language: String) -> [String: String] {
        guard let data = catalogData() else { return [:] }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["strings"] as? [String: [String: Any]]
        else { return [:] }
        var result: [String: String] = [:]
        for (key, entry) in entries {
            guard let localizations = entry["localizations"] as? [String: Any],
                  let locale = localizations[language] as? [String: Any],
                  let unit = locale["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String
            else { continue }
            result[key] = value
        }
        return result
    }

    /// Keys present in the catalog regardless of translation state. A key with
    /// only one locale still counts as declared.
    static func declaredKeys() -> Set<String> {
        guard let data = catalogData() else { return [] }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["strings"] as? [String: Any]
        else { return [] }
        return Set(entries.keys)
    }

    private static func catalogData() -> Data? {
        let path = SourceLocator.path("Sources/WenshuApp/Resources/Localizable.xcstrings")
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    /// Accepts either a locale ("zh-Hans") or a path ending in
    /// "zh-Hans.lproj/Localizable.strings", because the call sites were
    /// written against the old files and several still pass a path.
    static func language(from pathOrLanguage: String) -> String? {
        if pathOrLanguage == "en" || pathOrLanguage == "zh-Hans" {
            return pathOrLanguage
        }
        if pathOrLanguage.contains("zh-Hans") { return "zh-Hans" }
        if pathOrLanguage.contains("en.lproj") || pathOrLanguage.hasSuffix("en") { return "en" }
        return nil
    }

    /// Read by locale or by legacy path.
    static func strings(from pathOrLanguage: String) -> [String: String] {
        guard let language = language(from: pathOrLanguage) else { return [:] }
        return strings(language: language)
    }
}