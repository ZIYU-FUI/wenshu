# ticket 20 — Chat zone top bar tab switching (docs-only spec)

> Date: 2026-08-22
> Status: SPEC phase (impl pending backlog)
> Boss said: "实现真正的 tab 切换功能", "先记需求，一会排期实现"

## Boss verbal spec (verbatim)

- "实现真正的 tab 切换功能"
- "聊天区，顶栏的 ICON"
- "第一个用机器人"
- "第二个第三个，可以保留现在的这个，先放着，后面实现对应的两个视图的功能"
- "先记需求，一会排期实现"

## Business language spec (what boss understands)

Chat zone top bar has 3 tab icons. Currently clicking them does nothing (no real switching).

**What boss wants this round:**
1. Tab 1 icon = robot icon (SF Symbol "cpu" or "person.crop.circle.badge.questionmark") — replace current doc icon
2. Tab 1 click = truly switch to chat view (current implementation, no new logic needed)
3. Tab 2 + Tab 3 = keep current icons (search / slider), no switching yet — handled by future tickets 21 + 22

## Implementation spec (5 principles + Apple HIG)

### API shape

```swift
// ChatZoneView.swift — new enum + state
enum ChatTab: Hashable {
    case chat
    case search   // placeholder this round
    case settings // placeholder this round
}

// In ChatZoneView body:
@State private var selectedTab: ChatTab = .chat

VStack(spacing: 0) {
    ChatTabBar(selectedTab: $selectedTab) // new SwiftUI component
    Divider() // 1 PT splitter, ticket 13 already fixed
    switch selectedTab {
    case .chat:    ChatView() // current implementation
    case .search:  Text("Search (future)") // placeholder
    case .settings: Text("Settings (future)") // placeholder
    }
    Divider()
    ChatBottomBar() // ticket 13 + 14 fixed
}
```

### ChatTabBar component (new)

```swift
struct ChatTabBar: View {
    @Binding var selectedTab: ChatTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach([ChatTab.chat, .search, .settings], id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Image(systemName: iconName(for: tab))
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                }
                .buttonStyle(.plain) // full hot area
            }
            Spacer()
            // status area (unchanged from current impl)
        }
        .padding(.horizontal, 18) // Apple HIG 18 PT leading inset
    }

    private func iconName(for tab: ChatTab) -> String {
        switch tab {
        case .chat:    return "cpu" // Apple SF Symbol — robot
        case .search:  return "magnifyingglass" // current
        case .settings: return "slider.horizontal.3" // current
        }
    }
}
```

### Acceptance criteria

- [ ] ChatTab enum = .chat / .search / .settings
- [ ] ChatZoneView body uses VStack { ChatTabBar, Divider, switch selectedTab, Divider, ChatBottomBar }
- [ ] Tab 1 icon = "cpu" (Apple SF Symbol robot)
- [ ] Tab 1 click = switch to ChatView (current implementation)
- [ ] Tab 2 + 3 = keep current icons, no switching this round (placeholder Text views)
- [ ] ChatTabBar hot area = full button (buttonStyle(.plain)), 18 PT leading inset
- [ ] 1 PT splitter lines (top and bottom of content area) — existing, not touched
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] Boss CUA verification: click tab 1 icon → chat view shown, tab 1 icon = robot

### Do not touch (Q20 / Q51)

- ChatBottomBar (ticket 13 + 14 fixed value)
- 1 PT splitter line above content
- ChatView input box + message list + ChatMessageView
- ChatViewModel.send / clear / switchModel / loadAvailableModels API
- LayoutShellView / ZoneModule parent components
- WenshuConductor / AgentProtocol
- App.swift .commands { SettingsLink } + Settings Scene
- ProviderKeychain / Storing protocol / MiniMaxModelFetcher
- Any existing .frame / .padding values outside this ticket

### Q47 lock: implementation method

macOS SwiftUI 14+ standard TabView API — OR custom HStack + Button(.plain) with full hot area. TabView is the Apple HIG canonical choice; custom HStack is acceptable if TabView style does not match the 3-icon layout.

### Apple HIG references

- https://developer.apple.com/documentation/swiftui/tabview
- https://developer.apple.com/documentation/swiftui/view/buttonstyle(_:)
- https://developer.apple.com/documentation/swiftui/image (SF Symbols)

### History

- ticket 09 + 10: ChatZoneView child component pattern fixed (Q51 parent unchanged)
- ticket 13 + 14: ChatBottomBar 18 PT inset fixed
- ticket 15 + 16 + 17: Provider API config fixed
- Future: ticket 21 (search tab real view), ticket 22 (settings tab real view)
