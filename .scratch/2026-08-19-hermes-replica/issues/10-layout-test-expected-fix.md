# 10 — LayoutShellViewModelTests expected values change to ratio sum validation (老板 2026-08-19 拍 "by ratio, not absolute value")

**What to build:**
137 tests / 4 issues all in `LayoutShellViewModelTests`. Test expected values use absolute PT (editorW=797, aiChatW=1519, upper band sum=1917) = 8/18 old LayoutTokens values. LayoutTokens 8/19 changed to 794/1518 (mcp__sketch__run_code truth, ticket 012 commit `a513b67`), implementation `totalW * ratio` calculates correctly (794/1518/1914), but test expected values still hard-code old absolute PT.

老板 2026-08-19 拍: "current implementation all by ratio, not absolute value anymore, A this thing clear, don't fix". Dead principle = "implemented code = dead principle, do not touch" (LayoutTokens truth 794/1518 do not touch). Fix test expected values to use ratio sum validation, not absolute PT.

**After change:**
- Test expected values change from absolute PT to ratio sum validation (consistent with `totalW * LayoutTokens.ratio` implementation)
- 4 issues cleared (editorW / aiChatW sum / upper band sum / comments)
- `swift test` exit 0 (137/137 pass)
- Do not change LayoutTokens truth (794/1518 preserved)
- Do not change LayoutShellView / LayoutShellViewModel / NativeSplitter implementation

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit (老板 8/19 self-decision authorization + no verification needed)

## Acceptance criteria

- [ ] `Tests/WenshuAppTests/Layout/LayoutShellViewModelTests.swift` default ratio test changes to `vm.editorWRatio == Double(LayoutTokens.editorWRatio)` validation (ratio, not editorW=794 absolute value)
- [ ] Upper band sum test changes to `abs(sum - 1.0) < 0.0001` ratio sum validation (200+520+794+400 = 1914 ≠ 1920, but ratio sum = 1914/1920, using 1.0 validation = total width ratio conservation, leaves ±6 PT for splitter placeholder)
- [ ] Lower band sum test changes to `abs(sum - 1.0) < 0.0001` ratio sum validation (1518+400 = 1918/1920)
- [ ] Comments synchronized (delete "editor 794 PT" "aiChat 1518 PT" "upper band 1914" "lower band 1918" absolute value descriptions, change to "ratio consistent with LayoutTokens" "sum ratio conservation")
- [ ] `swift test` exit 0 (137/137 pass)
- [ ] `swift build` exit 0 (0 warning)
- [ ] Do not touch LayoutTokens / LayoutShellView / LayoutShellViewModel / NativeSplitter / DesignTokens
- [ ] Do not touch hermes app / `~/.hermes/profiles/pocock/`

## Business-language description (老板 understands)

- Implementation goes "by ratio × total width" operator (any window size adaptive), test expected values use absolute PT validation = old paradigm, change to ratio validation aligned with implementation
- Do not change layout truth, change test validation method
- 137 tests all pass

## Truth references

- LayoutShellView implementation (line 321-323, 355): `let editor = totalW * CGFloat(vm.editorWRatio)`, `let aiChatW = totalW * CGFloat(vm.aiChatRatio)` — 老板 8/19 拍 "use ratio write" paradigm
- v0.15 ticket 022.5 (commit `a37c560f`) revert ticket 022 `.containerRelativeFrame` change back to `LayoutTokens.ratio * totalW` (draggable + resize-responsive)
- v0.15 ticket 012 (commit `a513b67`) LayoutTokens.editorWRatio = 794/1920, aiChatRatio = 1518/1920 (mcp__sketch__run_code truth)