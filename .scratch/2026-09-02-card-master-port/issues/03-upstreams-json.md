# Issue 03 — `upstreams.json` + `THIRD_PARTY_NOTICES.md` (transparency)

## What (= scope)

Add `upstreams.json` (= machine-readable list of every embedded / preinstalled / vendored dependency with: GitHub URL + license + reason-for-inclusion) + auto-generated `THIRD_PARTY_NOTICES.md` (= human-readable Markdown summary).

Reference Card-master's `upstreams.json` (9.7 KB) + `THIRD_PARTY_NOTICES.md` (9.5 KB) at repo root.

## Why (= rationale)

Wenshu currently uses SPM (= `Package.swift`) which already lists dependencies. But it does NOT list:
- preinstalled userscript content (= any MD / JSON files shipped inside `.ws` templates).
- vendored runtime (= e.g. a bundled LLM inference engine).
- pre-installed templates.

The `upstreams.json` pattern covers all 3 categories (= SPM dependencies + bundled content + vendored binaries).

Boss 8/30 OOB: '你拍"全做"' → this is part of the 'all 11 items' = the boss wants wenshu to match Card-master's transparency.

## Apple-API-first check

- Custom code: a small Python script (= `Tools/wenshu-devtool/upstreams-scan.py`) that walks the repo + emits `upstreams.json`.
- Apple HIG candidate: n/a (= this is a build-tooling change, not Apple framework).
- Apple coverage: n/a (= no UI / framework change).
- LOC delta: ~100.
- Risk: low (= JSON schema is canonical).

## Files touched

- `upstreams.json` (NEW): wenshu's list of dependencies (= initial entry = empty or pre-existing ones).
- `THIRD_PARTY_NOTICES.md` (NEW): auto-generated Markdown summary.
- `Tools/wenshu-devtool/upstreams-scan.py` (NEW): build script.
- `Scripts/build-app.sh`: invoke `upstreams-scan.py` before `swift build` (= auto-update on each build).

## Acceptance criteria

- [ ] `upstreams.json` lists: SPM dependencies (= auto-detected from `Package.swift`) + bundled content (= wenshu templates, pre-installed MD files) + vendored binaries.
- [ ] `THIRD_PARTY_NOTICES.md` has 1 section per upstream (= name + URL + license + reason).
- [ ] `Tools/wenshu-devtool/upstreams-scan.py` is idempotent (= re-running = same output).
- [ ] `Scripts/build-app.sh` invokes the scanner before build.
- [ ] Documentation in `CONTEXT.md` (= domain glossary) references `upstreams.json` for "where do third-party dependencies come from".

## Implementation ticket chain

1. Write `upstreams.json` schema (= match Card-master: `name`, `url`, `license`, `reason`, `version`).
2. Write the scanner.
3. Run scanner + emit initial `upstreams.json` + `THIRD_PARTY_NOTICES.md`.
4. Wire into `Scripts/build-app.sh`.

## Dependencies

None (= standalone build tooling).

## References

- Source: Card-master `upstreams.json` + `THIRD_PARTY_NOTICES.md` at repo root
- Spec: `.scratch/2026-09-02-card-master-port/spec.md` §3 item 3

First line: fact. Last line: fact.