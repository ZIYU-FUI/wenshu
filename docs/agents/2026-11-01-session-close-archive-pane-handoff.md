# Session close: the archive pane's data layer, and the review skill's new floor

## The symptom, in the board's own words

The boss asked for an archive pane in Settings, structured like the Hermes
desktop archive page: the history of the agent's own work (sub-agent runs and
board tasks), one list, searchable by which agent and by session type, a
retention-days setting the user owns, cleanup when the retention expires, and
a click into the details of what the agent ran.

The rulings that followed are the contract:

| Ruling | What it settles |
| --- | --- |
| "reference Hermes completely; do not invent agent capabilities, only adjust the UI" | the shape comes from Hermes, not from a Wenshu invention |
| "the todo page's entries vanish when Hermes finishes them, so the setting is how many days to keep before deleting" | retention = delete after N days, not a soft archive |
| "delete, cannot restore, and click into the details to see what the agent ran" | the detail view is the transcript, not a summary |
| "name it the archive, not automation" | the pane is an archive |
| "Hermes's sub-agent IS a session; a task IS also a session; so is ours" | one session type, tagged and filtered, not two tables |
| "our parent sessions are few; all the work is done by sub-agents and tasks" | the archive's rows are the work units, not the chats |
| "P1 must open into the details; P2 add the agent name; P3 the todo is a temporary node and belongs in memory" | click-through, an `agentName` column, no todo archive |

Hermes' own shape was read from the source rather than guessed:
`hermes_state_common.py:461` declares ONE `sessions` table carrying
`source TEXT NOT NULL` and `parent_session_id TEXT`, and
`gateway/session_kanban.py:68` stamps a board task's session with
`source='kanban'`. So the boss's "is a big table or split tables" question
has a reference answer: ONE table, ONE tag.

## The fix, so far

`WSSession` gained the three columns the rulings name, and nothing else ships
yet.

| Column | Carries | Ruling |
| --- | --- | --- |
| `source: String?` | the work kind; nil = an ordinary chat | one session type, tagged |
| `parentSessionID: String?` | the session that asked for the work | walk back to the chat |
| `agentName: String?` | which agent did the work | P2 |

## The two defects this session found and fixed

### 1. SwiftData cannot persist a custom enum

The first draft typed the column `WSSessionSource?`. SwiftData's macro
expansion failed with `requires that 'WSSessionSource' conform to
'PersistentModel'`: a `@Model` property whose type is a Swift enum is
expanded into `getValue(forKey:)`/`setValue(forKey:to:)`, and those demand
`PersistentModel` conformance.

The fix is the house pattern: the COLUMN is a plain `String?` and the
vocabulary is a namespace of static constants, exactly as
`WSCardCoverStatus` does it in `WSCardCover.swift:90`. So
`WSSessionSource` is now a plain `enum` of `static let` strings, and
`WSSession.source` is `String?`.

### 2. The card body template carried a stale cap floor

`templates/kanban-card-body.md` told an author that a review card is "measured
against the review lane's 3600 s floor". The tool that prices the card says
otherwise: `Tools/wenshu-devtool/ticket_tier.py:168` holds
`REVIEW_LANE_CAP_FLOOR = 5400`, and the reference that moved the floor
(`references/the-review-round-is-a-new-card.md`) measures the completing
reviews at p50 30 min, p90 50 min, max 86 min. The template was the last
document still naming 3600, so a creator who followed it built a card the
tool itself reports as a violation. Fixed to 5400.

## The measured result

On the branch `pocock/archive` in the worktree
`/Volumes/ANAN/Engineering/wenshu/.worktrees/archive`:

| Measurement | Value |
| --- | --- |
| `swift build` (whole app) | exit 0 |
| `swift test --filter WenshuDataTests` | exit 0, 141 tests in 32 suites |
| fresh compile of `WSSession.swift` after deleting its object file | exit 0 |
| the diff | 1 file, +61/-1, unstaged |

## A stale build log that is not a regression

A background `swift build 2>&1 \| tail -5` reported `error: Build failed`
after the fix had landed. It is the PRE-fix tree:

- its error names `WSSessionSource` as the `Value` of SwiftData's
  `getValue(forKey:)`, which is only reachable when the property was typed
  `WSSessionSource?`;
- the source's mtime is 00:37:38 and the green build's `WSSession.o` was
  written 00:37:43, so the failing compile predates the fix;
- the pipeline reported `tail`'s exit code (0), not the compiler's, which is
  the trap pitfall 10 in `pocock-pitfalls.md` already names.

The tree does not regress; a log went stale.

## Where this is (the durable fact)

| What | Where |
| --- | --- |
| the data-layer diff | worktree `.worktrees/archive`, branch `pocock/archive`, unstaged |
| the shared-skill template fix | `/Users/anbaiqiang/.hermes/shared/wenshu-skills/wenshu-parallel-dev/templates/kanban-card-body.md` (the shared tree is `/Users/anbaiqiang/.hermes` -> `/Volumes/ANAN/.hermes`) |
| this closure doc | `docs/agents/2026-11-01-session-close-archive-pane-handoff.md` |
| the boss's rulings | the session's own messages 129594, 129681, 129730, 129768, 129786, 129897 |

## The open items, on purpose

**Nothing here is a ticket yet.** The archive feature is NOT done, and the
pieces below are the work that remains. They are listed as steps, not as a
summary, because a next session should be able to start from the first one
without re-deriving anything.

1. **The producer.** Nothing in the tree writes a session's `source`, so the
   archive list would render empty. The sub-agent run is the seam: when a
   delegation finishes, write a session row carrying `source`, `agentName`,
   `parentSessionID` (from the handle's `scope`), and the transcript as
   `WSChatMessage` rows under it. The raw material already exists at
   `SubAgentRunner.swift:355` (`result.messages`).
2. **The transcript's role vocabulary.** `LiveChatRepository.makeDomain`
   maps only `"user"`, `"wenshu"` and `"system"`; every other `role` returns
   nil and the row is dropped. A sub-agent's tool calls and tool results must
   land inside those three, or the click-through detail view (P1) shows
   nothing.
3. **The read path.** A query that lists the sessions carrying a tag, filtered
   by `agentName` and by kind.
4. **Retention and cleanup.** The house shape is the memory pane: a closed set
   of 30/90/180/365 days in `MemoryAdapter.DefaultsKey.retentionDays`, and a
   change to the setting triggers the purge. Hermes' own default is 3 days
   (`DEFAULT_AUTO_ARCHIVE_DAYS` in `sessions-settings.tsx`); the boss's
   Q2 answer says the setting is "how many days before deleting".
5. **The pane.** A ninth `SettingsPane` case, its icon, its localized title,
   the list, the click-through detail, and the delete action.
6. **Two tripwires that the ninth pane breaks.** `IconStylesTests.swift:246`
   asserts the settings scene declares exactly 8 `SettingsPane` cases and
   names each one; it must become 9. The `Localizable.xcstrings` catalog has
   zero `settings.archive` keys today.
7. **A disk-backed migration test.** `Container.swift` says SwiftData handles
   an additive change (new optional properties) without a
   `SchemaMigrationPlan`, and AGENTS.md 4.4 agrees that an additive change
   needs no plan. There is NO on-disk migration test in the repo, so that
   claim is documentation, not evidence. A user's existing library opening
   with the new columns is unproven.

**One decision the boss still owes.** The board's tasks have no session
producer today (the boss's own words: "we do not let other agents out yet"),
so a task column in the archive would be empty unless the task's producer
ships with it. Either this version ships the sub-agent sessions only, leaving
the tag vocabulary ready for the task kind, or the task producer ships in the
same batch. The first is recommended: the sub-agent half is a real producer
today, so it can close the P1 loop in one slice.

## The review card, when the work lands

The review lane's rules were re-read this session and the new ones bind:

- the card's cap is the lane's floor (5400 s), not the tier's number;
- the card's WRITE SET is empty (= the files under review go in the
  exclusion section, named by what they are; the paths it reads go in the
  evidence budget);
- the body names what an earlier card already measured, bounds a
  non-reproducing number at 15 minutes, and names `git show <sha>:<path>` as
  the authoritative read;
- `main` is frozen while the card runs;
- a rejected card is DONE, so a rework round is a NEW card naming the new
  shas.
