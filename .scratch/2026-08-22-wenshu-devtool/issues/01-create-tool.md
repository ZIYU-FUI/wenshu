# 01 — Tools/wenshu-devtool creation (Hermes tui_gateway pattern)

**Blocked by:** None.

**Status:** ready-for-agent

## Fix approach (3 steps, Hermes tui_gateway pattern)

1. `Tools/wenshu-devtool/wenshu_devtool.py` (Python 3.9+, zero deps, 7 subcommands)
2. `Tools/wenshu-devtool/README.md` (usage + warning + 老板 8/19 truth)
3. `Tools/wenshu-devtool/.gitignore` (temporary files not in git)

## Acceptance

- [ ] All 7 subcommands work (list_windows / screenshot / ui_dump / menu_dump / settings_dump / keychain_list / keychain_get)
- [ ] README.md clearly documents usage
- [ ] Package.swift unchanged (= does not import Tools/)
- [ ] build/Wenshu.app does not contain devtool (= build script does not cp)
- [ ] swift build / test exit 0
- [ ] 老板 macOS real verification: list_windows returns wenshu NSWindow truth

## Do not touch (Q20)

- Package.swift (do not touch)
- Sources/WenshuApp/ (do not touch)
- Scripts/build-app.sh (do not touch)
- AppIcon.icon/ (do not touch)
