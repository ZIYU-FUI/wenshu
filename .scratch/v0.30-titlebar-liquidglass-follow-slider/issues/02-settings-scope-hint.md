# Ticket 02 — Settings panel: document slider scope (no title bar)

> Component of: v0.30-titlebar-liquidglass-follow-slider (= boss 2026-09-01
> OOB + clarification "现在设置面板里的设置，影响除标题栏外，文枢的所有前端
> UI" + clarification "让标题栏跟随系统").

## Scope (= this file only)

`Sources/WenshuApp/App.swift` (= the Settings scene, around line 668 where
`@AppStorage("wenshu.liquidGlassOpacity")` is declared + the Slider control
in the same scene).

## Change (= 1 hunk in App.swift)

Find the Settings panel Liquid Glass slider control, and add a hint label
under it (or a `.help(...)` modifier on the slider) explaining the actual
scope:

- Boss-verbatim explanation: "影响除标题栏外的所有液态玻璃界面元素。
  标题栏跟随 macOS 系统设置 (系统设置 → 辅助功能 → 显示 → 减少透明度)".

The English equivalent (per the H-3 forward-fix protocol from v0.30):
- "Affects every Wenshu UI surface EXCEPT the title bar. The title bar
  follows macOS System Settings (System Settings → Accessibility →
  Display → Reduce transparency)."

## Why this is the right fix

Boss拍 "让标题栏跟随系统" means the slider will NOT change the title bar.
Without a UI hint, the next user (= or boss himself next session) will
expect the slider to affect the title bar (= the original boss OOB was
"标题栏的液态玻璃透明度没有跟随设置中的参数"). Documenting the scope
prevents the same confusion from recurring.

## Acceptance criteria

- [ ] The slider has a visible tooltip / sub-label / `.help(...)` text
  describing the actual scope
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0 (no regressions)

## Out of scope (= other tickets)

- AppStatusbar fix (= ticket 01)
- CONTEXT.md update (= ticket 03)

## Risk

- **Risk**: text localization. The Settings scene uses CJK strings
  elsewhere (= e.g. "通用", "模型"). The hint text above is CJK = fine
  for the wenshu single-language UI (= boss 8/26 OOB "Apple 标准 +
  最小代码"; UI text follows the user's existing locale). If wenshu
  ever ships localization, this hint moves to Localizable.strings —
  but that's a v0.40+ concern, not this PR.