# CJK translation safety — design notes (2026-09-04)

Boss 2026-09-04 OOB: ship secondary insurance for the CJK cascade garbage failure observed today. This document covers the rewritten `Scripts/translate-cjk-comments.py`. The subagent-resilience and hermes-preflight scripts have their own specs.

## Background — what went wrong on 2026-09-04

The v1 `Scripts/translate-cjk-comments.py` used `urllib.request` to call `api.mymemory.translated.net` (= free, no auth). During a 14K-LOC sweep, two compounding failures occurred:

1. The MyMemory free tier started returning 429 (rate limit) mid-sweep.
2. The script fell through to per-line fallback, but the per-line responses had partial garbage (= mixed line counts, HTML entities leaking through, truncation markers `<<<` / `>>>` for chunks over the per-request char limit).
3. A race between the v1 script and another subagent writing to the same `Sources/WenshuApp/` files produced interleaved garbage (= signature pollution marker = `♪` next to legitimate code, `@SlateView` next to `if let`, etc.).
4. Result: several Swift files were corrupted with mixed CJK + garbage + real code on the same lines. Recovery required a manual `git restore` + rerun with smaller scope.

## The 4 safety guards (v3 = the rewrite)

### 1. Pre-flight guard — refuse to write polluted files

At the top of `process_file()`, the script checks whether the file already contains any of these pollution markers:

```python
POLLUTION_MARKERS = (
    "\u266a",        # ♪
    "@SlateView",
    "@MarkdownView",
    "If sqlite3 exec",
    "If sqlite",
    "SLATE VIEW",
    "<<<",           # rate-limit truncation marker
    ">>>",           # rate-limit truncation marker
)
```

If ANY marker appears in the file's current contents, the file is SKIPPED entirely (= no read-modify-write, no partial translation). The script emits a `SKIPPING polluted file = ...` line and increments the `skipped_polluted` counter. The overall script exits 1 if any file was skipped (= caller knows to hand-clean + re-run).

Why this matters: writing to a polluted file would silently preserve the garbage AND inject more changes (= double corruption). The only safe path is "human cleans, then re-runs."

### 2. Atomic write — tmp + rename

Every modified file is written via:

```python
tmp = path.with_suffix(path.suffix + ".tmp")
tmp.write_text(content, encoding="utf-8")
os.rename(tmp, path)
```

If the process is SIGKILLed mid-write (= subagent dies, OOM, disk full mid-flush), the `.tmp` file is left orphaned but the original file is untouched. POSIX guarantees `os.rename` is atomic on the same filesystem.

### 3. Mark TODO only — never write garbage

If a CJK block has no entry in the offline cache AND no manual lookup rule matches AND `argostranslate` is unavailable, the script writes:

```swift
    // [CJK-TRANSLATE: 老板拍 v0.28 batch 1 = wenshu source has zero import Defaults]
```

…as a marker line ABOVE the block. The original CJK lines are preserved unchanged. A human (`grep -r "CJK-TRANSLATE" Sources/WenshuApp/`) can find every TODO at any later time and patch by hand. There is no path in v3 that writes garbage.

### 4. No online API — offline-only translation

v3 removes every `urllib.request` call. Translation sources, in priority order:

1. **Offline cache** (`.scratch/cjk-translation-cache.json` — 559 entries at last ship). Substring match against the full block text.
2. **Manual lookup** — small table of high-frequency wenshu terms (= `老板` → `boss`, `文枢` → `Wenshu`, `液态玻璃` → `Liquid Glass`, etc.).
3. **`argostranslate.translate(text, 'zh', 'en')`** — offline neural engine. Returns None if the model is not installed; the wrapper does NOT raise.

There is no third online-API fallback. If all 3 offline sources miss, the script writes the TODO marker and moves on.

## Cache logic (preserved from v1)

The 559-entry `.scratch/cjk-translation-cache.json` is loaded at start and written back at end. The cache is the primary translation source for v3 (= matches the v1 strategy of "avoid duplicate API calls", but no API is involved). The cache write itself is atomic (= tmp + rename).

## Hard rules (unchanged from v1 + v2)

- DO NOT touch string literals.
- DO NOT touch `.lproj` files.
- DO NOT touch anything outside `Sources/WenshuApp/`.
- DO NOT touch `AGENTS.md` / `CLAUDE.md` / `README.md` / `CHANGELOG.md`.
- DO NOT introduce any new third-party dependency (= `argostranslate` was already approved in the runtime env; nothing new is added).
- DO NOT call any online translation API.

## Invocation

```bash
Scripts/translate-cjk-comments.py
```

Exit 0 = clean run, no polluted files found. Exit 1 = at least one file was skipped due to pollution (= hand-clean and re-run).

## Acceptance

- Running v3 on a synthetic polluted file (= a `.swift` file containing `♪` on one line) prints `SKIPPING polluted file = ...` and exits 1 without modifying the file.
- Running v3 on a clean file produces either a translation OR a `[CJK-TRANSLATE: ...]` marker line, never garbage.
- v3 never calls `urllib.request` (= grep returns 0 hits in the source).

*First line = fact. Last line = fact.*
