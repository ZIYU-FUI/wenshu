# Spec Axis Code-Review — Boss 2026-08-26 OOB "po 全链路方法论按新的更新一下"

- **Trigger**: Boss 2026-08-26 OOB literal: "po 大神更新了方法论，发布了几个新技能，把我们的全链路方法论按新的更新一下"
- **Source link**: https://mp.weixin.qq.com/s/-kLdsTkavTrOM_zKcayDbg (extracted to /tmp/wx.html)
- **Reviewer**: Spec axis sub-agent (pocock profile)
- **Axis scope** (per Boss 8/25 protocol): boss OOB spec + UI 全中文 + visual verify claim + methodology/coverage fit with pocock full-chain
- **Baseline**:
  - `~/.hermes/profiles/pocock/AGENTS.md` — full-chain invocation contract
  - `~/.hermes/profiles/pocock/skills/engineering/wenshu-hermes-replica-workflow/SKILL.md` — wenshu replica 6-step recipe
  - `~/.hermes/profiles/pocock/skills/mattpocock/` — 35 mattpocock skills (true source from `mattpocock/skills`)
  - `/Volumes/ANAN/Engineering/wenshu/{AGENTS.md, CLAUDE.md, CONTEXT.md, docs/agents/35-skill-workflow.md}` — wenshu landing docs
- **Article truth**: 5 v1.2.0 new skills = Wait What, Grill Me (multi-round upgrade), Writing for Agents, Wizard, To Questionnaire. (Listed verbatim in article §01/04/05/06/07.)
- **Read-only**: this is a SPEC axis audit. No files were modified.

---

## 1. Boss verbatim intent interpretation

Boss literally said "po 大神更新了方法论，发布了几个新技能，把我们的全链路方法论按新的更新一下". Parsed:

- "po 大神" = Matt Pocock (pocock profile owner). 老板 8/18 拍 "按 PO 全链路方法论执行".
- "更新了方法论" = Pocock released v1.2.0 skill update (true; per article).
- "发布了几个新技能" = 5 new skills (Wait What / Grill Me multi-round / Writing for Agents / Wizard / To Questionnaire).
- "我们的全链路方法论" = the pocock full-chain: `AGENTS.md` §"强制走 po main flow (v0.10+ 老板 8/18 拍, 9/3 SOUL 升级)" + `wenshu-hermes-replica-workflow` 6-step + `35-skill-workflow.md` 10-step main flow.
- "按新的更新一下" = "update per new [release]". Ambiguous between (a) install new skills, (b) upgrade existing skill semantics to v1.2.0, (c) update workflow docs to mention v1.2.0 concepts.

**Most-likely intent (high confidence)**: Boss 8/25 拍 "按 PO 全链路方法论执行" = full-chain is the canonical truth-source. "按新的更新一下" is consistent with **Boss's prior pattern** ("v0.10+ 老板 8/18 拍, 9/3 SOUL 升级" — i.e., the full-chain itself gets versioned). The natural reading is **(b) + (c) combo**: existing equivalents (grill-me → multi-round, wait-what → ASD-STE100 invocation rule, writing-for-agents → 先导词 / 修剪, wizard → template.sh, to-questionnaire → 拷问发送方) should be **re-verified against v1.2.0 semantics** AND **referenced in workflow docs** so the full-chain knows they exist in v1.2.0 form.

Literal install (a) is **not** required: 4 of 5 skills already exist locally (35-skill inventory, see §3). Only Wizard is in a different bucket than the article implies (lives at `engineering/wizard/`, not `misc/wizard/` as boss's task description assumed).

Frontmatter rewrite (d) is **not** what boss asked: 先导词 pattern is a body content lever, not a frontmatter contract. SKILL.md frontmatter has its own rules in `writing-for-agents/SKILL-MECHANICS.md` (referenced, not loaded here).

---

## 2. 4 plausible interpretations (per task spec)

| # | Interpretation | What it changes | Verdict |
|---|----------------|-----------------|---------|
| **a** | Add 5 new skills to pocock profile (literal install) | `~/.hermes/profiles/pocock/skills/` | **N/A** — 4/5 already exist; only wizard needs install (and it's already installed at `engineering/wizard/`). No-op. |
| **b** | Update existing equivalent skills to v1.2.0 semantics | `grill-me` (→ multi-round), `wait-what` (→ ASD-STE100 rule strengthened), `writing-for-agents` (→ already matches), `wizard` (→ already matches), `to-questionnaire` (→ already matches) | **WARN** — most match v1.2.0 already (drift is small). See §3 per-skill audit. |
| **c** | Update workflow docs (`AGENTS.md` / `SOUL.md` / `CLAUDE.md` / `CONTEXT.md` / `wenshu-hermes-replica-workflow`) with v1.2.0 concepts (上下文指针 / 信息层级 / 先导词 / 修剪) | Doc-level only | **FAIL** (per task axes) — `wenshu-hermes-replica-workflow/SKILL.md` is also heavily polluted (see §6) so any rewrite is two problems at once. |
| **d** | Rewrite all SKILL.md frontmatter descriptions to use 先导词 pattern | All 35 mattpocock SKILL.md frontmatter | **NOT what boss asked** — `writing-for-agents` treats 先导词 as a *body content* lever for skill behavior, not frontmatter. Frontmatter rewrite would be wrong scope. |

**SPEC axis decision**: 老板's instruction is **(b) + (c)** — verify existing skills against v1.2.0 + add cross-reference lines to full-chain docs. Action items in §3 + §4.

---

## 3. Per-existing-skill v1.2.0 audit

### 3.1 `mattpocock/productivity/grill-me/SKILL.md` (current = 7 lines)

```yaml
---
name: grill-me
description: A relentless interview to sharpen a plan or design.
disable-model-invocation: true
---
Run a `/grilling` session.
```

**v1.2.0 delta**: single-round → multi-round. New version asks round-1 questions, waits for answers, then re-derives frontier for round 2, etc.

**Current behavior**: `grill-me` is a 1-line wrapper that just invokes `/grilling`. The actual multi-round loop logic lives in **`grilling/SKILL.md`** ("Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled … ask the whole frontier in one round … Then wait for the user's answers before the next round.") — this IS multi-round.

**Verdict**: **PASS** (no functional delta needed). `grill-me` correctly defers to `grilling` which already implements the multi-round frontier algorithm. The 8/25 task description "was single-round, now multi-round" is correct relative to v1.0 of grill-me, but the current installed version IS multi-round via the `grilling` primitive.

**Possible add**: bump frontmatter description from "relentless interview" → "multi-round relentless interview that re-derives the frontier each round" so the 先导词 improvement (the article specifically highlights 先导词 in v1.2.0) sharpens the trigger. **SUGGEST** (defer).

### 3.2 `mattpocock/productivity/wait-what/SKILL.md` (current = 7 lines)

```yaml
---
name: wait-what
description: Stop. That last message did not land — re-pitch it.
disable-model-invocation: true
---
Wait — I don't understand where you've got to here. Re-pitch that: give me a little bit of context, talk in ASD-STE100 Simplified Technical English, and use the ubiquitous language from `CONTEXT.md`.
```

**v1.2.0 delta**: strengthen ASD-STE100 invocation. Article §01 lists three steps: (1) give context, (2) ASD-STE100 STE rewrite, (3) use project's ubiquitous language from `CONTEXT.md`.

**Current behavior**: SKILL.md body already has all 3 steps (give context + ASD-STE100 + `CONTEXT.md` ubiquitous language). Body matches v1.2.0 spec.

**Verdict**: **PASS**. No change needed. Possibly sharpen frontmatter "did not land" with a 先导词 anchor like "Stop. Re-pitch in simplified technical English (ASD-STE100) and use the project's `CONTEXT.md` vocabulary." **SUGGEST** (defer).

### 3.3 `mattpocock/productivity/writing-for-agents/SKILL.md` (current = 81 lines)

**v1.2.0 delta**: explicit 上下文指针 / 信息层级 / 先导词 / 修剪 + 渐进式披露 + 反模式 (否定句).

**Current behavior**: 81-line body already has all 5 levers (上下文指针, 信息层级 with 渐进式披露, 先导词, 修剪, 否定句反模式). Body matches v1.2.0 spec verbatim.

**Verdict**: **PASS**. This skill was already at v1.2.0 maturity when installed. (Note: `writing-for-agents` actually references a `SKILL-MECHANICS.md` that is loaded as a linked file but was not opened in this audit — out of scope.)

### 3.4 `mattpocock/engineering/wizard/SKILL.md` (current = 44 lines) — **NOT in misc/ as task description said**

**v1.2.0 delta**: bash wizard + `template.sh` + 7 library helpers (stage, say/step, open_url, ask/ask_secret, write_env, set_secret/set_var, pause/confirm) + 确认闸门.

**Current behavior**: SKILL.md body covers exactly the v1.2.0 spec — "bash script that walks a human step by step … opens each URL, says exactly what to click and copy, captures the values, writes them where they belong (`.env`, GitHub secrets), confirms at every stage, and shows how many stages are left … `template.sh` (… cross-platform URL opening including WSL, hidden secret entry, idempotent `.env` upserts, `gh secret`/`gh variable` writes, and a closing summary)." `template.sh` exists in `~/.hermes/profiles/pocock/skills/mattpocock/engineering/wizard/template.sh` (39 lines confirmed).

**Verdict**: **PASS**. Skill body matches v1.2.0 spec. Location correction: wizard lives at `engineering/wizard/` (not `misc/wizard/` as the task description stated — that was a documentation mismatch in the boss's task brief, not a real gap).

### 3.5 `mattpocock/productivity/to-questionnaire/SKILL.md` (current = 53 lines)

**v1.2.0 delta**: 拷问发送方 (not 拷问主题) — 2 prerequisite questions (who is it going to + what do you need back) before writing the questionnaire. Document structure: 目的 / 收发双方 / 背景 / 回答说明 / 主题分组 / 最后兜底.

**Current behavior**: SKILL.md body explicitly says "**Grill the send, not the subject.** Interview the user only about the _send_ … who it goes to, and what they need back." Then steps 1 (who) + 2 (what) + 3 (write). Document structure template includes all 6 sections from v1.2.0 spec.

**Verdict**: **PASS**. Body matches v1.2.0 spec.

### 3.6 All 5 v1.2.0 skills inventory cross-check

| Skill | v1.2.0 article spec | Local `mattpocock/.../SKILL.md` body match | Verdict |
|---|---|---|---|
| Wait What | 3 steps: context + ASD-STE100 + ubiquitous language | matches all 3 (L7 body) | PASS |
| Grill Me multi-round | frontier rounds until empty | matches (via `grilling/` L8–22) | PASS |
| Writing for Agents | 上下文指针 + 信息层级 + 先导词 + 修剪 + 反模式 | matches all 5 | PASS |
| Wizard | bash + template.sh + 7 helpers + 确认闸门 | matches all | PASS |
| To Questionnaire | 拷问发送方 + 6-section template | matches all | PASS |

**Net finding**: 5/5 skills are already v1.2.0-aligned in body content. There is **no semantic gap** to close at the SKILL.md body level.

---

## 4. Workflow doc relevance audit

### 4.1 `~/.hermes/profiles/pocock/AGENTS.md`

- §"强制走 po main flow (v0.10+ 老板 8/18 拍, 9/3 SOUL 升级)" lists 6 main steps + 24 skill commands.
- Already mentions `/wait-what`, `/wizard`, `/write-for-agents`, `/to-questionnaire` in the 24-row command table (L60–84).
- **Already v1.2.0-aware at the registration level**.
- Possible improvement: bump command-table "用途" column from generic phrases to the v1.2.0 先导词 phrases (e.g. `/wait-what`: "上一句没落地,重说" → "用 ASD-STE100 重讲"). **SUGGEST** (defer — this is a 先导词 tightening, not a methodology change).

### 4.2 `~/.hermes/profiles/pocock/SOUL.md`

- 2-byte file (effectively empty per `cat` output). No methodology content to update.

### 4.3 `~/.hermes/profiles/pocock/CLAUDE.md`

- Not present locally for pocock profile. (Only the wenshu project has CLAUDE.md.)

### 4.4 `/Volumes/ANAN/Engineering/wenshu/AGENTS.md`

- Hard rule = English-only + 12 forbidden neutral + 12 forbidden 修真 vocab + boss address. v0.07.2 (2026-08-22).
- Methodology-level: §11 + §12 only. No reference to PO skill chain. **No update needed** — boss's request is about *pocock full-chain*, not wenshu project hard rules. (wenshu AGENTS.md is the wenshu truth-source, not the pocock workflow doc.)

### 4.5 `/Volumes/ANAN/Engineering/wenshu/CLAUDE.md`

- §9 explicitly says "English-only rule applies to this file (see `AGENTS.md` top section)". v0.07.2 (2026-08-22).
- Has "§9 Project Baseline Context (pocock must-read first)" — explicit pocock-reader-onboarding block. Should ideally reference v1.2.0 skill set as the canonical pocock methodology. **WARN** — optional, but missing the v1.2.0 reference means a pocock reader landing on wenshu CLAUDE.md gets stale skill contract. (However: this is wenshu repo scope, not pocock profile scope — and boss said "全链路方法论" = pocock's full-chain, not wenshu's CLAUDE.md.)

### 4.6 `/Volumes/ANAN/Engineering/wenshu/CONTEXT.md`

- 170 lines, mostly domain glossary (Zone / Band / Master / Instance / Drag Splitter / Static Divider / Library / Book / Bookshelf / Document / PT / LayoutTokens / 18 修真原 vocab row + many v0.18-v0.23 entries).
- No reference to PO skill chain. v0.18-v0.23 entries focus on wenshu domain, not pocock methodology.
- **No update needed** — wenshu domain glossary, separate concern from pocock full-chain.

### 4.7 `/Volumes/ANAN/Engineering/wenshu/docs/agents/35-skill-workflow.md`

- 140 lines. 35-skill inventory + main-flow 10 steps + phase-boundary 3 + standalone 7 + in-progress 6 + misc 4 + landed status (8/18).
- §3 Standalone 7 lists `grill-me` / `grilling` / `wizard` / `wait-what` / `to-questionnaire` / `writing-for-agents` — **already v1.2.0-aware at the inventory level**.
- §0 Overview says "Layer: Standalone (off-flow) 7 = 老板 explicit invoke" — counts 7, includes the 5 v1.2.0 skills + `prototype` + `research` + `teach` + `handoff` = wait, recount: §3 lists 10 standalone entries but says 7. Off-by-3 in §3 itself (counts `grill-me` + `grilling` + `prototype` + `research` + `wizard` + `wait-what` + `teach` + `to-questionnaire` + `handoff` + `writing-for-agents` = 10; §0 says 7 standalone; §8 says `grill-me / grilling / wait-what / wizard / to-questionnaire / writing-for-agents` await trigger — 6 of the v1.2.0 skills). **WARN** — minor doc drift, not blocking.

### 4.8 `~/.hermes/profiles/pocock/skills/engineering/wenshu-hermes-replica-workflow/SKILL.md` (wenshu 复刻 hermes 工作流)

- 169 lines. Defines 6-step replica recipe + Apple HIG + cross-skill contamination cleanup.
- **NOT v1.2.0-aware** — does not mention 多轮 Grill Me, ASD-STE100 invocation, 先导词 / 修剪 levers, or template.sh wizard paradigm.
- **FAIL** (per task axes): this is the wenshu workflow truth-source, and the boss's "全链路方法论按新的更新一下" applies to this file too. But see §6 — it's also heavily polluted.

---

## 5. SPEC axis verdict per file (boss 8/25 protocol: FAIL = must fix / WARN = boss review / SUGGEST = defer)

| File | Change implied by "按新的更新一下" | Verdict | Reason |
|---|---|---|---|
| `mattpocock/productivity/grill-me/SKILL.md` | Frontmatter 先导词 tightening only | **SUGGEST** (defer) | Body already multi-round via `grilling` primitive |
| `mattpocock/productivity/wait-what/SKILL.md` | Frontmatter 先导词 tightening | **SUGGEST** (defer) | Body already 3-step ASD-STE100 |
| `mattpocock/productivity/writing-for-agents/SKILL.md` | None | **PASS** (no-op) | Already at v1.2.0 maturity |
| `mattpocock/engineering/wizard/SKILL.md` | None | **PASS** (no-op) | Already at v1.2.0 maturity |
| `mattpocock/productivity/to-questionnaire/SKILL.md` | None | **PASS** (no-op) | Already at v1.2.0 maturity |
| `~/.hermes/profiles/pocock/AGENTS.md` | "用途" column 先导词 tightening | **SUGGEST** (defer) | 24-row table already v1.2.0-aware at registration level |
| `~/.hermes/profiles/pocock/SOUL.md` | None | **N/A** | Empty file |
| `/Volumes/ANAN/Engineering/wenshu/AGENTS.md` | None | **N/A** | wenshu project scope, not pocock full-chain |
| `/Volumes/ANAN/Engineering/wenshu/CLAUDE.md` | Optional §9 reference to v1.2.0 | **WARN** (boss review) | Out of pocock full-chain scope per boss's "我们的全链路方法论" |
| `/Volumes/ANAN/Engineering/wenshu/CONTEXT.md` | None | **N/A** | wenshu domain glossary, separate concern |
| `/Volumes/ANAN/Engineering/wenshu/docs/agents/35-skill-workflow.md` | Off-by-3 in §3 standalone count | **WARN** (boss review) | Doc drift, not blocking |
| `~/.hermes/profiles/pocock/skills/engineering/wenshu-hermes-replica-workflow/SKILL.md` | Add 多轮 Grill Me + ASD-STE100 + 先导词/修剪 reference + template.sh wizard paradigm | **FAIL** (must fix) — **blocked by §6 pollution** | This is the only FAIL file in scope, but the pollution blocks any clean rewrite |

**Aggregate verdict**: only **1 FAIL** (workflow doc) + **2 WARN** (wenshu CLAUDE.md + 35-skill doc) + **3 SUGGEST** (frontmatter 先导词 tightening). The 5 SKILL.md files themselves are **already v1.2.0-aligned** (5/5 PASS).

---

## 6. Cross-skill contamination finding (boss 8/13 protocol — extends the pollution-defense concern)

`~/.hermes/profiles/pocock/skills/engineering/wenshu-hermes-replica-workflow/SKILL.md` (169 lines) contains **28+ hits of `修真因`** (= the LLM-slip chain "修真" + "因"). Examples:

- L66: `## 修真因前 0 hits 检查 (Q28 强化)`
- L75: `- 修真因 commit 后必须 re-run 双轴`
- L83: `每个 ticket: 修真因 commit → build → 启动 binary`
- L87: `## 修真因最小影响原则 (老板 8/26 OOB flash-back rule...)`
- L89: `修真因时**禁止**策划范围比老板要求更大`
- L105: `修真因 修真因 金标准: **用最少的代码改动实现老板拍的 修真因**`
- L114: `**修真因 reference**: v0.25 v0.25.1 wenshu icon migration 修真因 keep-do`

This file is **not in the wenshu project's pollution allowlist** (`Tools/wenshu-devtool/commit_filter.py` allowlist) — the allowlist is for files in the wenshu repo (`AGENTS.md` / `CONTEXT.md` / `commit_filter.py` / test fixtures), NOT for `~/.hermes/profiles/pocock/skills/`. Per AGENTS.md §12 + `wenshu-pollution-defense/SKILL.md`, the 12 forbidden tokens are banned in **all committed artifacts**, and the skill lives outside the repo so it's not under the wenshu hooks' jurisdiction — but the **same 修真因 LLM-slip mechanism applies**.

**Critical**: any rewrite of this file per §5 FAIL must first purge 修真因 contamination, otherwise the v1.2.0 update will just stack more 修真因 on top. This is the kind of double-touch that boss 8/13 noted as the risk of cross-skill contamination cleanup.

**Proposed fix sequence**:
1. Replace 修真因 → 修复 / 修改 / 改 / fix in this SKILL.md (mechanical find-replace).
2. Then add v1.2.0 concepts (per §5 FAIL).
3. Re-run `python3 Tools/wenshu-devtool/pollution_watchdog.py` after editing.

But note: this file lives at `~/.hermes/profiles/pocock/skills/engineering/wenshu-hermes-replica-workflow/SKILL.md` which is **outside the wenshu repo**, so the watchdog won't scan it by default. The cleanup must be **manual + manually verified**.

---

## 7. Cross-skill contamination cleanup (boss 8/13 follow-up)

Boss 8/13 noted that 18 skill installs "contaminate" aif / cc-runner / my-pm / designer / reviewer profiles. Today's audit found that the contamination includes **`修真因` token bleed into the wenshu workflow doc** (28+ hits in `wenshu-hermes-replica-workflow/SKILL.md`).

For the SPEC axis audit on this turn: the **scope is boss's "按新的更新一下"**, not the historical contamination cleanup. Boss 8/13 cleanup is a **separate task** (likely WARN-deferred).

**Recommendation**: keep today's scope narrow (only update 修真因 contamination as a prerequisite to §5 FAIL fix). Do not bundle boss-8/13 cleanup into this turn.

---

## 8. Required decisions to grill boss before starting work

Boss's instruction is ambiguous in 3 places. SPEC axis needs boss to clarify before any FAIL fix lands:

1. **(b) vs (c) scope**: is "全链路方法论" = the **pocock `AGENTS.md` + wenshu replica workflow** (in scope) OR also wenshu repo's `CLAUDE.md` + `35-skill-workflow.md` + `CONTEXT.md` (which are wenshu project, not pocock)?
   - Recommendation: limit to pocock-profile scope (per "我们的" = ours = pocock's full-chain).
2. **先导词 frontmatter rewrite (SUGGEST items)**: tighten the 24 command-table "用途" + 5 SKILL.md frontmatter to 先导词 pattern? Or defer?
   - Recommendation: defer (SUGGEST items can wait until boss has time to review frontmatter rewrite as separate ticket).
3. **修真因 pollution cleanup**: fix 修真因污染 in `wenshu-hermes-replica-workflow/SKILL.md` as part of this turn, or queue as separate boss-8/13 follow-up?
   - Recommendation: bundle it (it's a hard prerequisite to §5 FAIL fix anyway).

---

## 9. 1-line summary for boss

**SPEC axis verdict**: 5/5 v1.2.0 skills already installed + aligned in body content; 1 FAIL on `wenshu-hermes-replica-workflow/SKILL.md` (also has 28+ hits of 修真因 pollution that must purge first); 2 WARN + 3 SUGGEST. Boss needs to clarify scope (pocock only vs also wenshu repo) + 先导词 tightening timing + pollution cleanup bundling before FAIL fix lands.

---

*SPEC axis report · 2026-08-26 · pocock profile · read-only audit · no files modified*
