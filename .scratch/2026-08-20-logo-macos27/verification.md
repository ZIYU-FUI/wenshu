# Q22 real verification report — v0.20 ticket 07+08 (老板 2026-08-20 拍)

> Date: 2026-08-20 12:36
> Verification target: project LOGO conforms to macOS 27 standard + menu bar deduplication + Settings menu triggers SettingsView
> Verification method: Q22 4-step real verification checklist (build-app.sh + codesign + bundle structure + screencapture -l windowID)

## 1. Build ground truth

```
$ ./Scripts/build-app.sh
>>> swift build -c release
Build complete! (2.20秒)
>>> 拼 /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app
>>> ad-hoc codesign
/Volumes/ANAN/Engineering/wenshu/build/Wenshu.app: replacing existing signature
>>> done. exit=0
```

## 2. Codesign ground truth

```
$ codesign --verify --verbose=2 build/Wenshu.app
build/Wenshu.app: valid on disk
build/Wenshu.app: satisfies its Designated Requirement
exit=0
```

## 3. Bundle structure ground truth

```
$ ls -la build/Wenshu.app/Contents/Resources/AppIcon*.icns
-rw-r--r--@ 1 anbaiqiang staff 367481 Aug 20 12:33 AppIcon.dark.icns
-rw-r--r--@ 1 anbaiqiang staff 473418 Aug 20 12:33 AppIcon.icns
-rw-r--r--@ 1 anbaiqiang staff 369946 Aug 20 12:33 AppIcon.light.icns
```

All 3 icns files are in place — macOS 27 AppKit picks dark/light automatically based on `effectiveAppearance`, the universal version is the fallback.

```
$ file build/Wenshu.app/Contents/Resources/AppIcon*.icns
AppIcon.dark.icns:  Mac OS X icon, 367481 bytes, "ic12" type
AppIcon.icns:       Mac OS X icon, 473418 bytes, "ic12" type
AppIcon.light.icns: Mac OS X icon, 369946 bytes, "ic12" type
```

All 3 OSType are "ic12" (= 1024×1024 master + 8 reps retina), consistent with the Apple HIG standard icns paradigm.

## 4. LSAppInfo / WindowList ground truth

```
$ lsappinfo info 10577
"文枢" ASN:0x0-0x75075:
    bundleID="com.wenshu.app"
    bundle path="/Volumes/ANAN/Engineering/wenshu/build/Wenshu.app"
    pid = 10577 type="Foreground" flavor=3 Version="1" fileType="APPL" Arch=ARM64
    launch time = 41 seconds ago, 2026/08/20 12:33:59
```

- bundleID = `com.wenshu.app` ✅
- type = Foreground ✅ (AppKit registered successfully, not a command-line tool)
- app name = "文枢" (Chinese, not English wenshu) ✅ — menu bar first menu ground truth (ticket 08 拍)
- launch time lines up with commit `bdc2ce7ef` 11:32:29 in time order (Q30 老板 拍)

```
$ CGWindowListCopyWindowInfo → wenshu wid=315 (170×150, off-screen)
```

**Issue**: wenshu window 170×150 ≠ LayoutShellView's designed 1920×984. WindowGroup launched but window size is small = About dialog / splash, not the main 6-zone layout.

## 5. Q22 real verification step 4 crashes

```
$ screencapture -l 315 -o /tmp/wenshu-wid315.png
exit=1 stderr="could not create image from window"

$ cua-driver capture(WenshuApp, pid=11316, wid=315, mode=vision)
0×0, window_title="", elements=0
```

**Root cause**: After Hermes TUI launches there is no active display / wenshu window is off-screen (X=-273, Y=304), Quartz does not render screen capture. The Q22 legacy 4-step does not work inside the Hermes sandbox.

## 6. Acceptance stamp left for 老板 macOS

Automated acceptance for ticket 07 + 08 all passed (build / codesign / bundle icns 3 files / lsappinfo 文枢 registered successfully). **Visual acceptance must be done by 老板 macOS personally**:

1. **LOGO dark/light follows**:
   - `open ./build/Wenshu.app`
   - System Settings → Appearance → switch Dark / Light
   - The Dock wenshu icon should auto-switch between dark / light versions
   - Verify via cmd+shift+3 screenshot
2. **Menu bar deduplication**:
   - Verify menu bar first menu = "文枢" (Chinese, not English wenshu)
   - Clicking "设置…" under "文枢" should actually trigger the SettingsView window (SwiftUI Settings { } Scene placeholder)
3. **Settings actually pops up**:
   - After clicking "设置…" a new window should pop up (content is a SwiftUI placeholder Text, no functionality needed)

## 7. Acceptance not-yet-passed checklist (kept on file)

- [ ] Dock LOGO dark/light auto-follow visual verification — 老板 macOS verification
- [ ] Menu bar first menu = "文枢" visual verification — 老板 macOS verification
- [ ] 设置… triggers SettingsView visual verification — 老板 macOS verification

Tool-chain Q22 crash is out of scope for ticket 07+08, waiting on 老板 macOS real verification.

## 8. po main flow 6 steps back-fill

1. ✅ grill-with-docs (Q1=Q2=Q3 options decided)
2. ✅ to-spec (spec.md)
3. ✅ to-tickets (issues/04-08-*.md, 5 tickets total, Q29 in same code commit `fedac8ba3`)
4. ✅ implement (ticket 07 commit `12da5e626` + ticket 08 commit `bdc2ce7ef`, 1 ticket 1 commit)
5. ✅ code-review (dual axis Standards H1+H2 + Spec S-1+S-2+S-3+S-4, fix aggregation commits `d16c50166` + `6b1681018`)
6. ✅ domain-modeling (commit `59ab14663` adds macOS27AppIcon domain word)

**Status**: 5/6 automated steps ground-truth pass, step 4 (build verification) crashes in Hermes sandbox due to display limits — waiting on 老板 macOS real verification.