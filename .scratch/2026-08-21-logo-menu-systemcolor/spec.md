# Spec — LOGO corner-radius mask + fully Chinese menu bar + LOGO follows system color (老板 2026-08-21 ruled)

> Date: 2026-08-21
> 老板 2026-08-21 reviewed v0.20 logo ticket 08 and reported: "the LOGO has no rounded corners; the LOGO doesn't follow the system color; the menu-bar `wenshu` still hasn't been fixed to Chinese."
> System color is already implemented (`DesignColor` uses `NSColor` semantic); this spec only covers LOGO corner radius + LOGO follows system color + fully Chinese menu bar — three items.

## Business language (老板-facing)

### 1. LOGO corner radius

- When macOS Dock / Launchpad / cmd+tab shows the wenshu LOGO = rounded rectangle (Apple HIG standard mask).
- Regardless of dark / light system appearance, the LOGO is always rounded.
- The LOGO content is unchanged; only macOS applies the corner mask.

### 2. LOGO follows the system color

- System = Dark Mode → Dock / Launchpad / cmd+tab show the dark LOGO variant.
- System = Light Mode → Dock / Launchpad / cmd+tab show the light LOGO variant.
- When the user switches the system appearance, the LOGO follows automatically (ticket 07 already shipped, but 老板 saw it not following → root cause pending).

### 3. Fully Chinese menu bar

- The top menu bar's 7 items = `Apple / 文枢` followed by the 5 standard macOS items (`File / Edit / View / Window / Help`), all 5 localized to Chinese per `CFBundleLocalizedString` convention.
- No English menu items are allowed; `wenshu` is the only English straggler.
- The English menu injected by macOS 27's lazy populate must not appear.

## Root-cause chain

### 1. LOGO has no rounded corners — root cause

- The current 3 icns files (`AppIcon.icns` universal + `AppIcon.dark.icns` + `AppIcon.light.icns`) **completely lack a mask chunk**.
- icns mask chunk standard names: `icp4` (16×16) / `icp5` (32×32) / `icp6` (64×64) / `icp7` (128×128) / `icp8` (256×256) / `icp9` (512×512) / `icp10` (1024×1024).
- mask = 8-bit grayscale PNG; black = opaque, white = transparent.
- macOS Dock / Launchpad / cmd+tab use the mask to apply rounded corners.
- The current 11 icns reps are all RGB PNGs with no alpha mask → Dock does not round the corners; corners render square.
- Root cause = the icns files lack a mask chunk (Apple HIG not met).

### 2. LOGO doesn't follow the system color — root cause

- Ticket 07 landed `AppIcon.dark.icns` (367481 bytes, 8 reps) + `AppIcon.light.icns` (369946 bytes, 8 reps); AppKit auto-selects based on `effectiveAppearance`.
- But 老板 saw on macOS that, in system Dark Mode, the LOGO still shows the light variant → not right.
- Three root-cause hypotheses:
  1. AppKit macOS 27 dark/light auto-selection has a bug (Pages / Numbers work fine → ruled out).
  2. macOS Dock cached the icns (restart Dock with `killall Dock` to clear the cache).
  3. The icns files themselves lack a macOS 27-required chunk (`ic07` with PNG + alpha channel, or `s8mk` mask chunk), so AppKit does not recognize them as dark/light variants.

### 3. Menu-bar "wenshu" English override — root cause (老板 8/21 supplement)

- 老板's screenshot shows the menu bar = `Apple / wenshu / [5 Chinese-localized File/Edit/View/Window/Help items]` (the latter 5 are correctly localized to Chinese).
- Only the first item "wenshu" is English (老板 requires "文枢"); the other 5 items are Chinese (correct).
- `NSMenu` L218-251 already installs the Chinese "文枢" as the real value (same pattern as Pages / Numbers / Xcode).
- Root cause = SwiftUI framework **automatically installs an empty "wenshu" menu group** (not a full File/Edit/View/Window/Help), because:
  1. `WindowGroup("文枢") { LayoutShellView() }`'s first-parameter `title` = "文枢" → SwiftUI expects to install one menu, but macOS 27's lazy-populate injection runs after `NSMenu.applicationWillFinishLaunching`, so SwiftUI overwrites the Chinese "文枢" installed by NSMenu with English "wenshu".
  2. `Settings { }` Scene internally installs an empty `CommandGroup(.appSettings)`, but that doesn't affect the first menu.
- 老板's requirement = "only the wenshu menu is English; the rest is fine" → NSMenu is already correct, but the first item is being overwritten by SwiftUI. Fix: remove the `WindowGroup` first-parameter `title` so the Chinese "文枢" installed by NSMenu is not overwritten by SwiftUI.

## Fix plan (3 tickets, 1 ticket 1 commit)

### Ticket 01 — LOGO corner radius enlarged (re-export master + iconutil regenerate icns)

#### Business language
- macOS Dock / Launchpad / cmd+tab show the wenshu LOGO at Apple HIG standard rounded corner radius (= 22% = ≈225 px on a 1024×1024 canvas).
- The LOGO design source changes = designer re-exports the master; the data flow runs through `iconutil` to auto-generate icns.
- All 3 icns files (dark / light / mono) are regenerated from the new master.

#### Fix specification (4 steps)
1. 老板 edits the Sketch master to enlarge the rounded-rect path: 22% on a 1024×1024 canvas (= ≈225 px radius).
2. 老板 re-exports 3 master PNGs:
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-dark.png`
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-light.png`
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-mono.png`
3. I use `iconutil` to regenerate the 3 icns files:
   - Build `wenshu-icon.iconset/`, run `sips -z <size> <png>` to generate 11 retina-standard reps (16/32/64/128/256/512/1024 + @2x), rename to iconutil's standard layout (`icon_16x16.png` + `icon_16x16@2x.png` etc.).
   - Run `iconutil -c icns wenshu-icon.iconset/ -o AppIcon.dark.icns` (one run per file, 3 total).
4. `cp` the 3 files into `Sources/WenshuApp/Resources/`; update `Scripts/build-app.sh` to also `cp` the mono icns.
5. 1 ticket 1 commit + Q33 icns verification script + 老板 macOS Dock corner-radius check.

#### Apple HIG references
- https://developer.apple.com/design/human-interface-guidelines/app-icons
- Apple App Icon 22% corner radius standard (= macOS 27 Dock mask applied automatically)
- `iconutil` man page

#### Out of scope
- `AppIcon.icns` (fallback universal version retained per ticket 04 + 05 truth)
- `App.swift` / `Package.swift` / `Info.plist`
- v0.21 chat ticket 01 (unrelated)

### Ticket 02 — LOGO dark variant text color lightened (matches system-color truth)

#### Business language
- System Dark Mode → Dock LOGO = dark background + light text (currently dark background + dark text, invisible).
- System Light Mode → Dock LOGO = light background + dark text (currently OK, untouched).
- System accent-color mode → Dock LOGO = accent background + dark text (from 老板's screenshot the text color hasn't changed; current state is OK, untouched).

#### Fix specification (2 steps)
1. 老板 edits the Sketch master to lighten the "文枢" text color on the dark variant master (= contrast against the dark background, similar to `#F5F5F5` or the Apple system label color light).
2. Re-export `wenshu-icon-master-1024-dark.png`; I run the ticket 01 regeneration pipeline.
3. 1 ticket 1 commit + 老板 macOS Dock verification when toggling Dark Mode.

#### Apple HIG references
- Apple HIG Dark Mode icon variant = light text + dark background (auto-selected by macOS Dark Mode).
- https://developer.apple.com/design/human-interface-guidelines/app-icons

#### Out of scope
- light / mono variants (current state OK)
- `App.swift` / `Package.swift` / `Info.plist`

### Ticket 03 — Menu bar "wenshu" → "文枢" (drop `WindowGroup` title + adopt `SettingsScene`)

#### Business language
- Top menu bar first item = "文枢" (Chinese, not English `wenshu`).
- The other 5 items (the Chinese-localized `File / Edit / View / Window / Help` labels) stay Chinese (already correct).
- The English menu injected by macOS 27 SwiftUI lazy populate no longer overwrites the Chinese installed by NSMenu.

#### Fix specification (4 steps)
1. In `App.swift` L176, drop `WindowGroup("文枢") { LayoutShellView() }`'s first-parameter `title`; change to `WindowGroup { LayoutShellView() }` (so SwiftUI doesn't inject the `wenshu` menu).
2. In `App.swift` L186, replace `Settings { }` Scene with the `SettingsScene` pattern (SwiftUI 5+ / macOS 14+ supports it) so we control menu installation ourselves.
3. The Chinese 6 items installed by `WenshuAppDelegate.applicationWillFinishLaunching`'s `NSMenu` stay (already landed in ticket 08; untouched).
4. Run `killall Dock` to clear macOS Dock's menu-bar cache (Dock caches the menu bar).
5. macOS 27 verification: system appearance dark + switch menu bar → first item is "文枢", not "wenshu".

#### Apple HIG references
- https://developer.apple.com/documentation/swiftui/windowgroup (the `title` parameter = SwiftUI lazy-populate menu name)
- https://developer.apple.com/documentation/swiftui/settingsscene
- vdhamer/Photo-Club-Hub-HTML#248 (SwiftUI `.commands` macOS 27 lazy-populate bug)

#### Out of scope
- The 6 Chinese items installed by `NSMenu` L218-251 (already landed in ticket 08)
- `ChatView` / `LayoutShellView` (unrelated to this ticket)
- v0.20 ticket 08 `SettingsLink` trigger mechanism (`SettingsScene` still triggers SwiftUI Settings)

## po main flow — 6 steps

1. ✅ grill-with-docs (3 decisions ruled: full Option A + LOGO corner radius + LOGO follows system color + Chinese menu bar)
2. ✅ to-spec (this file)
3. → to-tickets (`.scratch/2026-08-21-logo-menu-systemcolor/issues/01-03-*.md`)
4. → implement (1 ticket 1 commit, streak mode)
5. → code-review (dual-axis Standards + Spec, run once after all ticket commits)
6. → domain-modeling (add `AppleHIGIconMask` + `macOS27AppearanceIcon` + `SwiftUICommandsLazyPopulate` to CONTEXT.md)

## Acceptance criteria (老板 ruled 8/19 evening: streak mode)

- Each ticket: `swift build` exit 0 + `swift test` exit 0 + `iconutil` / Icon Composer real verification + Apple HIG standard.
- After all ticket commits: run dual-axis code-review.
- 老板 macOS verification:
  - Dock LOGO corner radius matches Apple HIG (regardless of dark/light/tinted/transparent — ticket 04 Icon Composer auto-derives)
  - When the system appearance changes, the Dock LOGO follows automatically (dark variant's light text fixes the "invisible" issue)
  - Menu bar fully Chinese (no English File / Edit / View / Window / Help) — **ticket 03 awaits round-4 grill root cause**
  - Transparent mode: LOGO renders transparently
  - Tinted mode: LOGO shows the accent-color truth

## Status (8/21 16:35)

- ✅ ticket 04 done (commit `0aabd989e`): Icon Composer replaces the 3 icns files; tickets 01 + 02 are also covered.
- ✅ ticket 05 done (commit `e474965`): Info.plist switched to Chinese + Icon Composer path, so the LOGO shows the real value and the menu bar auto-follows the APP name.
- ⏳ ticket 03 (menu bar "wenshu" → "文枢") awaits the round-4 grill root cause (Q15 `SettingsScene` may not exist → crash chain already found; don't guess the API). Ticket 05 changing `CFBundleDisplayName = "文枢"` may let the menu bar auto-follow — 老板's macOS verification decides whether ticket 03 needs to run.

## Out of scope (Q20 hard constraint)

- v0.20 tickets 04 + 05 (LOGO dark/light files already landed; ticket 02 verification is not redone)
- v0.20 tickets 07 + 08 (dark/light icns + `SettingsLink` trigger, already committed)
- v0.21 ticket 01 (`ChatMessage.source`, unrelated to this spec)
- AGENTS.md / CLAUDE.md (baselines untouched)
- macOS-only (no iOS / iPadOS / Catalyst)

## Related commits

- `5d8239d0a` — v0.21 ticket 01 `ChatMessage.source` (unrelated)
- `19ca2561f` — v0.21 spec + 6 tickets (chat-persistent-multi-agent, unrelated)
- `fedac8ba3` — v0.20 ticket 07 + 08 spec + issues (backfilled)
- `bdc2ce7ef` — v0.20 ticket 08 menu-bar dedupe + `SettingsView` trigger (foundation; ticket 03 builds on it)
- `12da5e626` — v0.20 ticket 07 LOGO dark/light auto-follow (foundation; ticket 02 verification)
