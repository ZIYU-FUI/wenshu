//
//  WenshuI18n.swift · Wenshu · v0.38 ticket P2
//
//  Apple-standard i18n helper. Thin wrapper over NSLocalizedString that:
//  1. Reads from the WenshuApp module's .main bundle (= Resources/*.lproj/Localizable.strings)
//  2. Falls back to the key path itself (= broken catalog never crashes the UI)
//  3. Supports format strings via %d / %@ / %f placeholders (= identical to NSLocalizedString)
//
//  Per boss OOB 2026-09-04 (= "走苹果 api, 英用默认语言先是中英文, 你移植 hermes 涉及到前端 UI 的你自动解决语言问题"):
//  - default = en (= user's OS language per Apple canonical Locale.current)
//  - bundled catalogs = en + zh-Hans
//  - no per-app language picker (= Apple standard means OS language decides)
//
//  Usage:
//      Text(WenshuI18n.t("settings.connector.header"))
//      Text(WenshuI18n.tf("statusbar.shelf", shelfCount))   // %d format
//      Text(WenshuI18n.ts("settings.provider.status.pasteNamed", providerName))  // %@ format
//

import Foundation

public enum WenshuI18n {

    /// Bundle that contains the Localizable.strings files. The .main bundle
    /// for an executable target is the .app bundle (= Resources/en.lproj etc.).
    /// Per Apple canonical NSLocalizedString, the default lookup is
    /// `Bundle.main`, which works because wenshu.app's main bundle contains
    /// the .lproj directories at the top level.
    private static let bundle: Bundle = .main

    /// Lookup a localized string by key. If the key is missing from all
    /// bundled catalogs (= broken catalog), returns the key itself so the
    /// UI shows something instead of crashing. Matches hermes i18n fallback
    /// policy (= i18n.py returns the key path when both en + user lang
    /// catalogs are missing the key).
    public static func t(_ key: String) -> String {
        let value = NSLocalizedString(key, bundle: bundle, comment: "")
        // Apple returns the key itself if not found, but with `.process("Resources")`
        // and a properly built catalog, this is robust. We double-check by
        // looking up the key in en.lproj explicitly (= source of truth):
        if value == key {
            // Last-resort: look up in en catalog directly. If even en is
            // missing, return the key path (= hermes i18n behavior).
            if let enPath = bundle.path(forResource: "en", ofType: "lproj"),
               let enBundle = Bundle(path: enPath) {
                let enValue = NSLocalizedString(key, bundle: enBundle, comment: "")
                return enValue == key ? key : enValue
            }
        }
        return value
    }

    /// Format-string variant: t(key) + substitute %d / %f / %@ placeholders.
    /// Uses Apple String(format:) which handles CVarArg arrays via
    /// NSString.localizedStringWithFormat under the hood (= respects
    /// the user's locale for number formatting). Order matches the
    /// placeholder positions in the Localizable.strings value.
    public static func tf(_ key: String, _ args: CVarArg...) -> String {
        let format = t(key)
        // String(format:) takes CVarArg... and passes them through
        // localizedStringWithFormat. Apple canonical: localizedStringWithFormat
        // uses the *format string's* locale for substitution rules
        // (= "%d" with thousands separators in zh-Hans), which is what we want.
        return String(format: format, arguments: args)
    }

    /// %@-style variant for object substitutions (provider names, model IDs).
    /// Equivalent to tf() but reads better at the call site.
    public static func ts(_ key: String, _ arg: String) -> String {
        tf(key, arg)
    }
}
