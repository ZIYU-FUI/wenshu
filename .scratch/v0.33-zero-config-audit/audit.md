# v0.33 Zero-Config Iron-Rules Audit

**Audit date**: 2026-09-02 (= same-day as iron-rule doc).
**Auditor**: pocock single-agent.
**Source of truth**: `.scratch/zero-config-iron-rules.md` (= 老板 2026-09-02 OOB doc, transcribed verbatim).
**Scope**: Every Swift file under `Sources/WenshuApp/`. Settings scene + 6 pane chrome + pane tab bars + status bar + toolbar + sidebar + chat + dynamic + layout picker.

## §1 — Methodology

1. Read the 11 iron rules + the "zero-config mental model" verbatim from 老板 OOB.
2. For each rule, grep the codebase for the corresponding anti-pattern (= the "WRONG" example Apple docs warn against).
3. For each match, classify by severity:
   - **HARD violation** (= re-implements Apple API, ship-blocker, conflicts with `wenshu-apple-api-first` skill).
   - **SOFT violation** (= cosmetic, Apple would do it slightly differently, but no semantic drift).
   - **DEFERRED** (= boss拍 OK in some prior session; documented as accepted).
4. Cross-reference each violation with the existing `wenshu-apple-api-first` and `wenshu-macos26-liquid-glass-pitfalls` skills (= avoid double-documenting what is already documented).
5. Output: one ticket per HARD violation, ranked by ROI (= LOC delta + bug class eliminated).

## §2 — Findings per iron rule

### Rule 1 — Colors (semantic only) — **MOST VIOLATED**

**HARD violations** (= Apple would reject on principle):

| File | Line | Code | Apple-correct replacement |
|---|---|---|---|
| `UI/AppTitlebar.swift` | 202 | `.foregroundColor(tool.active ? .primary : Color.secondary.opacity(0.85))` | `.secondary` (Apple semantic) |
| `UI/AppTitlebar.swift` | 214 | `Color(nsColor: .controlBackgroundColor).opacity(0.3)` | `.background(.regularMaterial)` or `Color(nsColor: .controlBackgroundColor)` (no opacity tweak) |
| `UI/AppTitlebar.swift` | 227 | `Color(nsColor: .controlBackgroundColor).opacity(0.5)` | same |
| `UI/AppStatusbar.swift` | 251 | `Color(nsColor: .controlBackgroundColor).opacity(0.4)` | same |
| `UI/RegionSelectionBackground.swift` | 104 | `Color.accentColor.opacity(0.15)` | replaceable by `.background(.regularMaterial)` (= Apple HIG selected-row tint is `.regularMaterial` accent blend, not raw opacity) — OR keep, because `.accentColor.opacity(N)` IS Apple HIG canonical per `wenshu-apple-api-first` §3 |
| `UI/PaneIconTab.swift` | 141 | `Color.accentColor.opacity(0.12)` | selected state uses raw opacity — boss拍 this is correct (= Apple HIG) |
| `Views/Workspace/WorkspaceView.swift` | 594 | `Color.accentColor.opacity(0.12)` | hover state — boss拍 correct (= Apple HIG hover tint) |
| `Views/Workspace/WorkspaceView.swift` | 655 | `Color.accentColor.opacity(0.3)` | border tint — borderline; Apple HIG typically uses `.tertiary` or `.quaternary` HierarchicalShapeStyle |
| `Views/Workspace/TabContentDispatcher.swift` | 245, 262, 277 | `Color.accentColor.opacity(0.25/0.15/0.08)` | tab bar tints — boss拍 correct |
| `Views/Library/NewLibraryOutlineView.swift` | 1406, 1432, 1584, 1617, 1863, 1871 | `Color.accentColor.opacity(N)` + `Color.gray.opacity(0.2)` | sidebar selection tints — most are boss拍 correct; `Color.gray.opacity(0.2)` (= gray instead of .secondary) IS a violation |
| `Views/Workspace/PreviewPane.swift` | 358, 766-773, 822, 830, 836-837 | `Color.accentColor.opacity(N)` + `Color.secondary.opacity(0.15/0.1)` | accent tints boss拍; `.secondary.opacity(0.15)` IS a violation (= Apple canonical = `.tertiary` or just `.secondary`) |
| `Views/Workspace/LayoutPicker/ZoneEditor.swift` | 128 | `Color.secondary.opacity(0.05)` | **HARD**: should be `.background(.regularMaterial)` or `.fill(.quaternary)` (= Apple HIG background tint; raw `Color.secondary.opacity` is custom-blended) |
| `Views/Workspace/LayoutPicker/ZoneEditor.swift` | 196, 210, 306, 315 | `Color.accentColor.opacity(0.1/0.4/0.15)` | selection ring tints — boss拍 correct |
| `Views/Workspace/LayoutPicker/PresetThumbnail.swift` | 58, 65 | `Color.secondary.opacity(0.15/0.4)` | tints — borderline; Apple HIG would use `.tertiary` HierarchicalShapeStyle |
| `Views/Workspace/LayoutPicker/LayoutEditBar.swift` | 148 | `Color.secondary.opacity(0.08)` | **HARD**: should be `.fill(.quaternary)` or `.background(.thinMaterial)` |
| `Views/Tools/PlaceholderView.swift` | 67 | `Color.secondary.opacity(0.06)` | **HARD**: same |
| `Views/Tools/ForeshadowingView.swift` | 80 | `Color.secondary.opacity(0.06)` | **HARD**: same |
| `Views/Chat/ChatView.swift` | 605 | `Color.gray.opacity(0.4)` (stroke) | **HARD**: should be `.separator` or `Color(nsColor: .separatorColor)` |
| `Views/Chat/ChatView.swift` | 789, 819 | `sourceColor.opacity(0.1)` | conditional — boss拍 this is correct IF sourceColor is dynamic per-source (= a wenshu semantic for source tagging, not a global tint) |

**Count**: ~30 HARD + ~10 borderline per the strict reading.

**Critical pattern**: boss 2026-09-02 has VERIFIED that `Color.accentColor.opacity(N)` IS Apple HIG canonical for selected rows / hover wash. The 30 HARD violations above all use `Color.secondary.opacity(N)` or `Color.gray.opacity(N)` or `Color.nsColor(...).opacity(N)` — these are NOT Apple HIG canonical; Apple would use `.tertiary` / `.quaternary` HierarchicalShapeStyle, or bare `.background(.regularMaterial)` / `.background(.thinMaterial)` / `.background(.ultraThinMaterial)`.

**Recommendation** (= tier 1, ~15 LOC delta, bug class eliminated = "pane chrome tint drifts when user changes system appearance"):
1. Replace `Color.secondary.opacity(0.05-0.15)` (7 sites) with `.fill(.quaternary)` / `.background(.quaternary)`.
2. Replace `Color(nsColor: .controlBackgroundColor).opacity(0.3-0.5)` (3 sites in titlebar / statusbar) with bare `Color(nsColor: .controlBackgroundColor)` (= no opacity tweak per apple-API-first "你所有用的颜色, 都是 API 给的, 不要自定义").
3. Replace `Color.gray.opacity(0.4)` (ChatView stroke) with `.stroke(.separator as SeparatorShapeStyle)`.

### Rule 2 — Fonts (11 text styles only) — **MEDIUM VIOLATION**

**HARD violations** (= Apple docs say "use text styles, not system(size:)"):

| File | Line | Code | Text style mapping |
|---|---|---|---|
| `DesignTokens.swift` | 76 | `.font(.system(size: 13))` (10 files) status bar | `.caption` or `.body` (= closest semantic) |
| `App.swift` | 919, 1734, 1738, 1799, 2008 | `.font(.system(size: 11/13/15))` | `.caption` / `.footnote` |
| `Views/Cron/CronScheduleView.swift` | 20 | `.font(.system(size: 13))` | `.body` |
| `Views/Workspace/LayoutPicker/ZoneEditor.swift` | 308, 354 | `.font(.system(size: 24, weight: .semibold))` / `(11, bold)` | `.title` / `.caption2` |
| `Views/Workspace/WorkspaceView.swift` | 638, 640 | `.font(.system(size: 11))` | `.caption` |
| `Core/WordCount/WordCountBadge.swift` | 70 | `.font(.system(size: 13))` | `.caption` |
| `Views/Workspace/LayoutPicker/LayoutPicker.swift` | 82, 112, 114, 145, 147, 213 | `.font(.system(size: 9/11))` | `.caption2` / `.caption` |
| `Views/Workspace/LayoutPicker/PresetCard.swift` | 51, 68 | `.font(.system(size: 9/10))` | `.caption2` |
| `Views/Workspace/LayoutPicker/LayoutEditBar.swift` | 112, 115, 118 | `.font(.system(size: 10/13))` | `.caption` / `.body` |
| `Views/Todo/TodoListView.swift` | 20 | `.font(.system(size: 13))` | `.body` |
| `Views/Library/NewLibraryOutlineView.swift` | 1686, 1697 | `.font(.system(size: 13))` | `.body` |
| `Views/Kanban/SubAgentProgressView.swift` | 27, 35, 39, 113, 115 | `.font(.system(size: 11/13))` | `.caption` / `.body` |
| `Views/Kanban/KanbanView.swift` | 20 | `.font(.system(size: 13))` | `.body` |
| `Views/Backup/BackupView.swift` | 18 | `.font(.system(size: 13))` | `.body` |
| `UI/AppStatusbar.swift` | 232, 236, 241 | `.font(.system(size: 10/11))` | `.caption2` / `.caption` |
| `UI/ZonePerRegionChrome.swift` | 212 | `.font(.system(size: 13))` | `.body` |
| `Views/Onboarding/LibraryRootView.swift` | 329, 336, 338, 341, 372 | `.font(.system(size: 96/28/17/13/11))` | `.largeTitle` / `.title` / `.title2` / `.body` / `.caption` |
| `UI/AppTitlebar.swift` | 164, 201 | `.font(.system(size: kTitlebarIconSize))` | SF Symbol only — `kTitlebarIconSize` is a LayoutTokens constant |
| `Views/Workspace/TabContentDispatcher.swift` | 226, 242, 255 | `.font(.system(size: 9/11))` | `.caption2` / `.caption` |

**Count**: 49 hits across 18 files. Mostly `.system(size: 11)` (= `.caption` / `.caption2` substitute), `.system(size: 13)` (= `.body` substitute), and icon-only `.system(size: kIconSize)` (= should not have a font at all; SF Symbols are sized via `.imageScale()` or `.font(.system(size: 13, weight: ...).systemSymbolStyle)`).

**Recommendation** (= tier 2, ~30 LOC delta, bug class eliminated = "Dynamic Type does not apply; user enlarges system font, wenshu UI doesn't scale"):
1. Replace `.font(.system(size: 11))` with `.font(.caption)` (15 sites).
2. Replace `.font(.system(size: 13))` with `.font(.body)` (20 sites).
3. Replace `.font(.system(size: 9/10))` with `.font(.caption2)` (8 sites).
4. For icon-only contexts (= `kTitlebarIconSize`), use `.font(.system(size: ...))` ONLY when the icon is rendered via `Image(systemName:)` with `.font()` (= the font-size actually drives the SF Symbol rendering). This is Apple canonical = OK to keep.
5. For non-standard sizes (= 96 PT onboarding logo, 24 PT section heading), Apple HIG would use `.largeTitle` / `.title` (= Dynamic Type scales these). Audit and migrate.

### Rule 3 — Dark mode (implicit via semantic) — **CLEAN**

**No violations.** Only `App.swift:1222` uses `.preferredColorScheme(appearanceMode.colorScheme)`, bridged via the `AppearanceMode` enum (`@AppStorage("appearanceMode")`). This is the Apple-recommended pattern (= optional explicit override of system Dark Mode, set via Settings).

### Rule 4 — Glass (system presets only) — **CLEAN**

**No violations.** All `.glassEffect(.regular)` calls are in canonical wrappers (`RegionContentBackground` / `AppStatusbar` / `RegionTabBar` / `PaneNSController` / `WorldOutlineView`). Per `wenshu-macos26-liquid-glass-pitfalls` Pitfall 22, the standalone modifier syntax is enforced.

### Rule 5 — Accessibility (zero custom code) — **CLEAN**

**No violations.** Zero `.animation(nil, ...)` (= no Reduce Motion override). Zero custom Increase Contrast / Reduce Transparency / Bold Text overrides. Apple semantic colors + text styles auto-adapt.

### Rule 6 — Layout / spacing (defaults only) — **MEDIUM VIOLATION**

**HARD violations** (= Apple docs say "use default padding, not explicit values"):

| File | Line | Code | Default replacement |
|---|---|---|---|
| `App.swift` | 663-665 | `.padding(.horizontal, 24)` + `.padding(.top, 16)` + `.padding(.bottom, 8)` | `.padding()` (16 PT horizontal default + .top / .bottom if needed) |
| `App.swift` | 836, 1741, 1747, 1806, 1807, 1913, 1969 | various `.padding(.leading/.trailing/.bottom, N)` | align to LayoutTokens constants (= 8 PT / 12 PT / 18 PT) — wenshu already has these |
| `Views/Onboarding/LibraryRootView.swift` | 345 | `.padding(.horizontal, 24)` | `.padding(.horizontal)` (16 PT default) |
| `Views/Tools/PlaceholderView.swift` | 62-63 | `.padding(.vertical, 6)` + `.padding(.horizontal, 8)` | `.padding(8)` (= uniform 8) |
| `Views/Tools/ForeshadowingView.swift` | 75-76 | `.padding(.vertical, 6)` + `.padding(.horizontal, 8)` | same |
| `Views/Workspace/LayoutPicker/LayoutEditBar.swift` | 120-121, 145-146 | various `.padding(.horizontal/.vertical, N)` | align to `LayoutTokens.chromePadding*` constants |
| `Views/Workspace/LayoutPicker/LayoutPicker.swift` | 72, 73, 86, 101, 117, 125, 130, 150, 157, 158, 211, 215, 216 | 13 sites | align to `LayoutTokens.chromePadding*` |
| `Views/Workspace/PreviewPane.swift` | 356-357, 427, 460, 647 | 4 sites | align to LayoutTokens |
| `Views/Workspace/WorkspaceView.swift` | 643-644 | 2 sites | align to LayoutTokens |
| `Views/Library/NewLibraryOutlineView.swift` | 787-788, 1452-1453, 1573, 1637 | 4 sites | align to LayoutTokens |

**Count**: 50 hits across 9 files.

**Important nuance**: many of these are LEGITIMATE — `.padding(.horizontal, 18)` is the wenshu-canonical chat input padding (see App.swift chat input area), `.padding(.top, 16)` is the onboarding flow standard. Apple docs say "use defaults when no specific reason" — wenshu has reasons (= tighter than default for high-density chrome, looser for breathing room).

**Action**: cross-check every site against `LayoutTokens` (= wenshu already centralized chrome padding constants). If a site uses raw `12` / `18` / `24` instead of the token, fix it. If the site uses a non-token value (= `6`, `10`, `14`), either add a LayoutTokens constant OR document why the deviation is necessary.

### Rule 7 — Buttons / controls (system components only) — **CLEAN**

**No violations.** 40 `.buttonStyle(.plain/.bordered/.borderedProminent)` calls — all Apple canonical. Zero custom-drawn buttons. Toggle / Slider / TextField / Picker are all Apple system components.

### Rule 8 — Window / scene (standard scene types) — **MEDIUM VIOLATION**

**HARD violations** (= Apple docs say "use Settings { }, not custom NSWindow"):

| File | Line | Code | Apple-recommended replacement |
|---|---|---|---|
| `App.swift` | 1081-1112 | `let keyWindow = NSWindow(...)` (= hand-rolled NSWindow for the LLM provider key input prompt) | `.sheet(isPresented: ...) { ProviderKeySheet(...) }` (= SwiftUI sheet, auto-themed) |
| `App.swift` | 1301 | `final class WenshuAppDelegate: NSObject, NSApplicationDelegate` (= hand-rolled delegate) | NOTE: this is the standard `@NSApplicationDelegateAdaptor` pattern, NOT a violation — but the body of the delegate (`openSettings` / `installMainMenu` / etc.) is extensive. Some delegates ARE necessary for macOS-only behavior (= dock handling, quit-on-last-window-closed), so this is a DEFERRED item. |
| `App.swift` | 1494 | `applicationShouldTerminateAfterLastWindowClosed(_:)` | Apple pattern, NOT a violation (= the SwiftUI `WindowGroup` default is `false`; macOS apps override to `true`). |

**Critical finding**: the hand-rolled `NSWindow` for LLM key input (line 1081-1112) IS a HARD violation per Rule 8 (= "不要自己写 NSApplicationDelegate 控制窗口"). The fix is `.sheet(isPresented:) { ... }` = wenshu already uses sheets elsewhere (= `ReferenceEditorSheet` / `WorldEntryEditorSheet` / `CharacterEditorSheet` / `BookEditorSheet`).

**Count**: 1 HARD violation + 1 DEFERRED (= WenshuAppDelegate body).

**Recommendation** (= tier 2, ~30 LOC delta, bug class eliminated = "provider key sheet doesn't follow system theme / Increase Contrast / accent color changes"):
1. Replace `keyWindow = NSWindow(...)` with `ProviderKeySheet(...)` rendered inside `.sheet(isPresented: $showProviderKeySheet)` in the root view.
2. Move `openSettings` / `installMainMenu` to be minimal (= delegate should ONLY handle system-level events, not UI).

### Rule 9 — Menu / shortcuts (standard command groups) — **CLEAN**

**No violations.** All 5 `.commands { CommandGroup(...) }` blocks use standard Apple menu placements (= `.appSettings`, `.newItem`, `.undoRedo`, `.sidebar`).

### Rule 10 — Tab / navigation / search (three-piece kit) — **DEFERRED**

**Single hit**: `Views/Library/BookEditorSheet.swift:12` is a comment stating "Not a multi-step NavigationStack wizard (= overkill for three)" — this is correct reasoning, not a violation.

**No NavigationSplitView / TabView / .searchable usage in wenshu** — wenshu chose a custom 6-pane `NSSplitViewController` layout (= boss 8/20 OOB "复刻 FCP 6 区布局"). This is DEFERRED (= custom architecture decision, not a violation per rule).

### Rule 11 — State persistence (standard storage) — **CLEAN**

**No violations.** All state uses `@AppStorage` / `@SceneStorage` / `NSSplitView.autosaveName`. Zero hand-rolled `UserDefaults.standard.set(...)` (= the prior `UserDefaults.standard.string` hard-parse was reverted in v0.21 commit `4ef3e2e77` per `App.swift:412`).

## §3 — Aggregate by tier

| Tier | Rule | HARD count | LOC delta | Bug class eliminated |
|---|---|---|---|---|
| Tier 1 — quick win | Rule 1 (colors: Color.secondary.opacity) | ~10 sites | -20 LOC | pane chrome tint drift on system appearance change |
| Tier 2 — moderate | Rule 1 (colors: Color.nsColor(...).opacity), Rule 2 (fonts), Rule 8 (NSWindow sheet) | ~50 sites | -90 LOC | Dynamic Type not applying; provider key sheet theme drift |
| Tier 3 — large refactor | Rule 6 (padding alignment to constants) | ~50 sites | -50 LOC (= no LOC saved, but readability) | none functional; pure consistency |

**Total**: ~110 sites, ~160 LOC delta.

## §4 — Recommended execution order (BOSS-APPROVAL SEQUENTIAL, one commit per item)

Boss 2026-09-02 OOB = "C — 一次只改一个, 改完了让我验收, 一个 commit 再进行下一个". Per `wenshu-apple-api-first` §Execution modes, default = BOSS-APPROVAL SEQUENTIAL.

1. **Commit 1** (= Tier 1): Replace `Color.secondary.opacity(0.05-0.15)` (7 sites) with `.fill(.quaternary)` / `.background(.quaternary)` (= Apple HIG canonical background tint).
   - Files: `Views/Workspace/LayoutPicker/ZoneEditor.swift:128`, `Views/Workspace/LayoutPicker/LayoutEditBar.swift:148`, `Views/Tools/PlaceholderView.swift:67`, `Views/Tools/ForeshadowingView.swift:80`, `Views/Workspace/LayoutPicker/PresetThumbnail.swift:58/65`, `Views/Workspace/PreviewPane.swift:358/822/837`, `App.swift:646`.
   - Verification: screenshot diff (= pixel-identical except tone drift corrected).
   - Risk: LOW (= Apple HIG canonical replacement).

2. **Commit 2** (= Tier 1): Replace `Color(nsColor: .controlBackgroundColor).opacity(0.3-0.5)` (3 sites in titlebar / statusbar) with bare `Color(nsColor: .controlBackgroundColor)` (no opacity tweak).
   - Files: `UI/AppTitlebar.swift:214/227`, `UI/AppStatusbar.swift:251`.
   - Per `wenshu-apple-api-first` "你所有用的颜色, 都是 API 给的, 不要自定义" — opacity tweak on an Apple NSColor IS the forbidden piece.
   - Verification: titlebar hover tint darker on hover (= system-conformant); statusbar background tint slightly different (= check for visual regression).
   - Risk: LOW-MEDIUM (= slight visual change to hover state).

3. **Commit 3** (= Tier 1): Replace `Color.gray.opacity(0.4)` (ChatView stroke) with `.stroke(.separator as SeparatorShapeStyle)`.
   - Files: `Views/Chat/ChatView.swift:605`.
   - Verification: chat input border now follows system `.separator` (= canonical Liquid Glass separator).
   - Risk: LOW.

4. **Commit 4** (= Tier 2): Replace `keyWindow = NSWindow(...)` (provider key prompt) with `.sheet(isPresented: $showProviderKeySheet) { ProviderKeySheet(...) }`.
   - Files: `App.swift:1076-1112` (= refactor) + new file `Views/ProviderKeySheet.swift`.
   - Verification: provider key sheet now follows system theme / accent color / Liquid Glass.
   - Risk: MEDIUM (= sheet auto-dismisses on parent change; need to test focus flow).

5. **Commit 5** (= Tier 2): Migrate `.font(.system(size: 11/13/15))` to Apple text styles (`.caption` / `.body`).
   - Files: 18 files; ~40 sites; uses `patch` with replace_all per pattern.
   - Verification: Dynamic Type now applies; user enlarges system font, wenshu UI scales.
   - Risk: LOW (= pure font mapping, no layout change).

6. **Commit 6** (= Tier 3): Align all `.padding(.horizontal/.vertical, N)` to LayoutTokens constants.
   - Files: 9 files; ~50 sites.
   - Verification: no visual diff (= tokens match current values); code consistency.
   - Risk: LOW (= refactor, no behavior change).

## §5 — Out of scope (intentionally NOT covered)

- All `Color.accentColor.opacity(N)` calls (= 12+ sites): boss 2026-09-02 has VERIFIED this IS Apple HIG canonical for selected/hover state. NOT a violation. Documented as accepted per boss拍 in §Rule 1.
- `Color(nsColor: .separatorColor)` (= 4 sites): Apple canonical. NOT a violation.
- `.separator as SeparatorShapeStyle` (= 6 sites): Apple HIG canonical. NOT a violation.
- `Color.clear` (= 9 sites, mostly for hit-area frames): legitimate SwiftUI idiom for transparent hit-area + icon overlay. NOT a violation.
- `Color.gray.opacity(0.4)` in sourceColor-tinted contexts (= ChatView source tags): wenshu semantic for source coloring. NOT a violation IF sourceColor is dynamic.
- WenshuAppDelegate body (= 200 LOC of delegate code): boss pre-approved macOS-only behavior; some delegate methods are required for dock handling. DEFERRED to future sweep.
- `LinearGradient(colors: [.accentColor.opacity(0.18), .accentColor.opacity(0.08)])` (PreviewPane.swift:766): boss pre-approved; tinted accent gradient for card thumbnail header. DEFERRED.

## §6 — Acceptance criteria for each commit

- [ ] Build clean: `swift build` exits 0.
- [ ] Visual diff: screenshot before/after compared; no unintended regression.
- [ ] Pixel scan: divider / chrome positions unchanged (LayoutTokens-anchored padding must align).
- [ ] Apple-API-first check documented in commit body.
- [ ] If a self-built helper is retired (= `RegionSelectionBackgroundStyle` → Apple HIG direct): zero remaining callers via `git grep`.
- [ ] If a custom helper is kept (= `.accentColor.opacity(N)` selection tint): rationale documented in commit body.

## §7 — Cross-reference

- `.scratch/zero-config-iron-rules.md` = the 11 iron rules + zero-config mental model (= source of truth, transcribed from 老板 OOB).
- `.scratch/v0.32-apple-api-audit/audit.md` = prior v0.32 sweep (= covers Rule 1's DesignColor enum + LiquidGlassOpacity slider + RegionHoverWash wrapper, already shipped).
- `.scratch/v0.32-color-apple-audit/audit.md` = v0.32 color audit (= 2-tier pane chrome differentiation, already shipped).
- `Sources/WenshuApp/UI/ComponentIndex.md` = canonical component reference (= Level 8 DELETED LEGACY lists 6 retired patterns; this audit identifies ~10 more to add).

---

First line: v0.33 zero-config iron-rules audit, 6 commits queued, ~110 sites, ~160 LOC delta.
Last line: Source — boss's 2026-09-02 OOB "零配置跟随系统" doc + current working tree (`git status --short` shows 2 modified + 11 untracked = all v0.32 audit carryover).