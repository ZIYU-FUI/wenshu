# ticket 27 — Settings popup tab switching auto-size (docs-only spec)

> Date: 2026-08-22
> Status: SPEC phase (impl pending backlog)
> Boss said: "Pages' settings tab switching — doesn't it auto-fit the popup size to the content? You didn't implement that either", "log this requirement, implement later"

## Boss verbal spec (verbatim)

- "And Pages' settings tab switching — doesn't it auto-fit the popup size to the content? You didn't implement that either"
- "Log this requirement, implement later"

## Boss reference: Apple Pages app

Apple Pages app settings popup — when switching tabs, the popup window resizes to fit the content of the current tab (auto-fit height).

## Business language spec (what boss understands)

Current: wenshu Settings popup = fixed size `.frame(width: 600, height: 480)`. Switching tabs does not resize the window.

Boss expectation: switch tab → window resizes to fit the content of the new tab (Pages.app paradigm).

## Current state (Q32 audit)

- `App.swift` `SettingView` L280: `.frame(width: 600, height: 480)` = fixed size
- `NSWindow` size = fixed at launch, does not respond to content changes
- macOS SwiftUI `Settings { }` Scene default behavior = fixed window size (no auto-fit)

## Implementation spec (5 principles + Apple HIG)

### Candidate A: self-implemented `NSWindow` + tab change listener (Pages.app paradigm, RECOMMENDED)

Abandon the `Settings { SettingView() }` Scene approach.

```
Settings Scene (old)                          Settings Window (new)
─────────────────────                        ─────────────────────────
Settings { SettingView() }   →   abandon      NSWindow + NSWindowController
                                          + SettingView + TabListener
                                          + window.setContentSize(dynamicHeight)
```

**Implementation steps:**
1. Remove `Settings { SettingView() }` from `App.swift` scenes
2. Add SettingsCommand to AppMenu or toolbar button to open custom NSWindow
3. In the custom window, load `SettingView` (existing)
4. Add `@State private var selectedTab: SettingTab` in `SettingView`
5. Listen to tab changes via `onChange(of: selectedTab)` in the window controller
6. Compute current tab content height (via `GeometryReader` or fixed mapping)
7. Call `window.setContentSize(NSSize(width: fixed, height: computed))`

**Tab content height mapping (fixed):**
```
.general       → 400 PT (few controls)
.providerApi   → 600 PT (11 providers, more rows)
.model         → 350 PT (model picker)
```

### Candidate B: SwiftUI adaptive frame (NOT recommended — does not truly auto-fit)

Replace `.frame(width: 600, height: 480)` with `.frame(minWidth: 480, idealWidth: 600, maxWidth: 800, minHeight: 400, idealHeight: 480, maxHeight: 600)`.

Does not truly auto-fit — window size still fixed per session. Candidate A is correct.

### Acceptance criteria

- [ ] Settings popup window resizes when switching tabs (Pages.app paradigm)
- [ ] Each tab has its own content-height mapping (general=400, providerApi=600, model=350)
- [ ] Tab change triggers smooth resize animation (`WenshuInteractionAnimationPrinciple`)
- [ ] Settings popup opened via toolbar button or menu (not `Settings { }` Scene)
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] Boss CUA verification: open settings, switch tabs, window height changes

### Do not touch (Q20 / Q51)

- `SettingView` 3-tab structure (`.general` / `.providerApi` / `.model`) — keep existing
- `providerTab` / `providerApiRow` / `providerApiEditor` functions — keep existing
- `LLMKeychain` / `AppDelegate` / `NSApp.mainMenu` / `.commands`
- `LayoutShellView` / `ZoneModule` / `ChatZoneView` / `ChatView`
- ticket 26 (Apple `DisclosureGroup`) fixed value — keep
- `ProviderKeychain` / `Storing` protocol / `MiniMaxModelFetcher`
- `Info.plist` CFBundle values (ticket 25 fixed)

### Q47 lock: implementation method

- If SwiftUI `Settings { }` Scene does not support auto-size: abandon it, use self-implemented `NSWindow` (Apple Pages.app paradigm)
- Use `onChange(of: selectedTab)` to trigger resize
- Use `WenshuCommonSenseInteractionPrinciple`: "use Apple's APIs to implement interactions as elegant as Apple's official ones" = animate resize with `NSWindow.animator().setContentSize()`

### Apple HIG / technical references

- https://developer.apple.com/documentation/appkit/nswindow/1422400-setcontentsize
- https://developer.apple.com/documentation/swiftui/view/geometryreader
- https://developer.apple.com/documentation/swiftui/settings (SwiftUI Settings Scene — does NOT support dynamic sizing)
- Apple Pages.app settings popup (OS native reference)

### History

- ticket 13 + 14: `ChatBottomBar` 18 PT inset fixed
- ticket 15 + 16 + 17: Provider API config fixed
- ticket 21: Pages toolbar paradigm (`NSWindow` + `NSWindowController` pattern) — relevant precedent
- ticket 25: `Info.plist` CFBundle fixed
- ticket 26: Apple `DisclosureGroup` pattern fixed
- Future: ticket 20 (chat zone tab switching — similar pattern, different component)
