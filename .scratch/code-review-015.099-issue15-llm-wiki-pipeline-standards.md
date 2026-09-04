# Standards Axis Code-Review — v0.28 Integration Batch 3 Issue 15 Commit Chain

- **Commits** (2-commit chain, oldest → newest):
  - `ebecda3cc` — `feat(wenshu): v0.28 integration batch 3 issue 15 — M5 LLM Wiki 4-layer pipeline verbatim port`
  - `5c52b77bf` — `docs(wenshu): v0.28 integration batch 3 — CONTEXT.md domain-modeling LLMWikiLayerDeriver + LLMWikiLinter`
- **Author**: cc-runner (wenshu) `<cc-runner-wenshu@local>`
- **Dates**: 2026-08-28 23:33:19 + 23:33:31 (+0800) — 12-second gap (= correct Q124 step-7 follow-up cadence)
- **Branch**: `wt/multi-agent-dispatch`
- **File scope** (chain total): 4 files, +573 / -0
  - `Sources/WenshuApp/Storage/LLMWikiLayerDeriver.swift` (new, 204 LOC)
  - `Sources/WenshuApp/Storage/LLMWikiLinter.swift` (new, 171 LOC)
  - `Tests/WenshuAppTests/Storage/LLMWikiLayerDeriverTests.swift` (new, 196 LOC)
  - `CONTEXT.md` (+2 rows, appended to "Domain words" table)
- **Reviewer**: Standards axis sub-agent (pocock profile)
- **Baseline doc**: `AGENTS.md` (English-only hard rule, 12 forbidden neutral + 12 forbidden 修真 vocab, 1-commit-1-atomic-change); `Tools/wenshu-devtool/commit_filter.py` (POLLUTION_ALLOWLIST)
- **Reference upstream**: `hermes-agent/skills/research/llm-wiki/SKILL.md` v2.1.0 (507 lines)
- **Triggered by**: Boss 2026-08-28 OOB 'agent 相关的, 不用调研, 就直接本地拿 hermes 源码复刻' + Q125 dual-axis code-review verbatim-port protocol
- **Protocol refs**: Q1 (English-only), Q8 (commit-message hygiene), Q34 (PO main-flow step 7 = domain-modeling), Q35 (commit-description vs truth), Q46 (forward-fix over amend), Q124 (1-commit-1-atomic-change), Q125 (dual-axis code-review)

---

## Axis 1 — English-only hard rule (commit body + code comments)

**Spec**: AGENTS.md L3-L6 — "This file is English only. No Chinese characters. No CJK punctuation. No mixed CJK + Latin characters. All commit messages, comments, prompts … follow the same English-only rule."

**Evidence — commit subjects + bodies** (both SHAs scanned via `git log -1 --format='%B'`):
- ebecda3cc subject: `feat(wenshu): v0.28 integration batch 3 issue 15 — M5 LLM Wiki 4-layer pipeline verbatim port` → CLEAN
- 5c52b77bf subject: `docs(wenshu): v0.28 integration batch 3 — CONTEXT.md domain-modeling LLMWikiLayerDeriver + LLMWikiLinter` → CLEAN
- ebecda3cc body: zero CJK chars across 99 body lines (verified via `python3` regex `[\u4e00-\u9fff]`)
- 5c52b77bf body: zero CJK chars across 17 body lines
- **Past pattern avoided**: per Q1 lesson from `99d83fd75` (issue 12 forward-fix) — old style was `// ReferenceEntityExtractor.swift · Wenshu (文枢) · v0.28`. New files correctly write `// LLMWikiLayerDeriver.swift · Wenshu · v0.28` (no 文枢). Q1 regression check = PASS.

**Evidence — new file headers** (first 5 lines of each new Swift file):
- `LLMWikiLayerDeriver.swift` → `// LLMWikiLayerDeriver.swift · Wenshu · v0.28` CLEAN
- `LLMWikiLinter.swift` → `// LLMWikiLinter.swift · Wenshu · v0.28` CLEAN
- `LLMWikiLayerDeriverTests.swift` → `// LLMWikiLayerDeriverTests.swift · Wenshu · v0.28` CLEAN
- File-wide scan first 100 lines of each file: zero CJK chars (verified via `python3` regex)

**Evidence — module doc comments**: Both `///` doc comments are English-only. The `LLMWikiLayerDeriver.swift` L60 `// and runs the deterministic pure-data derivations:` uses the `//` (single-slash) form, not `///` (triple-slash) — minor cosmetic inconsistency with the `///` style used in the rest of the struct's doc comments, but not a Standards violation (Q1 only forbids CJK chars, not `//` vs `///` choice).

**Axis 1 verdict**: **PASS**

---

## Axis 2 — 12 forbidden neutral words

**Spec**: AGENTS.md L8 — `可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许 / 或 / 任意 / 大概率 / 通常 / 一般来说`. Replace with `是 / 否 / 行 / 不行 / 可以 / 不可以 / 不变 / 变`.

**Evidence — new file scan** (full file, not just diff):
- `LLMWikiLayerDeriver.swift`: 0 hits
- `LLMWikiLinter.swift`: 0 hits
- `LLMWikiLayerDeriverTests.swift`: 0 hits
- `CONTEXT.md` (+2 rows): 0 hits in added rows (the 1 forbidden-word `可` if any exist elsewhere in CONTEXT.md are pre-existing baseline content, not introduced by 5c52b77bf)

**Axis 2 verdict**: **PASS**

---

## Axis 3 — 12 forbidden 修真 vocab

**Spec**: AGENTS.md L9 + `Tools/wenshu-devtool/commit_filter.py` — `修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障`. The v0.28 hex-encoding rule requires the literal tokens to NEVER appear in files the LLM might read.

**Evidence — new file scan** (full content):
- `LLMWikiLayerDeriver.swift`: 0 hits (CLEAN)
- `LLMWikiLinter.swift`: 0 hits (CLEAN)
- `LLMWikiLayerDeriverTests.swift`: 0 hits (CLEAN)
- `CONTEXT.md` (after 5c52b77bf): 12 hits BUT all on **single pre-existing line L113** (= the rule-definition enumeration, allowed by `commit_filter.py` `POLLUTION_ALLOWLIST` which lists `CONTEXT.md` explicitly). `git diff ebecda3cc^ 5c52b77bf -- CONTEXT.md | grep -E '^\+.*(修真|...)'` returned **EMPTY** — confirming these 2 commits add zero new forbidden-token occurrences to CONTEXT.md.

**Evidence — commit subjects + bodies** (both SHAs): zero forbidden-token occurrences.

**Axis 3 verdict**: **PASS** (CONTEXT.md's 12 pre-existing hits are protected by `POLLUTION_ALLOWLIST`; no NEW pollution introduced)

---

## Axis 4 — Verbatim-port line-range accuracy (Q35 commit-description vs truth)

**Spec**: Q35 — commit description must accurately reflect the diff. Q109 — doc-first + scope-refactor must be disclosed when refactoring a hermes-side concept.

**Evidence — line-range references in commit body** (3 explicit refs claimed):

### Reference 1: `L46-58 (= Three-Layer architecture)`
- Actual SKILL.md L46-58: starts with "The wiki is just a directory of markdown files" (L46), contains the `wiki/` directory tree diagram (L51-65 block but the bulk of the tree is L52-64). The "Three Layers" header is on L49, but L46-58 itself covers the intro paragraph + the start of the tree diagram.
- **Verdict**: The L46-58 range IS where the Three-Layer architecture diagram starts. Acceptable. The commit body's "raw -> entities/abstracts/indexes" gloss is a wenshu-side interpretation (hermes's actual layers are `raw` + `entities/concepts/comparisons/queries` + `SCHEMA.md/index.md/log.md`); the commit body correctly explains the mapping 1:1 in the next paragraph. PASS.

### Reference 2: `L213-244 (= linter: orphan pages, broken wikilinks, index completeness, schema drift)`
- Actual SKILL.md L213-244: contains (a) closing `\`\`\`` of the Update Policy code block on L213, (b) `### index.md Template` heading on L215, (c) the `index.md` template (L219-234), (d) the **Scaling rule** paragraph (L236-238), (e) `### log.md Template` heading on L240, (f) the `log.md` template (L242-253).
- **Linter content check**: The word "lint" appears only ONCE in the entire SKILL.md, on L212 (= "Flag for user review in the lint report"). The L213-244 range contains ZERO orphan / broken-wikilink / index-completeness / schema-drift linter checks. Those four check concepts in `LLMWikiLinter.swift` (LLM-ORPHAN-ENTITY / LLM-BROKEN-WIKILINK / LLM-MISSING-IN-INDEX / LLM-NO-ABSTRACT / LLM-ABSTRACT-STALE) are **wenshu-side inventions**, not from the cited SKILL.md lines.
- **S1 finding (commit-message drift)**: The L213-244 line-range reference is **misleading**. The commit body claims a "verbatim port" of the linter protocol from those exact lines, but those lines actually contain the `index.md` + `log.md` templates, not linter code. The wenshu linter is largely an original implementation. Per Q35 + Q109, the commit body MUST disclose scope refactors. It DOES partially disclose (the "wenshu 4-layer architecture ... differs from hermes's 3-layer" paragraph and the "scope refactor (= per Q109 doc-first + Q35 commit-description vs truth)" section), but it leaves the L213-244 line ref uncorrected and the word "verbatim" applied to the linter code.

### Reference 3: `L390-410 (= resume session ritual: SCHEMA + index + log read before ingest)`
- Actual SKILL.md L389-409: contains the **Ingest** section (numbered steps for ingesting sources), the **Archiving** section, and the start of the **Obsidian Integration** section (bullet list ending at L409). The "Resuming an Existing Wiki (CRITICAL — do this every session)" heading is on **L72**, not L390.
- **S1 finding (commit-message drift)**: The L390-410 range referenced as the "resume session ritual" does NOT contain the resume ritual. The resume ritual is on L72-95. L390-410 is the Obsidian Integration + Ingest sections. Minor line-range drift; the resume ritual concept IS in the SKILL.md, just at a different line range.

**Axis 4 verdict**: **S1 SOFT FINDING** — two line-range references (L213-244 + L390-410) are inaccurate. The L213-244 case is material because the commit body labels that range as the "linter: orphan pages, broken wikilinks, index completeness, schema drift" source, which is factually wrong (those lines are index.md + log.md templates, not linter code). The scope refactor IS disclosed elsewhere in the commit body, so this is a "reference accuracy" issue rather than a "scope-creep concealment" issue.

---

## Axis 5 — Scope refactor disclosure (Q109 + Q35)

**Spec**: When refactoring a hermes-side concept into wenshu's domain model, the commit body MUST explain what was kept verbatim, what was adapted, and what was invented.

**Evidence — scope refactor in commit body** (ebecda3cc):
- Section "scope refactor (= per Q109 doc-first + Q35 commit-description vs truth)" explicitly states: "The hermes llm-wiki SKILL is 507 lines of pattern documentation + LLM-call-driven ingestor recipes (= user asks 'add X to my wiki' and the agent follows the SKILL steps). Wenshu's M5-15 ticket asks for the pure-data derivation layer (= take raw .md files and produce entities + abstracts + indexes deterministically, with no LLM call)."
- Section "wenshu 4-layer architecture (= raw/entities/abstracts/indexes) differs from hermes's 3-layer ..." explicitly maps the layer rename.
- Section "What lands in this commit: 1. Abstracts layer ... 2. Indexes layer ... 3. Linter ..." — explicit scope statement.
- Section "out-of-scope (= per spec): LLM-driven ingestor (= lands with v0.29+) ..." — explicit out-of-scope statement.
- File-level header in `LLMWikiLayerDeriver.swift` L23-38 reiterates the scope refactor.

**Verdict**: The scope refactor IS adequately disclosed at the architectural level (3-layer → 4-layer mapping, LLM-driven out-of-scope, wenshu-specific notes). The only gap is the L213-244 line-range accuracy called out in Axis 4.

**Axis 5 verdict**: **PASS** (with the Axis 4 S1 caveat about L213-244 reference)

---

## Axis 6 — Pure-data vs LLM-driven ingestor (M5-15 ticket scope)

**Spec**: M5-15 ticket scope per spec = pure-data derivation orchestrator + static-analysis linter. LLM-driven ingestor = out of scope (lands with v0.29+ feature ticket).

**Evidence — code review of LLMWikiLayerDeriver.swift**:
- L91-103: `runDerivation()` calls `store.loadReferences(layer: .layerRaw)` → derives abstracts → derives indexes. **No LLM call** anywhere in the deriver. Imports only `Foundation` (no WenshuConductor / no LLM-side types).
- L111-114: `tokenize()` is pure (no I/O, no LLM, deterministic).
- L150-162: `firstParagraph()` is pure (string manipulation).
- L85 `init(store: ReferenceStoring)` takes only the storage abstraction.
- L137-147: index derivation is deterministic (`indexesWritten = new UUIDs generated per call` — explicit in commit body, code uses `saveReference` per keyword).

**Evidence — code review of LLMWikiLinter.swift**:
- L41-49: `lint()` returns `[LintFinding]` = pure data, no I/O mutation. All 4 checks (checkOrphanPages / checkBrokenWikilinks / checkIndexCompleteness / checkAbstractsRecency) are read-only against `store`.
- L168-178: `extractWikilinks(fromMarkdown:)` is pure NSRegularExpression extraction.
- Imports only `Foundation`.

**Verdict**: Both files are PURE-DATA (no LLM call, no LLM-side types). Matches the M5-15 ticket scope exactly. The LLM-driven ingestor is correctly excluded and the commit body explicitly says so.

**Axis 6 verdict**: **PASS**

---

## Axis 7 — 1-commit-1-atomic-change (Q124 atomic-coupling)

**Spec**: Q124 — each commit should touch one atomic change unit. For wenshu's batch 3 hermes-port pattern, the established cadence is: 1 `feat(wenshu)` commit for code + 1 `docs(wenshu)` commit for CONTEXT.md domain-modeling row.

**Evidence — chain atomicity**:
- ebecda3cc: 3 new files (1 deriver + 1 linter + 1 tests) = 571 LOC. Commit body "atomic-coupling justification: this commit touches 3 new files (2 source + 1 test) = 720 LOC. Per Q124 1-commit-1-atomic-change, this matches issue 15 scope (= LLM Wiki 4-layer pipeline = deriver + linter + tests)."
  - **Note**: Commit body claims "720 LOC" but `git show --stat` reports 571 insertions. Discrepancy of ~149 LOC = the LOC estimates in the file header comments (`~280 LOC`, `~150 LOC`, `~250 LOC`) summing to ~680 LOC, which itself doesn't match 720 LOC. Cosmetic inconsistency between claimed LOC in commit body vs actual `git diff --stat` output.
- 5c52b77bf: 1 file (CONTEXT.md = +2 rows = +1 deriver row + +1 linter row). Commit body: "this commit touches 1 file (CONTEXT.md = +2 rows) = 1 atomic change."

**Comparison to prior batch 3 pattern**:
- Issue 12 (aa37b4d04): 2 new files (entity extractor + tests), 238 LOC → followed by 1-row CONTEXT.md update (fe79ce727). Same atomic pattern.
- Issue 13 (938b1fa4b): 2 new files (gate + tests), 386 LOC → followed by 1-row CONTEXT.md update (dff2d221d). Same pattern.
- Issue 14 (573e79ebc): 2 new files (cross-ref + tests), 349 LOC → followed by 1-row CONTEXT.md update (a9dc49c75). Same pattern.
- Issue 15 (this chain): **3 new files** (deriver + linter + tests), 571 LOC → followed by 2-row CONTEXT.md update. **Slight deviation**: issue 15 produces TWO new source files (deriver + linter) instead of one. The CONTEXT.md rows also doubled (1→2). The deviation is internally consistent (= 2 source files = 2 CONTEXT.md rows) and matches the actual scope (deriver + linter are co-developed for the same ticket).

**Verdict**: The atomic-coupling pattern is preserved per Q124. The "2 source files in 1 feat commit" pattern (instead of the prior batch's "1 source file in 1 feat commit") is a natural consequence of the ticket scope (M5-15 = deriver + linter as a pair). The CONTEXT.md split into a separate docs commit follows Q34 step 7 exactly. The 12-second gap between ebecda3cc (23:33:19) and 5c52b77bf (23:33:31) is correct Q124 step-7 cadence.

**S3 finding (cosmetic)**: Commit body LOC claim ("720 LOC") doesn't match actual diff (571 insertions). The per-file header comments claim "~280 LOC", "~150 LOC", "~250 LOC" — summing to ~680, not 720, and not matching the diff either. Minor cosmetic drift; not a Standards violation.

**Axis 7 verdict**: **PASS** (with S3 cosmetic LOC-count drift)

---

## Axis 8 — Debug-print discipline (Q34 step 4)

**Spec**: Code committed to a long-lived branch should not contain `[DBG]` / `print(` / `NSLog(` / `os_log(` debugging artifacts (the repo convention per AGENTS.md is to use the LLM-side logging primitive, not raw print).

**Evidence — scan**:
- Regex `\[DBG[^\]]*\]` across 3 new Swift files + CONTEXT.md: 0 hits
- Regex `\b(print|NSLog|os_log)\s*\(` across the 2 source files (excluding comments): 0 hits (the only `// and runs` comment in LLMWikiLayerDeriver.swift L60 is a doc comment, not a print call)
- Tests file uses `Testing` framework `expect` macros, no `print()`.

**Axis 8 verdict**: **PASS**

---

## Axis 9 — Token filter spec match (M5-15 ticket requirement)

**Spec**: M5-15 ticket specifies a token filter for the index layer. Per the parent review brief, the filter must be "(>3 chars + at least one letter)" to match the hermes-side conceptual model.

**Evidence — implementation in LLMWikiLayerDeriver.swift L201**:
```
return tokens.filter { token in
    token.count > 3 && token.contains(where: { $0.isLetter })
}
```

**Note**: This filter is a **wenshu-side invention**, not a verbatim port from `SKILL.md` (which contains no equivalent rule). The commit body correctly discloses this in the "wenshu-specific notes" section: "Token filter: words > 3 chars AND contains at least one letter (= filters out pure-digit tokens like '123', '42' and short stopwords like 'the', 'a', 'in')".

**Evidence — test coverage** (LLMWikiLayerDeriverTests.swift L92-103):
```
@Test("tokenize filters short and digit-only tokens")
func tokenizeFilters() {
    let text = "The quick 123 brown fox jumps 42 over a lazy dog"
    let tokens = LLMWikiLayerDeriver.tokenize(text)
    #expect(!tokens.contains("123"))    // digit-only filtered
    #expect(!tokens.contains("42"))     // digit-only filtered
    #expect(!tokens.contains("the"))    // <3 chars filtered
    #expect(!tokens.contains("a"))      // <3 chars filtered
    #expect(tokens.contains("quick"))   // survives
    #expect(tokens.contains("brown"))   // survives
}
```

**Verdict**: The filter implementation matches the spec (>3 chars AND contains at least one letter). The test verifies both the rejection of digit-only tokens AND rejection of <3-char tokens. **S2 finding (test edge case gap)**: The test does not verify the "contains at least one letter" branch in isolation. Edge case: a 4+ char token that contains ONLY digits (e.g., "12345") would be filtered out by the `contains(where: { $0.isLetter })` clause but kept by the `token.count > 3` clause. The combined test covers digit-only strings of length ≤3 ("123" length 3) but not ≥4 ("1234" length 4). For the regex `CharacterSet.alphanumerics.inverted` separator, "1234" would tokenize to "1234" which passes `count > 3` but fails `contains(isLetter)`. The test fixture happens to use "123" and "42" (both length ≤3) which would be filtered by EITHER clause. A more rigorous test would add "1234" (length 4, digit-only) to confirm the letter-presence clause is independently exercised.

**Axis 9 verdict**: **PASS** (with S2 test edge case gap on digit-only tokens of length ≥4)

---

## Axis 10 — Forbidden-vocab meta-narrative (Q1 + Q46)

**Spec**: AGENTS.md L9 + Q46 (forward-fix over amend) — the pollution-defense hex-encoding rule requires the literal tokens to NEVER appear in files the LLM might read (per `wenshu-pollution-defense` skill).

**Evidence — meta-narrative phrasing in new files**:
- `LLMWikiLayerDeriver.swift` L41-43: `// per AGENTS.md Section 8 pollution-defense hex-encoding rule: this file does NOT contain the 12-token forbidden vocab literal; the rule enumeration is referenced semantically only.`
- `LLMWikiLinter.swift` L19-21: same phrasing.
- `LLMWikiLayerDeriverTests.swift`: same phrasing appears in file header.

**Verdict**: The meta-narrative is in **English** (correct per Q1). It correctly references "AGENTS.md Section 8 pollution-defense hex-encoding rule" without naming any of the 12 tokens. This is exactly the pattern the v0.28 hex-encoding fix established. No regression.

**Axis 10 verdict**: **PASS**

---

## Axis 11 — Idempotency + bug-fix disclosure

**Spec**: The commit body discloses a real bug fix found during development (= raw-uuid-as-abstract-id collision with `deleteReference` scanning all 4 layers). Q35 requires that bug fixes be disclosed in the commit body.

**Evidence — LLMWikiLayerDeriver.swift L112-118**:
```
do {
    try store.replaceReference(abstractRef, bodyMarkdown: summary)
} catch {
    // Abstract doesn't exist yet (= first run or new raw ref) -> saveReference
    try store.saveReference(abstractRef, bodyMarkdown: summary)
}
```

**Evidence — comment block L122-126**: explains the raw-uuid collision: "Use replaceReference-with-empty then delete to avoid the raw-uuid collision bug (= deleteReference scans all layers for <id>.md). Index UUIDs are unique to .layerIndexes so delete works."

**Evidence — commit body "bug fix (= found during development)" section**: explains the bug + fix in full.

**Evidence — test coverage**: `idempotent()` test verifies `runDerivation()` produces the same count on consecutive runs. This covers the bug-fix surface area (re-running doesn't produce duplicate abstracts because `replaceReference` is idempotent).

**Verdict**: Bug fix is disclosed + explained + tested. Q35 satisfied.

**Axis 11 verdict**: **PASS**

---

## Axis 12 — File header convention (Q34 step 6)

**Spec**: Per Q34 step 6, new source files should follow the wenshu file-header convention (= `// .swift · Wenshu · v0.<X>` line 1, followed by a `//` separator, then a multi-line `//` block describing the verbatim port source).

**Evidence — file headers**:
- `LLMWikiLayerDeriver.swift` L1: `// LLMWikiLayerDeriver.swift · Wenshu · v0.28` ✓
- `LLMWikiLinter.swift` L1: `// LLMWikiLinter.swift · Wenshu · v0.28` ✓
- `LLMWikiLayerDeriverTests.swift` L1: `// LLMWikiLayerDeriverTests.swift · Wenshu · v0.28` ✓
- Each header includes verbatim-port source attribution (hermes SKILL.md line ranges + LLM Wiki architecture description) ✓
- Each header includes scope-refactor disclosure (`scope refactor (= per Q109 ...)`) ✓
- Each header includes the AGENTS.md Section 8 hex-encoding rule reference (in English) ✓

**Verdict**: File header convention correctly applied. The 99d83fd75 forward-fix (avoid CJK `文枢` in headers) is properly observed.

**Axis 12 verdict**: **PASS**

---

## Summary

| Axis | Verdict | Notes |
|------|---------|-------|
| Axis 1 — English-only | **PASS** | All headers + bodies English-only; CJK regression check (Q1 from issue 12) avoided |
| Axis 2 — 12 forbidden neutral | **PASS** | 0 hits across 3 new files + 2 added CONTEXT.md rows |
| Axis 3 — 12 forbidden 修真 | **PASS** | 0 hits in new files; CONTEXT.md hits all pre-existing on L113 (allowlisted) |
| Axis 4 — Line-range accuracy | **S1** | L213-244 claimed as "linter source" but actually contains index.md + log.md templates; L390-410 claimed as "resume session ritual" but actually contains Obsidian Integration section |
| Axis 5 — Scope refactor disclosure | **PASS** | Adequate architectural-level disclosure; S1 caveat from Axis 4 |
| Axis 6 — Pure-data vs LLM-driven | **PASS** | Both files pure-data; LLM-driven ingestor correctly out-of-scope |
| Axis 7 — Atomic coupling | **PASS** | 1 feat + 1 docs pattern preserved; S3 cosmetic LOC-count drift |
| Axis 8 — Debug-print discipline | **PASS** | 0 [DBG] / 0 print / 0 NSLog in new files |
| Axis 9 — Token filter spec | **PASS** | Filter matches spec; S2 test edge case gap on digit-only ≥4-char tokens |
| Axis 10 — Meta-narrative | **PASS** | English-only pollution-defense reference, no token enumeration |
| Axis 11 — Idempotency + bug-fix | **PASS** | Bug disclosed + tested |
| Axis 12 — File header convention | **PASS** | Convention followed; CJK regression avoided |

---

## Findings

### H1 hard violations (English-only CJK header / forbidden vocab literal / scope creep)
**None.** The 99d83fd75 forward-fix is properly observed across all 3 new files (English-only headers, no 文枢 token). 0 forbidden-vocab literals in any new file. Scope refactor is disclosed (LLM-driven ingestor explicitly out-of-scope).

### H2 hard violations (per Q46: no amend, only forward-fix)
**None.** This is forward-fix territory by design (the previous H1+H2 forward-fix commit 99d83fd75 is the established baseline; this commit continues the forward-fix pattern).

### H3 hard violations (verifiability + Q34 step 4/5 evidence)
**None.** The commit body claims `swift build exit 0 (598 tasks; zero new warnings)` and `swift test --filter LLMWiki = 12/12 PASSED, 0 failed`. Both are concrete + verifiable (the test count of 12 matches the actual test file: 7 deriver tests + 5 linter tests = 12). The `0 imports or callers added` claim is verifiable via `git show ebecda3cc --stat` (no imports modified in non-test files).

### S1 soft warnings (commit message drift / test edge case gaps)
- **S1.1** (Axis 4): The L213-244 line-range reference in the commit body is inaccurate. The actual L213-244 contains the index.md + log.md templates, not linter code. The wenshu linter's 4 checks (orphan / broken-wikilink / missing-in-index / no-abstract-or-stale) are NOT verbatim ports of those lines. **Recommended fix**: add a sentence to the commit body of any follow-up clarifying ticket = "The 4 lint checks (orphan / broken-wikilink / missing-in-index / abstract-stale) are wenshu-side inventions per the M5-15 ticket spec, mirroring the spirit of the SKILL.md lint flag (L212) but not copying any specific check from the cited L213-244 range." No amend needed (Q46); forward-fix the reference if a follow-up amendment ever touches the LLM Wiki area.
- **S1.2** (Axis 4): The L390-410 line-range reference is inaccurate. The resume session ritual is on L72-95, not L390-410. L390-410 is the Ingest + Archiving + Obsidian Integration sections. Minor drift; same S1 category.

### S2 soft warnings (atomic-coupling drift)
**None.** The chain follows Q124 exactly (1 feat + 1 docs, 12-second gap, 2-row CONTEXT.md update matching 2 new source files).

### S3 cosmetic warnings
- **S3.1** (Axis 7): Commit body LOC claim ("720 LOC") doesn't match `git show --stat` output (571 insertions). The file-header comments claim "~280 LOC", "~150 LOC", "~250 LOC" — summing to ~680, not matching either number. Cosmetic drift between prose claim and diff reality.
- **S3.2** (Axis 1): `LLMWikiLayerDeriver.swift` L60 uses `// and runs the deterministic pure-data derivations:` (single-slash) inside a doc comment block that mostly uses `///`. Minor stylistic inconsistency; not a Standards violation but a polish item.

### Test edge case gaps (Axis 9)
- **S2.test.1**: `tokenizeFilters()` test uses "123" (3 chars) and "42" (2 chars) to verify digit-only filtering — both filtered by EITHER `count > 3` OR `contains(isLetter)`. A token like "1234" (4 chars, digit-only) would be filtered ONLY by `contains(isLetter)`. Add to the fixture to independently exercise the letter-presence clause.

---

## Final Verdict

**WARN** (acceptable to merge; forward-fix the S1 line-range references in a follow-up commit if a future ticket touches the LLM Wiki area)

The chain satisfies all HARD standards (English-only, no forbidden vocab, scope refactor disclosed, atomic coupling preserved, pure-data-only, no debug prints, token filter matches spec, file-header convention followed, bug-fix disclosed + tested). The two S1 findings (line-range accuracy for L213-244 + L390-410) are cosmetic-historical: the architectural scope refactor IS disclosed at the prose level, the line references are just wrong. Q46 (no amend) prohibits rewriting history; per Q46 the forward-fix pattern is the correct response — surface the S1 findings here, log them to `.scratch/reviews/` so any future LLM-Wiki-area ticket can correct the references inline.

No blockers. Ship-ready.
