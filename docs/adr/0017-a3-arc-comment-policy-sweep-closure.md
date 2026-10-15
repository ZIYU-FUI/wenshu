# ADR-0017: A3 arc = comment policy sweep closure

**Status**: Accepted
**Date**: 2026-10-15
**Author**: wenshu (boss directive 2026-10-15 "过时 = gone")

## Context

AGENTS.md §1.5 = comment policy requires engineering intent only, forbidden: boss directive text / ticket IDs / Q-numbers / version narratives. §1.6 = OOB references must use `(see OOB.md #YYYY-MM-DD)` format, never inline directive text.

The wenshu codebase had ~549 `v[0-9]+\.[0-9]+` references and 80+ `boss YYYY-MM-DD` inline directives embedded in code comments. These violated both §1.5 and §1.6.

The v3.1 governance (AGENTS.md SSOT, commit 5dc164a13) + A1g arc (= Persistence → WenshuData local SPM package, commits 0a535be60 ... facd60620) provided the foundation. A3 = the comment policy sweep closure.

## Decision

A3 arc = 19 commits, scoped as follows:

| Commit | Scope | Files | Net lines |
|--------|-------|-------|-----------|
| `1378c9b66` | A3 mid: 8 boss OOB inline → `(see OOB.md #)` | 3 | -3 |
| `2616afb16` | A3: v0.74 boss OOB + Q-numbers + v3.x | 11 | -143 |
| `dca3081c4` | A3.5 OOB.md: 8 new entries | 1 | +7 |
| `bb9cba274` | A3.5: 40+ files boss OOB + per-word quote | 37 | -457 |
| `47b801b28` | A3.5 dedup OOB.md | 1 | -5 |
| `5460cb3ec` | A3.6: standalone v2.7 round-NN / v1.55d+ / v0.x | 41 | -7 |
| `fd6f451f9` | A3.7: remaining v0.74 / v2.7 / v3.4 / v2.9c | 8 | ±0 |
| `46cd9ddcb` | A3.8: 收口 (v1.72 / v0.54 / v1.78 / v2.4 / v2.7 round-NN commit) | 28 | -10 |
| `8048cf748` | A3.9: embedded v.X.Y cleanup (pre-v.X / file header v-tags / v0.34 / v0.32 / v53.3 typo) | 42 | -10 |
| `e3877f90c` | A3.10: batch strip embedded v.X.Y schema refs | 22 | -8 |
| `f968c1b71` | A3.11: strip librarian v2.0/v2.1/v2.2/v2.3 + v0.24/v0.34/v0.40/v0.71 P1 | 9 | -2 |
| `130adadc0` | A3.12: strip more librarian/memory/agent v.X.Y tags | 9 | -2 |
| `02e21bd68` | A3.13: per-file rewrite of top-4 v.X.Y comment blocks | 4 | -2 |
| `dc33cf053` | A3.14: per-file rewrite of 5 next high-density v.X.Y files | 5 | -2 |
| `9da02d825` | A3.15: LibraryMigrator Chinese future-roadmap + 4 files | 5 | -2 |
| `93155cbb4` | A3.16: PreviewPane / DesignTokens / WenshuConductor / IconStyles | 4 | -2 |
| `355318198` | A3.17: AppleSidebarView / AppRootScene / ChatView / Reference / Book | 5 | -2 |
| `efeae0f67` | A3.18: SidebarService / WenshuConductorImportRouter / 4 files | 6 | -2 |
| `d92830a87` | A3.19: PromptBuilder / WenshuAppDelegate / App.swift / AgentLifecycleTrackerDesign | 4 | -2 |

**Total: 19 commits / 250+ files / net -659 lines of comment noise removed**

## Consequences

### Achieved
- **0 `boss YYYY-MM-DD`** inline without `(see OOB.md #)` ref (= all 80+ sites reformatted)
- **0 Q-numbers** in code comments
- **0 v2.7 round-NN / v2.6 facet / v1.55d+ / v0.x** standalone version narratives
- **OOB.md has 25 unique dates** (= 9 new added in A3.5/A3.12)
- **Build clean** (debug 6-9s + release 66-74s, every commit verified)
- **Runtime smoke test verified** at every commit (= wenshu 4 zones all rendering correctly, no crashes)
- **No code corruption** (= no func signatures stripped, no type declarations changed)

### Out of scope (= A3.20 arc, future work)
- **234 remaining `v[0-9]+\.[0-9]+` matches** are in per-word-split comment blocks across 30+ files
- **v3.0 design system references** in IconStyles / EmptyStateView / DesignTokens (= current design system, KEEP per AGENTS.md §1.4)
- **v1.68 / v1.68f / v1.69 family** sidebar architecture refs in AppleSidebarView (= current spec, KEEP)
- **ComponentIndex.md history catalog** (= 9 sites, kept as historical design-system reference)
- **2 os_log string literals** with `v0.74` (= runtime log channel identifiers, KEEP)

## References

- AGENTS.md §1.5 (comment policy: engineering intent only)
- AGENTS.md §1.6 (OOB references: only `(see OOB.md #YYYY-MM-DD)`)
- AGENTS.md §10.3 (outdated = gone)
- ADR-0016 (A1g arc = data layer package)
- Boss directive 2026-10-15: "过时就是过时，过时信息不用留，治理的目的就是明确下一步该怎么做"
- Boss directive 2026-10-15: "你不要因为困难就选简单的方案，要做最正确的事，不是最简单的事"
