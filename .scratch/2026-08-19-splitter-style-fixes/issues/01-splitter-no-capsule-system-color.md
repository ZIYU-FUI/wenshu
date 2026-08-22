# 01 — Splitter remove rounded caps + use Apple system color (老板 2026-08-19 拍)

**What to build:**
老板 2026-08-19 16:50 拍 "remove rounded caps" + 18:15 拍 "color use system color" + 18:48 feedback "you forgot 拍, now patch". Integrate into 1 commit run.

After change:
- NativeSplitter Rectangle remove `.clipShape(.capsule)` (cancel rounded caps)
- Rectangle `.fill` use `.separatorColor` (static) / `.controlAccentColor` (hover) (Apple system color)
- Rectangle `.shadow` use `.controlAccentColor` (same)
- `DesignColor.splitterLine` change to `.separatorColor`
- `DesignColor.accentBlue` change to `.controlAccentColor`
- `StaticDividerHorizontal` / `Vertical` change to `.separatorColor`

**Blocked by:** None
**Status:** ready-for-agent → impl done → waiting for 老板 verify

## Acceptance criteria

- [ ] NativeSplitter Rectangle remove `.clipShape(.capsule)` (cancel rounded caps, become rectangle)
- [ ] Static 2 PT use `Color(nsColor: .separatorColor)` (Apple HIG divider color)
- [ ] Hover 4 PT use `Color(nsColor: .controlAccentColor).opacity(0.25)` (Apple HIG system bright color)
- [ ] Shadow use `Color(nsColor: .controlAccentColor).opacity(0.15)`
- [ ] `DesignColor.splitterLine` change to `.separatorColor`
- [ ] `DesignColor.accentBlue` change to `.controlAccentColor`
- [ ] `StaticDividerHorizontal` / `Vertical` `.fill` change to `.separatorColor`
- [ ] D_h / D_v 5 vertical splitters all effective (1 component change 1 place = 6 all change)
- [ ] Splitter visual (4 PT hover thicker / shadow / opacity 0.25 / 0.15) all preserved
- [ ] Splitter drag / hit area / cursor unchanged (cursor backlog 02 todo)
- [ ] macOS chrome 52 PT unchanged
- [ ] LayoutTokens / bandH / toolbar width unchanged
- [ ] `swift build` exit 0

## Business-language description (老板 understands)

- Splitter becomes rectangle (not draw rounded corners, same as macOS system divider)
- Static 2 PT use Apple system color (dark/light auto-adapt, no hard-code)
- Hover 4 PT use Apple system bright color (consistent with macOS accent color)