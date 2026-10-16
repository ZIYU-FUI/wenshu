// SidebarIconResolver.swift · Wenshu
//
// Maps a sidebar row's title to the SF Symbol matching the title's
// pinyin first letter, per boss 2026-10-16 directive
// "目录树的 ICON, 根据目录项的首字的拼音首字母, 匹配 SF 字符的
//  A-Z 的 26 个字母字符 a.circle".
//
// Implementation layers (in priority order):
//   1. Hand-curated pinyin table for the high-frequency wenshu
//      sidebar titles (= "书架", "从这里开始", "Reference Library",
//      etc.). These show on every user's sidebar; = explicit
//      entries guarantee canonical mapping for the canonical
//      labels.
//   2. CFStringTransform with the "Han-Latin" identifier
//      (= the AUTOMATIC layer). macOS returns a Latin
//      transliteration with tone marks ("qīng míng"); = the
//      first A-Z alphabetic character is the pinyin first
//      letter. This handles ARBITRARY USER-ENTERED TITLES =
//      new shelves, books, folders the user creates at
//      runtime, with NO resolver knowledge required up front.
//   3. Layer 2 produced nothing (= pure symbols/digits).
//      Scan the title's own raw alphabetic characters. Last
//      fallback = `circle.dotted.circle` (= SF Symbol
//      dotted-circle placeholder; = per boss 2026-10-16 OOB
//      "宁可有一个替代, 也不能随便安一个 A": never guess a
//      letter; = if the resolver can't pin a real first
//      letter, surface the dotted-circle placeholder).
//
// Implementation note on Swift type shadowing: this module
// defines its own `Character` struct (= the wenshu novel-
// character data model in `Features/Library/Model/Character.swift`)
// which shadows Swift's built-in `Swift.Character` throughout
// the wenshu module. The previous attempt to dodge the
// shadowing via fully-qualified `Swift.Character` was
// INSUFFICIENT: the wenshu Character still wins the overload
// resolution at the call site of `alphabet.contains(character)`,
// so the set lookup silently returned `false` for every input
// (= every sidebar row hit the dotted-circle fallback, even
// the hand-curated ones). The fix below is to use `String`
// (= 1-character String) for ALL inter-function values; = the
// String pipeline has no Character ambiguity.

import Foundation
import CoreFoundation

enum SidebarIconResolver {
    /// SF Symbol used when no pinyin first letter can be resolved.
    /// (= boss 2026-10-16 OOB explicit fallback. Apple ships this
    /// in SF Symbols 6 on macOS 14+.)
    static let unresolvedSymbol: String = "circle.dotted.circle"

    /// Hand-curated override table for the most common wenshu
    /// sidebar titles (= canonical labels). Layer 2 covers all
    /// other titles, including user-authored entries.
    ///
    /// Storage: `(String-title, single-letter-String)`. We use
    /// `String` (= 1-character String) instead of `Character`
    /// throughout this file to avoid the project's `Character`
    /// shadowing conflict with `Swift.Character`.
    private static let handCurated: [(String, String)] = [
        ("书架",       "S"),
        ("从这里开始",  "C"),
        ("角色",       "J"),
        ("章节大纲",   "Z"),
        ("小说正文",   "X"),
        ("小说草稿",   "X"),
        ("素材库",     "S"),
        ("资料库",     "Z"),
        ("Reference Library", "R"),
    ]

    /// Set of "A".."Z" uppercase single-Character Strings.
    /// (= the legal first-letter set; = used to validate
    /// transliteration output.)
    private static let alphabet: Set<String> = {
        var set = Set<String>()
        for scalar in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".unicodeScalars {
            set.insert(String(scalar))
        }
        return set
    }()

    /// Resolve a title to its SF Symbol. The single public
    /// entry point: handles the 3-layer fallback chain and
    /// returns the dotted-circle placeholder when no A-Z
    /// first letter can be identified.
    static func sfSymbol(forTitle title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return unresolvedSymbol }

        // Layer 1: hand-curated lookup (= exact match for
        // canonical labels).
        if let letter = handCurated.first(where: { $0.0 == trimmed })?.1,
           alphabet.contains(letter) {
            return letter.lowercased() + ".circle"
        }

        // Layer 2: CFStringTransform transliteration (= the
        // AUTOMATIC pinyin fallback for any user-authored title).
        // macOS returns "qīng míng" or similar Latin with tone
        // marks; = the first A-Z single-Character String in the
        // result is the pinyin first letter.
        let transliterated = transliterateToLatin(trimmed)
        for scalar in transliterated.unicodeScalars {
            // Build 1-character `String` candidates (= ASCII
            // upper/lower variants). The `String(scalar)` form
            // is the decoder-overload-free way (= avoids the
            // project's `Character` shadowing).
            let candidates: [String] = [
                String(scalar),
                String(scalar).uppercased(),
            ]
            for letter in candidates where alphabet.contains(letter) {
                return letter.lowercased() + ".circle"
            }
        }

        // Layer 3: scan the title's OWN raw alphabetic characters
        // (= e.g. "Project A 计划" → "P"). If none either, fall
        // through to the unresolved placeholder.
        for scalar in trimmed.unicodeScalars {
            let letter = String(scalar).uppercased()
            if alphabet.contains(letter) {
                return letter.lowercased() + ".circle"
            }
        }

        // Per boss 2026-10-16 OOB "宁可有一个替代, 也不能随便安一
        // 个 A": never guess a letter. Return the dotted-circle
        // placeholder (= signals "no first letter identified").
        return unresolvedSymbol
    }

    /// Apply CFStringTransform with the "Han-Latin" identifier
    /// (= Apple's public API for Chinese-to-Latin transliteration;
    /// = the closest Apple-public pinyin approximation). Tone
    /// marks are retained (= `qīng míng`); = the caller iterates
    /// the result to find the first alphabetic character.
    ///
    /// Note: the constant exported by CoreFoundation as
    /// `kCFStringTransformMandarinToLatin` (= a C identifier not
    /// exposed directly to Swift on this toolchain) maps to the
    /// C string literal `"Han-Latin"`. Building the identifier
    /// via `CFStringCreateWithCString` is the portable bridge.
    ///
    /// This is the automatic-match layer that handles every
    /// user-authored title the resolver has never seen before.
    private static func transliterateToLatin(_ source: String) -> String {
        let mutable = NSMutableString(string: source)
        guard let transform = CFStringCreateWithCString(
            kCFAllocatorDefault,
            "Han-Latin",
            CFStringEncoding(kCFStringEncodingASCII)
        ) else {
            return source
        }
        guard CFStringTransform(
            mutable,
            nil,
            transform,
            false
        ) else {
            return source
        }
        return mutable as String
    }
}
