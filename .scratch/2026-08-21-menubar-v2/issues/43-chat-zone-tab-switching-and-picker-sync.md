# 43 — Chat zone top-bar tab real switching (backlog 20) + picker ↔ UserDefaults sync (out-of-scope #5)

**What to build:**
2 fixes streak (Q38 streak mode 老板 8/22 ruled "engineering management — your call" + Q54 all recommended):

**A. backlog 20 chat-zone top-bar tab real switching** (老板 2026-08-22 06:22 ruled in backlog phase):
- Current truth: `ChatZoneView` `ZoneTopToolbar(iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"])` 3 SF Symbol placeholders, taps do nothing
- Boss verbatim: "implement real tab switching" (boss typo'd "tab" as "teb")
- Boss verbatim: "the first one uses a robot, the second and third keep what they are now, leave them for now, implement the corresponding views later"
- Fix: `ChatZoneView` adds `ChatZoneTab` enum + `@State selectedTab` + tap on tab triggers `selectedTab` switch + body `switch` view

**B. picker ↔ UserDefaults sync fix** (out-of-scope bug found while fixing the chat pipeline, post-ticket 38 commit):
- Current truth: `ChatZoneView` `Menu` `Button` action writes `UserDefaults.standard.set(entry.id, forKey: "wenshu.llm.model")`, but `ChatViewModel.currentModel` reads `UserDefaults.standard.string(forKey:)` as init default. Two state chains aren't bound = after switching picker, `ChatViewModel.currentModel` may be stale (boss noticed when capturing the ticket 39 screenshot)
- Boss ruling (Q54 decision): switch to `@AppStorage("wenshu.llm.model")` (Apple SwiftUI truth, single UserDefaults source, auto-respond)

**Boss feedback verbatim:**
- backlog 20: "implement real tab switching, chat zone, the ICON row in the top bar, the first one uses a robot, the second and third keep what they are now, leave them for now, implement the corresponding views later, first record the requirement, schedule impl later"
- picker sync: 老板 2026-08-22 17:55 ruled "engineering management I don't understand, you decide" → Q38 streak mode + agent ruling

**Q63 verify-before-claim current truth (code-level lock):**

```swift
// Sources/WenshuApp/App.swift L1028
ZoneTopToolbar(iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"])

// Sources/WenshuApp/App.swift L1119-1138 (ChatZoneView Menu)
Menu {
    ForEach(ModelDisplay.curated(availableModels), id: \.self) { entry in
        Button(entry.display) {
            currentModel = entry.id
            UserDefaults.standard.set(entry.id, forKey: "wenshu.llm.model")
        }
    }
} label: { ... }
.menuStyle(.button)
.buttonStyle(.plain)
```

```swift
// Sources/WenshuApp/Views/Chat/ChatView.swift L75
public var currentModel: String = UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? MiniMaxModel.m3.rawValue

// L131
let currentModel: String = UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? "MiniMax-M3"
```

**Root cause:**
1. `ChatZoneView` `Menu` writes `UserDefaults` → but `ChatZoneView` `currentModel` is `@State` (not bound to UserDefaults)
2. `ChatViewModel.currentModel` reads `UserDefaults` as init default → but doesn't respond to `UserDefaults` changes (read once)
3. `ChatViewModel.send()` re-reads `UserDefaults` (L131) → but the `UserDefaults` write and `ChatViewModel.currentModel` aren't in sync
4. Fix: `ChatZoneView.currentModel` + `ChatViewModel.currentModel` + `UserDefaults` are out of sync; after switching picker, the question goes through the old model

**Spec truth (Q34 round-1 grill ruling, Q62 + Q54 + Q61 all recommended):**

**Step 1 — NSLog trace truth** (commit 1, Q63 verify-before-claim):
- `ChatZoneView` body adds `[wenshu.tab] selectedTab: <tab> onAppear: <tab>` trace
- `ChatViewModel.send()` adds `[wenshu.model] effective model: <id> source: UserDefaults|ChatVM` trace
- Run the real `.app`, switch picker, send a question, capture stderr truth: lock down the current model-inconsistency root cause

**Step 2 — Fix A: tab real switching** (commit 2, 老板 ruled Option A):
- Create `ChatZoneTab` enum (Apple SwiftUI truth): `.chat` / `.search` / `.settings` (3 cases; the 2nd / 3rd stubbed)
- `ChatZoneView` adds `@State selectedTab: ChatZoneTab`
- `ZoneTopToolbar` updates API: accepts `selectedTab` binding + `onSelect` callback (Apple HIG truth)
- `ZoneTopToolbar` body: each icon in the `HStack` uses `Button(.plain)` + `contentShape(Rectangle())` (ticket 17 + 21 fixed paradigm)
- Selected icon gets `.foregroundStyle(.accentColor)` (boss visual: selected state = accent color)
- `ChatZoneView` body adds `switch selectedTab: { case .chat: ChatView; case .search: stub "In development"; case .settings: stub "In development" }`
- 1st icon: `book.closed` → `person.crop.circle.badge.questionmark` (boss ruled "use a robot" = robot face, tickets 30 + 33 fixed)

**Step 3 — Fix B: picker ↔ UserDefaults sync fix** (commit 3, agent ruling Q54):
- `ChatZoneView` `Menu` `Picker` switches to `@AppStorage("wenshu.llm.model") var currentModel: String` (Apple SwiftUI truth)
- `@AppStorage` auto-responds to `UserDefaults` changes (single source, bidirectional sync)
- `ChatViewModel.currentModel` changes init default: `UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? MiniMaxModel.m3.rawValue` (ticket 38 fixed; untouched)
- `ChatViewModel.send()` L131 untouched (`UserDefaults.standard.string` read, re-read on each send, guaranteed truth)
- Q20 untouched: `ChatViewModel.send()` body / ticket 38 wire / ticket 39 union decode / ticket 40 binding / ticket 41 auto-scroll / ticket 42 shell removal

**Step 4 — domain-modeling** (commit 4, Q57):
- Add `ChatZoneTabSwitching` domain word to `CONTEXT.md`
- Root-cause chain + fix paradigm + Apple SwiftUI `@AppStorage` truth + `ChatZoneView` tab paradigm
- Future SwiftUI multi-tab view standard fix

**Out of scope (Q20):**
- `Sources/WenshuApp/Views/Chat/ChatView.swift` `ChatViewModel.send()` body
- `Sources/WenshuApp/Views/Chat/ChatView.swift` `ChatView` body `VStack` structure (Q51 parents untouched)
- `Sources/WenshuApp/Core/Agent/MiniMaxVerifier.swift` `send` truth (ticket 39 union decode)
- `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` `handle` model param (ticket 38 wire)
- ticket 38 + 39 + 40 + 41 + 42 committed chain untouched
- `ZoneTopToolbar` `toolbarHeight` 30 PT untouched (Q20 ticket 008)
- `ZoneTopToolbar` placeholder text "placeholder text" untouched (Q20 ticket 008)

**Dependencies:**
- ticket 17 (`providerApiTab` whole-row hot area `Button(.plain)` + `contentShape`) — committed, reused
- ticket 30 + 33 (robot face SF Symbol `person.crop.circle.badge.questionmark`) — committed, reused
- ticket 38 (model switching wire) — committed, reused `UserDefaults` read path
- ticket 42 (model picker shell removal) — committed, reused `Menu` `Button` `(.plain)` paradigm

**Q47 + Q51 + Q20 + Q63 locks:**
- Q47 lock implementation method = SwiftUI `@State` + `@Observable` + `@AppStorage` (Apple SwiftUI truth) + `Button(.plain)` + `contentShape` (Q58.3) + Apple default animation `.animation(.default, value:)` (Q58.4) — don't switch framework
- Q51 parents untouched = `ChatZoneView` `VStack { ChatView; toolbar }` structure + `ZoneTopToolbar` height 30 PT + `ZoneModule` `.aiChat` case body
- Q20 untouched = `ChatViewModel.send()` / ticket 38 wire / ticket 39 union decode / ticket 40 binding / ticket 41 auto-scroll / ticket 42 shell removal / `ChatView` body
- Q63 verify-before-claim = NSLog truth check required before impl (Step 1), no guess-based fix

**Apple HIG references:**
- https://developer.apple.com/documentation/swiftui/appstorage
- https://developer.apple.com/documentation/swiftui/state
- https://developer.apple.com/documentation/swiftui/button/init(_:action:label:)
- https://developer.apple.com/documentation/swiftui/view/contentshape(_:eoofill:)
- https://developer.apple.com/documentation/swiftui/view/animation(_:value:) (Q58.4 Apple default animation)

**References:**
- history: ticket 42 `fix(wenshu): v0.21 ticket 42 model picker shell removal`
- history: ticket 41 `fix(wenshu): v0.21 ticket 41 step 2 ChatView .defaultScrollAnchor + content-based onChange`
- history: ticket 40 `fix(wenshu): v0.21 ticket 40 step 2 ChatZoneView reads vm.contextUsed`
- history: ticket 38 `fix(wenshu): v0.21 ticket 38 model switching actually wired`
- history: ticket 30 `fix(wenshu): v0.21 ticket 30 AI status indicator fix into message list + small robot ICON`
- branch: `feature/agentan-bottom-toolbar-in-child` (Q53 ticket 10 onward, continued)
