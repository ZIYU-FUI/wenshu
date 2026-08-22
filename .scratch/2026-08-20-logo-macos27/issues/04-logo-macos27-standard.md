# 04 — Project LOGO conforms to Apple macOS 27 standard app (老板 2026-08-20 拍)

**What to build:**

老板 2026-08-20 09:25 拍 "not just the Dock LOGO, the entire project LOGO conforms to the APPLE MAC OS 27 standard app". Engineering management authorized by 老板 (8/19 拍 "you decide on your own") + no acceptance needed + 1 ticket 1 commit hard rule + po main flow 6 steps.

**Fix ground truth:**

1. Project's `Sources/WenshuApp/Resources/AppIcon.icns` ground truth = 473 KB, 11 reps (ic04/ic05/ic07/ic08/ic09/ic10/ic11/ic12/ic13/ic14/info, 16/32/64/128/256/512/1024 PT). Follows the Apple HIG standard Cocoa .app bundle paradigm, AppKit reads `Contents/Resources/AppIcon.icns` to auto-render Dock + Launchpad + cmd+tab
2. Modify `Package.swift`: keep `Resources/Info.plist` excluded + add `Resources/AppIcon.icns` to resources processing
   - SwiftPM `.executableTarget` add `resources: [.process("Resources")]` or `.copy([.init(stringLiteral: "AppIcon.icns")])`
3. Modify `Sources/WenshuApp/App.swift`:
   - Delete `applicationWillFinishLaunching` code that installs applicationIconImage (ticket 05 takes over entirely, runtime safety net is deprecated, see CONTEXT.md macOS27AppIcon row)
   - **No longer keep runtime fallback**: the .app bundle paradigm is the Apple HIG authoritative source, runtime install code conflicts with AppKit Dock tile
   - `applicationDidFinishLaunching` unchanged (ticket 05 decision)
4. Keep `Info.plist` line 11-12 `CFBundleIconFile="AppIcon"` + `CFBundleIconName="AppIcon"` (already correct, no change)
5. swift build exit 0
6. Q22 real verification: pkill + launch new + screencapture -l real screenshot

**Blockers:** none

**Acceptance:**

- swift build exit 0
- swift test 12/12 LayoutShellViewModelTests all pass
- 老板 launches wenshu, Dock 文枢 LOGO visible (not generic system icon)
- macOS 27 standard app paradigm (Pages / Numbers / Xcode same Dock LOGO rendering)
- Does not depend on `/Users/anbaiqiang/Desktop/LOGO/` desktop files (persisted into the project)

**Do not touch:**

- /Volumes/ANAN/.hermes/ any files (老板 8/11 拍 'hermes do not touch')
- ~/wenshu-plugin/ outside the project directory
- macOS chrome 52 PT (.windowStyle(.titleBar))
- Menu bar NSMenu 6 items (老板 8/20 09:25 拍 keep)
- Drag line visuals (ticket 02 already commit 88c30efe6)
- WenshuCore 14 ground-truth modules
- ChatView (v0.20 ticket 01)

**Ground-truth references (Apple HIG):**

- NSApplication applicationIconImage: https://developer.apple.com/documentation/appkit/nsapplication/applicationiconimage
- CFBundleIconFile: https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleiconfile
- CFBundleIconName: https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleiconname
- NSApplication dockTile: https://developer.apple.com/documentation/appkit/nsapplication/docktile
- NSDockTile display: https://developer.apple.com/documentation/appkit/nsdocktile/display()
- macOS 27 App icon HIG: https://developer.apple.com/design/human-interface-guidelines/app-icons