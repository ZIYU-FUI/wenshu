# Issue 11 — Third-party notices automation (build hook)

## What (= scope)

`Tools/wenshu-devtool/upstreams-notices-build.py` runs at build time: scans `upstreams.json` (= from Issue 03), emits `THIRD_PARTY_NOTICES.md` (= canonical Card-master format). Wired into `Scripts/build-app.sh` (= before `swift build`).

Reference Card-master's CI build pipeline (= their build script auto-emits `THIRD_PARTY_NOTICES.md` from `upstreams.json`).

## Why (= rationale)

Issue 03 sets up the data + scanner. Issue 11 wires it into the build (= so `THIRD_PARTY_NOTICES.md` is always in sync with `upstreams.json`).

## Apple-API-first check

- Custom code: 1 Python script + 1 build-script wiring line.
- Apple HIG candidate: n/a (= build tooling).
- Apple coverage: n/a.
- LOC delta: ~80.
- Risk: low.

## Files touched

- `Tools/wenshu-devtool/upstreams-notices-build.py` (NEW): emits `THIRD_PARTY_NOTICES.md` from `upstreams.json`.
- `Scripts/build-app.sh`: invoke the script before `swift build`.
- `CONTEXT.md`: reference to the auto-generated `THIRD_PARTY_NOTICES.md` (= update the domain glossary).

## Acceptance criteria

- [ ] `Tools/wenshu-devtool/upstreams-notices-build.py` is idempotent (= re-running produces same output).
- [ ] `Scripts/build-app.sh` invokes the script before build.
- [ ] `CONTEXT.md` references `THIRD_PARTY_NOTICES.md`.
- [ ] `bash Scripts/build-app.sh` exits 0 with the hook in place.

## Dependencies

- Issue 03 (= `upstreams.json` + scanner).

## References

- Source: Card-master CI build pipeline (= auto-emits `THIRD_PARTY_NOTICES.md`)
- Spec: `.scratch/2026-09-02-card-master-port/spec.md` §3 item 11

First line: fact. Last line: fact.