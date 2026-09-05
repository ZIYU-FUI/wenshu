# 2026-09-05 Today Banner

Wenshu v0.38 work packet summary. First line = fact. Last line = fact.

## Stage table (= 13 stages + commits)

| Stage | Description | Commits | Cumulative |
|---|---|---|---|
| 1 | Boss 7-question batch (= 7 questions A-G resolved) | 7 | 7 |
| 2 | Hermes 5 subsystem 1:1 port | 5 + 1 fix | 13 |
| 3 | 18 partial modules 1:1 port (= P0 / P1 / P2) | 20 | 33 |
| 4 | GAP-001..008 module gaps closed | 16 | 49 |
| 5 | 7-connector profile gap-fill (= DeepSeek + Ollama + OpenRouter + minimax-cn + Anthropic + OpenAI + Gemini + byte-parity) | 5 | 54 |
| 6 | 9 HERMES-INTERNAL 1:1 port | 9 | 63 |
| 7 | HOOK-SYSTEM + DISPATCH + ChatBox | 9 | 72 |
| 8 | Build fixup + launch fix | 2 | 74 |
| 9 | Integration plan 23 ticket | 23 | 97 |
| 10 | FIX-TODO-LOCK-001 + VERIFY-INTEGRATION-001 | 2 | 99 |
| 11 | v0.40 ToolRegistry 1:1 port | 4 | 103 |
| 12 | v0.40 Liquid Glass polish | 6 | 109 |
| 13 | Inventory auto-pilot cleanup | 8 | 117 |

Note: total commit count in git log since 2026-09-04 = 220+ (= 13 stage commits + cleanup commits + integration commits + retrospective + backlog closeout).

## Top 5 most-impactful tickets (= boss-verify-ready)

1. **Stage 12 POLISH-LIQUIDGLASS-005** (= `fe68fe2ee`): Apply Liquid Glass to menu popovers + dropdown panels + context menus. macOS 27 polish extends from TopBar + Sidebar + Editor + StatusBar + sheets to all popover surfaces.
2. **Stage 12 POLISH-LIQUIDGLASS-003** (= `be2bfc62d`): Apply Liquid Glass to Editor chrome + StatusBar chrome. macOS 27 polish extends from TopBar + Sidebar.
3. **Stage 11 v0.40 ToolRegistry port** (= 4 commits): hermes ToolRegistry verbatim port to Swift + wire to WenshuConductor + migrate existing call sites + verify integration tests green.
4. **Stage 9 Integration plan 23 ticket** (= 23 commits): 18 wayfinder-priority + 5 supporting tickets. Full integration sweep.
5. **Stage 3 + Stage 4 partial modules 1:1 port + GAP** (= 36 commits): 18 partial hermes modules ported to Swift + 8 module gaps closed. Coverage went 18/143 partial → 0 partial.

## Bottom 5 still-pending items (= boss dependencies)

1. **B-10 phase B Apple Keychain entitlement codesign** (= blocked on Apple Developer Program paid by boss). Until then InMemoryKeychainStore remains the default backend.
2. **Tier-2 / Tier-3 Apple-API-first sweep** (= 5-7 days Tier-2 + 10-14 days Tier-3; deferred to v0.41+ unless boss拍 expedites).
3. **v0.40 architecture refactor Option C execution** (= the remaining ConversationLoop per-concern actor extraction is deferred to v0.41+ unless boss拍 expedites).
4. **B-07 residue 7 tickets** (= 028-001 / 028-002 / 028-011 / 015-014 / 015-015 / 015-019 / 015-020 / 015-073). Per integration plan, these are "等老板拍下一条".
5. **v0.39 ticket 001 manual X-test** (= requires boss to launch wenshu and verify wiki-link + image-resolution + preview/edit toggle features; Section 5 rows 9-12 in retrospective).

## ASCII architecture diagram (wenshu post-v0.38)

```
+----------------------------------------------------------------+
|                  Wenshu (Swift / SwiftUI / macOS 27)            |
+----------------------------------------------------------------+
|                                                                |
|  +-----------------+    +------------------+   +-------------+ |
|  |   Frontend      |    |   Core / Agent    |   |  Connectors  | |
|  |   (6-zone UI)    |<-->|   (Hermes port)   |<->|  (7 profiles) | |
|  |                 |    |                  |   |              | |
|  | TopBar [Liquid] |    | ConversationLoop  |   |  Anthropic   | |
|  | Sidebar [Liquid]|    | ToolRegistry     |   |  OpenAI      | |
|  | Editor [Liquid] |    | 9 HERMES-INTERNAL |   |  Gemini      | |
|  | StatusBar [Liq] |    | Goal/Todo/Kanban |   |  DeepSeek    | |
|  | Modal Sheets[L] |    | EventBus          |   |  Ollama      | |
|  | Menu Popover[L] |    | SecretScope       |   |  OpenRouter  | |
|  | + 14 verify items|    | SkillBundles      |   |  minimax-cn  | |
|  +-----------------+    +------------------+   +-------------+ |
|         |                       |                     |       |
|         v                       v                     v       |
|  +--------------------------------------------------------------+|
|  |                  Storage (Apple HIG)                          ||
|  |  .ws Library Package (NSOpenPanel)                            ||
|  |  +-- Info.plist (WSSchemaVersion)                             ||
|  |  +-- chat.sqlite (FTS5 via GRDB)                               ||
|  |  +-- reference-library/ (system-managed, ONE)                ||
|  |  +-- shelves/ (user bookshelves; multiple)                    ||
|  |  |    +-- books/<uuid>/ (8 folders + 8 JSON sidecars)         ||
|  |  +-- cache/ (thumbnails + search index)                        ||
|  +--------------------------------------------------------------+|
|         |                                                          |
|         v                                                          |
|  +--------------------------------------------------------------+|
|  |  v0.40 ToolRegistry 1:1 port (hermes ToolRegistry verbatim)     ||
|  |  + Tool.swift + ToolRegistry.swift + ToolDispatchHelpers.swift ||
|  |  + ShellHookChain.swift + EventBus.swift + SkillKeywordMatcher  ||
|  +--------------------------------------------------------------+|
|         |                                                          |
|         v                                                          |
|  +--------------------------------------------------------------+|
|  |  PollDef:                                                            ||
|  |  - commit_filter.py: 12 forbidden tokens hex-encoded (v0.28)   ||
|  |  - 3 git hooks: pre-commit + commit-msg + pre-push            ||
|  |  - .github/workflows/ci.yml Pollution check                  ||
|  |  - working-tree watchdog (cron-every-few-minutes)              ||
|  +--------------------------------------------------------------+|
+------------------------------------------------------------------+
```

## Build state (= post-v0.38 HEAD)

- swift build = exit 0 (= green)
- swift build --target WenshuAppTests = exit 0 (= green)
- working tree = clean after INV-BATCH-2 push (= 3 commits ahead of v0.37.2 baseline)
- git remote: old-origin (github) + origin (gitcode) both synced
- 14 frontend verify items = pending boss manual launch + verify

## Files inventory (= new + modified since v0.37.2)

- New = ~80 files (mostly Stage 3 partial ports + Stage 6 HERMES-INTERNAL + Stage 11 ToolRegistry)
- Modified = ~40 files (Liquid Glass polish on all 6 chrome surfaces + I18N-INLINE-001 + B-13 scope picker + DEAD-PIN-CLEANUP-001)
- Removed = 0 files (DEAD-PIN only removes SPM package declarations; no source files imported the dead packages)

First line = fact. Last line = fact.
