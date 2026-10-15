// Sources/WenshuApp/Editor/EditorPreferences.swift
//
// Host-side preferences surface for the markdown editor (= T-12).
// Each preference is an `@AppStorage` getter (= SwiftUI-aware
// persistence via UserDefaults; = wenshu's standard "Settings →
// Editor" surface reads these getters). The factory
// (= WenshuEditorServicesFactory.make) reads the preferences via a
// new `preferences: EditorPreferences = .live` parameter and
// forwards the values to `MarkdownEditorConfiguration`.
//
// We don't bind `@AppStorage` to the configuration directly
// because `MarkdownEditorConfiguration` is a `Sendable` value type
// (= no `@AppStorage` semantics); = a getter that returns the
// current value (= `.live` is a singleton that snapshots the live
// `UserDefaults`) keeps the boundary clean.
import SwiftUI
import MarkdownEngine

/// One host-side preference (= SwiftUI AppStorage-backed). Each
/// field is its own getter so a future "Settings → Editor" panel
/// can bind to individual fields without rebuilding the entire
/// struct (= Apple HIG Settings panel = one toggle per row = =
/// one @AppStorage per row).
///
/// Default values mirror `MarkdownEditorConfiguration.default`
/// (= the engine's defaults = the user gets engine defaults until
/// they flip a preference; = no Settings panel is needed for the
/// defaults to take effect).
struct EditorPreferences: Equatable, Sendable {
    /// Reading column width (= the centered fixed-width column
    /// that Pages / Numbers call "reading width"). nil = use the
    /// window width (= the engine fills horizontally).
    var readingWidth: CGFloat?
    /// Vertical growth behavior (= .scrolls = NSTextView scrolls; =
    /// .fitsContent = NSTextView grows with content = the Apple
    /// HIG Pages inspector "Page Setup" choice).
    var heightBehavior: MarkdownEditorConfiguration.HeightBehavior
    /// Show raw markdown source instead of rendered prose (= the
    /// engine's `rawSourceMode` toggle).
    var rawSourceMode: Bool
    /// Show spell-check squiggles (= `NSTextView.isContinuous-
    /// SpellCheckingEnabled` mirror).
    var continuousSpellChecking: Bool
    /// Show grammar-check squiggles (= `NSTextView.isGrammar-
    /// CheckingEnabled` mirror).
    var grammarChecking: Bool
    /// Auto-correct as the user types (= `NSTextView.isAutomatic-
    /// SpellingCorrectionEnabled` mirror).
    var automaticSpellingCorrection: Bool
    /// Master switch for list-editing helpers (auto-continue, auto-indent,
    /// marker conversion). When `false`, lists are still rendered but
    /// typing-time conveniences are skipped (= `ListStyle.helpersEnabled`
    /// in the SMC engine).
    var listHelpersEnabled: Bool
    /// Master switch for auto-closing pairs `()`, `{}`, `[]` while typing
    /// (= `ListStyle.autoClosePairsEnabled` in the SMC engine).
    var autoClosePairsEnabled: Bool

    /// Engine-default snapshot (= matches
    /// `MarkdownEditorConfiguration.default`).
    static let engineDefault = EditorPreferences(
        readingWidth: nil,
        heightBehavior: .scrolls,
        rawSourceMode: false,
        continuousSpellChecking: true,
        grammarChecking: true,
        automaticSpellingCorrection: true,
        listHelpersEnabled: true,
        autoClosePairsEnabled: true
    )

    /// Live snapshot (= reads from `UserDefaults` via the
    /// `@AppStorage`-backed getters in
    /// `EditorPreferences+AppStorage`; = call sites that want
    /// live values (= the factory) use this).
    static let live = EditorPreferences.liveSnapshot()
}

/// AppStorage bridge (= each preference is its own getter; = a
/// future "Settings → Editor" panel binds its toggles to the
/// `@AppStorage` keys (= no factory rebuild needed)). The bridge
/// lives in a separate file (= the SwiftUI AppStorage macro is
/// only legal in View-typed contexts; = this file holds the value
/// struct, = the AppStorage bridge lives here too because both
/// files live under `Editor/`).
extension EditorPreferences {
    /// The 6 UserDefaults keys (= one per preference). Centralized
    /// here (= if a future ticket renames a key, = this is the only
    /// place to edit).
    enum AppStorageKey: String, CaseIterable {
        case readingWidth = "wenshu.editor.readingWidth"
        case heightBehavior = "wenshu.editor.heightBehavior"
        case rawSourceMode = "wenshu.editor.rawSourceMode"
        case continuousSpellChecking = "wenshu.editor.continuousSpellChecking"
        case grammarChecking = "wenshu.editor.grammarChecking"
        case automaticSpellingCorrection = "wenshu.editor.automaticSpellingCorrection"
        case listHelpersEnabled = "wenshu.editor.listHelpersEnabled"
        case autoClosePairsEnabled = "wenshu.editor.autoClosePairsEnabled"
    }

    /// Live snapshot (= reads from `UserDefaults.standard`; = the
    /// factory uses this = every snapshot so the host's settings
    /// flow into the next `make` call).
    fileprivate static func liveSnapshot() -> EditorPreferences {
        let defaults = UserDefaults.standard
        let readingWidth: CGFloat? = defaults
            .object(forKey: AppStorageKey.readingWidth.rawValue)
            .flatMap { $0 as? Double }
            .map { CGFloat($0) }
        let heightBehaviorRaw = defaults.string(
            forKey: AppStorageKey.heightBehavior.rawValue
        ) ?? "scrolls"
        let heightBehavior: MarkdownEditorConfiguration.HeightBehavior = {
            switch heightBehaviorRaw {
            case "fitsContent": return .fitsContent
            default: return .scrolls
            }
        }()
        return EditorPreferences(
            readingWidth: readingWidth,
            heightBehavior: heightBehavior,
            rawSourceMode: defaults.bool(forKey: AppStorageKey.rawSourceMode.rawValue),
            continuousSpellChecking: defaults.object(
                forKey: AppStorageKey.continuousSpellChecking.rawValue
            ) as? Bool ?? true,
            grammarChecking: defaults.object(
                forKey: AppStorageKey.grammarChecking.rawValue
            ) as? Bool ?? true,
            automaticSpellingCorrection: defaults.object(
                forKey: AppStorageKey.automaticSpellingCorrection.rawValue
            ) as? Bool ?? true,
            listHelpersEnabled: defaults.object(
                forKey: AppStorageKey.listHelpersEnabled.rawValue
            ) as? Bool ?? true,
            autoClosePairsEnabled: defaults.object(
                forKey: AppStorageKey.autoClosePairsEnabled.rawValue
            ) as? Bool ?? true
        )
    }
}