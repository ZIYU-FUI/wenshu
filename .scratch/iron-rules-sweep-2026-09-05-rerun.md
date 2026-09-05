# Zero-Config Iron-Rules Sweep · 2026-09-05 RERUN

**Scope**: `fbf3bbe9d..9e43547f7` (= 19 non-merge commits, 38 Swift files, +969/-818 LOC; the
post-prior-sweep work envelope covering the CJK cleanup batch series, the AGENTS.md v0.10
proposal side doc, the v0.38 CHANGELOG, and the iron-rules followup Rule 2 fix commit
`6ee3822d3`).

**Methodology**: identical to prior sweep at `.scratch/iron-rules-sweep-2026-09-05.md` —
follow `.scratch/v0.34-standards-axis/code-review-standards-axis-report.md` template. Grep the
diff (`+` lines only, non-comment bodies) for the canonical violation patterns from
`.scratch/zero-config-iron-rules.md` per rule.

**Verdict per rule** (one line each): PASS = 0 violations introduced; FINDING = N violation(s)
introduced (with site list); REFER = pre-existing violations outside this sweep's scope.

**First/last line = fact** (AGENTS.md hard rule). English-only. Sole address = 老板.

---

## Comparison to prior sweep (`.scratch/iron-rules-sweep-2026-09-05.md`)

Prior sweep covered `5058183d3~1..fbf3bbe9d` (= 162 commits, 233 Swift files, +42,177/-437 LOC).
That sweep produced: 10 PASS + 1 FINDING (Rule 2 typography, 4 sites in `b405cab56`
WIRE-PARAGRAPH-002) + 12 POSITIVE Rule 4 `.glassEffect(.regular)` calls.

This rerun covers `fbf3bbe9d..9e43547f7` (= 19 commits, 38 Swift files, +969/-818 LOC; the
post-prior-sweep tail of today's work).

|| Bucket | Prior sweep (`5058183d3~1..fbf3bbe9d`) | Rerun (`fbf3bbe9d..9e43547f7`) |
||---|---|---|
|| Commits | 162 | 19 |
|| Swift files touched | 233 | 38 |
|| Net LOC delta | +42,177 / -437 | +969 / -818 |
|| Rules checked | 11 | 11 |
|| PASS | 10 | 11 |
|| FINDING | 1 (Rule 2, 4 sites in `b405cab56`) | 0 |
|| POSITIVE (Rule 4 `.glassEffect`) | 12 new canonical calls | 0 new (no UI surface changes in this batch) |

**Net new violations introduced since prior sweep**: **0**.

**Net violations resolved since prior sweep**: **0**.

The prior sweep's Rule 2 finding (4 sites of `.system(size: 12, design: .monospaced)` in
`b405cab56` WIRE-PARAGRAPH-002) is **STILL PRESENT** in the current source tree:

```
Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:2207  .font(.system(size: 12, design: .monospaced))
Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:2228  .font(.system(size: 12, design: .monospaced))
Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:2248  .font(.system(size: 12, design: .monospaced))
Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:2276  .font(.system(size: 12, design: .monospaced))
```

The fix commit `6ee3822d3` (INV-PUSH-7, subject "iron-rules sweep followup Rule 2 typography")
moved the 4 inline English `.help()` strings to `Localizable.strings` — that addresses the I18n
inline English issue (related but separate concern) but did NOT replace the `.system(size: 12,
design: .monospaced)` typography with the canonical Lucide/Apple text style pattern recommended
by the prior sweep's "Recommended fix" section.

**Recommended followup**: a future 1-class-1-commit fix replacing the 4 `.system(size: 12,
design: .monospaced)` calls with the canonical pattern per `wenshu-apple-api-first` skill
pitfall "Lucide icons reject `.font(_:weight:)` modifiers":

```swift
// WRONG (current): .font has no effect on Lucide path; SF Symbol variant violates Rule 2
Image(systemName: "arrow.up.left.and.arrow.down.right")
    .font(.system(size: 12, design: .monospaced))

// RIGHT: explicit size + frame (Lucide) OR .font(.caption2.weight(.medium)) (SF Symbol)
LucideIconSystemFallback("arrow-up-left-and-arrow-down-right", size: 12)
    .frame(width: 14, height: 14)
    .foregroundStyle(.secondary)
```

A 5th site at `WorkspaceView.swift:1095` (introduced in `7cceb2b01` v0.39 ticket 001-C on
2026-09-04) is pre-existing from BEFORE the prior sweep's CHANGELOG anchor and remains pre-existing
in this rerun's scope. Noted for completeness.

---

## Sweep range

|| Anchor | Commit | Subject |
||---|---|---|
|| Base | `fbf3bbe9d` (= prior sweep head) | test(wenshu): POLISH-LIQUIDGLASS-006 — e2e test asserts all 5 polish surfaces use canonical Apple .glassEffect API + no third-party clone |
|| Head | `9e43547f7` | docs(wenshu): AGENTS.md v0.10 proposal (= side doc awaiting boss explicit approval; AGENTS.md itself is protected) |
|| Span | 19 commits, 2026-09-05 (= post-prior-sweep tail) | (= CJK cleanup batch series + I18N-INLINE-001 + CHANGELOG v0.38 + AGENTS.md v0.10 side doc + iron-rules followup + retrospective + dead-pin cleanup) |

---

## Rule-by-rule verdicts

### Rule 1 — Colors: semantic only

> Write `Color.primary` / `Color.secondary` / `Color.accentColor` / `Color(nsColor: .windowBackgroundColor)` etc. NEVER hardcode RGB / hex / `Color.red` / `Color(red:...)`.

**Verdict: PASS.** Grep on `+` lines of `fbf3bbe9d..9e43547f7` diff:

- `Color\.(red|blue|green|yellow|orange|purple|pink|black|white|gray|grey)\b` → 0 hits
- `Color\(red:` → 0 hits
- `Color\(white:` → 0 hits

### Rule 2 — Fonts: 11 text styles only

> `.largeTitle` / `.title` / `.title2` / `.title3` / `.headline` / `.body` / `.callout` / `.subheadline` / `.footnote` / `.caption` / `.caption2`. NEVER `.system(size: 17)`.

**Verdict: PASS (no NEW violations introduced in this sweep's range).** Grep on `+` lines:

- `\.system\(size:` → 0 hits

However, the prior sweep's Rule 2 finding (4 sites of `.system(size: 12, design: .monospaced)` in
`WorkspaceView.swift` introduced by `b405cab56` WIRE-PARAGRAPH-002) **remains unresolved** in the
current source tree. See "Comparison to prior sweep" above for site list and followup
recommendation. The rerun does NOT count the pre-existing 4 sites as "introduced by this
sweep" — they are outside the rerun's diff range.

### Rule 3 — Dark mode: implicit via semantic colors

> NEVER `view.overrideUserInterfaceStyle = .dark`, NEVER `NSAppearance.customAppearanceNamed(.darkAqua)`, NEVER hardcode light/dark value. Optional `AppearanceMode` enum (.system default / .light / .dark) is allowed IF bridged via `.preferredColorScheme(...)`.

**Verdict: PASS.** Grep:

- `overrideUserInterfaceStyle` → 0 hits
- `NSAppearance\.customAppearanceNamed` → 0 hits
- `preferredColorScheme\(\.(dark|light)` → 0 hits

### Rule 4 — Glass: system presets only

> `.glassEffect()` / `.glassEffect(.regular.tint(.accentColor))` / `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`. Default `.regular`, default `Capsule()`, no manual shape, no manual non-accent color.

**Verdict: PASS (no new `.glassEffect` calls; surface coverage unchanged from prior sweep).** Grep:

- `\.glassEffect\(` → 0 hits in `+` lines
- `\.buttonStyle\(\.glass` → 0 hits
- `\.buttonStyle\(\.glassProminent` → 0 hits

The post-prior-sweep work envelope (CJK cleanup batch + I18N-INLINE-001 + CHANGELOG + AGENTS.md
proposal + retrospective + dead-pin cleanup) is **purely backend + docs work** — no UI surface
changes, so zero new `.glassEffect` calls is the expected outcome. The 12 canonical
`.glassEffect(.regular)` calls from the prior sweep's POLISH-LIQUIDGLASS-001..005 work remain
intact.

### Rule 5 — Accessibility: zero custom code

> Reduce Transparency / Increase Contrast / Reduce Motion / Dynamic Type / Bold Text = automatic via Apple semantic APIs. NEVER `.animation(nil, value:)` to kill motion.

**Verdict: PASS.** Grep:

- `\.animation\(nil,` → 0 hits

### Rule 6 — Layout / spacing: defaults only

> NEVER `.padding(.all, 12)`, NEVER `Spacer().frame(height: 24)`. Use VStack/HStack defaults + `.padding()`.

**Verdict: PASS.** Grep:

- `\.padding\(\.all,\s*\d+` → 0 hits
- `Spacer\(\)\.frame\(height:\s*\d+` → 0 hits

Borderline observation (same as prior sweep, NOT a violation per the rule's explicit wording):
`.padding(.horizontal, N)` and `.padding(.vertical, N)` patterns are present in the codebase
but are NOT forbidden by the rule as written.

### Rule 7 — Buttons / controls: system components only

> `Button("Save")` + `.buttonStyle(.bordered / .borderedProminent / .glass / .glassProminent / .plain)`. Use `Toggle` / `Slider` / `TextField` / `Picker` — never custom-drawn.

**Verdict: PASS.** Manual inspection:

- No new custom-drawn buttons (no `Canvas` / `Shape` / `Path` Button body in the diff).
- The only `.help()` changes in the diff are string-replacement to `WenshuI18n.t(...)` calls
  (I18N-INLINE-001 fix), preserving the underlying Button + `.buttonStyle(.plain)` structure.
- No new `Toggle` / `Slider` / `TextField` / `Picker` sites.

### Rule 8 — Window / scene: standard scene types

> `WindowGroup` + `Settings { }` + `MenuBarExtra`. NEVER self-written `NSApplicationDelegate` for window control.

**Verdict: PASS.** Grep:

- `WindowGroup\(` → 0 hits in `+` lines
- `NSApplicationDelegate` → 0 hits
- `^\s*Window\(` (SwiftUI Scene type) → 0 hits

### Rule 9 — Menu / shortcuts: standard command groups

> `.commands { CommandGroup(replacing: .newItem) { Button(...).keyboardShortcut(...) } }`. NEVER hand-built menu.

**Verdict: PASS.** Grep:

- `\.commands\s*\{` → 0 hits in `+` lines
- `CommandGroup\(` → 0 hits
- `keyboardShortcut\(` → 0 hits in `+` lines

### Rule 10 — Tab / navigation / search: three-piece kit

> `NavigationSplitView` / `TabView` / `.searchable(text:placement:)`. NEVER hand-written sidebar.

**Verdict: PASS.** Grep:

- `NavigationSplitView\(` → 0 hits
- `TabView\(` → 0 hits
- `\.searchable\(text:` → 0 hits

### Rule 11 — State persistence: standard storage

> `@AppStorage("...")` / `@SceneStorage("...")`. Window position/size auto-restored by AppKit.

**Verdict: PASS.** Grep:

- `@AppStorage\(` → 0 hits
- `@SceneStorage\(` → 0 hits

---

## Tally

|| Bucket | Count |
||---|---|
|| Total iron rules checked | 11 |
|| PASS (0 violations) | 11 |
|| FINDING (violations introduced by this rerun's range) | 0 |
|| Net new violations since prior sweep | 0 |
|| Net violations resolved since prior sweep | 0 (= the prior Rule 2 finding remains unaddressed) |

---

## Verdict

**Overall: PASS (11/11 rules clean in the rerun range).**

Today's post-prior-sweep work is **zero-config clean** — the CJK cleanup batch series,
I18N-INLINE-001 Localizable.strings move, CHANGELOG v0.38, AGENTS.md v0.10 side doc, iron-rules
followup Rule 2 fix (which actually only addressed the inline English strings, not the
typography), retrospective spec, and dead-pin cleanup introduced ZERO new iron-rule
violations. This validates the v0.40 ToolRegistry migration + Liquid Glass polish + CJK cleanup
pipeline as Apple-HIG-faithful.

**Outstanding followup from prior sweep (NOT introduced by this rerun, NOT in this rerun's
scope to fix)**: the 4 sites of `.system(size: 12, design: .monospaced)` in
`WorkspaceView.swift:2207, 2228, 2248, 2276` remain. The `6ee3822d3` commit subject
("iron-rules sweep followup Rule 2 typography") was misleading — it only addressed the I18n
inline English strings, not the Rule 2 typography. A future 1-class-1-commit fix is recommended
per the prior sweep's "Recommended fix" snippet (= use `LucideIconSystemFallback(.frame)` for
Lucide icons OR `.font(.caption2.weight(.medium))` for SF Symbols).

---

## Cross-references

- Iron rules source: `.scratch/zero-config-iron-rules.md`
- Prior sweep (this rerun compares to it): `.scratch/iron-rules-sweep-2026-09-05.md`
- Sweep methodology: `.scratch/v0.34-standards-axis/code-review-standards-axis-report.md`
- wenshu-apple-api-first skill: `~/.hermes/profiles/pocock/skills/wenshu-apple-api-first/SKILL.md`
- wenshu-macos26-liquid-glass-pitfalls skill: `~/.hermes/profiles/pocock/skills/wenshu-macos26-liquid-glass-pitfalls/SKILL.md`

## Sweep metadata

- Author: pocock single-agent (= direct dialog with 老板, no dispatch).
- Date: 2026-09-05.
- Diff range: `fbf3bbe9d..9e43547f7` (= 19 non-merge commits, 38 Swift files, +969/-818 LOC).
- Grep tool: `git diff -U0` + `grep -E` on non-comment `+`-line classification (= same
  methodology as prior sweep).
- Verdict per rule: one of PASS / FINDING / REFER (= documented above).
- First line = fact. Last line = fact. English-only. Sole address = 老板.

---

*Iron-rules sweep rerun 2026-09-05 · pocock single-agent · 11/11 rules PASS in the rerun
range · 0 net new violations · 0 net violations resolved (= prior Rule 2 finding in
`WorkspaceView.swift` remains unaddressed in source; followup recommended). English-only per
AGENTS.md hard rule. Sole address = 老板.*
