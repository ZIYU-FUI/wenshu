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
//   2. CFStringTransform with kCFStringTransformMandarinToLatin
//      (= the AUTOMATIC layer). macOS returns a Latin
//      transliteration with tone numbers ("zhong1 guo2"); = the
//      first alphabetic character is the pinyin first letter.
//      This is what handles ARBITRARY USER-ENTERED TITLES = new
//      shelves, books, folders the user creates at runtime,
//      with NO resolver knowledge required up front.
//   3. Layer 2 produces no alphabetic character (= pure
//      symbols/digits). Scan the title's own raw alphabetic
//      characters. Last fallback = `circle.dotted.circle`
//      (= SF Symbol dotted-circle placeholder; = per boss
//      2026-10-16 OOB "宁可有一个替代, 也不能随便安一个 A":
//      never guess a letter; = if the resolver can't pin a
//      real first letter, surface the dotted-circle placeholder).
//
// NOTE on Swift type shadowing: this module defines its own
// `Character` struct (= the wenshu novel-character data model in
// `Features/Library/Model/Character.swift`). It shadows Swift's
// built-in `Swift.Character` throughout the wenshu module. Every
// reference to the Swift built-in character below is fully-
// qualified (= `Swift.Character`).

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

    /// Set of "A".."Z" Swift.Character values (= legal
    /// first-letter set; = used to validate transliteration
    /// output).
    private static let alphabet: Set<Swift.Character> = {
        var set = Set<Swift.Character>()
        let scalars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".unicodeScalars
        for scalar in scalars {
            set.insert(Swift.Character(scalar))
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
           let ch = letter.first {
            return sfSymbolForLetter(ch)
        }

        // Layer 2: CFStringTransform transliteration (= the
        // AUTOMATIC pinyin fallback for any user-authored title).
        // macOS returns "zhong1 guo2" or similar Latin with tone
        // numbers; = the first Swift.Character in the result
        // that's in [A-Z] is the pinyin first letter.
        let transliterated = transliterateToLatin(trimmed)
        // Walk the result character-by-character via the Unicode
        // scalar view (= this returns Swift.Character directly,
        // = avoids the project's `Character` shadowing). The
        // module-local `Character` type (= the wenshu novel-
        // character data model) shadows Swift's built-in
        // Swift.Character within this module's scopes.
        for scalar in transliterated.unicodeScalars {
            let character = Swift.Character(scalar)
            if alphabet.contains(character) {
                return sfSymbolForLetter(character)
            }
        }

        // Layer 3: scan the title's OWN raw alphabetic characters
        // (= e.g. "Project A 计划" → "P"). If none either, fall
        // through to the unresolved placeholder.
        for scalar in trimmed.unicodeScalars {
            let character = Swift.Character(scalar)
            let upperString = String([character]).uppercased()
            if let upperChar = upperString.first,
               alphabet.contains(upperChar) {
                return sfSymbolForLetter(upperChar)
            }
        }

        // Per boss 2026-10-16 OOB "宁可有一个替代, 也不能随便安一
        // 个 A": never guess a letter. Return the dotted-circle
        // placeholder (= signals "no first letter identified").
        return unresolvedSymbol
    }

    /// Build the SF Symbol name for a single ASCII letter.
    /// `letter.circle` for letters A-Z (= legal first-letter set).
    /// The dotted-circle placeholder is the documented fallback
    /// path (= never rebuilt per call; = the `unresolvedSymbol`
    /// static).
    private static func sfSymbolForLetter(_ letter: Swift.Character) -> String {
        let upperString = String([letter]).uppercased()
        guard let upperChar = upperString.first,
              alphabet.contains(upperChar) else {
            return unresolvedSymbol
        }
        // Build the lowercase ASCII byte from the
        // Swift.Character's UTF-8 representation (= 1 byte
        // for A-Z) and route through String(bytes:encoding:)
        // so we never invoke String(Character) (= ambiguous
        // = with the project's `Character` shadowing).
        let bytes: [UInt8] = [UInt8(String([upperChar]).utf8.first ?? 65)]
        let letterString = String(bytes: bytes, encoding: .ascii)
            ?? "A"
        return "\(letterString.lowercased()).circle"
    }

    /// Apply CFStringTransform with the "Han-Latin" identifier
    /// (= Apple's public API for Chinese-to-Latin transliteration;
    /// = the closest Apple-public pinyin approximation). Tone
    /// numbers are retained (= `zhong1 guo2`); = the caller picks
    /// the first alphabetic character as the pinyin first letter.
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
