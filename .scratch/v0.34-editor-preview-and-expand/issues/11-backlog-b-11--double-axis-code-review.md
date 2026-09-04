# 11: Backlog B-11 + double-axis code review

**What to build:** Update .scratch/backlog.md with B-11 entry (= editor-preview-and-expand ticket series = done; cross-refs to spec + tickets). Run double-axis code review (= Standards + Spec sub-agents per Q37 streak rule established 2026-08-25) on the entire 10-commit series. Post-hoc domain modeling per Q34 step 7.

**Blocked by:** 01..10 (all implementation done)

**Status:** ready-for-agent

## Acceptance criteria

- [ ] .scratch/backlog.md has B-11 entry with cross-refs to spec.md + 10 issue files
- [ ] Standards axis sub-agent dispatched (= AGENTS.md hard rules + 11 iron rules + ComponentIndex consistency on all 10 commits)
- [ ] Spec axis sub-agent dispatched (= spec user stories + implementation decisions vs actual code on all 10 commits)
- [ ] If both axes PASS: B-11 marked done, boss notified (= Q34 step 8)
- [ ] If any axis FAIL: file follow-up tickets (= Q34 step 3 vertical slice repeats for failures)
- [ ] Domain glossary updated in CONTEXT.md (= add terms: EditorMode, wikilink rendered preview, Backlinks panel scope, Expand/Shrink snapshot)

## Iron rules applied (= check before commit)

- [ ] Rule 6: layout/spacing uses DesignTokens (= no magic numbers)
- [ ] Rule 7: Button + system buttonStyle (= no custom-drawn icons, Lucide only)
- [ ] Rule 8: stays inside WindowGroup scene tree (= no new NSWindow)
- [ ] Rule 11: state persistence via @AppStorage / @SceneStorage (= Rule 11 + Apple HIG standard)
- [ ] wenshu-apple-api-first: grep Apple HIG first, write ZERO custom code if built-in covers it
- [ ] AGENTS.md §11.1: use pinned deps (swift-markdown 0.4.0) — NO add new deps
- [ ] AGENTS.md hard rule: English-only commit body + new comments; "老板" sole address

## Double-axis review (= per Q37 streak rule)

- [ ] Standards axis = sub-agent reviews AGENTS.md hard rules + 11 iron rules + ComponentIndex consistency
- [ ] Spec axis = sub-agent reviews spec user stories + implementation decisions vs actual code
