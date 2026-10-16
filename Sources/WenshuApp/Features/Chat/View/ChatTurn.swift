//
//  ChatTurn.swift
//
//  The transcript's grouping type for the ChatView scroll viewport.
//  Extracted from ChatView.swift in A98 (= §6.6 600-LOC cap
//  god-class split).
//
//  Why a separate file (= and not in ChatView.swift): the §6.6
//  600-LOC cap on per-file LOC. ChatView.swift is 1368 LOC = 2.28x
//  the cap; = ChatTurn is a top-level domain type used by the
//  scroll viewport (and exposed in O(n) walks); = putting it in
//  its own file lets the next reader find the turn-grouping
//  logic by name.
//
//  Per the §6.2 4-slot spec (= Apple Backyard Birds shape
//  adapted to wenshu actuals): ChatTurn is a pure value type
//  (= no SwiftUI / no WenshuData / no business logic) = Model
//  slot. ChatView/View/ already had Model-adjacent value types
//  before A98; = ChatTurn joins them here.
//

import Foundation

// MARK: - ChatTurn (= unit of grouping for sticky-top user bubbles)

/// Each ChatTurn groups one user message (= the Section.header that pins to
/// the scroll viewport top via `LazyVStack(pinnedViews: [.sectionHeaders])`)
/// with all following assistant/placeholder messages (= the Section.content
/// that scrolls underneath). The turn structure mirrors hermes
/// `apps/desktop/src/components/assistant-ui/thread/user-message.tsx:46`
/// `sticky top-0 z-40` (= continuous position:sticky; = no jarring yank when a
/// new user message lands). `userMessage == nil` covers the opening greeting
/// case (= the first transcript entry may be a placeholder like "" with no
/// preceding user message; = we still want it rendered in scroll order; = it
/// just has no sticky header).
struct ChatTurn: Identifiable {
    let id = UUID()
    let userMessage: ChatMessage?
    var replies: [ChatMessage]
}
