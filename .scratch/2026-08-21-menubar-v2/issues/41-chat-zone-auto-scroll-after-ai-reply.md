# 41 — Chat zone auto-scroll (after AI reply, scroll to bottom)

**What to build:**
Fix the bug where the chat window doesn't auto-scroll after AI replies. After the user sends a question + the AI reply (2 messages), 老板 has to scroll manually to see the AI reply content.

**Boss feedback verbatim (2026-08-22 17:00):**
- "After AI replies, the chat window doesn't auto-scroll, so the latest message needs to be manually scrolled to the bottom to see"

**Current code truth (Q63 verify-before-claim, `Sources/WenshuApp/Views/Chat/ChatView.swift` L223-241):**
```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(vm.messages) { msg in
                ChatMessageView(message: msg)
                    .id(msg.id)
            }
        }
        .padding(8)
    }
    .onChange(of: vm.messages.count) { _, _ in
        if let last = vm.messages.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
```

**Q63 root-cause hypothesis (code-level + Q44 swiftinterface verified, needs NSLog lock):**

Root cause chain (4 candidate root causes, priority order):

1. **count-based `onChange` doesn't notice placeholder → reply replacement** (most likely)
   - `ChatViewModel.send()` L120 creates `placeholderId`; L159 placeholder is replaced with the real reply, **reusing the same `placeholderId` UUID**
   - `vm.messages.count` doesn't change (placeholder is replaced, not a new message appended)
   - `onChange` doesn't trigger → `scrollTo` doesn't run
   - 老板 sees the reply appear at the placeholder position but **the scrollbar stays put** = manual scroll required to see the full reply

2. **`withAnimation` wrapping `scrollTo` doesn't respond in some SwiftUI macOS 27 scenarios**
   - SwiftUI `ScrollViewReader.scrollTo` inside an `animation` context has timing race conditions
   - When the new message first appears, the animation hasn't finished and `scrollTo` gets ignored

3. **`anchor: .bottom` doesn't precisely scroll to bottom under `LazyVStack` + long-reply content**
   - 老板's AI replies often contain thinking `DisclosureGroup` that expands and changes height
   - `anchor: .bottom` scrolls to the placeholder's bottom (short text), not the new reply's bottom

4. **Apple SwiftUI `ScrollView` default behavior = scroll to top, doesn't auto-track content bottom**
   - `ScrollView` without `defaultScrollAnchor` doesn't auto-stick to the bottom when content is appended

**Q44 swiftinterface truth check (run in this session, truth):**
- `ScrollView.defaultScrollAnchor(_ anchor: UnitPoint?)` exists ✅ (Apple SwiftUI macOS 14+)
- `ScrollView.defaultScrollAnchor(_ anchor: UnitPoint?, for role: ScrollAnchorRole)` overload exists ✅
- Don't guess the API (Q38 + Q44 hard constraint)

**Spec truth (Q34 round-2 grill ruling, Option D + A double-guard):**

**Fix 1 — `.defaultScrollAnchor(.bottom)`** (Option D, Apple SwiftUI 14+ standard truth):
- Add `.defaultScrollAnchor(.bottom)` modifier to `ScrollView`
- Apple truth = `ScrollView` content change auto-sticks to bottom, doesn't depend on `scrollTo`
- Fixes root cause 4 (default scroll-to-top) + backstops root cause 1 (count unchanged)

**Fix 2 — `onChange` listens to `messages.last?.id` not just count** (Option A):
- Replace `onChange(of: vm.messages.count)` → `onChange(of: vm.messages.last?.id)`
- On placeholder → reply replacement the `placeholderId` is reused → `onChange` doesn't trigger
- Fix: when replacing the placeholder, use a new UUID (so count grows) OR listen for `last?.content` changes
- Choosing `last?.id` because it matches the current `scrollTo(last.id)` use

**Fix 3 — Fix trace lines** (Q63 verify-before-claim, commit 1):
- `ChatViewModel.send()` L120 placeholder replacement NSLog:
  - `[wenshu.scroll] placeholder replace: id=<id> beforeCount=N afterCount=N`
- `ChatView` `onChange` trigger NSLog:
  - `[wenshu.scroll] onChange trigger: lastId=<id> lastContentLen=N`

**Step 1 — NSLog trace truth** (commit 1, Q63 verify-before-claim):
- Add trace lines without touching business code
- Run the real `.app`, send a question, capture stderr truth:
  - `onChange` trigger count (= 老板 sends + AI replies)
  - Whether `count` changes before/after placeholder replacement
  - Whether `lastId` changes on placeholder → reply
- Verify root cause 1 (count unchanged) true or false

**Step 2 — Fix** (commit 2):
- `ChatView` `ScrollView` adds `.defaultScrollAnchor(.bottom)` modifier (Fix 1)
- `ChatView` `onChange` changes to `onChange(of: vm.messages.last?.id)` (Fix 2)
- Remove `withAnimation { proxy.scrollTo(...) }` wrapper (Apple SwiftUI 14+ `defaultScrollAnchor` handles animation automatically)
- Q47 lock: Apple SwiftUI standard modifier, don't switch framework
- Q51 parents untouched: `ChatViewModel.send()` body / placeholder replacement logic untouched
- Q20 untouched: ticket 38 wire / ticket 39 union decode / ticket 40 binding untouched

**Step 3 — domain-modeling** (commit 3, Q57):
- Add `ChatZoneAutoScroll` domain word to `CONTEXT.md`
- Root-cause chain + fix paradigm + Apple SwiftUI `defaultScrollAnchor` truth
- Future standard fix for SwiftUI scroll issues (new SwiftUI 14+ projects should default to `defaultScrollAnchor`)

**Out of scope (Q20):**
- `Sources/WenshuApp/Views/Chat/ChatView.swift` `ChatViewModel` any field
- `Sources/WenshuApp/Views/Chat/ChatView.swift` `send()` body (placeholder replacement logic)
- `Sources/WenshuApp/Views/Chat/ChatView.swift` `ChatMessageView` (Q47 locked sub-component)
- ticket 38 wire + ticket 39 union decode + ticket 40 binding
- `Sources/WenshuApp/App.swift` `ChatZoneView` (Q51 parents untouched)

**Dependencies:**
- ticket 40 (context usage UI binding) — committed; `ChatZoneView` holds shared `vm` instance
- ticket 30 (AI status indicator placeholder) — committed; placeholder reuses `placeholderId` UUID
- ticket 39 (union decode + thinking footnote) — committed; reply content may contain thinking `DisclosureGroup`

**Q47 + Q51 + Q20 + Q44 + Q63 + Q37 locks:**
- Q47 lock implementation method = Apple SwiftUI `ScrollView.defaultScrollAnchor` + `onChange` modifier, don't switch framework
- Q51 parents untouched = `ChatView` body `VStack` structure untouched, only `ScrollView` modifiers change
- Q20 untouched = `ChatViewModel` / `ChatMessageView` / `ChatZoneView` untouched
- Q44 swiftinterface truth check run = `defaultScrollAnchor` API exists
- Q63 verify-before-claim = NSLog must verify 4 root causes before impl, no guess-based fix
- Q37 dual-axis review = after impl commit, run 2 sub-agents (Standards + Spec) in parallel; hard-violation fix verbatim into fix commit

**Apple HIG references:**
- https://developer.apple.com/documentation/swiftui/scrollview/defaultscrollanchor(_:)
- https://developer.apple.com/documentation/swiftui/scrollanchorrole
- https://developer.apple.com/documentation/swiftui/scrollviewreader

**References:**
- history: ticket 40 `fix(wenshu): v0.21 ticket 40 step 2 ChatZoneView reads vm.contextUsed`
- history: ticket 39 `fix(wenshu): v0.21 ticket 39 step 2 MiniMaxBlock union decode + thinking footnote`
- history: ticket 30 `fix(wenshu): v0.21 ticket 30 AI status indicator fix into message list (placeholder reuses UUID)`
- branch: `feature/agentan-bottom-toolbar-in-child` (Q53 ticket 10 onward, continued)
