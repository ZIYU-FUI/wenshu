# 01 — flip useWorkspace default to true (= trailing 新建/入驻 buttons visible)

**What to build:**

Boss 2026-08-30 OOB '我看截图, 你把库管理顶栏右边的新建和导入按钮
改掉了, 原来的不能用吗, 为什么换'. After my v0.30 sidebar rewrite
(commit `c5ed76169`), trailing 新建/入驻 buttons were missing from
the screenshot. Root cause: `LibraryRootView.useWorkspace` defaulted to
`false` (= LayoutShellView path), which uses `ZoneModule` (= no
trailingButton slot). The trailing button wiring lives in App.swift:2626
(= v0.27 commit `bca226704`), bound only to ZoneContentView in
WorkspaceView path.

Fix: flip `@AppStorage("wenshu.useWorkspace") private var useWorkspace:
Bool` from `false` to `true` (= WorkspaceView path = default).
WorkspaceView path renders trailing buttons correctly via
ZoneContentView's trailingButton parameter.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent (= already committed as `3342850a6`,
this ticket documents the commit after-the-fact per Q5.6 partial
commit 接管规范).

## Fix specification

1. In `Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift`,
   locate `@AppStorage("wenshu.useWorkspace") private var useWorkspace:
   Bool = false` (~line 110).
2. Change default from `false` to `true`.
3. Update the inline comment block above this line to document the
   2026-08-30 boss OOB triggering the flip (= trailing buttons were
   invisible in default path screenshots).

## Acceptance

- [ ] `@AppStorage` default flipped to `true`
- [ ] Build exit 0
- [ ] Sidebar zone header trailing area shows 新建 + 入驻 buttons
  (= verified via screenshot)
- [ ] No regression: cards in preview pane, sort menu in top-right,
  etc. all still render

## Out-of-scope (= NOT in this ticket)

- WorkspaceView vs LayoutShellView path feature parity. If
  WorkspaceView is missing other features, file a separate ticket.
- User-configurable path switcher UI (= boss can already flip via
  `defaults write com.wenshu.app wenshu.useWorkspace -bool false`
  in terminal, but no UI yet).
