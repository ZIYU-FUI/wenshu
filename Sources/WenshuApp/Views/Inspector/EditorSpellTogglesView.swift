// Sources/WenshuApp/Views/Inspector/EditorSpellTogglesView.swift
//
// Sub-tool 5 of 5 (= T-09) inside the `documentTools` page:
// spell-check toggles. Reflects the engine's current spell-checking
// policy in a 3-toggle inspector row (= continuous spell / grammar
// / autocorrect = Apple HIG system Settings → Keyboard → Text
// pattern).
//
// Engine has no public mutable API for spell policy:
// `MarkdownEditorConfiguration.spellChecking` is init-time only; =
// after `makeNSView` the user's NSTextView context-menu choices
// take precedence and are surfaced via
// `NativeTextViewCoordinator.onSpellCheckingPolicyChanged` (= a
// closure on the coordinator, = NOT a public notification on the
// bus). T-09 ships the inspector surface as a 3-toggle display
// panel (= disabled; = inspector reflects engine state, = it does
// NOT mutate the engine's policy = Apple HIG system Settings
// pattern: Settings toggles here reflect; = mutating happens in
// the right place = the editor's context menu).
//
// The host preserves the wiring slot (= `bus` is kept as a View
// parameter so a future ticket can wire the coordinator closure
// without changing the picker source = parent that supplies `bus`).
import SwiftUI
import MarkdownEngine

/// Spell-check toggle row (= continuous spell check / grammar
/// autocorrect). Three Toggle controls (= disabled = inspector
/// reflects the engine's `SpellCheckingPolicy`; = the actual
/// mutation happens in the editor's context menu = the canonical
/// Apple HIG pattern). The current policy values are read from
/// `MarkdownEditorConfiguration.spellChecking` (= the engine's
/// init-time field; = the inspector reflects this initial seed).
struct EditorSpellTogglesView: View {
    let bus: MarkdownEditorBus
    /// The engine's initial spell-checking policy (= read from
    /// `MarkdownEditorConfiguration.spellChecking`; = the engine
    /// seeds this in `makeNSView` and exposes changes via the
    /// coordinator closure `onSpellCheckingPolicyChanged`).
    let initialPolicy: SpellCheckingPolicy

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
            // Section header (= Apple HIG inspector sub-section
            // pattern = secondary-tint title).
            Text(String(localized: "inspector.documentTools.spellToggles.title"))
                .font(.callout)
                .foregroundStyle(.secondary)

            // 3-toggle row (= continuous spell / grammar / auto-
            // correct). Each Toggle is disabled (= inspector
            // reflects; = mutating happens in the editor context
            // menu = Apple HIG system Settings pattern).
            VStack(alignment: .leading, spacing: DesignTokens.spacingCaption) {
                Toggle(isOn: .constant(initialPolicy.continuousSpellChecking)) {
                    Text(String(localized: "inspector.documentTools.spellToggles.continuous"))
                        .font(.callout)
                }
                .toggleStyle(.checkbox)
                .disabled(true)
                .help(String(localized: "inspector.documentTools.spellToggles.continuous.help"))

                Toggle(isOn: .constant(initialPolicy.grammarChecking)) {
                    Text(String(localized: "inspector.documentTools.spellToggles.grammar"))
                        .font(.callout)
                }
                .toggleStyle(.checkbox)
                .disabled(true)
                .help(String(localized: "inspector.documentTools.spellToggles.grammar.help"))

                Toggle(isOn: .constant(initialPolicy.automaticSpellingCorrection)) {
                    Text(String(localized: "inspector.documentTools.spellToggles.autocorrect"))
                        .font(.callout)
                }
                .toggleStyle(.checkbox)
                .disabled(true)
                .help(String(localized: "inspector.documentTools.spellToggles.autocorrect.help"))
            }

            // Footer hint (= explain the canonical Apple HIG
            // pattern: the inspector reflects the engine state; =
            // mutation happens in the editor's context menu =
            // "Spelling and Grammar" submenu).
            Text(String(localized: "inspector.documentTools.spellToggles.footer"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}