# v0.01.0 WO-001 Acceptance Log

**WO**: v0.01.0 极简闭环 · WO-001 SwiftPM 初始化 + macOS 空窗口
**Date**: 2026-08-07
**Verifier**: my-pm (PM-direct)
**CC final commit**: `442fe2003e7c4a22148a0a32e9921771e15b3cb3`
**Branch**: main
**Acceptance**: ✅ All 6 criteria met + visual window verified by PM-direct

---

## AC checklist

- [x] `Package.swift` exists at `/Volumes/ANAN/Engineering/wenshu/Package.swift`
- [x] `Sources/WenshuApp/App.swift` and `MainView.swift` with `@main` + `WindowGroup` + `NavigationSplitView`
- [x] `swift build` exits 0 (12.21s cold, 0.33s warm)
- [x] `swift run` launches "文枢" window (PID 16951 alive, NSApplication run loop running)
- [x] `.gitignore` at wenshu/ root with `.build/`, `*.xcodeproj/`, `DerivedData/`, `Package.resolved`
- [x] `git init` + initial commit `442fe20` (8 files, 1052 insertions)

## PM-direct visual verification (above-and-beyond)

Launched `swift run` in background, captured window via cua-driver AX tree:

- Window title: **欢迎** (right detail pane placeholder, as specced)
- Window bounds: (569, 92) size 900x652
- Sidebar heading: **项目** (left pane placeholder, as specced)
- Toolbar button: **隐藏边栏** (NavigationSplitView default control)
- Menu bar root: **Wenshu** (ProcessName from binary, NOT from bundle — expected at SwiftPM-only phase)
- File menu item: **新文枢窗口** (WindowGroup default)
- 134 interactable AX elements captured (window UI fully wired, not a stub)

Process killed after verification (PID 16951). No lingering window state.

## Compatibility decisions CC made (PM-direct endorses)

1. **`swift-tools-version: 6.4`** (not 6.0) — required to unlock `_PackageDescription 6.4` for `MacOSVersion.v27`. NOT a platform downgrade — `.macOS(.v27)` kept per spec. Documented in `Package.swift` header comment.
2. **`Info.plist` at `Sources/WenshuApp/Resources/Info.plist`** (excluded from SwiftPM resource bundling) — SwiftPM rejects top-level `Info.plist` resource. File still consumed via linker `-sectcreate __TEXT __info_plist` flag. Verified via `otool -P` (1059 bytes embedded).
3. **No `wenshu.xcodeproj`** — SwiftPM-only this phase. Xcode project arrives when iPadOS/iOS targets are added (iOS 27 simulator still gated per `CLAUDE.md §10`).

## Known scope non-coverage (deferred to subsequent WOs, not regressions)

- No CoreData / WenshuStoreActor → **WO-002**
- No LLM provider / SSEParser → **WO-003**
- No `wenshu.xcodeproj`
- No XCTest target (no testable surface in pure skeleton)
- `.hermes/` empty dir (committed in spirit; git can't track empty dirs without `.gitkeep`)

## Workspace state after WO-001

```
/Volumes/ANAN/Engineering/wenshu/
├── .build/                  (gitignored, 12s cold build)
├── .git/                    (main branch, 1 commit)
├── .gitignore
├── .hermes/                 (empty, exists)
├── AGENTS.md
├── CLAUDE.md
├── Package.swift            (SwiftPM 6.4, .macOS(.v27))
├── README.md
└── Sources/
    └── WenshuApp/
        ├── App.swift        (@main + WindowGroup("文枢"))
        ├── MainView.swift   (NavigationSplitView 项目|欢迎)
        └── Resources/
            └── Info.plist   (LSUIElement=false, CFBundleDisplayName=文枢)
```

## Dispatch notes for next worker

- Dispatcher initially skipped `t_c4579934` because `claude-code` profile is not on-disk (only `default/aif/designer/my-pm/wenshu` are). Reassigned to `my-pm` and PM-direct fired `claude --bare -p` via wrapper script `/tmp/cc-out/_fire-wo-001.sh` (template: `~/.hermes/profiles/my-pm/skills/software-development/pm-loop-execution/references/cc-fire-wrapper-script-escape-hatch.md`).
- CC self-reported complete in 3:50 (PID 15443, fire.log `/tmp/cc-out/wo-001-fire.log`).
- Pattern for future WOs: write prompt + wrapper, fire via `terminal(background=true, notify_on_complete=true)`, poll `fire.log` until `CC_DONE=` line appears.

## Status

✅ **WO-001 complete**. PM-direct authorizes WO-002 dispatch (CoreData model + WenshuStoreActor).