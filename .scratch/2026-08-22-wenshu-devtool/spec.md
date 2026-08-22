# Spec — Tools/wenshu-devtool (Hermes tui_gateway pattern remote dev tool)

> Date: 2026-08-22
> 老板 2026-08-22 拍: "Can you embed a tool inside the 文枢 app that can grab UI state — at release time we remove it; spin up a separate remote dev tool thing. At actual release we remove it."

## Business language (老板-facing)

老板's requirement: at wenshu app runtime, be able to retrieve UI state (screenshot + UI state + window list) for remote debugging (= hermes side can see what wenshu looks like on macOS, no need to ask 老板 to screenshot and send each time).

老板's original words: "just spin up a separate remote dev tool thing" = **separate-process dev tool, not embedded in wenshu**. 老板 himself knows "at actual release we remove it" = this tool does not ship in the wenshu bundle, only used during dev.

## Fix approach (5 principles 1 + 3 + 4 satisfaction, Hermes tui_gateway pattern)

`Tools/wenshu-devtool/` (inside wenshu repo, wenshu release bundle **does not contain** (= Package.swift does not import `Tools/`, build-app.sh does not cp `Tools/`)):

1. `Tools/wenshu-devtool/wenshu_devtool.py` (Python 3.9+ stdlib, zero dependencies):
   - `cmd_list_windows`: use `osascript -e 'tell application "System Events" to tell process "WenshuApp" to get ...'` to list NSWindow truth (title / frame / visible / id)
   - `cmd_screenshot <window_id>`: `screencapture -l <window_id> <output_path>` (老板 8/19 truth = macOS `screencapture -l` window truth)
   - `cmd_ui_dump`: use `osascript` + System Events to dump the current frontmost window's UI elements (button / text / menu item truth)
   - `cmd_menu_dump`: dump the current NSMenu tree (Apple / 文枢 / File / Edit / View / Window / Help truth)
   - `cmd_settings_dump`: read UserDefaults to show wenshu.llm.* truth (= provider / model / base_url truth)
   - `cmd_keychain_list`: list providers already stored in ProviderKeychain
   - `cmd_keychain_get <provider_slug>`: return provider's key (last 8 chars shown, not logged)
   - Main entry: `python3 wenshu_devtool.py <subcommand> [args...]`
2. `Tools/wenshu-devtool/README.md` (usage + warning + 老板 8/19 truth = "not embedded in wenshu core")
3. `Tools/wenshu-devtool/.gitignore` (key cache not in git, if any temporary files)

**Package.swift not changed**: `Tools/` is not in Swift package sources (= not compiled into wenshu binary).
**Scripts/build-app.sh not changed**: does not cp `Tools/` into `build/Wenshu.app/Contents/Resources/` (= not in release bundle).

## Truth (老板 8/19 truth baseline not violated)

- ✅ **wenshu core code not changed** (Package.swift / Sources/WenshuApp/ / Sources/ not changed)
- ✅ **wenshu build script not changed** (Scripts/build-app.sh not changed)
- ✅ **wenshu release bundle does not contain devtool** (build/Wenshu.app/ does not add devtool files)
- ✅ **devtool is an independent Python process**, runs on the Hermes side, not inside the wenshu process (= does not change wenshu UI / state truth)
- ✅ devtool uses Apple standard APIs (`osascript` + `screencapture` + `NSUserDefaults` reads), no inject no hook no patch wenshu
- ✅ 老板 himself 拍 "at actual release we remove it" = add TODO in README, at release time delete the `Tools/` directory (= no need to fix wenshu core)

## Interface truth (7 subcommands)

```
python3 Tools/wenshu-devtool/wenshu_devtool.py list_windows
python3 Tools/wenshu-devtool/wenshu_devtool.py screenshot <window_id> <output_path>
python3 Tools/wenshu-devtool/wenshu_devtool.py ui_dump
python3 Tools/wenshu-devtool/wenshu_devtool.py menu_dump
python3 Tools/wenshu-devtool/wenshu_devtool.py settings_dump
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_list
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_get <provider_slug>
```

## Acceptance

- [ ] `Tools/wenshu-devtool/wenshu_devtool.py` created (7 subcommands)
- [ ] `Tools/wenshu-devtool/README.md` (usage + warning)
- [ ] Package.swift not changed (= Swift sources do not include `Tools/`)
- [ ] build/Wenshu.app/Contents/Resources/ does not contain devtool
- [ ] swift build exit 0 (Package.swift still compiles cleanly)
- [ ] swift test exit 0
- [ ] 老板 macOS real verification: run `list_windows` returns wenshu NSWindow truth

## Do not touch (Q20 hard constraint)

- Package.swift (do not touch)
- Sources/WenshuApp/ (do not touch)
- Scripts/build-app.sh (do not touch)
- AppIcon.icon/ (do not touch)

## Apple truth references

- https://developer.apple.com/library/archive/qa/qa1519/_index.html (AppleScript System Events GUI truth)
- https://developer.apple.com/documentation/security/keychain_services (security command-line truth)
- https://ss64.com/mac/screencapture.html (`screencapture -l` truth)
- Hermes tui_gateway/server.py (Hermes truth pattern = independent dev tool process)

## Related

- Depends on: none
- Depended on by: none (independent dev tool, does not affect wenshu truth)
