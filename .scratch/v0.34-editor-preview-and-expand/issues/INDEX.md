# Tickets Index (= v0.34 editor preview/expand)

## Q34 step 3 完成 (= 11 tickets published)

| # | Ticket | Blocked by | Status |
|---|---|---|---|
| 01 | @AppStorage + AppCommands enum | None | ready-for-agent |
| 02 | PaneNSController.handleEditorMaximizedChanged | 01 | ready-for-agent |
| 03 | Fix EditorExpandShrinkTrailingButton | 01, 02 | ready-for-agent |
| 04 | EditorMode enum + mode toggle | None | ready-for-agent |
| 05 | Preview mode = swift-markdown + InternalLinkParser | 04 | ready-for-agent |
| 06 | Preview mode = BacklinksPanel | 05 | ready-for-agent |
| 07 | Edit mode = TextEditor + dirty + save | 04 | ready-for-agent |
| 08 | Editor top bar toolbar layout | 03, 04, 07 | ready-for-agent |
| 09 | Close button + dirty confirm dialog | 08 | ready-for-agent |
| 10 | Cmd+E / Cmd+W / Cmd+Shift+E hotkeys | 08 | ready-for-agent |
| 11 | Backlog B-11 + double-axis review | 01..10 | ready-for-agent |

## Dependency graph (= 2 parallel tracks)

```
Track A (修复展开): 01 → 02 → 03 ──┐
                                  ├──→ 08 ──→ 09
Track B (preview/edit): 04 ──→ 05 ──┤   │
      └─→ 07 ──────────────────┤   ├──→ 10
                                │   │
                                └───┴──→ 11 (post-hoc double-axis)
```

## Total estimated effort

- 11 commits (one per ticket) per Q37 streak rule
- Each commit 30-90 min (~ 8-12 hours total)
- Each commit: implement + smoke test + double-axis review (Standards + Spec sub-agents) + commit + push
- Boss final 拍 after ticket 11 双轴 PASS (= Q34 step 8)

## Front-of-queue (= can start immediately)

- **01** (@AppStorage + AppCommands enum for editor expand)
- **04** (EditorMode enum + mode toggle)

## Iron rules applied (= per ticket acceptance criteria)

- Rule 6: DesignTokens.paneTabHotArea = 28 PT (= no magic numbers)
- Rule 7: Button + system buttonStyle + Lucide icons only
- Rule 8: Stays inside WindowGroup scene tree (= no new NSWindow)
- Rule 11: @AppStorage / @SceneStorage standard storage
- wenshu-apple-api-first: use Apple HIG built-ins + wenshu's existing parsers/panels
- AGENTS.md §11.1: pinned swift-markdown 0.4.0 (= no new deps)
- AGENTS.md hard rule: English-only commit body + new comments; "老板" sole address
