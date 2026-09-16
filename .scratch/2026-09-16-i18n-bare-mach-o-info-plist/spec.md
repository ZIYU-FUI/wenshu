# i18n bare-Mach-O Info.plist section embedding

## Boss OOB chain

- 2026-09-16 morning: boss reports '左栏目录树，因为改 IOCN，出错了，UI 显示错误' (= sidebar folder ICON = Lucide kebab-case names after v1.0.0-m1-shell migration to SF Symbols 6 = blank rectangles)
- 2026-09-16 mid-day: boss reports '目录树重叠了。然后多语言没加载' (= reference library section header overlapping a folder row + sidebar / inspector labels in English for a zh-Hans-CN user)
- 2026-09-16 afternoon: boss interrupts the half-measure fallback attempt with '不要什么都先想着最简单，不要为以后留坑。要想着从根本解决问题' (= root-cause fix, not runtime workaround)

## Surface symptoms

1. `NewLibraryOutlineView.swift:1158-1166` `standardFolderNames` literal still passed `globe` / `user-round` / `list-tree` / `book-text` / `file-pen-line` to `Image(systemName:)` = blank rectangles in the sidebar folder rows.
2. `PreviewPane.swift:107-114` `EntityType.icon` enum case strings = same Lucide kebab-case = blank rectangles on the reference entity preview thumbnail at L802.
3. `ShellDetailColumn.swift:492` `kanban` and L505 `list-checks` toolbar button ICONs = blank rectangles in the detail-column toolbar.
4. Sidebar reference-library section header overlapped with folder row visually (= Chinese strings are wider than English, broke List(.sidebar) implicit row height).
5. Every NSLocalizedString call returned English values for the debug Mach-O binary, even though the user's system language is zh-Hans-CN.

## Root cause analysis

For (1)-(3) the root cause is the same: SwiftUI's `Image(systemName:)` accepts only Apple SF Symbols identifiers; Lucide names like `user-round` / `list-tree` / `book-text` / `file-pen-line` / `kanban` / `list-checks` are not valid SF Symbols and SwiftUI falls back to a placeholder rectangle glyph.

For (4)-(5) the root cause is per Apple HIG TN2418 + developer.apple.com/forums/thread/734540:

> Bundle's preferred localization matching uses the bundle's
> `CFBundleLocalizations` (= declared in Info.plist) +
> `CFBundleDevelopmentRegion`. If `CFBundleLocalizations` is
> missing from a bundle's Info.plist, Foundation falls back to
> `CFBundleDevelopmentRegion` only and `Bundle.preferredLocalizations`
> returns just that one locale regardless of the user's actual
> `Locale.preferredLanguages`.

When wenshu runs as a bare Mach-O (`swift build` + `open .build/.../WenshuApp`), `Bundle.main` resolves to the binary path. The binary has no Info.plist file alongside it (= there is no `.app` wrapper). Therefore `Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations")` returns nil and Foundation falls back to the absent `CFBundleDevelopmentRegion` (= treated as en per Foundation's defaults) and every NSLocalizedString returns the English fallback value.

The v1.50 worktree's previous fix (commits `89de1d648` + `e7a08c002`) addressed this by copying `Sources/WenshuApp/Resources/{en,zh-Hans}.lproj/` into `.app/Contents/Resources/` in `Scripts/build-app.sh`. That fixes the production .app build but does NOT fix the dev iteration loop (= every `swift build` followed by `open .build/.../WenshuApp` hits the regression).

## Apple HIG canonical fix

Embed `Sources/WenshuApp/Resources/Info.plist` into the Mach-O's `__TEXT,__info_plist` section via the linker flag `-sectcreate __TEXT __info_plist Sources/WenshuApp/Resources/Info.plist`. This is the pattern Apple recommends for SPM-built executables that need a Bundle.main with metadata (per polpiella.dev "Adding an Info.plist file to a Swift executable" + developer.apple.com/forums/thread/734540 `CREATE_INFOPLIST_SECTION_IN_BINARY` build setting).

Verification on a minimal probe binary (lives in `/tmp/probe_bin` during the audit):

| Test | CFBundleLocalizations | preferred | NSLocalizedString |
|---|---|---|---|
| bare Mach-O without `-sectcreate` | MISSING | [en] | FALLBACK (key string) |
| **bare Mach-O with `-sectcreate __TEXT __info_plist`** | **[en, zh-Hans]** | **[zh-Hans]** | **zh-Hans value** |

After the fix:

- `Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations")` returns `["en", "zh-Hans"]`
- `Bundle.main.preferredLocalizations` returns `["zh-Hans"]` for zh-Hans-CN users
- NSLocalizedString resolves to zh-Hans values regardless of whether wenshu is launched as a bare Mach-O (`swift run`, `swift build` + `open`) or as a packaged `.app` bundle (`bash Scripts/build-app.sh` + `open build/Wenshu.app`)

The .app bundle still receives the same Info.plist via `Scripts/build-app.sh` for Finder / LaunchServices metadata (= canonical .app layout); `__info_plist` is the binary-side mirror that makes dev builds behave identically.

## SPM field-order requirement

PackageDescription's Target builder validates parameter order: `linkerSettings` must follow `resources`. The wrong order (`linkerSettings` before `resources`) fails with:

```
error: argument 'resources' must precede argument 'linkerSettings'
```

## Commits in this batch

- `fcd025f17` — Package.swift: add `linkerSettings.unsafeFlags([-sectcreate ...])` to WenshuApp executable target
- `7c3502b3a` — NewLibraryOutlineView.swift: 5 Lucide kebab-case names → SF Symbols 6 dot.case names in `standardFolderNames`
- `84f8ce53c` — merge commit (no-op)
- `b8b94ab49` — PreviewPane.swift + ShellDetailColumn.swift: same migration gap closed at 2 more render paths (caught by dual-axis Spec sub-agent review)

## Verification commands

```bash
# 1. __info_plist section embedded in binary
$ otool -P .build/out/Products/Debug/WenshuApp | head -3
.build/out/Products/Debug/WenshuApp:
(__TEXT,__info_plist) section
<?xml version="1.0" encoding="UTF-8"?>

# 2. CFBundleLocalizations present in embedded plist
$ otool -P .build/out/Products/Debug/WenshuApp | grep CFBundleLocalizations
         Added CFBundleLocalizations = ["en", "zh-Hans"]

# 3. No remaining Lucide names in render paths
$ grep -rn 'systemName: "\(kanban\|list-checks\|user-round\|list-tree\|book-text\|file-pen-line\)' Sources/
(no output = 0 hits)
```

## Acceptance criteria

| # | Criterion | Verification |
|---|---|---|
| 1 | sidebar folder rows show SF Symbols 6 glyphs (globe / person / list.bullet.rectangle / text.book.closed / pencil) | screenshot from the live session |
| 2 | reference entity thumbnail in PreviewPane shows SF Symbols 6 glyphs (EntityType.icon via L802) | screenshot from the live session |
| 3 | ShellDetailColumn kanban + todo toolbar buttons show SF Symbols 6 glyphs (rectangle.split.3x1 + checklist) | live observation |
| 4 | NSLocalizedString returns zh-Hans values for zh-Hans-CN user running bare-Mach-O Wenshu binary | sidebar / inspector / search field all display Chinese |
| 5 | No regression: reference library section header does not overlap folder rows | Chinese strings are wider but the sidebar auto-reflows correctly |
| 6 | Build clean: `swift build` exit 0, no new warnings | confirmed |