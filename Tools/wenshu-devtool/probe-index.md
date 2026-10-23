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

## Recorded measurement

The run below is the proof that the row above carries a real number. It is
the probe's own output, taken against commit `3ee82bf48b18`, with the
subject `Hi` at the reference host width.

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

## Re-measuring

```
swift Tools/wenshu-devtool/probes/chat_bubble_metrics.swift "Hi"
```

The probe exits 0 when the measurement is sound, 2 when the production
source no longer matches what the probe reproduces (no number is reported),
and 3 when the fill was not found in the rendered pixels. A number that
cannot be tied to the source is worse than no number.
