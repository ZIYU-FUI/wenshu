# Ticket 001 — embed Info.plist into __TEXT,__info_plist section

Status: done (commit `fcd025f17`)

## What

Add `linkerSettings.unsafeFlags([-Xlinker, -sectcreate, -Xlinker, __TEXT, -Xlinker, __info_plist, -Xlinker, Sources/WenshuApp/Resources/Info.plist])` to the WenshuApp executable target in `Package.swift`.

## Why

Per Apple HIG TN2418 + developer.apple.com/forums/thread/734540:

- `Bundle.preferredLocalizations` requires `CFBundleLocalizations` (declared in Info.plist) for the bundle to know what locales it supports.
- For bare Mach-O binaries (`swift build` + `open .build/.../WenshuApp`), `Bundle.main` resolves to the binary path which has no Info.plist alongside it.
- Foundation falls back to `CFBundleDevelopmentRegion` (or, if absent, to en) and returns English for every NSLocalizedString regardless of the user's `Locale.preferredLanguages`.
- The previous v1.50 fix attempts (commits `89de1d648` + `e7a08c002`) addressed only the .app case via `Scripts/build-app.sh` copy. Dev iteration loops still hit the regression.

## How

Apply the linker flag pattern documented in polpiella.dev "Adding an Info.plist file to a Swift executable":

```swift
linkerSettings: [
    .unsafeFlags([
        "-Xlinker", "-sectcreate",
        "-Xlinker", "__TEXT",
        "-Xlinker", "__info_plist",
        "-Xlinker", "Sources/WenshuApp/Resources/Info.plist"
    ])
]
```

**Field-order requirement**: `linkerSettings` must follow `resources` in the Target builder (= SPM PackageDescription validates parameter order).

## Verification

```bash
$ otool -P .build/out/Products/Debug/WenshuApp
.build/out/Products/Debug/WenshuApp:
(__TEXT,__info_plist) section
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <!-- v0.40 apple-001 i18n ... -->
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
    </array>
    ...
```

At runtime, for a zh-Hans-CN user:

- `Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations")` returns `["en", "zh-Hans"]`
- `Bundle.main.preferredLocalizations` returns `["zh-Hans"]`
- `NSLocalizedString("tab.title.foreshadowing", bundle: .main, value: "FB")` returns `"伏笔"` (= zh-Hans value)

## Side effects

- `Scripts/build-app.sh` still copies `Sources/WenshuApp/Resources/Info.plist` into `Wenshu.app/Contents/Info.plist` for Finder / LaunchServices metadata. The `__info_plist` section in the binary is a secondary mirror — for the .app case, `Contents/Info.plist` takes precedence (= canonical .app layout).
- The existing comment in `Scripts/build-app.sh` L26 "SwiftPM `-sectcreate __TEXT __info_plist` 是裸 run 用的, .app bundle 不需要" is now slightly contradicted (= the section is benign for .app but no longer strictly necessary). Soft follow-up: update the comment to clarify that the section is the binary-side mirror.

## Future Apple HIG implications

- `swift run`: works (bare Mach-O embeds section into the run binary).
- `swift test`: works (test target uses `Bundle.module`; its own Resources have their own CFBundleLocalizations).
- `bash Scripts/build-app.sh`: works (.app gets Info.plist from both Contents/Info.plist and __info_plist; Contents/Info.plist takes precedence).
- Future Xcode .xcodeproj migration: works (Xcode's own INFOPLIST_FILE + GENERATE_INFOPLIST_FILE take precedence; the SPM linkerSettings would be redundant but not harmful).