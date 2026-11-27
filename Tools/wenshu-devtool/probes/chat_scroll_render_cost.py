#!/usr/bin/env python3
"""Read one exported frame table and print what a render cost the app.

WHY THIS EXISTS. `xctrace export` writes a repeated cell value ONCE and points
at it later with `ref="N"`. A parser that reads only a cell's inline text
therefore sees a MINORITY of the rows, and the minority is not random: the
dropped rows are exactly the ones whose value repeated, so the durations that
survive are the unusual ones. The session whose numbers this instrument owns
published a render median and a frame-budget count from such a partial read
(611 rows and 512 over budget, against the 1124 rows and 1025 over budget the
same export holds once the `ref` chains are resolved). It prints both readings
side by side, so the gap is the instrument's own evidence rather than a
footnote.

Usage:  chat_scroll_render_cost.py <renders.xml> [label] [recording-seconds]

With the recording length given it also prints renders per second, which is
the only way two arms whose recordings differ in length can be compared on
rate at all.
"""

import os
import re
import statistics
import sys

FRAME_BUDGET_MS = 1000.0 / 60.0

ROW = re.compile(r"<row>(.*?)</row>", re.S)
CELL = re.compile(r"<duration\b[^>]*?(?:/>|>.*?</duration>)", re.S)
REF = re.compile(r'\bref="(\d+)"')
FMT = re.compile(r'\bfmt="([^"]*)"')
DECL = re.compile(r'<duration\b[^>]*\bid="(\d+)"[^>]*>')
MS = re.compile(r"^([0-9.]+)\s*ms$")
NS = re.compile(r"^(\d+)$")


def parse_ms(text):
    """A duration cell prints either as 'N.NN ms' in fmt, or as bare ns text."""
    if not text:
        return None
    t = text.strip()
    m = MS.match(t)
    if m:
        return float(m.group(1))
    m = NS.match(t)
    if m:  # a bare integer cell is nanoseconds
        return int(m.group(1)) / 1e6
    return None


def value_of(cell, decls):
    """Return (value_ms, kind) where kind is 'ref', 'inline' or 'lost'."""
    ref = REF.search(cell)
    if ref is not None:
        got = decls.get(ref.group(1))
        return (got, "ref") if got is not None else (None, "lost")
    fmt = FMT.search(cell)
    got = parse_ms(fmt.group(1)) if fmt else None
    if got is None:
        got = parse_ms(re.sub(r"</?[^>]+>", "", cell).strip())
    return (got, "inline") if got is not None else (None, "lost")


def collect(path):
    """Return (resolved, inline_only, rows, unreadable) for one export.

    `decls` maps an element id to the value it declares, which is what a later
    `ref` points at; the export emits the declaration before any reference.
    """
    with open(path, errors="replace") as handle:
        data = handle.read()
    decls = {}
    for m in DECL.finditer(data):
        fmt = FMT.search(m.group(0))
        value = parse_ms(fmt.group(1)) if fmt else None
        if value is not None:
            decls[m.group(1)] = value
    resolved, inline_only, unreadable, rows = [], [], 0, 0
    for m in ROW.finditer(data):
        rows += 1
        cell = CELL.search(m.group(1))
        if cell is None:
            unreadable += 1
            continue
        value, kind = value_of(cell.group(0), decls)
        if value is None:
            unreadable += 1
            continue
        resolved.append(value)
        if kind == "inline":
            inline_only.append(value)
    return resolved, inline_only, rows, unreadable


def report(label, durations):
    ordered = sorted(durations)
    over = sum(1 for v in ordered if v > FRAME_BUDGET_MS)
    p90 = ordered[int(0.9 * (len(ordered) - 1))]
    return (f"  {label}: rows read {len(ordered)}"
            f"  median {statistics.median(ordered):.2f} ms"
            f"  p90 {p90:.2f} ms"
            f"  over one frame {over} of {len(ordered)}"
            f" ({over / len(ordered) * 100:.1f}%)")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(path)
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        print(f"MISSING: {path} (no export, no numbers)")
        return 2
    resolved, inline_only, rows, unreadable = collect(path)
    if not resolved:
        print(f"NO DURATIONS: {path}")
        return 2
    print(f"probe: chat_scroll_render_cost  file: {path}")
    print(f"arm: {label}")
    print(f"rows in the table: {rows}   (= {len(resolved)} durations read)")
    print(f"rows with no readable duration: {unreadable}")
    print(f"--- the frame budget is {FRAME_BUDGET_MS:.2f} ms ---")
    print(report("read WITH the ref chains resolved", resolved))
    if inline_only:
        print(report("read INLINE only (the trap)", inline_only))
        gap = len(resolved) - len(inline_only)
        print(f"  the inline-only read loses {gap} of {len(resolved)} rows"
              f" ({gap / len(resolved) * 100:.1f}%)")
    if len(sys.argv) > 3:
        secs = float(sys.argv[3])
        print(f"  renders per second over the {secs:g} s recording:"
              f" {len(resolved) / secs:.1f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
