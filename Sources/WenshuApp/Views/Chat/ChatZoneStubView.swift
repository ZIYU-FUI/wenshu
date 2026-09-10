//
//  ChatZoneStubView.swift · Wenshu · v0.40 apple-001 phase 3 ticket 2
//
//  Extracted from App.swift (formerly inline `struct ChatZoneStubView`
//  at line 1450, = 19 LOC). v0.40 apple-001 phase 3 ticket 2
//  (LOW-RISK leg).
//
//  v0.21 ticket 43: ChatZoneStubView = placeholder for the 2nd/3rd
// tab in the chat zone (boss ', '). Apple HIG
//  canonical placeholder = large icon + 'in development' label
//  + tertiary foregroundStyle (= the grayed-out convention for
//  upcoming features).
//
//  Apple HIG = one view per file. ChatZoneStubView is small
//  (= 19 LOC) but standalone (= no @State / @Binding / @Environment
//  dependencies, just 2 let parameters = title + icon).
//
//  This slice ALSO bundles an AGENTS.md English-only sweep:
// the original line `Text("\(title) (developin progress)")` = the literal
// Chinese 'developin progress' (= 'in development'). Replaced with
//  WenshuI18n.t("chat.stub.in_development_label") wrapping the
//  title via a ts() variant (= Apple HIG conventions: the
//  placeholder reads `Title (In Development)` per the en catalog,
// and `title (developin progress)` per the zh-Hans catalog).
//
//  Both keys ship in both zh-Hans and en Localizable.strings.
//

import SwiftUI

/// v0.21 ticket 43: ChatZoneStubView = 2/3 tab view (', ')
/// Apple HIG: VStack in progress + icon + 'developin progress' placeholder +
struct ChatZoneStubView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            // v0.27 boss 8/27 OOB: dynamic icon string → Lucide via helper.
            LucideIconSystemFallback(icon, size: 48)
                .foregroundStyle(.tertiary)
            Text(WenshuI18n.ts("chat.stub.in_development_label", title))
                .font(.title3)
                .foregroundStyle(.tertiary)
        }
        // wrapper with bare Color(nsColor: .controlBackgroundColor).
        // v0.40 boss 2026-09-08 OOB 'sweep for remaining background colors: removed the
        // chrome tier background tint (= .controlBackgroundColor
        // = boss wants gone per the 'go up another layer and remove the background' cleanup).
    }
}
