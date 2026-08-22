# 01 — Menu bar visible + Dock logo (老板 2026-08-20 拍)

**What to build:**
老板 2026-08-20 拍 "macOS still has no menu bar, and the Dock has no app LOGO". Fix ticket 01.

After fix:
- WenshuAppDelegate.applicationDidFinishLaunching delete setContentSize/center (avoid touching NSWindow before SwiftUI finishes the main menu, root cause is macOS 27 lazy menu populate bug)
- NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon") set at launch (Dock logo ground truth)
- Keep `.commands { CommandMenu/CommandGroup/SettingsLink }` (v0.17 ticket 07 commit 4c42fa79)

**Blockers:** 老板 2026-08-20 拍 "solve these two first before tackling the chat area".

**Acceptance:**
- swift build exit 0
- 老板 launches wenshu and sees the menu bar (screenshot verification, 老板 8/19 evening 拍 "I can only verify requirements that screenshots can verify")
- 老板 sees the Dock logo (wenshu logo replaces generic icon)
- Do not touch: hermes / 6-zone layout framework / drag line visuals / WenshuCore 14 ground-truth modules / ChatView