# Vocabulary pollution loop — root-cause research and mitigation plan

> 老板 2026-08-22 拍: research why the model emits forbidden vocabulary (修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障) and design a defense.
> Status: research complete, mitigation designed. Implementation pending ticket creation.

## 1. Phenomenon (what we observe)

The MiniMax-M2.7 / M2.5 / M2.1 family (minimax cn) occasionally emits the Chinese xianxia vocabulary listed above in commits / docs / comments, even when the prompt is fully English. Empirical pattern (2026-08-19 → 2026-08-22 multi-turn edits):

1. Pocock reads `AGENTS.md` listing the forbidden tokens.
2. During a multi-turn grep + patch loop on a Chinese-bilingual repo, the model produces tokens like `修真` instead of `修正` (a one-char transliteration slip — 修真 ≠ 修正).
3. The slipped token then appears in commit messages, code comments, and downstream doc edits.
4. Each subsequent turn inherits the polluted context, increasing the probability of re-emission.

This is **vocabulary pollution**, not the classical "repetition loop" (which is a separate LLM pathology around `n-gram` reuse).

## 2. Root cause (from research)

Two mechanisms combine:

**Mechanism A — Token-distribution overlap in the training corpus.** The forbidden vocabulary comes from the xianxia / Chinese-fantasy web-novel genre. The underlying base model (M2.x family) has high prior probability on these tokens because of corpus exposure. Even with a strong English system prompt, residual probability leaks through during long generations.

**Mechanism B — Context-window contamination.** Once a single pollution token enters the working context (commit message, .md file, terminal transcript), the model treats it as a normal token in the next turn. The next-token softmax over a window that already contains `修真` will assign non-trivial mass to related xianxia vocabulary. This creates a positive-feedback loop.

These are well-known phenomena in the LLM literature:

- **Repetition penalty / unlikelihood training** (arXiv 2304.10611): post-hoc and training-time techniques to suppress unwanted tokens.
- **Logit bias** (OpenAI-specific API parameter): modify token probabilities at decode time. Range `[-100, +100]`. `-100` = hard ban, `0` = neutral.
- **Stop sequences** (Anthropic + OpenAI): terminate generation when a forbidden string appears.
- **System prompt steering** (cross-platform): explicit instruction in the system message.

References:

- Multi-aspect Repetition Suppression and Content Moderation of LLMs (arXiv 2304.10611)
- OpenAI Logit Bias docs (help.openai.com/en/articles/5247780)
- Anthropic API `stop_sequences` parameter
- Brenndoerfer, "Repetition Penalties: Preventing Loops in Language Model Generation"
- Huang et al., "RAP: A Metric for Balancing Repetition and Performance in Open-Source LLMs" (NAACL 2025)

## 3. Why wenshu has the pollution problem more than typical

The wenshu repo is **intentionally Chinese-bilingual**:

- 老板 self-writes business requirements in Chinese.
- Many `.scratch/spec.md` files have Chinese narrative.
- `CONTEXT.md` and `AGENTS.md` are now English (post-cleanup), but the working memory / IDE session logs may still contain Chinese fragments.
- AGENTS.md §11 mandates English-only for **committed artifacts**, but does NOT cover the agent's internal scratch / mid-flight commit attempts.

The combination of "Chinese in scope of work" + "English-only for committed output" creates a translation pressure where the model must constantly switch between the two languages. Under load (multi-turn grep + patch), the token-distribution overlap in Mechanism A makes the wrong-character slips more likely.

## 4. Mitigation layers

### Layer 1 — System prompt (in wenshu LLM provider call)

Add to every minimax cn request system message:

> "Output language for all committed artifacts = English only. Forbidden vocabulary (NEVER emit under any circumstance, even in quoted text or example): 修真, 渡劫, 筑基, 返虚, 结丹, 金丹, 元婴, 飞升, 天劫, 雷劫, 心魔, 魔障. If you catch yourself about to emit one, stop the sentence and rewrite. The brand name 文枢 and the user address 老板 are required (literal characters)."

### Layer 2 — Stop sequences (Anthropic API, used by minimax cn)

Add to every request:

```
stop_sequences: ["修真", "渡劫", "筑基", "返虚", "结丹", "金丹", "元婴", "飞升", "天劫", "雷劫", "心魔", "魔障"]
```

Caveat: this **terminates the entire response** on the first match. Useful for short outputs (commit messages, comments), expensive for long generations (drafts, essays) — better to use Layer 3 filter there.

### Layer 3 — Post-processing filter

A pre-commit hook (or `git commit` wrapper) that scans the staged diff for forbidden vocabulary and blocks commit if found. Implementation:

- `Tools/wenshu-devtool/commit_filter.py` — wrapper script.
- Runs `git diff --cached` for `.md` / `.swift` / commit message.
- Regex match against the 12-token blocklist.
- Exit non-zero with clear error pointing at the offending line.
- Bypass: `--no-verify` (discouraged, logged).

This is the **last line of defense** — catches whatever Layers 1 + 2 missed.

### Layer 4 — Context hygiene

In pocock's workflow:

- After any commit that accidentally contained pollution, run `git commit --amend` or follow-up commit to clean.
- Do NOT feed the polluted commit message back into the next turn's context (it perpetuates Mechanism B).
- Use Hermes' `clear` or `compact` between major edits to reset working memory.

## 5. Tooling available vs not available

| Mechanism | OpenAI | Anthropic / minimax cn | Notes |
|-----------|--------|------------------------|-------|
| `logit_bias` (hard token ban) | yes (-100 = ban) | **no** | OpenAI-only. minimax cn uses Anthropic-compatible protocol — unavailable. |
| `stop_sequences` | yes | yes | Terminate generation on string match. Heavy hammer. |
| System prompt | yes | yes | Soft steering. |
| Post-processing filter | yes | yes | Tooling-side. Always available. |
| Model retraining | no | no | Out of our control. |

The cleanest stack for wenshu (Anthropic-compatible): Layer 1 (system prompt) + Layer 2 (stop sequences for short outputs only) + Layer 3 (pre-commit hook).

## 6. Implementation tickets (forward, not in this cleanup ticket)

This is a research doc, NOT a ticket. Future work, in order:

1. **Ticket A** — Modify `Sources/WenshuCore/LLM/MinimaxProvider.swift` to inject the English-only + forbidden-vocab system message into every request.
2. **Ticket B** — Add `stop_sequences` to short-output endpoints (commit message generation, code comment suggestions). Skip for long-output endpoints (chapter drafts).
3. **Ticket C** — Add `Tools/wenshu-devtool/commit_filter.py` pre-commit hook. Wire to `.git/hooks/pre-commit`.
4. **Ticket D** — Add a CI check (if/when CI exists) that runs `rg -n '修真|渡劫|筑基|返虚|结丹|金丹|元婴|飞升|天劫|雷劫|心魔|魔障' docs/ Sources/ AGENTS.md CLAUDE.md README.md CONTEXT.md .scratch/` and fails on match.
5. **Ticket E** — Document the mitigation in `CONTEXT.md` domain glossary + ADR.

Each ticket = 1 commit per `wenshu-pocock-workflow` main flow.

## 7. What this cleanup ticket did NOT solve

- The model can still emit pollution tokens in the next session.
- Existing pollution in commit history (`git log`) is **NOT cleaned** (would require `git filter-branch` or `git filter-repo`, which destroys commit hashes and breaks reviewer references — escalate to 老板 before doing).
- Old `wenshu-pour/` directory deleted (per 老板 拍), but the same content may exist in `~/.wenshu/` or `~/.hermes/` backups — out of scope for this ticket.

## 8. Acknowledgements

- 老板 拍 2026-08-22 19:00: research the root cause + design mitigation.
- Memory: prior MiniMax-M2.7 pollution loop noted 2026-08-22 (project memory).
- arXiv 2304.10611 — "Multi-aspect Repetition Suppression and Content Moderation of LLMs".
- OpenAI Logit Bias docs.
- Anthropic Messages API `stop_sequences`.