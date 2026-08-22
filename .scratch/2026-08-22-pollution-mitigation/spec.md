# Pollution Mitigation — WenshuVerifier rename + 3-Layer Defense

> 老板 2026-08-22 拍: rename `MiniMaxVerifier` → `WenshuVerifier` (decouple from vendor brand), AND implement 3-layer defense (Tickets A + B + C) in same PR.
> Research = `.scratch/2026-08-22-pollution-mitigation/research.md`.

## Business language (老板-facing)

Current `MiniMaxVerifier` has two problems:
1. **Naming pollution**: `MiniMax` in the class name implies wenshu is a minimax sub-product. This contradicts `AGENTS.md` §11 ("self-built lightweight AI kernel, no external AI platform dependency"). User-configured LLM does NOT make wenshu a minimax product — boss self-chose minimax as the v1 LLM provider, but the app architecture is provider-agnostic.
2. **No pollution defense**: model emits Chinese xianxia vocabulary (修真 / 渡劫 / 筑基 / etc.) in English output. Forward defense = 3 layers (system prompt, stop sequences, pre-commit hook).

**Both fixes in 1 PR**:
- Rename `MiniMaxVerifier` → `WenshuVerifier` + rename `MiniMaxRequest` / `MiniMaxResponse` / `MiniMaxMessage` / `MiniMaxError` to `WenshuLLMRequest` / `WenshuLLMResponse` / `WenshuLLMMessage` / `WenshuLLMError`. The `WenshuLLM*` prefix signals "wenshu LLM types" (provider-agnostic; current impl is minimax but class is replaceable).
- Inject English-only + forbidden-vocab system prompt on every request (Ticket A).
- Add `OutputKind` enum + stop_sequences for short outputs (Ticket B).
- Add pre-commit filter `Tools/wenshu-devtool/commit_filter.py` + `install_hook.sh` (Ticket C).

## Architecture context

Current state:

- `Sources/WenshuApp/Core/Agent/MiniMaxVerifier.swift` — only LLM call site in v0.21. Contains `MiniMaxRequest`, `MiniMaxResponse`, `MiniMaxMessage`, `MiniMaxError` data types.
- `Sources/WenshuApp/Core/Agent/MiniMaxModelFetcher.swift` — model-list fetcher (also rename to `WenshuLLMModelFetcher`).
- `Sources/WenshuApp/Core/Agent/LLMKeychain.swift` — API key store (likely unaffected, but grep for `MiniMax` references).

Target state:

- `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift` — renamed + 3 layers of pollution defense wired in.
- `Sources/WenshuApp/Core/Agent/WenshuLLMModelFetcher.swift` — renamed (no defensive layers; just model list).
- `Sources/WenshuApp/Core/Agent/WenshuLLMTypes.swift` (new file) — extract `WenshuLLMRequest` / `WenshuLLMResponse` / `WenshuLLMMessage` / `WenshuLLMError` data types for clarity. (Or keep them in WenshuVerifier.swift — confirm during grill-with-docs.)
- `Tools/wenshu-devtool/commit_filter.py` — Python pre-commit filter.
- `Tools/wenshu-devtool/install_hook.sh` — Hook installer.

## Cross-cutting design

**Forbidden vocabulary list** (single source of truth, mirror in 3 places):

```
修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障
```

Hard-coded into:
- WenshuVerifier (Ticket A) — Swift constant `systemPromptEnglishOnly` includes the list + allows list.
- WenshuVerifier (Ticket B) — Swift constant `shortOutputStopSequences: [String]` (machine-readable list).
- commit_filter.py (Ticket C) — Python regex list (mirror).

If boss adds/removes a token, edit all 3 places.

**Allowed CJK tokens** (project-mandated literal characters, NOT pollution):

```
老板 / 文枢 / 拍 / 拍板 / ※
```

- Tickets A + B: documented in system prompt only (Swift code does not filter these — model is trusted to keep them per system prompt).
- Ticket C: Python filter explicitly allows these (regex exemption).

## Renaming details

| Old name | New name | File |
|----------|----------|------|
| `MiniMaxVerifier` (class) | `WenshuVerifier` (class) | `WenshuVerifier.swift` |
| `MiniMaxRequest` (struct) | `WenshuLLMRequest` (struct) | extract to `WenshuLLMTypes.swift` |
| `MiniMaxResponse` (struct) | `WenshuLLMResponse` (struct) | extract to `WenshuLLMTypes.swift` |
| `MiniMaxMessage` (struct) | `WenshuLLMMessage` (struct) | extract to `WenshuLLMTypes.swift` |
| `MiniMaxError` (enum) | `WenshuLLMError` (enum) | extract to `WenshuLLMTypes.swift` |
| `MiniMaxModelFetcher` (enum) | `WenshuLLMModelFetcher` (enum) | rename file + body |
| `MiniMaxVerifier.send(...)` | `WenshuVerifier.send(...)` | signature change |

Naming rationale:

- `WenshuVerifier` — verifies wenshu's LLM integration works (provider-agnostic naming).
- `WenshuLLM*` prefix on data types — "LLM types owned by wenshu". When we add a second provider later, these types stay; new impl just swaps.

Update all call sites that reference old names:

- `grep -r 'MiniMax' Sources/ Tools/ Tests/` should return zero hits post-rename.

## Tickets

### Ticket A — System prompt English-only + forbidden-vocab rule

**File**: `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift` (renamed from `MiniMaxVerifier.swift`).

Add a static constant `WenshuVerifier.systemPromptEnglishOnly: String` and inject it as the leading `system` field on every Anthropic-compatible request, prepended to any caller-provided system message.

Acceptance criteria:

- [ ] Constant contains explicit English-only rule + forbidden-vocab list + allowed-token clarification.
- [ ] Every LLM call (`WenshuVerifier.send(_:)`, `complete(_:)`) prepends this constant.
- [ ] No caller-supplied system message is dropped or overwritten.
- [ ] swift build exit 0.
- [ ] swift test exit 0.
- [ ] Code-review 2 axes.

### Ticket B — OutputKind enum + stop sequences on short outputs

**File**: `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift`.

Add `OutputKind` enum + `WenshuVerifier.shortOutputStopSequences: [String]` constant. Branch on `outputKind` in `send(_:)`:
- `.chat` / `.draft` — no `stop_sequences` (would terminate long outputs).
- `.shortText` — attach `stop_sequences` to request body.

Acceptance criteria:

- [ ] `OutputKind` enum added with `.chat / .draft / .shortText` cases.
- [ ] `shortOutputStopSequences` constant has exactly the 12 tokens.
- [ ] `.shortText` calls include `stop_sequences` in request body.
- [ ] `.chat` + `.draft` calls do NOT include `stop_sequences`.
- [ ] swift build + swift test exit 0.
- [ ] Code-review 2 axes.

### Ticket C — Pre-commit hook (`commit_filter.py` + `install_hook.sh`)

**Files**:
- `Tools/wenshu-devtool/commit_filter.py` (new).
- `Tools/wenshu-devtool/install_hook.sh` (new).
- `Tools/wenshu-devtool/tests/test_block_pollution.sh` (new test fixture).
- `Tools/wenshu-devtool/tests/test_allow_allowed_tokens.sh` (new test fixture).
- `Tools/wenshu-devtool/tests/README.md` (new).

Acceptance criteria:

- [ ] Filter blocks commits containing forbidden vocab in staged .md / .swift / commit message.
- [ ] Filter allows commits containing only allowed tokens (`老板` / `文枢` / `拍` / `拍板` / `※`).
- [ ] Install script sets up `.git/hooks/pre-commit` correctly on first run; idempotent on re-run.
- [ ] Test fixtures self-contained (use `mktemp -d`, don't touch real repo).
- [ ] Python syntax check (`ast.parse`) passes; bash syntax check (`bash -n`) passes.
- [ ] Code-review 2 axes.

## Order of execution (1 PR, sequential commits within)

1. Commit 1 — Rename `MiniMax*` → `Wenshu*` + extract LLM types. (Pure rename; no behavior change.)
2. Commit 2 — Add `systemPromptEnglishOnly` constant + injection. (Ticket A.)
3. Commit 3 — Add `OutputKind` enum + `shortOutputStopSequences` + wire into request body. (Ticket B.)
4. Commit 4 — Add `commit_filter.py` + `install_hook.sh` + tests. (Ticket C.)

All 4 commits land on `wt/pollution-3-layer-defense` branch → PR → code-review (2 axes per commit) → merge.

## What this PR does NOT cover

- Ticket D — CI check (no CI today).
- Ticket E — `CONTEXT.md` glossary entry + ADR `0008-pollution-3-layer-defense.md` (separate doc-only ticket, follow-up after PR merges).
- Cleanup of historical commits in `git log` — out of scope (would require `git filter-branch`, escalate to 老板 first).
- Cleanup of `~/.wenshu/` / `~/.hermes/` backups — out of scope.

## Risks

- **Rename blast radius**: any file referencing `MiniMax*` will break. Mitigation: grep all `Sources/` + `Tests/` before commit; run `swift build` + `swift test` to confirm zero hits.
- **Prompt cache miss**: prepending system prompt breaks Anthropic prompt caching. Mitigation: keep constant byte-stable.
- **Stop sequences on long outputs would be catastrophic**: would terminate novel chapter on first forbidden token match. Mitigation: branch on `OutputKind` — only `.shortText` uses it.
- **Pre-commit filter bypass**: `git commit --no-verify` always works. Mitigation: log to stderr; rely on culture + code-review.
- **3 commits in 1 PR = bigger review surface**: but each commit is small + isolated; review can be per-commit.

## Acceptance criteria (overall PR)

- [ ] All 4 commits merged on `wt/pollution-3-layer-defense`.
- [ ] `grep -r 'MiniMax' Sources/ Tools/ Tests/` → 0 hits.
- [ ] swift build exit 0.
- [ ] swift test exit 0.
- [ ] pre-commit hook test fixtures both pass.
- [ ] Code-review 2 axes on each commit (Standards + Spec).
- [ ] Ticket E (CONTEXT.md + ADR) opened as follow-up.

## Further notes

- Research doc = `.scratch/2026-08-22-pollution-mitigation/research.md`.
- Issue breakdown = `.scratch/2026-08-22-pollution-mitigation/issues/`.

---

*Spec v0.2 · 2026-08-22 pocock · project root = `/Volumes/ANAN/Engineering/wenshu/`*