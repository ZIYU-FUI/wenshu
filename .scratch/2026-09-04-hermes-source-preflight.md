# Hermes source pre-flight — design notes (2026-09-04)

Boss 2026-09-04 OOB: ship secondary insurance for the hermes-5-subsystem brief path failure observed today. This document covers `Scripts/hermes-source-preflight.sh`. The subagent-resilience and CJK-translation scripts have their own specs.

## Background — what went wrong on 2026-09-04

The first subagent dispatched with a HERMES-SUBSYSTEM brief (= port `~/.hermes/agent/agent/<module>.py` to wenshu) hit a "wrong brief" failure:

- The brief referenced `/Volumes/ANAN/.hermes/agent/agent/<file>.py` paths.
- The actual filesystem layout at the time was different (= the source had been moved / renamed in a recent hermes commit).
- The subagent refused to fabricate (= correct behavior per `hermes-source-preflight` skill's "Refused fabrication" rule) and reported the missing paths back.
- The full subagent cycle was wasted (= ~10 min of model time + delegation overhead).

The retry subagent (= same brief, with corrected paths from `find /Volumes/ANAN/.hermes -name <file>`) shipped the port. This script is the secondary insurance that catches the same class of error BEFORE the subagent is spawned.

## What `Scripts/hermes-source-preflight.sh` does

Reads a brief file, extracts every `/Volumes/ANAN/.hermes/...` path token, and validates each one against the live filesystem.

For each missing path, it emits:

```
preflight: MISSING hermes source = /Volumes/ANAN/.hermes/agent/agent/foo.py
  real candidates:
    /Volumes/ANAN/.hermes/agent/agent_v2/foo.py
    /Volumes/ANAN/.hermes/agent/foo.py
```

Exit codes:

- `0` = every path exists (= safe to dispatch).
- `1` = at least one path missing (= brief needs human correction).
- `2` = usage error (= no brief path, or brief file not found).

## Why a shell script, not a Python tool

Two reasons:

1. **Zero-dependency** — `grep` + `find` are coreutils (= available everywhere). No `pip install`, no `argostranslate`, no Python runtime required.
2. **Sub-second execution** — runs in well under 100ms on any brief. Subagents invoke it before dispatch (= a slow preflight would defeat the purpose).

## Token extraction regex

```
grep -oE '/Volumes/ANAN/\.hermes/[^ )`]+' "$BRIEF" | sort -u
```

The character class `[^ )`]+` stops at whitespace, closing paren, or backtick (= captures real paths even when they appear inside markdown links, backtick code spans, or parenthetical asides like "see `/Volumes/ANAN/.hermes/agent/foo.py` for context").

## Real-path suggestion via `find`

For each missing path, the script runs:

```
find /Volumes/ANAN/.hermes -name "$(basename "$p")" | head -3
```

This gives the human dispatcher up to 3 candidate paths so the brief can be patched in one step (= replace the stale path with the real one, re-run preflight, dispatch).

## Idempotency

Running the script twice on the same brief produces the same output. It is purely read-only (= no writes, no side effects). Safe to invoke from any CI step.

## Invocation

```bash
Scripts/hermes-source-preflight.sh .scratch/2026-09-04-b-07-015-019-spec.md
```

Expected output for a clean brief:

```
preflight: all 3 hermes source path(s) valid in .scratch/2026-09-04-b-07-015-019-spec.md
```

Expected output for a bad brief:

```
preflight: MISSING hermes source = /Volumes/ANAN/.hermes/agent/agent/foo.py
  real candidates:
    /Volumes/ANAN/.hermes/agent/foo.py
preflight: 1 of 3 hermes source path(s) missing — brief needs human correction before dispatch
```

Exit 1 in the second case.

## What this script does NOT do

- It does NOT auto-correct briefs (= the human dispatcher decides whether to update the path or change the task scope).
- It does NOT validate non-hermes paths (= briefs may also reference `Sources/`, `docs/`, etc.; those are the parent's job to validate).
- It does NOT prevent the subagent from running (= it is a gate that the parent MUST call explicitly before `delegate_task`).

## Acceptance

- Exit 0 on a known-good brief (= all referenced hermes source paths exist).
- Exit 1 on a known-bad brief (= at least one referenced path missing, with real candidates printed).
- Runs in under 100ms on briefs under 10K lines.

*First line = fact. Last line = fact.*
