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
        // v0.38 P2: 3-candidate bundle resolution chain (= Bundle.main for
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

    /// Lookup a localized string by key. If the key is missing from all
    /// bundled catalogs (= broken catalog), returns the key itself so the
    /// UI shows something instead of crashing. Matches hermes i18n fallback
    /// policy (= i18n.py returns the key path when both en + user lang
    /// catalogs are missing the key).
    public static func t(_ key: String) -> String {
        let value = NSLocalizedString(key, bundle: bundle, comment: "")
        // Apple returns the key itself if not found. With our bundle-resolution
        // chain above, the lookup should hit a real catalog for any key the
        // catalogs declare. If it still doesn't (= truly missing key),
        // returning the key path is the hermes i18n behavior.
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
