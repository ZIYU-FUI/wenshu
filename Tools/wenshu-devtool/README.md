# wenshu-devtool

Remote dev tool for wenshu macOS app. Hermes `tui_gateway` pattern: a standalone Python process that uses Apple standard APIs (`osascript` / `screencapture` / `defaults` / `security`) to read wenshu NSWindow + UI state.

**Core principles (老板 8/19 truth source):**
- Does not embed wenshu core (does not modify `Sources/WenshuApp/`)
- Does not modify `Package.swift` (Tools/ is not part of Swift sources)
- Does not modify `Scripts/build-app.sh`
- Does not enter the wenshu release bundle (`build/Wenshu.app/Contents/Resources/` does not contain devtool)
- At release: simply delete the `Tools/wenshu-devtool/` directory, no need to change wenshu core

## Usage

```bash
# 1. List wenshu NSWindow truth source
python3 Tools/wenshu-devtool/wenshu_devtool.py list_windows

# 2. Screenshot a specific wenshu NSWindow
python3 Tools/wenshu-devtool/wenshu_devtool.py screenshot <window_id> <output.png>

# 3. Dump frontmost window UI tree (System Events UI elements)
python3 Tools/wenshu-devtool/wenshu_devtool.py ui_dump

# 4. Dump menu bar (Apple / 文枢 / File / Edit / View / Window / Help)
python3 Tools/wenshu-devtool/wenshu_devtool.py menu_dump

# 5. Dump UserDefaults (provider / model / appearance)
python3 Tools/wenshu-devtool/wenshu_devtool.py settings_dump

# 6. List ProviderKeychain's stored providers
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_list

# 7. Return provider key (masked, only first 4 + last 4 shown)
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_get openrouter
```

## Front-end measurement

A separate tool, because it measures the app's own source tree instead of
the running app.

```bash
# 8. Measure the front end's parameter drilling (= dead parameters + heaviest initializers)
python3 Tools/wenshu-devtool/measure-drill.py --root Sources/WenshuApp

# 8b. Only the heaviest N call sites
python3 Tools/wenshu-devtool/measure-drill.py --root Sources/WenshuApp --top 10
```

It reads the Swift source, strips comments and string literals, and
reports the initializer parameters that are declared, passed down through
their call sites, and never read. Its own test suite runs on fixtures:

```bash
python3 Tools/wenshu-devtool/tests/test_measure_drill.py
```

## Visual probes

`Tools/wenshu-devtool/probes/` holds the measurements that outlive their
session: one file per measurement, named after what it measures, so a
worker told to "measure the bubble" finds the last worker's measurement
instead of writing its own. `Tools/wenshu-devtool/probe-index.md` lists
every probe with the commit its numbers came from, because a number
measured against one commit does not describe a later commit.

```bash
# 10. The chat bubble's painted width and corner radius, from rendered pixels
swift Tools/wenshu-devtool/probes/chat_bubble_metrics.swift "Hi"

# 11. Whether two neighbouring columns share one chrome band, from a 2x capture
python3 Tools/wenshu-devtool/probes/column_chrome_band.py <capture.png>

# 12. Prove that gate has teeth (it must REJECT a short band whose centre agrees)
python3 Tools/wenshu-devtool/probes/column_chrome_band.py --selftest
```

The index's own test proves the index and the probes directory agree in
both directions (= a probe with no row, and a row with no probe behind it,
are both reported):

```bash
python3 Tools/wenshu-devtool/tests/test_probe_index.py
```

## Ticket difficulty tier

Another separate tool, because it measures a card body instead of the
source tree. It derives a card's difficulty tier (T1 trivial / T2 standard /
T3 deep) from the work the body describes, and prints the runtime cap, the
retry budget and the gate that tier buys.

```bash
# 9. The tier contract (= the caps, the budgets, the gates)
python3 Tools/wenshu-devtool/ticket_tier.py --plan

# 9b. Rate a card body before dispatching it
python3 Tools/wenshu-devtool/ticket_tier.py --body card.md

# 9c. Check every card on the board against the tier it earns
python3 Tools/wenshu-devtool/ticket_tier.py --board wenshu-par --check
```

Its test suite runs on fixture bodies:

```bash
python3 Tools/wenshu-devtool/tests/test_ticket_tier.py
```

The tier's contract and the measurements behind its numbers are in
`docs/agents/ticket-tiers.md`.

**A card in the review lane is held to the review lane's own floor, not to
its tier's cap.** A review run re-reads the diff, re-derives the acceptance
and re-runs the gates, so it is slower than the implementation it audits:
measured on this board, the review runs on a 1500 s cap died at 25.1 min
(seven of them) and a review on a 3600 s cap completed at 27 min. So a card
whose status is `review` must carry at least 3600 s, and a card carrying more
is generous rather than wrong. The floor belongs to the lane, so it does not
move with the card's tier.

## Dead-code gate

Another separate tool, because it measures the source tree instead of the
running app. It reports the types no file can reach: a type whose name
appears in no other file is a candidate only when nothing reads it either
(= no member read, no value received from a called function, no use in its
own file).

```bash
# 13. Scan the view tree for unreachable types
python3 Tools/wenshu-devtool/verify-dead.py --ui-components

# 13b. Why one type is alive (= the reader that reaches it)
python3 Tools/wenshu-devtool/verify-dead.py --ui-components --verbose \
    Sources/WenshuApp/Features/Editor/Service/WordCounter.swift
```

With no file arguments the scan covers the view tree (= every
`Features/*/View` directory plus `Shared/UI`), and it names the
directories it scanned. A directory that does not exist is skipped, so a
moved directory never breaks the scan. With file arguments it checks
exactly those files. The exit code is non-zero when it finds a deletion
candidate.

Its test suite runs on fixture trees:

```bash
python3 Tools/wenshu-devtool/tests/test_verify_dead.py
```

## Independent-review gate

Another separate tool, because it reads the BOARD instead of the source tree.
It answers the two questions the review contract needs:

- **CONTRACT** = what the card owes: does the body write code, and does it
  name a reviewer profile that is not the implementer?
- **RECORD** = what the board holds: is there an approving verdict, and which
  profile gave it? The verdict lives in ONE field of the approving run's
  metadata (`review_outcome: "approved"`), so a verdict written in the run's
  summary is not a verdict the gate can see, and the field is never
  backfilled by hand.

The obligation to get an independent verdict is DERIVED from the work the body
describes, never hand-set, and it is independent of the difficulty tier: a
T1 code card and a T3 code card owe the same verdict, and a prose card owes
none. That is not a preference. Measured on board `wenshu-par`, 2026-10-26:
113 of 114 done cards carried ZERO review events, the one review that did run
was the implementer reviewing itself, and 5 done cards promised files their
branch does not contain (= a false done) — all 5 wrote code, 0 wrote prose.

```bash
# 14. What does this body owe (= before dispatching it)
python3 Tools/wenshu-devtool/review_gate.py --body card.md

# 14b. What does the board hold for this card
python3 Tools/wenshu-devtool/review_gate.py --card t_xxx

# 14c. Every card on the board
python3 Tools/wenshu-devtool/review_gate.py --board wenshu-par --check
```

Its test suite runs on fixture bodies and fixture board records:

```bash
python3 Tools/wenshu-devtool/tests/test_review_gate.py
```

Exit code: 0 = the gate is satisfied, 1 = a contract error, 2 = the board could
not be read, 3 = a card owes a verdict it does not have. The merge gate
(`Scripts/merge-preflight.sh`) runs the record check for the branch it is
asked to bless and refuses the merge until the verdict is on the record.

## AGENTS.md contract gate

Another separate tool, because it reads the SSOT instead of the source tree
or the board. It answers one question: is AGENTS.md still loadable and true?

- **frontmatter** parses as YAML, and carries name / version / description
- **budget** the file fits the loader's cap (20,000 chars) AS THE LOADER
  READS IT: the whole file, frontmatter included, plus the `## AGENTS.md`
  label. The cap drops the MIDDLE of a file that is too long, so a
  body-only budget would pass a file whose middle rules silently vanish.
- **references** every path the file names exists, and every skill it names
  is installed
- **vocabulary** CJK appears only in the rules that enumerate the vocabulary
  (1.2 / 1.3 / 1.4), and only as a token from that vocabulary
- **ids** the rule ids of each section are contiguous, no row id is
  duplicated, and every internal section reference resolves
- **structure** the required sections (§1 / §7 / §8 / §10) are present

```bash
# 15. Is AGENTS.md still loadable and true?
python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md

# 15b. The same verdict, machine-readable
python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md --json

# 15c. What the gate checks (= the contract it enforces)
python3 Tools/wenshu-devtool/agents_gate.py --plan
```

Its test suite runs on fixture files:

```bash
python3 Tools/wenshu-devtool/tests/test_agents_gate.py
```

Exit code: 0 = the file is loadable and true, 1 = a contract error, 2 = the
file could not be read.

## Requirements

- macOS (uses `osascript`, `screencapture`, `defaults`, `security`)
- Python 3.9+ (no third-party deps, stdlib only)
- WenshuApp running (for `list_windows` / `screenshot` / `ui_dump` / `menu_dump`)

## Security

- `keychain_get` output only shows the first 4 + last 4 characters (does not expose the full key)
- No log writes (= `print(json.dumps(...))` is not persisted)
- Does not modify any file (= read-only)
- Requires macOS Screen Recording / Accessibility permission (System Settings → Privacy & Security → Screen Recording / Accessibility)

## Release

老板 拍 "for real release we remove it" themselves:
- Delete the `Tools/wenshu-devtool/` directory
- No need to change `Sources/WenshuApp/` / `Package.swift` / `Scripts/build-app.sh`
- wenshu release bundle auto-excludes devtool