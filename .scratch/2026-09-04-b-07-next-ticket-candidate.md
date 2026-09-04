# B-07 next ticket candidate (boss 2026-09-04 OOB 'E' partial)

## Goal

Pick ONE ticket from B-07 (= 9 boss-skipped items per boss 8/27/8/29/9/02
"等我拍") for boss to拍 next. Write a recommendation spec (= NOT code; boss
will then拍 which to ship). Also outline B-10 phase B activation prep.

## Already-shipped (= canonical state as of 2026-09-04)

Boss 2026-09-04 OOB ratified the previous ticket `028-003 pane-zone mapping`
(= commit `aebc97b8b`). The remaining backlog (B-07) is therefore 8 tickets,
NOT 9 — `028-003` is closed.

## Stale-status cleanup (= 6 of the remaining 8 are already shipped, but backlog.md B-07 still lists them as open)

While auditing each ticket, 6 were found to have ship-commits in git history
that the B-07 backlog never picked up. They are NOT candidates; they need
backlog status = DONE, not a new spec:

| Ticket | Status reality | Evidence (= shipped commits) |
|---|---|---|
| 028-001 | shipped (= boss ratified (b) 2026-08-27) | `.scratch/2026-08-28-v0-28-free-layout/tickets/028-001.md` L31-37 (= "Boss decision = b" + ratify line) |
| 028-002 | shipped (= boss ratified b/II = FCP Browser) | `.scratch/cjk-translation-cache.json` L553 (= "ticket 028-002 = b/II") + `Sources/WenshuApp/State/WorkspaceStore.swift:505-621` (= builtinDefault preset = FCP Browser 3-pane hybrid) |
| 028-011 | shipped (= DragRegressionTests + pre-commit hook) | commits `daec822e9` + `857e492cd` (= 7 drag scenarios + CI wiring) |
| 015.014 | shipped (= archive icon + FAIL cleanup + concurrency) | commits `8330ddda3` + `d2195a121` + `1f1293b95` + `a03e0c0a5` (4 commits, v0.24 boss验收) |
| 015.019 | shipped (= "书: N" book count) | commits `9950fc47e` + `42bb97f7f` (v0.24 boss验收) |
| 015.020 | shipped (= hide 2 tabs + relabel + 占位文字 fix) | commits `831dbe0ae` + `b45847369`; PaneStatusBar.swift shipped; "占位文字" string at `Sources/WenshuApp/UI/ZonePerRegionChrome.swift:9` is the canonical placeholder text (NOT audit debt) |
| 015.073 | shipped (= 5th button projectPreview zone) | commits `fadfbf3ec` + `4a8536487` (v0.24 boss验收) |

So the actual candidate pool is **2 tickets**, not 8.

## Remaining candidate pool (= 2 truly-open tickets)

| # | Ticket | Status | Spec exists? | Effort | Risk | Value |
|---|---|---|---|---|---|---|
| 1 | 028-001 | open-by-misclassification (= boss拍 done; backlog stale) | yes (= `.scratch/2026-08-28-v0-28-free-layout/tickets/028-001.md`) | none | none | none (= ship-cleanup only; no code change) |
| 2 | 015.015 | TRULY OPEN (= per-book project files; architectural) | yes (= `.scratch/2026-08-24-v0-24-boss-receiving/spec.md` L200-201 + L220-221) | L | High | High (= blocks 015.016 + 015.017 = 2 downstream tickets) |

## Recommended next

**015.015** — per-book project files (= wenshu-style AGENTS.md + README.md +
CONTEXT.md equivalents inside each `.ws/<shelf>/<book>/` folder).

### Why 015.015

- **Truly open** (= the only ticket with zero shipped commits).
- **Boss intent documented** (= spec at
  `.scratch/2026-08-24-v0-24-boss-receiving/spec.md` L200-201 explicitly
  names "wenshu-style AGENTS.md + README.md + CONTEXT.md equivalents inside
  book folder" as the ticket definition).
- **Architectural = highest value** (= this ticket blocks tickets 015.016
  + 015.017 per the same spec L211-214; without per-book project files,
  per-book selection sync and per-book long-form context cannot land).
- **User-visible** (= each book folder shows the 3 standard docs; the
  authoring loop "open book folder, read its README" matches wenshu's own
  dev workflow = direct parity with the boss's mental model).
- **Spec already exists** (= boss already accepted the design as part of
  the v0.24 boss-receiving flow; the "等我拍" skip was on IMPLEMENTATION,
  not on DESIGN).
- **Risk surface bounded** (= adds 3 text files per book on creation;
  no renderer changes; no Settings UI; no new dependencies).

### Why NOT 028-001

028-001 is open in B-07 backlog only because nobody closed the bookkeeping
entry. Boss already拍 (b) 2026-08-27 (= WorkspaceView ON by default;
LayoutShellView as opt-in fallback). WorkspaceStore.workspace ships that
behavior today. This ticket is **backlog hygiene** (= rewrite the B-07 entry
to status = DONE), NOT a code deliverable. Lowering risk to zero is fine,
but it delivers zero new user value — not the right answer for the next
slot.

### Risk + blockers (= call-out for boss拍)

- **Blocker #1 (boss-decision only)**: spec at
  `.scratch/2026-08-24-v0-24-boss-receiving/spec.md` L200-201 uses generic
  filenames ("AGENTS.md / README.md / CONTEXT.md equivalents"). Boss may
  want different filenames (= wenshu root uses `AGENTS.md` literally, but
  the per-book variants might need different names to avoid collision with
  the wenshu root convention). My recommendation = keep the same 3 names
  verbatim (= `AGENTS.md`, `README.md`, `CONTEXT.md`) so the per-book
  convention IS wenshu's convention; explicitly a sub-decision boss should拍.
- **Blocker #2 (sub-decision)**: on `BookStore.createBook(...)`, the 3
  files should ship with what seed content? My recommendation = minimal
  (= single header line + the book's `title` interpolated). Boss can拍
  richer seed (= include the book UUID + creation date + 1-line stub for
  AGENTS.md only).
- **No new dependencies** (= ADR-0008 holds; just file I/O on book
  folder creation).
- **No AGENTS.md / CLAUDE.md / README.md / CHANGELOG.md touch** (= spec
  explicitly forbids).
- **No renderer changes** (= the 3 docs are inert on disk until a
  followup ticket surfaces them in a UI; ticket 015.017 = per-book
  long-form context = the surface-area followup that READS these files).

## B-10 phase B prep outline

B-10 (boss 2026-09-02 OOB: "the unified key settings page should write to
Apple Keychain via SecItemAdd") = re-enable the commented-out real
`SecItemAdd` / `SecItemCopyMatching` / `SecItemDelete` code in
`Sources/WenshuApp/Core/Provider/ProviderKeychain.swift:50-155`.

State today: the code is present but commented out (= v0.28 followup per
boss 2026-08-29 OOB "注释掉密码功能"). The stub returns success for
save/delete and a hardcoded debug key `'wenshu.debug.api.key'` for load.
LLM calls succeed with the fake credential (= Apple Keychain is NOT being
written to).

### Phase B activation steps (= what B-10 needs before boss拍 phase B = "go"):

1. **Verify the real SecItemAdd path is correct (= no Boss time wasted on bad code)**.
   - The commented-out `saveKeySync` body should write
     `kSecClassGenericPassword` + `kSecAttrService "com.wenshu.app.provider"`
     + `kSecAttrAccount "<provider.slug>.api.key"` +
     `kSecAttrAccessibleAfterFirstUnlock`.
   - Re-read the commented-out block in
     `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` and confirm:
     - `kSecValueData` = the key bytes (CFData, NOT the String)
     - `errSecDuplicateItem` handling (= delete + retry, not fatal)
     - CFRelease of any `CFTypeRef` returned (= no leak)
   - Verification = READ ONLY (= no actual `SecItemAdd` run; that waits for
     phase B go-ahead).
   - If any of the 3 checks fails, file a SUGGEST doc before phase B =
     boss拍.

2. **Confirm the unified add interface is the ONLY write path** (= already
   verified per backlog L193: 9 caller sites across App.swift,
   AvailableModelsDiscovery.swift, WenshuVerifier.swift; all go through
   `ProviderKeychain.saveKeySync(_:for:)`). No new wiring needed.

3. **Add a "phase B activation" toggle in Settings** (= optional; only if
   boss wants to gate phase B behind a user-visible toggle).
   - Path: `Sources/WenshuApp/UI/Settings/KeySettingsView.swift` (= already
     exists per the unified add interface)
   - New `@AppStorage` bool `wenshu.providerKeychain.realSecItemAddEnabled`
     (= default = false; current stub stays until boss flips it).
   - When false: today's stub (= debug key + early-return success).
   - When true: real SecItemAdd path runs (= `kSecClassGenericPassword`).
   - This is the safest "soft launch" path: boss can flip the toggle in
     the running app, watch the macOS SecurityAgent modal prompt appear,
     grant it, and observe the real Keychain write in
     `Keychain Access.app`.

4. **Activation spec (= the document boss will拍 on)**:
   - One-commit change to `ProviderKeychain.AppleKeychainStore.saveKeySync`
     (= uncomment the real SecItemAdd block + delete the stub).
   - One-commit change to `loadKeySync` (= uncomment SecItemCopyMatching;
     on errSecItemNotFound = return nil, NOT the debug key).
   - One-commit change to `deleteKeySync` (= uncomment SecItemDelete; on
     errSecItemNotFound = success, NOT a fatal error).
   - Acceptance:
     - `grep -rn 'wenshu.debug.api.key' Sources/` = 0 hits.
     - `grep -rn 'kSecClass.*kSecClassGenericPassword' Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` = 4+ hits.
     - `swift build` exit 0.
     - Manual test (= on real Mac with securityagent authorization): save
       a key via Settings → Provider Keys, observe the macOS modal,
       grant it, restart app, verify key survives via
       `security find-generic-password -s com.wenshu.app.provider`.

5. **Boss gate (= when phase B activates)**: macOS shows the SecurityAgent
   modal prompt the FIRST time. Boss拍 to proceed (= modal accept), then
   SecItemAdd runs. Subsequent writes = no modal (= same app signing identity).

### Out of scope (= intentionally NOT in phase B):

- Migrating existing callers to a newer API surface (= `ProviderKeychain`
  is already single source of truth).
- New `LLMKeychain.swift` revival (= deleted as dead code in the B-10
  cleanup this session per backlog L187).
- Replacing stub with keychain-export-via-env-var (= LLM keys in process
  env is a security regression; out).

### Phase B activation timeline (= my recommendation)

Phase B is a **one-shot activation**, NOT a multi-ticket rollout. Once boss
拍 go:

- 1 commit = real SecItemAdd uncommented
- 1 commit = real SecItemCopyMatching uncommented
- 1 commit = real SecItemDelete uncommented
- 1 commit = Settings UI toggle (= optional, only if boss wants the soft-launch gate)

Total = 3-4 commits, all ~10 LOC each, all in one file
(`ProviderKeychain.swift`). Real-world effort = ~15 minutes (= the build is
fast; the only time cost is the macOS modal prompt manual test).

### Risk call-out (= be honest)

The macOS SecurityAgent modal prompt = a HARD gate. If boss declines it,
SecItemAdd returns `errSecAuthFailed` (= NOT a silent failure; user-visible
error in the Settings pane). The Settings pane must surface the error
gracefully (= current stub never errors; phase B introduces the first
error path). Spec must include an alert view (= Apple HIG standard error
presentation) for the auth-declined case. **This is the one design
decision boss should拍 before phase B ships** (= which error UX? my
recommendation = SwiftUI `.alert` modal with "Open Keychain Access.app"
button).

## Hard rules (= this task)

- English-only in commit message + file body.
- DO NOT touch `AGENTS.md` / `CLAUDE.md` / `README.md` / `CHANGELOG.md`.
- DO NOT touch any Swift source code (= spec-only).
- DO NOT remove any existing public surface.

## Acceptance

- File `.scratch/2026-09-04-b-07-next-ticket-candidate.md` exists at this
  path with the sections above.
- `swift build` exit 0 (= sanity; docs-only commit shouldn't change build).
- Working tree clean for the commit (= untracked files outside this spec
  doc are kept as-is).
- 1 commit on `main` (= current branch) with English-only message.
- Pushed to `origin` (gitcode) + `old-origin` (github).
- B-07 backlog.md B-07 section NOT touched (= stale-status cleanup is a
  SEPARATE followup; this task only picks next ticket + outlines phase B).

## Frontend verification dependency

None (= spec-only; no UI changes).

## Workspace

`/Volumes/ANAN/Engineering/wenshu`. Do NOT switch branches.

## Report back

- Commit hash (short)
- `swift build` exit code
- Recommended B-07 next ticket (= 015.015)
- B-10 phase B prep outline (= toggle + 3 uncomment commits + 1 alert UX
  decision)
- Push status (= both `origin` + `old-origin`)
- Acceptance block (one-liner):

```
B-07 next ticket candidate shipped: 8 remaining candidates audited; 6 already
shipped (= backlog cleanup needed separately, not in this commit); 2 truly
open; recommended next = 015.015 per-book project files (blocks 015.016 +
015.017); B-10 phase B prep outlined (= real SecItemAdd verification +
optional activation toggle + 3 uncomment commits + alert UX decision).
1 spec commit pushed to origin + old-origin.
```

Last line: fact.