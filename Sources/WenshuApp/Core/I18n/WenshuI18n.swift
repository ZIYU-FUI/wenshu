//
//  WenshuI18n.swift
//
//  Apple-standard i18n helper. Thin wrapper over NSLocalizedString that:
//  1. Reads from the WenshuApp module's .main bundle (= Resources/*.lproj/Localizable.strings)
//  2. Falls back to the key path itself (= broken catalog never crashes the UI)
//  3. Supports format strings via %d / %@ / %f placeholders (= identical to NSLocalizedString)
//
//  - default = en (= user's OS language per Apple canonical Locale.current)
//  - bundled catalogs = en + zh-Hans
//  - no per-app language picker (= Apple standard means OS language decides)
//
//  Usage:
//      Text(String(localized: "settings.connector.header"))
//      Text(WenshuI18n.tf("statusbar.shelf", shelfCount))   // %d format
//      Text(WenshuI18n.ts("settings.provider.status.pasteNamed", providerName))  // %@ format
//

import Foundation

enum WenshuI18n {

    /// Bundle that contains the Localizable.strings files. There are 3 candidate
    /// bundles Apple can resolve against at runtime; we try each in order:
    ///
    /// 1. `Bundle.main` (= the wenshu.app's Contents/Resources/) — works for
    ///    traditional .app builds (= Xcode/.xcodeproj) but NOT for SPM
    ///    executable targets running through `swift test` (where Bundle.main
    ///    is the toolchain, not the wenshu binary).
    /// 2. `Wenshu_WenshuApp.bundle` (= SPM's module-named resource bundle).
    ///    SPM places this at:
    ///      - `Products/Debug/Wenshu_WenshuApp.bundle` next to the binary
    ///        when building the executable target directly.
    ///      - `WenshuAppTests.xctest/Contents/Resources/Wenshu_WenshuApp.bundle`
    ///        when running tests (= SPM nests it under the test bundle).
    ///    We search both candidate paths under a list of roots.
    /// 3. Last-resort fallback: `Bundle.main` (returns key for missing
    ///    entries; matches hermes i18n fallback policy in i18n.py).
    private static let bundle: Bundle = {
        // 3-candidate bundle resolution chain (= Bundle.main for
        // Xcode .app builds + Wenshu_WenshuApp.bundle for SPM-built
        // executables + SPM test target context). The lazy static evaluates
        // on first call to t() and caches the winning bundle. Per
        // hermes i18n fallback policy, missing keys return the key path
        // itself so a broken catalog never crashes the UI.
        // 1. Bundle.main with .lproj directly accessible (Xcode .app build)
        if let url = Bundle.main.url(forResource: "en", withExtension: "lproj") {
            return .main
        }
        // 2. SPM module-named bundle (= canonical for executable targets).
        //    Bundle layout in SPM-built executables:
        //      - .build/out/Products/Debug/Wenshu_WenshuApp.bundle/Contents/Resources/{en,zh-Hans}.lproj
        //      - After our manual copy into .app:
        //        build/Wenshu.app/Contents/Resources/Wenshu_WenshuApp.bundle/Contents/Resources/{en,zh-Hans}.lproj
        //      - For test target (= swift test): SPM nests the bundle under
        //        .build/out/Products/Debug/ or .build/debug/ (= both spellings
        //        observed across SPM versions).
        let roots: [String] = {
            var r: [String] = []
            // Binary parent (SPM layout: bundle sits next to the binary)
            if let url = Bundle.main.executableURL {
                r.append(url.deletingLastPathComponent().path)
            }
            // .app's Resources/ (= after our manual copy: bundle lives in
            // Contents/Resources/Wenshu_WenshuApp.bundle)
            if let resourceURL = Bundle.main.resourceURL {
                r.append(resourceURL.path)
                // also try Contents/ (= parent of Resources/)
                r.append(resourceURL.deletingLastPathComponent().path)
            }
            // SPM test target nests bundles under Contents/Resources of the
            // .xctest bundle (= e.g. when running `swift test`).
            r.append(Bundle.main.bundlePath + "/Contents/Resources")
            // CWD + parents (last-resort heuristics for ad-hoc runs)
            var cwd = FileManager.default.currentDirectoryPath
            for _ in 0..<3 {
                r.append(cwd)
                cwd = (cwd as NSString).deletingLastPathComponent
            }
            // SwiftPM also places a copy under .build/debug and .build/release
            // (= observed in recent SPM versions; harmless to include both).
            let packageBuild = FileManager.default.currentDirectoryPath + "/.build"
            for sub in ["debug", "release", "Debug", "Release"] {
                r.append("\(packageBuild)/\(sub)")
            }
            return r
        }()
        for root in roots {
            let candidate = (root as NSString).appendingPathComponent("Wenshu_WenshuApp.bundle")
            guard let b = Bundle(path: candidate) else { continue }
            if b.url(forResource: "en", withExtension: "lproj") != nil {
                return b
            }
        }
        // 3. Last-resort: Bundle.main (returns key for missing entries; matches
        //    hermes i18n fallback policy in i18n.py).
        return .main
    }()

    /// Apple HIG canonical lookup. Per
    /// developer.apple.com/tutorials/data/documentation/xcode/
    /// preparing-your-apps-text-for-translation:
    ///
    ///   > "Use the String(localized: 'key') initializer when
    ///   > creating String and AttributedString objects
    ///   > that contain text you want to localize. ...
    ///   > To create localizable strings with different keys
    ///   > and values, use the String(localized:defaultValue:
    ///   > options:table:bundle:locale:comment:) initializer.
    ///   > Xcode uses the first parameter as the key and
    ///   > the second parameter as the default source string."
    ///
    /// We delegate to `NSLocalizedString` (= the macOS
    /// Foundation equivalent of Apple's recommended
    /// `String(localized:defaultValue:)` initializer). Per
    /// the NSLocalizedString docs:
    ///
    /// 1. `key` is the lookup string (= rows in
    ///    Localizable.strings under the resolved .lproj).
    /// 2. `value` (= Apple calls it `defaultValue`) is the
    ///    source string shown to the user in development
    ///    language when the key is missing from the .strings
    ///    catalog; AND exported to translators as the value
    ///    to translate.
    /// 3. `comment` is the developer annotation shown next
    ///    to the row in the .strings catalog and in the
    ///    Xcode String Catalog editor.
    ///
    /// Apple HIG says: the defaultValue is NOT a runtime
    /// fallback (= if the key is missing AND the language
    /// has its own catalog, the user sees the key string;
    /// the defaultValue is only used for the development
    /// language and as a hint to translators). For wenshu,
    /// the development language is en (= `Info.plist`
    /// `CFBundleDevelopmentRegion`), so an English default
    /// for new keys is the canonical pattern. When the
    /// user's locale is zh-Hans, missing keys fall back
    /// to the en catalog; if still missing, the key string
    /// itself (= hermes i18n fallback policy).
    static func t(_ key: String, defaultValue: String, comment: String? = nil) -> String {
        NSLocalizedString(
            key,
            tableName: nil,
            bundle: bundle,
            value: defaultValue,
            comment: comment ?? ""
        )
    }

    /// Apple HIG canonical for runtime String keys (=
    /// the key is computed rather than a string literal).
    /// `String(localized:)` only accepts `StaticString` literals
    /// (= the compiler refuses to bridge a runtime String);
    /// = NSLocalizedString accepts a runtime String per
    /// Apple's Foundation signature. The 633 inline
    /// `String(localized: "literal")` call sites (= the common
    /// wenshu pattern) still use the Swift-native form; this
    /// 1-arg wrapper is kept for the ~2 call sites that need
    /// a runtime-computed key (= e.g. `WenshuI18n.t(folderNameKey
    /// ?? "preview.empty_state.default")`).
    static func t(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    /// Format-string variant: NSLocalizedString + substitute
    /// %d / %f / %@ placeholders via Apple's String(format:).
    /// Apple HIG canonical pattern for localized format strings.
    /// The 1-arg form (= key only, no defaultValue) is the
    /// wenshu-canonical = matches the 633 call sites that were
    /// migrated from the previous 1-arg `WenshuI18n.t(_:)` form
    /// (= see commit that inlines `String(localized:)` at every
    /// call site). The 2-arg form (= with defaultValue) is kept
    /// for the rare case where the localizable default text is
    /// computed (= e.g. contains a runtime placeholder).
    static func tf(_ key: String, defaultValue: String, _ args: CVarArg..., comment: String? = nil) -> String {
        let format = NSLocalizedString(key, tableName: nil, bundle: .main, value: defaultValue, comment: comment ?? "")
        return String(format: format, arguments: args)
    }

    /// Backward-compat format-string 1-arg form (= key only,
    /// defaultValue = key, = the localizable default text is the
    /// key string itself per Apple NSLocalizedString behavior).
    static func tf(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, arguments: args)
    }

    /// %@-style variant for object substitutions (provider names, model IDs).
    static func ts(_ key: String, defaultValue: String, _ arg: String, comment: String? = nil) -> String {
        tf(key, defaultValue: defaultValue, arg, comment: comment)
    }

    /// Backward-compat %@ 1-arg form.
    static func ts(_ key: String, _ arg: String) -> String {
        tf(key, arg)
    }
}
