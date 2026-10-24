# Probe index

One row per probe in `Tools/wenshu-devtool/probes/`. A probe measures one
visual subject, prints its numbers to standard output, and writes no file.

The commit column is what makes a number reusable. A number measured
against one commit does not describe a later commit, so every row says
which commit the measurement was taken against. A row with no measurement
behind it is worse than no row at all.

The commit named is the tree the probe ran against, and it is the commit
whose app source the numbers describe. The probe prints that tree's HEAD
at run time, so a re-run on a later commit prints that later commit; the
numbers are unchanged as long as the app source is unchanged, and this
card's commit does not touch the app source.

| Probe | Subject measured | Numbers printed | Commit measured against |
| --- | --- | --- | --- |
| `chat_bubble_metrics.swift` | The user's own chat bubble (the outgoing message surface in the chat column), painted width and corner radius read from rendered pixels at a stated host width. | `painted_width_pt`, `painted_height_pt`, `corner_radius_pt`, `shape_rule_radius_pt`, `subject_ink_width_pt`, `host_width_pt`, `calibration_radius_pt`, `calibration_measured_pt` | `3ee82bf48b18` |
| `column_chrome_band.py` | The column-top chrome band of two neighbouring columns of the running app (= the materials column's search band and the editor column's format-toolbar band), read from a 2x capture: the content ink band, the MATERIAL surface the band paints, and the closing hairline. | `content_centre_delta_pt`, `band_surface_top_delta_pt`, `band_surface_bottom_delta_pt`, plus each column's content centre and band surface top/bottom | `ab0de05659` |
| `editor_chat_arrangement.py` | The editor and chat zone's arrangement (= which pane is where), read from the running app's accessibility tree as native coordinates: the chat's composer, the editor's toolbar, and the editor's body. It names the arrangement from those coordinates and checks the production fragments it reproduces before it reports a number. | `composer_x`, `composer_y`, `editor_toolbar_x`, `editor_toolbar_y`, `editor_body_x`, `editor_body_y`, `arrangement`, plus `requested_mode` and `agreement` | `158852c04d38` |
| `toolbar_preference_change.py` | The main window's toolbar after the app's preferences changed: the app's own Settings scene is driven through the accessibility tree, its group rows are switched N times (= N app-preference changes), and the process is watched for the abort AppKit raises when a window asks for more "Update Constraints in Window" passes than it has views. | `switches_landed`, `survived`, `pane_after`, `unresolvable_symbol_faults`, `max_update_constraints_count`, `layout_loop_warnings`, `new_crash_reports` | `d6b4b42a782b` |
| `toolbar_preference_change.swift` | The accessibility driver the toolbar probe runs: it opens the app's own Settings scene, selects its group rows through the accessibility tree, and verifies every switch against the persisted group key, so a driver that silently did nothing cannot report a pass. | `group_rows`, `strategy`, `switches_landed`, plus the group and pane of each round | `d6b4b42a782b` |

## Recorded measurement

The runs below are the proof that the rows above carry real numbers. They
are the probes' own output.

### `chat_bubble_metrics.swift`

Taken against commit `3ee82bf48b18`, with the subject `Hi` at the
reference host width.

```
probe: chat_bubble_metrics
subject: Hi
host_width_pt: 723.0
painted_width_pt: 36.9
painted_height_pt: 35.9
corner_radius_pt: 16.9
shape_rule_radius_pt: 18.0
subject_ink_width_pt: 11.0
calibration_radius_pt: 10.0
calibration_measured_pt: 9.8
source_commit: 3ee82bf48b18
```

Two numbers in that run are worth reading together:

- `corner_radius_pt` is what the pixels say, `shape_rule_radius_pt` is what
  the production shape rule computes. The fit reads the radius about one
  point under the rule, because the 50%-coverage contour of a rounded edge
  sits inside the drawn arc. The reference shape in the same run (a known
  10 PT radius) reads 9.8, so the reader can see the fit's own bias on the
  machine that took the measurement.
- `painted_width_pt` is the width the fill covers, not the width of the
  subject's ink. The production bubble paints its background BEFORE the
  width cap, so the fill hugs the words (= 36.9 PT for a two-character
  subject at a 723 PT host) and the cap only bounds the result.
  `subject_ink_width_pt` is the subject's own width.

### `column_chrome_band.py`

Taken against commit `ab0de05659`, on a 2x capture of the running app with
the window maximized. That commit is the one that put the materials
column's search row on the shared `ChromeTopBar` and gave it the editor
column's full 28 PT band, so its band geometry is the one the numbers
describe. The chrome-band rows of `AssetsPane.swift`, `ChromeTopBar.swift`
and `EditorFormatToolbar.swift` are byte-identical from that commit to
`main` today, so the numbers still describe a later tree.

```
probe: column_chrome_band
capture: recorded-capture.png   (= the skill wenshu-visual-audit, references/recorded-capture.png)
capture 3840x1968  scale=2.0
  CONTENT band = 96.0 .. 108.5 pt   centre 102.25
  BAND SURFACE = 88.5 .. 116.0 pt (28.5 pt tall, anchor 250.0)
  CONTENT band = 96.5 .. 108.5 pt   centre 102.50
  BAND SURFACE = 88.5 .. 116.0 pt (28.5 pt tall, anchor 250.0)
content centre : assets 102.25 pt   editor 102.50 pt   DELTA 0.25 pt (tolerance 1.0 pt)
band surface   : assets 88.5..116.0   editor 88.5..116.0   DELTA top 0.00 pt, bottom 0.00 pt (tolerance 1.0 pt)
GATE: PASSED
```

Two things in that run are worth reading together:

- The band SURFACE is measured separately from the content centre, because
  a short band centred in its slot has the RIGHT centre. Measured
  2026-10-23, before the fix: the assets surface was `94.5..110.0` (16.5
  PT) against the editor's `88.5..116.0` (28.5 PT) — a 6.00 PT inset on
  both edges — while the two content centres already agreed to 0.25 PT. A
  centre-only gate calls that a PASS.
- The closing hairline is printed for information and is NOT compared
  across the columns. The surface under a band differs per column (the
  editor's is the white canvas, the assets' is the sidebar background), so
  "the first darker row below the band" is a different thing in each.

## Re-measuring

```
swift Tools/wenshu-devtool/probes/chat_bubble_metrics.swift "Hi"
python3 Tools/wenshu-devtool/probes/column_chrome_band.py <capture.png>
python3 Tools/wenshu-devtool/probes/column_chrome_band.py --selftest
```

The bubble probe exits 0 when the measurement is sound, 2 when the
production source no longer matches what the probe reproduces (no number
is reported), and 3 when the fill was not found in the rendered pixels. A
number that cannot be tied to the source is worse than no number.

The chrome-band probe exits 0 when the two columns' bands agree within the
tolerances, and 1 when they disagree or the capture is unusable. Its
`--selftest` builds three synthetic captures and asserts the gate REJECTS a
short band whose centre agrees — a gate that has only ever passed has no
discriminating power.

## The index's own test

```
python3 Tools/wenshu-devtool/tests/test_probe_index.py
```

The index and the probes directory must agree in both directions: a probe
with no row, and a row with no probe behind it, are both reported.
