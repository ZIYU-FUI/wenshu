# Standards-Axis Code Review — wenshu third-party library integration commit chain

**Scope:** Standards axis ONLY (English-only / forbidden-vocab / Apple HIG / atomic-coupling justification). NOT merged with Spec axis.
**Branch / commits:** `wt/multi-agent-dispatch`
- `ab5ba62e3` — `docs(wenshu): v0.28 third-party-integration-fix spec + ticket 01`
- `3177d3f48` — `fix(wenshu): v0.28 third-party-integration ticket 01 — NukeUI SPM conflict`
- `6e3667cf6` — `docs(wenshu): AGENTS.md §11.1 ratification 2026-08-28 — 11 libraries approved`
**Workspace:** `/Volumes/ANAN/Engineering/wenshu`
**Date:** 2026-08-28
**Reviewer:** Standards-axis sub-agent (dual-axis dispatch)

---

## H1. HARD VIOLATION — CJK characters added to `.scratch/2026-08-28-third-party-integration-fix/spec.md` (commit `ab5ba62e3`)

**File:** `.scratch/2026-08-28-third-party-integration-fix/spec.md`
**Lines added (commit `ab5ba62e3`):**
- L5: `> "你按你的推荐推进" (= autonomous推进授权)`
- L7: `> Q&A round 2 reply: "我觉的应该是二" (= full audit before commit, not blind commit)`

**Rule violated:** AGENTS.md L5-6 hard rule — "This file is English only. No Chinese characters. No CJK punctuation. No mixed CJK + Latin characters." + "All commit messages, comments, prompts, `.scratch/spec.md`, `.scratch/issues/`, … follow the same English-only rule."

**Why this is a hard violation, not an allowlisted edge case:**
- `.scratch/2026-08-28-third-party-integration-fix/` is NOT in the `POLLUTION_ALLOWLIST` in `Tools/wenshu-devtool/commit_filter.py` (per the wenshu-pollution-defense skill — only `.scratch/2026-08-22-pollution-mitigation/`, `.scratch/2026-08-23-monday-acceptance-checklist/`, `.scratch/2026-08-23-agent-identity/`, `.scratch/2026-08-24-v0-24-boss-receiving/`, `.scratch/reviews/`, `.scratch/code-review-` are prefix-allowlisted).
- The CJK here is not the 12-token [forbidden 12-token list per AGENTS.md §8], so the commit_filter would not block — but the English-only rule is a separate hard constraint enforced by the LLM's own instruction-following, not by the hooks.
- AGENTS.md L7 carves out `老板` as the sole literal address token, and L8-9 carve out the rule-definition enumerations. Neither carve-out covers arbitrary CJK prose inside a `.scratch/spec.md` "Boss 2026-08-28 OOB (verbatim)" blockquote.
- The blockquote has a parenthetical English gloss for each CJK string, which proves the agent CAN render the meaning in English; the CJK is not load-bearing.

**Severity rationale:** Hard violation because the rule explicitly enumerates `.scratch/spec.md` as in-scope and the file path is not allowlist-prefixed. Two added lines, but the pattern (treating "verbatim boss quote" as license to write Chinese) is a recurring failure mode (cf. `2026-08-26-fcp-library-replica/spec.md` AGENTS.md L54 carve-out note).

**Required fix:** Replace the two blockquote lines with English glosses; if a verbatim transcription is essential for traceability, add the CJK source inside a fenced code block labeled as `[non-compliant OOB transcription — English gloss follows]` and immediately re-state the meaning in English.

---

## H2. HARD VIOLATION — Forbidden modal vocab `应该` introduced in `.scratch/2026-08-28-third-party-integration-fix/spec.md` (commit `ab5ba62e3`)

**File:** `.scratch/2026-08-28-third-party-integration-fix/spec.md`
**Line added (commit `ab5ba62e3`):**
- L7: `> Q&A round 2 reply: "我觉的应该是二" (= full audit before commit, not blind commit)`

**Rule violated:** AGENTS.md L8 — "Forbidden neutral words: 可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许 / 或 / 任意 / 大概率 / 通常 / 一般来说. Replace with: 是 / 否 / 行 / 不行 / 可以 / 不可以 / 不变 / 变."

**Why this is a hard violation:** The verbatim boss quote embeds the token `应该`. The rule says these tokens are forbidden in `commit body / comment / doc / prompt / card body` — there is no "boss-quote" carve-out. Even as a quotation, the token enters the file content and propagates to future LLM turns (Mechanism B from `.scratch/2026-08-22-pollution-mitigation/research.md`).

**Note (for the Spec-axis sub-agent, NOT counted here):** "我觉的应该是二" has no English semantic equivalent that matches "二" — it appears to be a fabricated or paraphrased "verbatim" quote. That is a Spec-axis concern (verifiability of OOB claims); Standards-axis only flags the token, not the truth of the attribution.

**Required fix:** Replace `应该` with `认为` or drop the blockquote; if the verbatim must be preserved, transcribe as `[token-elided, English gloss: "I think it's option two"]`.

---

## S1. SOFT WARNING — `老板` token added in `Package.swift` comment (commit `3177d3f48`)

**File:** `Package.swift`
**Line added (commit `3177d3f48`):**
- L10: `// 2026-08-28 OOB: 老板 ratified "all libraries can be introduced immediately".`

**Why this is borderline, not a hard violation:**
- AGENTS.md L7 explicitly carves out `老板` ("Sole address for the user = 老板 (the literal characters)") and L71-72 re-affirm ("Every dialog / doc / commit message / comment / prompt uses 老板").
- The token appears once in a `//` comment, and the literal string `"all libraries can be introduced immediately"` immediately follows in English — meaning the comment is otherwise English-only.
- The token usage is consistent with the project-wide honorific pattern (cf. AGENTS.md L7, L20, L29, L46, L65, L71, plus the `.scratch/2026-08-28-third-party-integration-fix/spec.md` "Boss" section header pattern).

**Why it's still worth flagging:** The wenshu-pollution-defense skill frames the carve-out as `老板` = the boss address. Project-wide usage is consistently as a direct-address noun. Here, `老板` functions as the grammatical subject of an English predicate ("老板 ratified ..."), which is a syntactic extension of the address rule into a third-person reference. It is in line with how AGENTS.md itself uses the token (L17: "v0.27 boss OOB: …", L20: "老板 8/18 拍", L46: "ratified 2026-08-28 OOB by 老板"), so it's not a deviation — but reviewers who are auditing for CJK-in-code-comments may flag it without context.

**Required action:** None — the token usage matches the established project pattern. Soft warning only, in case the strict-no-CJK-in-Swift-comments rule is later tightened beyond the 老板 carve-out.

---

## S2. SOFT WARNING — `老板` token added in `AGENTS.md` §11.1 ratification header (commit `6e3667cf6`)

**File:** `AGENTS.md`
**Lines added (commit `6e3667cf6`):**
- L46: `- Approved third-party exceptions (ratified 2026-08-28 OOB by 老板 = "all libraries can be introduced immediately"):`
- L65: `- Pending evaluation (= needs demo + 老板拍, no current commitment):`

**Why this is borderline, not a hard violation:**
- `AGENTS.md` is explicitly in `POLLUTION_ALLOWLIST` (per wenshu-pollution-defense skill: "AGENTS.md, CONTEXT.md — rule definition + domain glossary").
- The `老板` token usage follows the project-wide convention (AGENTS.md §7 + §12 + pre-existing L20/L29/L32/L39/L40/L42-L45/L46/L65/L71) — every pre-existing line that mentions 老板 ratified/decreed/拍 a prior decision uses exactly this construction.

**Why it's still worth flagging:** AGENTS.md is also subject to the "English-only" rule at L5 — but L7's `老板` carve-out and the file's own allowlist role resolve the apparent contradiction. No fix required; included so the orchestrator can confirm the precedence was applied.

**Required action:** None.

---

## S3. SOFT WARNING — `AGENTS.md` §11.1 ratifies `老板` / `文枢` / `认可` / `保证` / `信誉` / `兼容` / `库不接受` / `官方` etc. on lines NOT introduced by this commit chain

**File:** `AGENTS.md` L8, L9, L12, L17, L20, L29, L32, L39, L40, L42, L43, L44, L45

**Why this is in scope at all:** The Standards-axis brief asks me to verify "AGENTS.md §11.1 ratification list (commit 6e3667cf6) — banned CJK characters". Commit `6e3667cf6` does not introduce the CJK on L8/L9/L12/L17/L20/L29/L32/L39/L40/L42-L45 — these lines are pre-existing and untouched by the diff (verified via `git show 6e3667cf6 -- AGENTS.md -U3`, context-block at L43-L45 shows `-` removed = pre-existing rule).

**Verdict:** No violation introduced by the review commits; pre-existing CJK in AGENTS.md is covered by the `AGENTS.md` allowlist entry in `POLLUTION_ALLOWLIST`. Not in scope of this review.

**Required action:** None.

---

## S4. SOFT WARNING — `ab5ba62e3` commit body lacks explicit `atomic-coupling justification:` block (style inconsistency)

**File:** Commit `ab5ba62e3` body

**What the project convention is:** Per `.scratch/2026-08-26-fcp-library-replica/spec.md` (L321, L331, L370) + the previous standards-axis reports (`code-review-cp1-standards.md` L67-69, `standards-axis-report-v3.md` L43, `standards-axis-report-v4.md` L46), every multi-file commit in wenshu carries an explicit `**Atomic-coupling justification:**` paragraph naming the spec/section that locks the coupling.

**What `ab5ba62e3` actually says:** "Pre-implementation trace: this commit captures the spec + per-ticket file before the Package.swift fix lands in a follow-up commit (= per Q124 1-commit-1-atomic-change, doc batch separate from code batch; per Q29 spec/ticket never left untracked)." This is **content-equivalent** — it cites Q124 (1-commit-1-atomic-change) and Q29 (spec/ticket never left untracked) — but it does not use the label `atomic-coupling justification:` that the two follow-up commits (`3177d3f48`, `6e3667cf6`) both use verbatim.

**Why it's soft, not hard:** The justification substance is present (Q124 + Q29 cited; the coupling to the Package.swift fix in `3177d3f48` is named via "follow-up commit"). The label inconsistency is the only defect.

**Required action (optional):** Add the `**Atomic-coupling justification:**` label header to the commit body for consistency with the other two commits in the chain. Not blocking.

---

## Cleanliness confirmation (no findings)

The following review-scope items pass cleanly:

1. **All three commit subject prefixes valid:** `docs(wenshu):`, `fix(wenshu):`, `docs(wenshu):` — all match the conventional `<type>(wenshu):` shape used throughout the repo (cf. recent `feat(wenshu): v0.27 tickets 027-34+035`, `feat(wenshu): v0.27 tickets 027-32+033`, `fix(wenshu): v0.27 ticket 027-30`, etc.).
2. **Fix commit `3177d3f48` references finding编号:** subject contains `ticket 01`; body contains `Issue 01` equivalent context (the per-ticket file is referenced via `.scratch/2026-08-28-third-party-integration-fix/issues/01-nuke-ui-spm-conflict-fix.md`).
3. **Fix commit `3177d3f48` and ratify commit `6e3667cf6` both carry `atomic-coupling justification:` blocks.** `ab5ba62e3` carries the equivalent content without the label (see S4).
4. **Package.swift NukeUI architectural reason is explained in code comments** (L33-39: "kean merged NukeUI into Nuke at the 11.0 release in 2022-07-20; the standalone `kean/NukeUI` repo is frozen at Nuke 10.5 line and cannot resolve against `Nuke from: "13.2.0"` — see .scratch/2026-08-28-third-party-integration-fix/issues/01-*.md. Verified via `git ls-remote --tags` 2026-08-28.") and in the product line (L74-75: "NukeUI is a product of the main Nuke repo since Nuke 11.0 (= same row above; see comment on the .package line).").
5. **Package.swift does NOT contain `stevengharris/SplitView` or `Sameesunkaria/OutlineView` references in active code** — verified via `git show 6e3667cf6:Package.swift | grep` (zero hits for both library names).
6. **AGENTS.md §11.1 history mentions of superseded libraries are confined to the `Superseded prior list` block** (L63-64) and the `Pending evaluation` block (L65-67) — exactly the carve-out the brief allows.
7. **The 11 library names (lucide-swift, Defaults, KeyboardShortcuts, Nuke, NukeUI, ZIPFoundation, GRDB.swift, swift-markdown, EventSource, textual, ViewInspector, Inject, SwiftLint, SwiftFormat) appear as identifiers inside backticks and English-only prose** — they are library identifiers, not document body CJK.
8. **`.scratch/2026-08-28-third-party-integration-fix/issues/01-nuke-ui-spm-conflict-fix.md` is fully English-only** — zero CJK hits in the added file (`git show ab5ba62e3:...` shows the full 53-line file).
9. **Commit messages contain no forbidden modal tokens, no [forbidden-vocab] tokens, no `和 FCP 一样` phrase** — verified across all three commit subjects and bodies (modals loop returned zero hits when the CJK content of spec.md is excluded; commit bodies are pure English/Latin).
10. **AGENTS.md §11.1 ratification list does not introduce any new [forbidden-vocab] token** (zero hits in the diff added lines for `[forbidden vocab-1]/[forbidden-2]/[forbidden-3]/[forbidden-4]/[forbidden-5]/[forbidden-6]/[forbidden-7]/[forbidden-8]/[forbidden-9]/[forbidden-10]/[forbidden-11]/[forbidden-12]`).
11. **No Apple HIG regressions introduced:** Package.swift comment additions do not propose any UI changes; the architectural decision (NukeUI = product of Nuke repo since 11.0) is upstream of any view code. The `swift package resolve` / `swift build` exit-0 verification recorded in the fix commit body is the relevant HIG/build-rule check.
12. **`fix(wenshu):` subject correctly references the ticket (finding编号) — `ticket 01`.** Body does NOT use the literal word "finding" but DOES use the heading `finding:` (lowercase, paragraph-style) — slightly different from prior conventions but equivalent in intent.

---

## Summary verdict: **FAIL**

**Reason:** Two hard violations (H1 + H2) in commit `ab5ba62e3`, both introducing CJK characters AND a forbidden modal token (`应该`) into `.scratch/2026-08-28-third-party-integration-fix/spec.md` — a file explicitly named in AGENTS.md L6 as in-scope for the English-only rule, and not covered by any allowlist prefix.

**Path to PASS:**
1. Replace L5 + L7 of `spec.md` with English-only equivalents (H1).
2. Replace the `应该` token in L7 with `认为` or drop the blockquote entirely (H2).
3. (Optional but recommended) Add the `**Atomic-coupling justification:**` label header to `ab5ba62e3` commit body to match the other two commits (S4).
4. (Optional) Amend the commit and `git push` after pre-commit + commit-msg + pre-push hooks pass.

**WARN-level soft items:** S1 (老板 in Package.swift comment), S2 (老板 in AGENTS.md §11.1), S4 (atomic-coupling justification label style) — none blocking, all match established project carve-outs and conventions.

**NOT in Standards-axis scope (deferred to Spec-axis sub-agent):**
- Whether the OOB quotes in spec.md L5/L7 are truly verbatim vs. paraphrased / fabricated.
- Whether the Package.swift pins (Defaults 8.2.0, Nuke 13.2.0, GRDB.swift 7.11.1, swift-markdown 0.4.0, textual 0.5.0, Inject 1.6.0, ViewInspector 0.10.3, KeyboardShortcuts 1.10.0, ZIPFoundation 0.9.20, EventSource 1.5.1) actually resolve per `swift package resolve` (the fix commit body claims exit 0; Spec axis should independently verify).
- Whether the 11-library list matches the spec.md audit table exactly (e.g., does spec.md list 12 libraries because of the old standalone NukeUI row? cross-check).
- Whether the `11 libraries approved` ratification count in commit `6e3667cf6` matches the AGENTS.md §11.1 list exactly (RUNTIME = 9 + DEV/TEST = 3 = 12, not 11; Spec axis should reconcile).
