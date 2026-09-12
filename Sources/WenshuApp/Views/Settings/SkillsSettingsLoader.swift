//
//  SkillsSettingsLoader.swift · Wenshu · v0.40 apple-001 phase 3 ticket 3
//
//  Extracted from App.swift (formerly inline `private struct
//  SkillsSettingsLoader: View` at line 897, = 30 LOC). v0.40
//  apple-001 phase 3 ticket 3 (MEDIUM-RISK leg).
//
//  v0.38 ticket A2: thin async-loader wrapper around
//  SkillsSettingsView (= seeds the @State array with the result
//  of SkillAdapter.listSkills() = the user-facing skills-hub
//  pane). Apple HIG canonical async-data pattern = .task
//  modifier on the seeded view (= SwiftUI handles task lifecycle
//  and cancellation automatically; = no manual Task management).
//
//  Apple HIG = one view per file. SkillsSettingsLoader has
//  2 @State + 0 @Binding / @Environment (= fully self-contained).
//
//  Only call site = SettingView's "skills" sub-view in App.swift
//  (= line 884, `SkillsSettingsLoader()`). Extracting it does
//  not change any caller signature.
//

import SwiftUI

/// v0.38 ticket A2: thin loader view that owns the @State array of
/// SkillAdapter.Skill + triggers an async load on appear. Bridges the
/// gap between async actor-isolated SkillAdapter.listSkills() (= v0.35
/// ticket 010 spec) and the passive SkillsSettingsView (= expects an
/// already-populated @State binding). Per Apple SwiftUI canonical state
/// ownership pattern (= child view owns its own data, parent provides
/// the read site).
struct SkillsSettingsLoader: View {
    @State private var skills: [SkillAdapter.Skill] = []
    @State private var hasLoaded: Bool = false

    var body: some View {
        // v0.38 ticket A2: SkillsSettingsView is a public View with @State
        // binding; passing our @State array as init() seeds its state. The
        // empty-array placeholder ("No skills installed yet") shows briefly
        // while .task fires; once listSkills() returns, the @State
        // reassignment triggers a re-render with the populated list.
        SkillsSettingsView(skills: skills)
            .task {
                let loaded = await SkillAdapter().listSkills()
                await MainActor.run {
                    self.skills = loaded
                    self.hasLoaded = true
                }
            }
            // v0.38 ticket A2: hidden accessibility hint that conveys
            // load state to assistive tech; visible UI is unchanged
            // (= Settings tab is a known site; the user can see skills
            // populate in real time).
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                hasLoaded
                    ? WenshuI18n.tf("a11y.skills_settings.loaded", skills.count)
                    : WenshuI18n.t("a11y.skills_settings.loading")
            )
    }
}
