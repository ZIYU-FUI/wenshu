# 011: AGENTS.md §11 + §11.2 + CLAUDE.md sync (= docs-only ticket)

**What to build:** Land the AGENTS.md §11 baseline rewrite + new §11.2 connector-profiles section + new "tool-only" product-positioning rule (all per spec §7). Sync CLAUDE.md lines 15, 16, 19, 40, 51, 58, 103 to match. This ticket is docs-only and runs in parallel with the code work (= boss拍 2026-09-03 ratified the rewrite; the rewrite must land before the connector UI ships in issue 006, otherwise the §11 baseline would block code review).

**Blocked by:** None (can land any time; ideally lands at end of spec execution so all 7 connector profiles are documented when the rewrite hits `main`)

**Status:** ready-for-agent

## Acceptance criteria

- [ ] `AGENTS.md` §11 line 18 rewrites from 'v1 LLM provider supports minimax cn only (Anthropic-compatible protocol).' to the 7-connector architecture wording per spec §7.1
- [ ] `AGENTS.md` §11 product-positioning rule added at top-of-section per spec §7.2
- [ ] `AGENTS.md` §11.2 NEW section added per spec §7.3 (7 connector profiles table)
- [ ] `CLAUDE.md` line 15 syncs: replace 'minimax cn LLM' framing with connector-layer framing
- [ ] `CLAUDE.md` line 16 syncs: LLM provider abstraction now references §11.2 (= 7 connectors), not 'minimax cn'
- [ ] `CLAUDE.md` line 19 syncs: v1 LLM provider section references §11.2
- [ ] `CLAUDE.md` line 40 syncs: LLM provider table → references §11.2 7 profiles
- [ ] `CLAUDE.md` line 51 syncs: LLM connector section
- [ ] `CLAUDE.md` line 58 syncs: 'no LangChain / SwiftAI / Vercel AI SDK' rule retained (= connector layer is direct port, not third-party abstraction)
- [ ] `CLAUDE.md` line 103 syncs: `Sources/WenshuCore/LLM/` table references all 7 connectors, not just minimax
- [ ] `swift build` exit 0 (docs change should not break build, but verify)
- [ ] No code changes in this ticket (= docs only)
- [ ] git commit: `docs(wenshu): v0.35 -- §11 baseline rewrite + §11.2 7 connector profiles + tool-only rule + CLAUDE.md sync (= ticket 011 of 11)`

## Iron rules applied

- [ ] AGENTS.md hard rule: English-only (no CJK)
- [ ] AGENTS.md hard rule: "老板" sole address
- [ ] AGENTS.md hard rule: First line = fact, last line = fact
- [ ] AGENTS.md §11 baseline rewrite: keep the version number v0.07 unchanged (§11 = baseline; version bump is a separate commit)

## Estimated LOC

~80 lines of markdown changes (AGENTS.md ~40 + CLAUDE.md ~40). No code.

## Commit format

`docs(wenshu): v0.35 -- §11 baseline rewrite + §11.2 7 connector profiles + tool-only rule + CLAUDE.md sync (= ticket 011 of 11)`

## Risk notes

- This is a **baseline-breaking** doc change. After merge, any PR review must check §11 baseline compliance (= no minimax-only assumption in new code).
- Boss拍 2026-09-03 ratified the rewrite verbatim. This ticket is the durable record of that拍.