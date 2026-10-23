#!/usr/bin/env python3
"""column_chrome_band.py — do two neighbouring columns share one chrome band?

WHAT IT MEASURES
  The two column-top chrome bands of the running Wenshu window, in WINDOW
  POINTS:
    * ASSETS column  = the search band under the section title
    * EDITOR column  = the format-toolbar band under the tab strip
  For each column it finds, inside the second row (88..126 pt):
    * the CONTENT ink band  (the rows holding glyphs)
    * the BAND SURFACE      (the contiguous run of rows sharing the band's own
      surface luminance = the chrome material, not the glyphs and not the
      background around the band)
    * the BOTTOM HAIRLINE   (the row where the band ends)
  and prints the DELTA on the numbers the eye reads as "the same height":
    1. content band CENTRE
    2. band surface TOP
    3. band surface BOTTOM
    4. bottom hairline ROW

HOW IT MEASURES
  It reads a 2x PNG capture of the running app and measures the pixels. The
  subject is the app's PAINTED chrome, so the input is a capture rather than
  the source tree: the band a user sees is the material the app actually
  painted, and only the pixels say how tall that material is.

  It prints the tree's HEAD at run time, so a re-run on a later commit
  prints that later commit. The numbers describe the app source as it was
  at the commit the capture was taken against, which is the commit the
  index row names.

THE TRAPS THIS SCRIPT AVOIDS (all measured 2026-10-22 and 2026-10-23)
  1. A whole-window mean hides the two columns' separate bands. Measure PER
     COLUMN, never over the whole window.
  2. Scale. The input is a 2x capture, so a device row index is HALVED to get
     window points. Comparing device rows against points reports a 4x error.
  3. A VERTICAL artifact (= a column separator or a toolbar chunk divider)
     reads as "ink" on every row of the band and swallows the whole band.
     Defence: mask out every x-column that carries ink on more than
     VERTICAL_ARTIFACT_FRACTION of the band's rows (= a vertical structure),
     then count ink on the surviving columns only.
  4. The band's OUTER edges are equal even when the content inside one band
     sits lower. Compare the CONTENT, never the outer box.
  5. Below the band the next surface starts (the editor's paper canvas is
     BRIGHTER than the band). A hairline search must stop at the first row
     whose mean moves away from the band background by more than a hair.
  6. CONTENT CENTRE ALONE IS A RUBBER STAMP. Measured 2026-10-23: a capture
     whose two content centres agreed to 0.00 PT still had the assets band
     surface 6 PT short of the editor's (assets surface 95..110 vs editor
     89..116), and this script called it PASSED. The content sits centred in
     whatever band it is given, so centring it says nothing about the band's
     HEIGHT. The band surface's top and bottom are measured separately, and a
     band that is 16 PT tall fails next to a band that is 28 PT tall even
     though their centres agree.
  7. The surface run must be picked by the row that HOLDS THE GLYPHS, not by
     the longest flat run: the background above and below the band is also a
     long flat run, and it is usually longer than the band itself. Pick the
     maximal run whose rows share a luminance within SURFACE_FLATNESS of each
     other AND which contains (or touches) the content ink band.
  8. THE PNG FILTER'S LEFT OFFSET IS IN BYTES PER PIXEL, NOT IN BYTES.
     Measured 2026-10-23: a decoder that used a one-byte offset produced
     row medians of 190.0 where the true value was 250.2, and the error was
     INVISIBLE in the ink-band numbers (the glyphs are far darker than the
     surface either way) and fatal for any measurement of the SURFACE. A
     gate that reads a surface must be checked against a reference decoder
     on the SAME file.

USAGE
  # 1. capture the running window at 2x (read-only; no focus steal):
  swiftc -O sck-capture.swift -o sck-capture
  ./sck-capture <window title> /tmp/live.png 2.0
  # 2. measure:
  python3 Tools/wenshu-devtool/probes/column_chrome_band.py /tmp/live.png
  # 3. prove the gate has teeth (it must REJECT a short band):
  python3 Tools/wenshu-devtool/probes/column_chrome_band.py --selftest

EXIT CODE
  0 = the two columns agree within the tolerances (PASS)
  1 = they disagree, or the capture is unusable (FAIL)
"""
import os
import sys
import tempfile
import zlib
import struct
from collections import Counter

TOL_CENTRE_PT = 1.0     # the two columns' second-row content centres
TOL_BAND_PT = 1.0       # the two columns' second-row band surface top/bottom
TOL_HAIRLINE_PT = 1.0   # the two columns' second-row bottom hairlines
MIN_INK = 3              # samples that must differ from the row's modal value
VERTICAL_ARTIFACT_FRACTION = 0.60   # an x-column this inked is a vertical rule
ROW_LO, ROW_HI = 88.0, 126.0   # the second row, in window points
SURFACE_FLATNESS = 6.0  # rows within this luminance share one surface

# The sampled x-ranges stop SHORT of the column separators, because a 1px
# vertical edge inside the range reads as ink on every row.
#
# EDITOR_X covers the FIRST chunk of format buttons only (460..590). The
# toolbar draws a vertical `Divider()` between its chunks (a rule as tall as
# the band), and a wider window measures that rule as content on every row,
# which drags the measured band top up to the band edge instead of to the
# glyphs. The assets window covers the whole search row, which carries no
# vertical rule.
ASSETS_X = (206, 432)
EDITOR_X = (460, 590)


def tree_commit():
    """The commit this tree is at, printed so a number is never orphaned.

    A number measured against one commit does not describe a later commit,
    so the probe prints the tree it ran against every time. The index row
    names the same commit for the recorded run.
    """
    import subprocess
    here = os.path.dirname(os.path.abspath(__file__))
    # probes/ -> wenshu-devtool/ -> Tools/ -> the repo root
    root = os.path.dirname(os.path.dirname(os.path.dirname(here)))
    try:
        out = subprocess.run(
            ["/usr/bin/git", "-C", root, "rev-parse", "--short=12", "HEAD"],
            capture_output=True, text=True, timeout=10)
        text = (out.stdout or "").strip()
        return text if text else "unknown"
    except Exception:
        return "unknown"


def load_png(path):
    data = open(path, 'rb').read()
    pos = 8
    idat = b''
    w = h = ct = None
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + ln]
        if typ == b'IHDR':
            w, h, bd, ct = struct.unpack('>IIBB', chunk[:10])
        elif typ == b'IDAT':
            idat += chunk
        elif typ == b'IEND':
            break
        pos += 12 + ln
    raw = zlib.decompress(idat)
    nch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    stride = w * nch
    out = bytearray(h * stride)
    prev = bytearray(stride)
    p = 0
    # The PNG filter offsets are in BYTES PER PIXEL (= bpp = nch for a
    # non-palette image), NOT in bytes. Using `i - 1` (a byte offset) or
    # `i - stride` (a whole row) instead of `i - nch` decodes the image into
    # plausible-looking but WRONG pixels.
    #
    # Measured 2026-10-23: this decoder produced row medians of 190.0 where
    # the true value was 250.2, and a fresh reference decoder disagreed with
    # it on the very first row. The bug was INVISIBLE in the ink-band
    # numbers (the glyphs are far darker than the surface either way, so the
    # band boundaries still came out right) and fatal for any measurement of
    # the SURFACE itself. A gate that reads a surface must be checked
    # against a reference decoder on the SAME file.
    bpp = nch
    for y in range(h):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if f == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                line[i] = (line[i] + ((a + b) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                pa = abs(b - c); pb = abs(a - c); pc = abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return w, h, nch, out


def _write_png(path, w, h, pixels):
    """Minimal RGB PNG writer (= the fixture generator for --selftest)."""
    raw = b''.join(b'\x00' + bytes(pixels[y * w * 3:(y + 1) * w * 3]) for y in range(h))

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, 'wb') as fh:
        fh.write(b'\x89PNG\r\n\x1a\n')
        fh.write(chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)))
        fh.write(chunk(b'IDAT', zlib.compress(raw)))
        fh.write(chunk(b'IEND', b''))


def selftest(tmpdir):
    """Prove the detector READS the offsets instead of rubber-stamping them.

    Three synthetic captures:
      1. "level"          = the two columns' glyph bands are level -> ~0.0 PT
      2. "offset by 4 PT" = the assets glyph band sits 4 PT lower -> ~4.0 PT
      3. "short band"     = the assets glyph band is CENTRED (so the content
                            centre agrees) but its SURFACE is only 12 PT tall
                            against the editor's 28 PT. The content-centre
                            check alone calls this a PASS; the band-surface
                            check must call it a FAIL. This is the exact
                            rubber stamp measured on 2026-10-23.
    """
    w, h, scale = 1200, 400, 2
    ok = True

    def make(name, assets_offset_pt, assets_surface_pt):
        """Build one synthetic capture.

        The editor column always has a 28 PT surface band with its glyphs
        near its top. The assets column has a surface band of
        assets_surface_pt rows and glyphs shifted by assets_offset_pt.

        A band SHORTER than the editor's is CENTRED on the editor band's
        centre, because that is the real defect: the short band floats in
        the middle of the slot it is given, so its top AND its bottom are
        inset. A short band sharing the editor's top would only move one
        edge and would not exercise the check.
        """
        px = bytearray(b'\xbe' * (w * h * 3))          # flat pane background
        ed_top = int(100 * scale)
        ed_rows = 28
        ed_centre = ed_top + ed_rows // 2

        # the editor column: a full 28 PT surface with its glyphs CENTRED in
        # it (measured on the real capture: band 88.5..116, ink 96.5..108.5,
        # and (28-12)/2 = 8 puts the ink at 96.5).
        # The ink block must stay narrow enough that the row's MEDIAN is
        # still the surface and not the ink (= how the real capture reads),
        # so it covers well under half the sampled window.
        for dy in range(0, ed_rows):
            row = ed_top + dy
            for x in range(int(460 * scale), int(590 * scale)):
                i = (row * w + x) * 3
                px[i:i + 3] = b'\x60\x60\x60'
        for dy in range(0, 12):
            row = ed_top + (ed_rows - 12) // 2 + dy
            for x in range(int(500 * scale), int(550 * scale)):
                i = (row * w + x) * 3
                px[i:i + 3] = b'\x10\x10\x10'

        # the assets column: its band, centred on the editor band's centre
        a_top = ed_centre - assets_surface_pt // 2
        for dy in range(0, assets_surface_pt):
            row = a_top + dy
            if row + 1 >= h:
                continue
            for x in range(int(206 * scale), int(432 * scale)):
                i = (row * w + x) * 3
                px[i:i + 3] = b'\x60\x60\x60'
        # its glyphs, centred in its own band, plus the requested offset
        a_ink = a_top + (assets_surface_pt - 12) // 2 + int(assets_offset_pt * scale)
        for dy in range(0, 12):
            row = a_ink + dy
            if row + 1 >= h:
                continue
            for x in range(int(280 * scale), int(340 * scale)):
                i = (row * w + x) * 3
                px[i:i + 3] = b'\x10\x10\x10'
        path = f"{tmpdir}/{name}.png"
        _write_png(path, w, h, px)
        return path

    import subprocess

    def run(path):
        out = subprocess.run(
            [sys.executable, os.path.abspath(__file__), path, str(scale)],
            capture_output=True, text=True).stdout
        centre = band_top = band_bot = None
        for line in out.splitlines():
            if line.startswith('content centre'):
                centre = float(line.split('DELTA')[1].split('pt')[0].strip())
            if line.startswith('band surface'):
                band_top = float(line.split('DELTA top')[1].split('pt')[0].strip())
                band_bot = float(line.split('bottom')[1].split('pt')[0].strip())
        return centre, band_top, band_bot, out

    # 1. level: centre delta ~0, band delta ~0, gate PASSES
    c, bt, bb, out = run(make("level", 0.0, 28))
    good = (c is not None and abs(c) <= 0.6 and bt is not None
            and abs(bt) <= 0.6 and abs(bb) <= 0.6)
    ok = ok and good
    print(f"  selftest {'level':16s}: centre {c} pt, band top {bt} bottom {bb} pt => "
          f"{'OK' if good else 'FAIL'}")

    # 2. content offset by 4 PT: centre delta ~4, band delta ~0
    c, bt, bb, out = run(make("offset4", 4.0, 28))
    good = c is not None and abs(c - 4.0) <= 0.6
    ok = ok and good
    print(f"  selftest {'offset by 4 PT':16s}: centre {c} pt, band top {bt} bottom {bb} pt => "
          f"{'OK' if good else 'FAIL'}")

    # 3. short band: the CENTRE agrees but the band is short on BOTH edges.
    #    A centre-only gate would pass this capture; the band-surface check
    #    must catch it. This is the exact rubber stamp measured on
    #    2026-10-23 (assets surface 16 PT vs editor 28 PT, centres equal).
    c, bt, bb, out = run(make("shortband", 0.0, 12))
    good = (c is not None and abs(c) <= 0.6 and bt is not None
            and bb is not None and abs(bt) >= 4.0 and abs(bb) >= 4.0)
    ok = ok and good
    print(f"  selftest {'short band':16s}: centre {c} pt, band top {bt} bottom {bb} pt => "
          f"{'OK' if good else 'FAIL'}")
    print("SELFTEST: PASSED" if ok else "SELFTEST: FAILED")
    return 0 if ok else 1


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    if sys.argv[1] == '--selftest':
        with tempfile.TemporaryDirectory() as td:
            return selftest(td)
    path = sys.argv[1]
    scale = float(sys.argv[2]) if len(sys.argv) > 2 else 2.0
    print(f"probe: column_chrome_band")
    print(f"capture: {path}")
    w, h, nch, buf = load_png(path)
    print(f"capture {w}x{h}  scale={scale}")

    def lum(x, y):
        i = (y * w + x) * nch
        return 0.299 * buf[i] + 0.587 * buf[i + 1] + 0.114 * buf[i + 2]

    def analyse(x0pt, x1pt, label):
        x0, x1 = int(x0pt * scale), int(x1pt * scale)
        print(f"\n=== {label}  x[{x0pt},{x1pt}) pt ===")
        rows = list(range(int(ROW_LO * scale), min(int(ROW_HI * scale), h)))
        # --- per x-column ink map (the vertical-artifact mask) ---
        col_ink = {}
        for x in range(x0, x1, 2):
            hits = 0
            for dy in rows:
                vals = [lum(xx, dy) for xx in range(x, min(x + 4, x1))]
                modal = Counter(vals).most_common(1)[0][0]
                if any(abs(v - modal) > 18 for v in vals):
                    hits += 1
            col_ink[x] = hits
        nrows = max(1, len(rows))
        masked = {x for x, hits in col_ink.items()
                  if hits > VERTICAL_ARTIFACT_FRACTION * nrows}
        keep = sorted(set(col_ink) - masked)
        print(f"  x-columns kept {len(keep)}/{len(col_ink)} "
              f"(masked {len(masked)} vertical-artifact columns)")
        if not keep:
            print("  (every column masked = the band is all vertical rules)")
            return None, None
        prof = []
        for dy in rows:
            vals = sorted(lum(x, dy) for x in keep)
            modal = Counter(vals).most_common(1)[0][0]
            ink = sum(1 for v in vals if abs(v - modal) > 18)
            mean = sum(vals) / len(vals)
            median = vals[len(vals) // 2]
            prof.append((dy, dy / scale, ink, mean, median))
        ink_rows = [p for p in prof if p[2] >= MIN_INK]
        if not ink_rows:
            print("  (no content ink found)")
            return None, None, None, None
        bands = []
        s = p = ink_rows[0]
        for r in ink_rows[1:]:
            if r[0] == p[0] + 1:
                p = r
            else:
                bands.append((s, p))
                s = p = r
        bands.append((s, p))
        print("  content bands (device rows):", [(b[0][0], b[1][0]) for b in bands])
        best = max(bands, key=lambda b: b[1][0] - b[0][0])
        lo_pt, hi_pt = best[0][1], best[1][1]
        print(f"  CONTENT band = {lo_pt:.1f} .. {hi_pt:.1f} pt   centre {(lo_pt+hi_pt)/2:.2f}")

        # --- BAND SURFACE -------------------------------------------------
        # The band surface is the run of rows whose MEDIAN luminance is the
        # surface the glyphs sit on. Anchor on the CONTENT BAND's median
        # (not on every inked row: rows further down the window carry
        # unrelated ink and would drag the anchor elsewhere), then walk
        # outwards while the row's median stays within SURFACE_FLATNESS of it.
        # The walk stops at the first row that does not: the hairline above
        # the band, the bare background beside a short band, or the editor's
        # brighter paper canvas below.
        #
        # Use the row MEDIAN, not the mode: the chrome material is a
        # translucent gradient, so every row's mode is a slightly different
        # value and a mode-of-modes is noise.
        #
        # Chained adjacency is WRONG here too: the editor's canvas is only
        # ~5 luminance units brighter than its band, so a chain swallows it.
        # Anchoring on the content band and bounding the walk avoids that.
        band_rows = [p for p in prof if best[0][0] <= p[0] <= best[1][0]]
        anchor = sorted(p[4] for p in band_rows)[len(band_rows) // 2]
        i_lo = i_hi = None
        for i, p in enumerate(prof):
            if best[0][0] <= p[0] <= best[1][0]:
                if i_lo is None:
                    i_lo = i
                i_hi = i
        surf_top = surf_bot = None
        if i_lo is not None:
            a = i_lo
            while a - 1 >= 0 and abs(prof[a - 1][4] - anchor) <= SURFACE_FLATNESS:
                a -= 1
            b = i_hi
            while b + 1 < len(prof) and abs(prof[b + 1][4] - anchor) <= SURFACE_FLATNESS:
                b += 1
            surf_top, surf_bot = prof[a][1], prof[b][1]
            print(f"  BAND SURFACE = {surf_top:.1f} .. {surf_bot:.1f} pt "
                  f"({(surf_bot - surf_top + 1):.1f} pt tall, anchor {anchor:.1f})")

        # The closing line below the band: the first row under the band
        # surface that is DARKER than the surface itself. Printed for
        # information only, and it is NOT part of the gate: the surface
        # UNDER a band differs per column (the editor's is the white canvas,
        # the assets' is the sidebar background), so "a darker row below the
        # band" cannot be compared across the two columns. The band's own
        # bottom edge IS the comparable quantity, and it is measured above.
        bg = max((p[3] for p in prof if p[2] < MIN_INK), default=None)
        hair = None
        if bg is not None and surf_bot is not None:
            for dy, pt, ink, mean, med in prof:
                if pt > surf_bot and med < anchor - 3.0:
                    hair = pt
                    break
        print(f"  closing line below band = {hair} pt")
        return (lo_pt + hi_pt) / 2.0, surf_top, surf_bot, hair

    a_c, a_t, a_b, a_h = analyse(*ASSETS_X, "ASSETS column")
    e_c, e_t, e_b, e_h = analyse(*EDITOR_X, "EDITOR column")

    print("\n================ GATE ================")
    if a_c is None or e_c is None:
        print("FAILED: a column's second-row content was not found "
              "(wrong window, wrong layout, or the app was not running)")
        return 1
    d_c = abs(a_c - e_c)
    print(f"content centre : assets {a_c:.2f} pt   editor {e_c:.2f} pt   DELTA {d_c:.2f} pt "
          f"(tolerance {TOL_CENTRE_PT} pt)")
    ok = d_c <= TOL_CENTRE_PT
    if a_t is not None and e_t is not None:
        d_t = abs(a_t - e_t)
        d_b = abs(a_b - e_b)
        print(f"band surface   : assets {a_t:.1f}..{a_b:.1f}   editor {e_t:.1f}..{e_b:.1f}   "
              f"DELTA top {d_t:.2f} pt, bottom {d_b:.2f} pt (tolerance {TOL_BAND_PT} pt)")
        ok = ok and d_t <= TOL_BAND_PT and d_b <= TOL_BAND_PT
    else:
        print("band surface: not detected in both columns (FAILED)")
        ok = False
    print(f"closing lines  : assets {a_h}   editor {e_h}   (informational: the "
          f"surface under a band differs per column, so these are not compared)")
    print(f"source_commit: {tree_commit()}")
    print("GATE: PASSED" if ok else "GATE: FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
