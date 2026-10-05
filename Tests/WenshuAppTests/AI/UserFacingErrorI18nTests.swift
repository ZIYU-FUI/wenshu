//
//  UserFacingErrorI18nTests.swift · Wenshu · cjk-i18n-sweep (2026-09-25)
//
//  Verifies that the UserFacingError 12-case surface routes through
//  String(localized:) (= hermes-style: every user-visible string lives in
//  the Localizable.strings catalogs, never hard-coded in source).
//  Same parity pattern as PlanModeI18nTests: read both locales via
//  plutil, assert the keys exist + the EN/ZH values differ (= actual
//  translation, not copy-paste).
//
//  Also verifies behavior: every UserFacingError case returns a
//  non-empty errorDescription that survives .localizedDescription
//  (= LocalizedError contract per Apple Foundation).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("UserFacingError i18n parity (cjk-i18n-sweep 2026-09-25)")
struct UserFacingErrorI18nTests {

    private func readStrings(at path: String) -> [String: String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        process.arguments = ["-p", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [:] }
        let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var dict: [String: String] = [:]
        let pattern = try? NSRegularExpression(
            pattern: "^\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\s*=>\\s*\"((?:[^\"\\\\]|\\\\.)*)\"",
            options: [.anchorsMatchLines]
        )
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        pattern?.enumerateMatches(in: raw, options: [], range: range) { match, _, _ in
            guard let m = match, m.numberOfRanges == 3 else { return }
            guard let keyRange = Range(m.range(at: 1), in: raw),
                  let valRange = Range(m.range(at: 2), in: raw) else { return }
            dict[String(raw[keyRange])] = String(raw[valRange])
        }
        return dict
    }

    /// All 19 error.* keys must exist in BOTH en + zh-Hans catalogs.
    static let requiredKeys = [
        "error.network.failure",
        "error.api_key.missing",
        "error.api_key.invalid",
        "error.rate_limit.generic",
        "error.rate_limit.provider",
        "error.output_too_long",
        "error.model_refusal.with_reason",
        "error.model_refusal.generic",
        "error.context_too_long.with_count",
        "error.context_too_long.generic",
        "error.file_write.with_path",
        "error.file_write.generic",
        "error.database.operation_failed",
        "error.invalid_input.with_field_reason",
        "error.invalid_input.with_reason",
        "error.invalid_input.generic",
        "error.timeout.with_seconds",
        "error.timeout.generic",
        "error.unknown",
    ]

    @Test func all_keys_in_en_locale() {
        let en = readStrings(
            at: "Sources/WenshuApp/Resources/en.lproj/Localizable.strings"
        )
        for key in Self.requiredKeys {
            #expect(en[key] != nil,
                    "expected \(key) in en.lproj/Localizable.strings")
        }
    }

    @Test func all_keys_in_zh_locale() {
        let zh = readStrings(
            at: "Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings"
        )
        for key in Self.requiredKeys {
            #expect(zh[key] != nil,
                    "expected \(key) in zh-Hans.lproj/Localizable.strings")
        }
    }

    /// EN and ZH values must actually translate (= not copy-paste).
    /// Format-string keys can share %@ / %d placeholders, but the
    /// surrounding prose must differ between locales.
    @Test func locales_are_actual_translations() {
        let en = readStrings(
            at: "Sources/WenshuApp/Resources/en.lproj/Localizable.strings"
        )
        let zh = readStrings(
            at: "Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings"
        )
        for key in Self.requiredKeys {
            guard let enVal = en[key], let zhVal = zh[key] else { continue }
            #expect(enVal != zhVal,
                    "expected EN and ZH to differ for \(key)")
        }
    }

    /// Format-string keys must contain the expected placeholders.
    @Test func format_placeholders_present() {
        let en = readStrings(
            at: "Sources/WenshuApp/Resources/en.lproj/Localizable.strings"
        )
        #expect(en["error.rate_limit.provider"]?.contains("%@") == true,
                "rate_limit.provider must use %@ for the provider name")
        #expect(en["error.output_too_long"]?.contains("%@") == true,
                "output_too_long must use %@ for the model name")
        #expect(en["error.context_too_long.with_count"]?.contains("%d") == true,
                "context_too_long.with_count must use %d for the token count")
        #expect(en["error.file_write.with_path"]?.contains("%@") == true,
                "file_write.with_path must use %@ for the file path")
        #expect(en["error.database.operation_failed"]?.contains("%@") == true,
                "database.operation_failed must use %@ for the operation name")
        #expect(en["error.invalid_input.with_field_reason"]?.contains("%@") == true,
                "invalid_input.with_field_reason must use %@ for the field+reason")
        #expect(en["error.timeout.with_seconds"]?.contains("%d") == true,
                "timeout.with_seconds must use %d for the seconds count")
    }

    // MARK: - Behavior: UserFacingError returns non-empty localized text

    @Test func every_case_returns_non_empty_description() {
        let cases: [UserFacingError] = [
            .networkFailure(),
            .apiKeyMissing(provider: "Anthropic"),
            .apiKeyInvalid(provider: "OpenAI"),
            .rateLimited(provider: ""),
            .rateLimited(provider: "DeepSeek"),
            .outputTooLong(model: "gpt-5"),
            .modelRefusal(reason: "policy"),
            .modelRefusal(reason: nil),
            .contextTooLong(tokenCount: 8000),
            .contextTooLong(tokenCount: nil),
            .fileWriteFailure(path: "/tmp/x"),
            .fileWriteFailure(path: nil, underlying: nil),
            .databaseError(operation: "fetch"),
            .invalidUserInput(field: "name", reason: "empty"),
            .invalidUserInput(field: "name", reason: nil),
            .invalidUserInput(field: nil, reason: nil),
            .timeout(operation: "search", seconds: 5.0),
            .timeout(operation: "search", seconds: nil),
            .unknown(underlying: nil),
        ]
        for c in cases {
            let desc = c.errorDescription
            #expect(desc != nil, "UserFacingError case \(c) returned nil errorDescription")
            #expect(desc?.isEmpty == false, "UserFacingError case \(c) returned empty errorDescription")
        }
    }

    /// LocalizedError contract: errorDescription must be reachable
    /// via .localizedDescription (= Apple Foundation pattern).
    @Test func conforms_to_localized_error_contract() {
        let err: Error = UserFacingError.networkFailure()
        let localized = err.localizedDescription
        #expect(localized.isEmpty == false,
                "LocalizedError.localizedDescription must be non-empty")
    }
}