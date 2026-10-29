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
| `editor_chat_arrangement.py` | The editor and chat zone's arrangement (= which pane is where), read from the running app's accessibility tree as native coordinates: the chat's composer, the editor's toolbar, and the editor's body. It names the arrangement from those coordinates and checks the production fragments it reproduces before it reports a number. | `composer_x`, `composer_y`, `editor_toolbar_x`, `editor_toolbar_y`, `editor_body_x`, `editor_body_y`, `arrangement`, plus `requested_mode` and `agreement` | `560c70ae51` |
| `toolbar_preference_change.py` | The main window's toolbar after the app's preferences changed: the app's own Settings scene is driven through the accessibility tree, its group rows are switched N times (= N app-preference changes), and the process is watched for the abort AppKit raises when a window asks for more "Update Constraints in Window" passes than it has views. | `switches_landed`, `survived`, `pane_after`, `unresolvable_symbol_faults`, `max_update_constraints_count`, `layout_loop_warnings`, `new_crash_reports`, `other_crash_reports`, plus `bundle`, `bundle_id`, `executable`, `pid`, `instance_owned` and `source_commit` | `37e941c604` |
| `toolbar_preference_change.swift` | RETIRED AS A GUI DRIVER (2026-10-29: the AX press takes the operator's mouse and foreground; the GUI drive goes through the CUA tool). The accessibility driver the toolbar probe runs: it opens the app's own Settings scene, selects its group rows through the accessibility tree, and verifies every switch against the persisted group key, so a driver that silently did nothing cannot report a pass. It drives the PID it is given and never re-derives one from a path, because every build of the app ships the same bundle id and a path does not name an instance. It checks that the running instance claims the bundle id it was given, because the preferences it reads live in the domain of that id. | `group_rows`, `strategy`, `switches_landed`, plus the group and pane of each round | `37e941c604` |

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
describe. The band itself lives in `ChromeTopBar.swift` and
`EditorFormatToolbar.swift`, and both are byte-identical from that commit
to `main` today, so the numbers still describe a later tree.
`AssetsPane.swift` HAS changed since (= three commits: = the cards, = the
cover, = the column's bottom bar), = but none of them touches the band or
the search row, = so the band's geometry is the one the numbers describe.

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

### `editor_chat_arrangement.py`

Taken against commit `560c70ae51`, on the running app's own
accessibility tree (= no screenshot; = the tree's coordinates are the
measurement).

```
probe: editor_chat_arrangement
source_commit: 560c70ae51
source_fragments: 8/8 match
pid: 69568
bundle_id: com.wenshu.app
requested_mode: automatic
composer_x: 856
composer_y: 930
editor_toolbar_x: 714
editor_toolbar_y: -30
editor_body_x: 706
editor_body_y: -2
arrangement: stacked
agreement: the automatic mode follows the width (= no fixed arrangement)
GATE: PASSED
```

Two things in that run are worth reading together:

- `source_fragments: 8/8 match` is the probe's own refusal: = it
  reproduces the production fragments it measures (= the preference key,
  = the three modes, = the width rule's thresholds, = the autosave
  names), = and it prints no number when one of them disagrees with the
  live source. = The numbers below describe the tree the probe read.
- `arrangement: stacked` with `requested_mode: automatic` and
  `agreement: the automatic mode follows the width` is not a
  contradiction: = in the automatic mode the arrangement follows the
  window's width, = so a narrow window stacks the panes and a wide one
  puts them side by side, = and the probe reports which one it found.

### `toolbar_preference_change.py`

Taken against commit `37e941c604`, the commit that gave the inspector's
toggle a symbol the system has. The app source the numbers describe is
that commit's: `InspectorView.swift` and `SettingView.swift` are
byte-identical from it to `main` today, so the numbers still describe a
later tree. The probe prints the tree it ran in as `source_commit`, so a
re-run on a later tree prints that later tree.

The run was given a RELATIVE bundle path, with another copy of the same
bundle id already running at another path. That is the case the probe
used to answer with "the app did not launch".

```
bundle: /Volumes/ANAN/Engineering/wenshu/.worktrees/t_58e0967a/build/Wenshu.app
bundle_id: com.wenshu.app
executable: /Volumes/ANAN/Engineering/wenshu/.worktrees/t_58e0967a/build/Wenshu.app/Contents/MacOS/WenshuApp
pid: 7597
instance_owned: yes
pane_before: network
opened_settings: yes
group_rows: 8
strategy: AXSelected
switches_landed: 10/10
SURVIVED
survived: yes
pane_after: network
unresolvable_symbol_faults: 0
max_update_constraints_count: 0
layout_loop_warnings: 0
new_crash_reports: none
other_crash_reports: none
GATE: PASSED
```

Three things in that run are worth reading together:

- The probe named the instance it drove by the REAL executable path, so
  the other copy at another path was never a candidate. Before the fix
  the probe matched a PATTERN over the command line, and the relative
  path `build/Wenshu.app/Contents/MacOS/WenshuApp` is a suffix of every
  worktree's build: measured 2026-10-24, that pattern named two
  processes, one of them another worktree's.
- `instance_owned: yes` and the other session's instance still running
  afterwards are the same fact seen from both ends. The probe stopped
  the PID it started and nothing else, so no `pkill` by name took the
  other copy with it.
- `other_crash_reports` counts the crash reports of this app that
  belong to a different process, and `new_crash_reports` the ones that
  belong to this run's PID. A crash of another copy of the app is
  neither.

## The constraint a probe that launches the app must obey

A probe that starts the app owns ONE process: the one it started, and it
must prove which process that is. On this machine the app ships the same
bundle id from every build, so a path does not name an instance.

  * The bundle id comes from the bundle's own Info.plist, and the
    instance is located through LaunchServices' own table
    (`lsappinfo`). A copy of that id at another path is reported as
    "another copy", never as a missing app.
  * The process is found by its REAL executable path (the process
    table's `comm`, compared whole) and by the PID that owns it. A
    pattern match over the command line cannot do this: a relative path
    such as `build/Wenshu.app/Contents/MacOS/WenshuApp` is a SUFFIX of
    every other worktree's build, so `pgrep -f` names another build's
    process. Measured 2026-10-24: the relative pattern matched two
    processes, one of them another worktree's. The path the probe
    compares against is the RESOLVED one, so a relative bundle path
    cannot degrade into a suffix match.
  * The driver takes the PID as its argument and never re-derives one
    from a path. `NSRunningApplication.executableURL?.path` is
    ABSOLUTE, so an exact comparison against the path as it was typed
    never matches a relative path. The bundle id travels with the PID
    because the preferences the driver reads live in the domain of that
    id, and the driver checks that the running instance claims it.
  * A crash report counts as the run's only when the report names the
    run's PID, so another session's crash is never read as this run's.
  * The probe stops the PID it started and NOTHING else: no `pkill` by
    name and no `pkill` by pattern. `pkill -x WenshuApp` kills every
    copy on the machine, including the instance another session is
    using. Before the probe signals a PID it checks that the PID still
    runs this bundle's binary, because a PID the system handed to
    another process in the meantime is not the probe's to stop.

A probe that reports "the app did not launch" without saying which
copy the system resolved to is a harness error, not a measurement. So
a probe that cannot find its instance names the copies the system holds
for that bundle id: the ones running now, and the ones registered with
LaunchServices. Measured 2026-10-24: the system held 87 registered
bundles for this bundle id, 10 of them on disk.

## Re-measuring

```
swift Tools/wenshu-devtool/probes/chat_bubble_metrics.swift "Hi"
python3 Tools/wenshu-devtool/probes/column_chrome_band.py <capture.png>
python3 Tools/wenshu-devtool/probes/column_chrome_band.py --selftest
python3 Tools/wenshu-devtool/probes/toolbar_preference_change.py --selftest
python3 Tools/wenshu-devtool/probes/toolbar_preference_change.py <app-bundle> [rounds]
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

The toolbar probe exits 0 when the app survived with no crash report of
its own and no unresolvable symbol name, 1 when it crashed, died, or
logged an unresolvable symbol name, and 2 when the probe could not put
the driver in front of a known instance. Its `--selftest` asserts the
identity rules on fixtures, and every case calls the function the probe
itself calls: that a pattern match over the command line names both
builds where the whole-path match names one, that a resolved relative
path still names one build, that an instance of the same bundle id at
another path is reported as another copy rather than as ours, that a
crash report of another process is not this run's crash, and that a PID
the system handed to another process is not the probe's to stop.

## The index's own test

```
python3 Tools/wenshu-devtool/tests/test_probe_index.py
```

The index and the probes directory must agree in both directions: a probe
with no row, and a row with no probe behind it, are both reported.
