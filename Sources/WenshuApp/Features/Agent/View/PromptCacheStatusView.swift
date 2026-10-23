// PromptCacheStatusView.swift · Wenshu
//
// What the prompt cache saved.
//
// The cache is invisible by nature: the provider bills the cached
// prefix at a discount and says nothing about it. This panel is where
// the user can read the number, so the saving is something they can
// trust and tune rather than a claim in a log.
//
// The number comes from the package's recorder (= the running total
// per conversation, folded in by the turn path), so it is the
// provider's own report: the tokens the provider served from its
// cache, the tokens it wrote into it, and the input those cached
// tokens kept out of the bill.
//
// The TTL tier sits here too. It is the user's choice (= how long the
// provider holds the cached prefix), and the tier the user picks is
// the tier the next request asks for.

import SwiftUI
import WenshuAgent

/// The prompt cache's status.
///
/// The panel shows the running conversation's total. The recorder keeps
/// the totals per conversation, and the most recent one is the
/// conversation the user is in (= the one that just spent the tokens).
struct PromptCacheStatusView: View {
    /// The conversation whose totals are shown (= the running chat).
    let conversationId: String?

    /// The tier the user picked (= the tier the next request asks for).
    @AppStorage(PromptCacheTTLSetting.defaultsKey)
    private var ttlTier: String = PromptCachePolicy.TTL.auto.rawValue

    /// The recorder's totals (= the provider's own numbers).
    @State private var totals: PromptCacheTotals = PromptCacheTotals()

    var body: some View {
        Section {
            LabeledContent {
                Text(String.localizedStringWithFormat(NSLocalizedString("settings.cache.read", comment: ""),
                                                     totals.cacheReadTokens))
            } label: {
                Label {
                    Text(String(
                        localized: "settings.cache.read.label",
                        defaultValue: "Read from cache"
                    ))
                } icon: {
                    SFIcon("bolt.horizontal.circle", style: .inlineSmall, color: IconColor.secondary)
                }
            }

            LabeledContent {
                Text(String.localizedStringWithFormat(NSLocalizedString("settings.cache.written", comment: ""),
                                                     totals.cacheCreationTokens))
            } label: {
                Label {
                    Text(String(
                        localized: "settings.cache.written.label",
                        defaultValue: "Written to cache"
                    ))
                } icon: {
                    SFIcon("tray.and.arrow.down", style: .inlineSmall, color: IconColor.secondary)
                }
            }

            LabeledContent {
                Text(String.localizedStringWithFormat(NSLocalizedString("settings.cache.saved", comment: ""),
                                                     totals.savedInputTokens))
            } label: {
                Label {
                    Text(String(
                        localized: "settings.cache.saved.label",
                        defaultValue: "Saved"
                    ))
                } icon: {
                    SFIcon("dollarsign.circle", style: .inlineSmall, color: IconColor.secondary)
                }
            }

            Picker(
                String(localized: "settings.cache.ttl", defaultValue: "Cache lifetime"),
                selection: $ttlTier
            ) {
                Text(String(localized: "settings.cache.ttl.auto", defaultValue: "Automatic"))
                    .tag(PromptCachePolicy.TTL.auto.rawValue)
                Text(String(localized: "settings.cache.ttl.short", defaultValue: "5 minutes"))
                    .tag(PromptCachePolicy.TTL.short.rawValue)
                Text(String(localized: "settings.cache.ttl.long", defaultValue: "1 hour"))
                    .tag(PromptCachePolicy.TTL.long.rawValue)
            }
        } header: {
            Text(String(localized: "settings.cache.title", defaultValue: "Prompt cache"))
        } footer: {
            Text(String(
                localized: "settings.cache.footer",
                defaultValue: "The cached prefix is billed at roughly a quarter of the input rate."
            ))
        }
        .task {
            // The totals are read from the recorder while the panel is
            // open, so a turn that finishes while the user is looking
            // updates the number without a restart.
            await refreshTotals()
        }
    }

    /// Read the recorder's totals for the conversation on screen.
    ///
    /// A conversation id is used when the caller knows it (= the chat
    /// itself); otherwise the most recent conversation is shown, because
    /// that is the one that just spent the tokens.
    private func refreshTotals() async {
        if let conversationId {
            totals = await PromptCacheRecorder.shared.totals(conversationId: conversationId)
        } else {
            totals = await PromptCacheRecorder.shared.mostRecentTotals()
        }
    }
}
