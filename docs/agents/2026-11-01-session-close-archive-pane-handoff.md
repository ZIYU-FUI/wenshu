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

## The four defects this session found and fixed

### 1. SwiftData cannot persist a non-Codable custom enum

The first draft typed the column `WSSessionSource?`. SwiftData's macro
expansion failed with `requires that 'WSSessionSource' conform to
'PersistentModel'`: a `@Model` property whose type is a Swift enum is
expanded into `getValue(forKey:)`/`setValue(forKey:to:)`, and those demand
`PersistentModel` conformance.

The constraint is a NON-Codable Swift enum, not a Swift enum: measured on
this toolchain, `enum Kind { case agent }` fails with exactly those two
errors, while `enum Kind: String, Codable` compiles and its value survives
a real `ModelContainer` round-trip (= including a fresh context, = the
reload path). So the reason a plain enum fails is its missing `Codable`
conformance, not its being an enum.

One more rule the reproduction hits, so it is written down here: a `@Model`
property's default that NAMES A MEMBER must be written fully qualified.
`var kind: Kind = Kind.agent` compiles; `var kind: Kind = .agent` fails with
"A default value requires a fully qualified domain named value (from macro
'Model')". A LITERAL default needs no qualification (= `var count: Int = 0`
and `var title: String = "hello"` compile in the same model), so the rule is
about naming a member, not about defaults in general. That is a second macro
rule, separate from the `PersistentModel` one above, and it has nothing to do
with the enum's conformances.

The fix is the house pattern, and it is unaffected by that measurement: the
COLUMN is a plain `String?` and the vocabulary is a namespace of static
constants, exactly as `WSCardCoverStatus` does it in
`WSCardCover.swift:90`. So `WSSessionSource` is now a plain `enum` of
`static let` strings, and `WSSession.source` is `String?`.

### 2. The card body template carried a stale cap floor

`templates/kanban-card-body.md` told an author that a review card is "measured
against the review lane's 3600 s floor". The tool that prices the card says
otherwise: `Tools/wenshu-devtool/ticket_tier.py:168` holds
`REVIEW_LANE_CAP_FLOOR = 5400`, and the reference that moved the floor
(`references/the-review-round-is-a-new-card.md`) measures the completing
reviews at p50 30 min, p90 50 min, max 86 min. The template was the last
document still naming 3600, so a creator who followed it built a card the
tool itself reports as a violation. Fixed to 5400.

The same stale floor also sat in the reference that STATES the rule
(`references/review-lane-cap-is-not-the-implementation-cap.md`), so a reader
of the rule saw two different floors. Fixed to 5400 in both places.

### 3. A manifest declaration the package manager never reads

The `mem0` provider's backend failed to initialize in the serving process
(`No module named 'sentence_transformers'`), so `mem0_search` and
`mem0_add` returned "Mem0 backend not initialized" while still registering
their tool schemas.

The plugin's `plugin.yaml` DID declare `sentence-transformers>=3` in
`pip_dependencies`. The declaration was simply never read: the PM's reader
(`pm/plugin_declarations.py::read_python_declaration`) returns a plugin's
`pyproject.toml` `[project] dependencies` when that file exists and was not
PM-generated, and never falls back to the manifest's `pip_dependencies`. So
the installed set was `mem0ai` + `httpx` only, in every environment built
after that edit, while the environment built before it carried the whole
stack.

The proof that needs no rebuild: `read_python_declaration(plugin_dir)
.install_requirements` prints the set the PM will actually install, and it
named no embedder. The fix declares the dependency where the PM reads it
(= each plugin copy's `pyproject.toml`), and the reader now reports it.

The rebuild that installs it, and the process restart that activates it,
are left to a moment when no board card is in flight (= a gateway restart
destroys every running worker). The memories this session wrote went in
through the provider's OWN path (= `_backend.OSSBackend` -> `mem0.Memory` ->
qdrant) in a fresh process, and a search through the same path finds them.

### 4. The tag constant held a value no Hermes producer writes

The review round caught this one, and it was a real defect rather than a
wording problem. The constant read `WSSessionSource.agent = "agent"`, and
the commit body, the file's own doc comment and this record all claimed it
held "the value Hermes writes into its `source` column".

Hermes does not write that value. It reserves `'subagent'` for delegated
children (`hermes_cli/session_listing.py:13` names it
`SUBAGENT_SOURCE`), and a board task's session reads `'kanban'`. Measured
across Hermes' three live stores: `source='agent'` holds 0 rows, and no
Hermes PRODUCER writes `'agent'` into a session row's source column.

**Which value a delegated child's row carries depends on the path, so the
durable facts are the producers and the precedence, not a census of the
live stores.** Hermes has two delegate paths, and BOTH can write
`'subagent'`:

- The **reserved / worker** path stamps the row's source literally:
  `agent/runtime_session_child.py:32` and `gateway/session_worker_child.py:63`
  both write `'subagent'`.
- The **in-process** path builds the child with `platform="subagent"`
  (`tools/delegate_tool.py:296`), and the row's source comes from
  `session_source_for(self.platform)` at `run_agent.py:319`. That function
  (`agent/session_source.py:34-42`) normally returns the **inherited**
  `HERMES_SESSION_SOURCE` BEFORE the platform, so a parent whose env says
  `desktop` produces a child row reading `'desktop'`, likewise `'tui'`,
  `'local'` and `'kanban'`.

**The precedence has one exception, and it is the one that matters here.**
`agent/session_source.py:36-39` drops an inherited `tui` or `desktop` label
when the one-shot marker is set (`HERMES_SINGLE_QUERY_SESSION=1`), and then
the platform's `'subagent'` wins. Measured with Hermes' own function:

| parent env | clean | one-shot marker set |
| --- | --- | --- |
| `desktop` | `desktop` | **`subagent`** |
| `tui` | `tui` | **`subagent`** |
| `local` | `local` | `local` |
| `kanban` | `kanban` | `kanban` |
| (empty) | `subagent` | `subagent` |

The marker is set by `hermes_cli/cli_single_query.py:496` (`hermes chat -q`)
and `hermes_cli/oneshot.py:280` (`hermes -z`), and a one-shot session DOES
delegate (= `ONESHOT_DISABLED_TOOLSETS` keeps `delegate_task`,
`agent/oneshot_footprint.py:28`). So the in-process path writes
`'subagent'` too, whenever the parent's label is `tui` or `desktop` under the
one-shot marker. That is not a corner case to be argued away: it is the
configuration the one-shot lane runs in.

Both paths are live at once, so the stores show the mix rather than one
value: the delegated rows (= every row whose `parent_session_id` matches
`json_extract(model_config,'$._delegate_from')`, with `_branched_from` and
`_reset_from` NULL) read a mix of `'subagent'` and the parent's surface
label. No `kanban` row in any of the three stores carries a parent at all.
(= the store carries no field that separates the two paths, so which path
wrote which row is an inference from the code, not a measurement.)

So the constant now holds `subagent`, and its doc comment names the two
Hermes sites that reserve it and the path that writes it. The test that
named the claim could not have caught the gap: it compared the constant to a
literal sitting in the same test file, so it proved only that two copies
agree. It now pins the value from OUTSIDE the assertion's subject, so a
divergence from Hermes' vocabulary fails the suite.

The value is not in question here: `'subagent'` is the string Hermes
RESERVES for delegated children (`SUBAGENT_SOURCE`) and the one its
reserved / worker path writes. What this record will not claim is that every
delegated child's row reads it.

## The measured result

Measured on the tree this session's commit carries (= the branch `pocock/archive`
at the commit whose subject is `feat(archive): the session table carries what
kind of work it records`):

| Measurement | Value |
| --- | --- |
| `swift build` (whole app) | exit 0 |
| `swift test --filter WenshuDataTests` | exit 0, 143 tests in 32 suites (= 141 before this session's two new cases) |
| fresh compile of `WSSession.swift` after deleting its object file | exit 0 |
| the settings scene's 8-pane tripwire (`IconStylesTests`) | passes (= this change adds no pane) |

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
| the data-layer change | the commit on the branch `pocock/archive` whose subject is `feat(archive): the session table carries what kind of work it records`; it is an ancestor of `refs/heads/pocock/archive` on BOTH remotes (`origin` = `gitcode.com:ZIYU1983/wenshu`, `old-origin` = `github.com:ZIYU-FUI/wenshu`) |
| the review card | the board card whose body names that commit's sha (= the one review card this session created) |
| the shared-skill template fix | `/Users/anbaiqiang/.hermes/shared/wenshu-skills/wenshu-parallel-dev/templates/kanban-card-body.md` (the shared tree is `/Users/anbaiqiang/.hermes` -> `/Volumes/ANAN/.hermes`) |
| the shared-skill reference fix | `.../wenshu-parallel-dev/references/review-lane-cap-is-not-the-implementation-cap.md` (= the same stale 3600 s floor, in the reference that states the rule) |
| the dependency fix | the `mem0` plugin's `pyproject.toml` in each of the three plugin copies (= see the mem0 note above) |
| this closure doc | `docs/agents/2026-11-01-session-close-archive-pane-handoff.md` |
| the boss's rulings | the session's own messages 129594, 129681, 129730, 129768, 129786, 129897 |

## The open items, on purpose

**Nothing here is a ticket yet.** The archive feature is NOT done, and the
pieces below are the work that remains. They are listed as steps, not as a
summary, because a next session should be able to start from the first one
without re-deriving anything.

1. **The producer.** Nothing in the tree writes a session's `source`, so the
   archive list would render empty. The sub-agent run is the seam: when a
   delegation finishes, write a session row carrying `source` (= the
   `WSSessionSource.subagent` tag, = the value Hermes writes for the same
   kind of work), `agentName`, `parentSessionID` (from the handle's
   `scope`), and the transcript as `WSChatMessage` rows under it. The raw
   material already exists at `SubAgentRunner.swift:355` (`result.messages`).
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

**THE RECORD WAS CORRECTED IN A SECOND COMMIT, AND THAT MOVES THE REVIEW'S
FOOTING.** The measured table above was written while the change was still
unstaged, so it named "unstaged", a file count and a test count that the
commit made stale (= the house rule: a closure record states DURABLE facts,
never tips). Correcting it is a second commit on the branch, and a second
commit changes the branch's EDIT (= the gate's identity is the diff from
where the branch left `main`, so the correction is part of it). Measured:
the identity of the branch tip with the correction is NOT the identity of
the sha the running card names, so the running verdict does NOT cover the
corrected tip.

So the corrected tip needs its own review card, exactly as a rework round
does (= the rule above). The card this session created carries the FIRST
commit's sha; the correction's card names the sha that carries the
correction. Both are named in the board comment on the first card, so the
next reader sees the pair.
