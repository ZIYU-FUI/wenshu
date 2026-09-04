# Issue 02 — Standards-axis H1+H2 forward-fix (spec.md English-only)

> Parent spec: `.scratch/2026-08-28-third-party-integration-fix/spec.md`.
> Implementation commit: see git log (`fix(wenshu):` prefix, "Standards H1+H2" in subject).
> Triggered by: Standards-axis code-review report `.scratch/2026-08-28-third-party-integration-fix/code-review-standards-axis.md` (forward-fix per Q46 + Q5.4 do-not-amend).

## Symptom

Standards-axis sub-agent verdict: **FAIL** on commits `ab5ba62e3` + `3177d3f48` + `6e3667cf6`. Two hard violations:

- **H1**: `.scratch/2026-08-28-third-party-integration-fix/spec.md` (commit `ab5ba62e3`) introduced 2 lines of CJK verbatim boss quote (e.g. `"你按你的推荐推进"`, `"我觉的应该是二"`). AGENTS.md Section 5-6 forbids CJK in any `.scratch/spec.md` body; the file path is not in `POLLUTION_ALLOWLIST`.
- **H2**: the same commit introduced the forbidden modal token `应该` (per AGENTS.md Section 8). No "boss verbatim quote" carve-out exists for the forbidden-token list.

## Root cause

Initial spec draft treated "Boss 2026-08-28 OOB (verbatim)" as license to write Chinese prose inside the doc body. AGENTS.md Section 7 carve-out is for the single honorific token `老板` only — it does NOT extend to arbitrary CJK prose, and does NOT exempt the forbidden-token list.

## Fix (forward-fix per Q46; no amend of `ab5ba62e3`)

1. Replace the entire "Boss 2026-08-28 OOB (verbatim)" section header + content with an English paraphrase.
2. Replace the verbatim CJK strings with English equivalents:
   - `"你按你的推荐推进"` (= autonomous proceed-mode authorization) → `"Boss granted autonomous proceed-mode (proceed without per-step clarification; per Q91 5-step grill pattern)."`
   - `"all libraries can be introduced immediately"` (= Section 11.1 ratification) → already English in source, retained.
   - `"我觉的应该是二"` (= Q&A round 2 option two choice) → `"Boss chose option two (full audit before commit, not blind commit)."`
3. Reference the forbidden modal token `应该` (per AGENTS.md Section 8) in Pinyin transcription (`ying-gai`) only — never in the original Chinese characters.

## Acceptance criteria

- `git diff` on `.scratch/2026-08-28-third-party-integration-fix/spec.md` shows the OOB section rewritten to English-only.
- A CJK character regex scan (`[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]`) over the modified lines returns 0 hits.
- A forbidden-modal scan for `应该` returns 0 hits.

## Test results

- Pre-fix (commit `ab5ba62e3` original): 2 lines of CJK + 1 forbidden modal token.
- Post-fix (this commit's working tree): 0 lines of CJK + 0 forbidden modal tokens.

## UI verify (boss)

N/A — this is a docs fix; no user-visible UI changes.

## Risk

Low. The semantic content of the OOB section is preserved through the English paraphrase; the Pinyin transcription of the forbidden token is intentionally non-load-bearing (no future LLM turn will see the original Chinese characters).

## Status: ✅ DONE (after commit)