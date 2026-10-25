# Session close — 2026-10-26 — the import chain lands, and the turn's failure surfaces

> Boss directives 2026-10-25 to 2026-10-26 (rendered in English per rule 1.1):
> the markdown import must really write to disk, into the folder the user picked;
> the import runs through an agent (= a sub-session, = a clean context, = a fixed
> procedure) and the agent is the only writer; the library import must call the
> search tool to verify its content; the library's browse surface is two levels
> (= 22 categories, = exclusive tags), with semantic badges, and the subcategory
> sharpens the decision without being shown; the editor's left column becomes
> three parts (= the shelf, = the library, = the reference shelf) with the
> selection of each part remembered; an import may be slow, but it must not
> produce a program error, and the user has to see the progress; "the usage is
> restored, continue"; "wrap up the session".
>
> Sessions: the wenshu-par board's ten cards for this arc, plus this session's
> own nine commits. Closure type: production source changed (nine commits),
> one skill reference added, one closure doc.

## 1. What landed

| # | Deliverable | Where | Card |
|---|-------------|-------|------|
| 1 | The write tool has a declaration the model can see, and it is registered | `WriteBookDocTool`, `ImportAgentDriver`, `ToolRegistryBootstrap` | `t_808a8ab8` |
| 2 | The import turn runs with a clean context, on the model the user picked | `ImportAgentDriver`, `ImportModelPinnedConnector` | `t_ee51256a` |
| 3 | Every book folder has its own procedure (= six of them) | `Sources/WenshuApp/Resources/SOPs/Import*Prompt.md`, `ImportSOPLoader` | `t_a7eb967c` |
| 4 | The user's folder wins, and the agent is the only writer | `WriteBookDocTool`, `ImportServiceBookTree` | `t_240f4810` |
| 5 | One library call produces the whole entity, verified against the web | `ImportReferenceLibraryRouter` | `t_7821d6f4` |
| 6 | The tags sit under the library categories, each in exactly one | `SidebarService`, `EntityCategory` | `t_823fd8f1` |
| 7 | Each part of the sidebar remembers its own selection | `WorkspaceUIState`, `UserDefaultsStore` | `t_6073b4f8` |
| 8 | The left column has three parts, switched by a segmented control | `AppleSidebarView`, `LabelSegmentedControl` | `t_c2f74627` |
| 9 | The import sheet shows the agent's reply the way the chat zone does | `ImportAgentReplyView`, `ImportAgentPartEmitter` | `t_18558d3e` |
| 10 | An imported reference carries the category the model chose | `ImportReferenceLibraryRouter`, `EntityClassifier` | `t_7e1577f2` |

The nine commits of this session's own arc (`b33a7db153` → `fe2940da5`) carry the
failure-surface work: the refusal becomes visible, the thinking budget reaches
the wire, the pin keeps the request's settings, the driver degrades on a
refusal and counts the writes that landed, and the reader keeps the default
session it always had.

## 2. The root causes behind "the import finished and wrote nothing"

Five separate faults sat behind one symptom. Each is now fixed, and each has a
test that fails without its fix.

1. **The provider's refusal was swallowed.** The SSE reader threw the status
   away, the wireup finished the stream without a word, and the caller saw a
   turn that looked like a model that said nothing. The reader now keeps the
   provider's body, and the wireup puts the failure into the stream (= the
   reply carries it).
2. **The tool the model was told about did not exist in the request.** A
   handler without a declaration is never called: the turn answered in plain
   text, wrote nothing, and reported success.
3. **The thinking budget never reached the wire.** The pin wrapper rebuilds the
   call options, and the field it was not taught was dropped there; the
   Minimax body shape had no place for the key at all.
4. **A call was counted as a write.** The driver counted the tool CALLS, so a
   run whose every write was refused (= a wrong path, = a missing folder, = a
   full disk) reported success with no file on disk. The count now comes from
   the handler, because the turn's final messages are the compressed history
   and the tool answers are gone from them.
5. **Every thrown error was read as a provider refusal.** A tool that threw
   `pathGuardViolation` was reported as a token-budget problem, three times,
   with a halved budget each time.

## 3. The measured before and after

| Measure | Before | After |
| --- | --- | --- |
| Live book import | zero files, reported as success | 8-10 documents, all inside the folder the user picked |
| Live library import | zero entities | a whole entity per file, with 2-4 web searches behind it |
| A refused write | reported as success | an error that names the provider's own words |
| Targeted suite (= import, write-to-disk, rollback, refusal ladder, pin, SOP, tool registry) | — | 20/20 green |
| Full suite, same command on both trees | baseline `15901058d`: 30 failures | this tree: 12 failures, and every one of the 12 is also in the baseline (= new failures 0) |

Two of the twelve are the live-provider tests, which fail because the machine
has no DNS (= §4).

## 4. Open gaps (= the environment, and one card)

**The machine lost its DNS, and the app cannot reach any provider.** Clash
Verge's core is not running (= only the privileged helper is), its TUN mode
still hijacks DNS, and the hijacked listener answers nothing:
`scutil --dns` reports "No DNS configuration available", the proxy's ports are
not listening, and the Wi-Fi's DHCP lease carries no resolver. `curl` and
`dig` still resolve (= they take a different path), so the symptom is
specific: every URLSession client on this machine fails with `-1003`, and the
Wenshu app is a URLSession client. The fix is on the machine, not in the
tree: restart Clash Verge (= or turn its TUN off, = or re-connect the Wi-Fi,
= or set a resolver with `networksetup`). Until then the last live round
cannot be re-run; `live_verify.sh` in the session scratch runs it the moment
the network is back, and exits 2 (= no code verdict) while it is down.

**One card stays blocked, and it is not this arc's work.** `t_798b4132` (= the
provider protocol mappings for the cover dialects) gave up twice: the worker
profile's model slug is rejected by the provider, and the card's body needs
the official documentation, which the machine cannot fetch either. Its
deliverable is not in the tree. The card is prose, so it ends with
`kanban_complete` once a model slug and a network exist; the reason is
recorded on the card.

**Content quality is the owner's call.** The generated documents and the
chosen categories (= a poet filed under a person category and an entity type)
are mechanically correct and readable; whether they taste right is a review
the owner does in person.

## 5. The skills that carry the lesson forward

`wenshu-pocock-workflow/references/wenshu-agent-turn-failure-surfaces.md`
(= new) holds the five shapes above with the probe that settles each one, and
the SKILL.md points at it. The durable rules that were not already written
down: a refusal arrives as a stream error and not as a throw; the turn's final
messages are the compressed history, so what landed is counted at the handler;
only a provider error walks a budget ladder; and a wrapper that rebuilds the
call options drops every field it was not taught.

## 6. The tree state

`main` at `fe2940da5`, the working tree clean, `swift build --build-tests`
exits 0. The ten cards are `done`, each with a verdict comment carrying the
numbers above. The long-lived scratch worktrees of earlier sessions
(`wt-deadcode`, `wt-review-loop`, `wt-survey`) were left alone on purpose:
they may still hold work that is not merged, and they are not this session's
to delete.
