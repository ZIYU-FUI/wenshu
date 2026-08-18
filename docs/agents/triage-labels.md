# Triage labels

Default triage label vocabulary (do not change unless the tracker already has a different convention):

| Role | Label | Meaning |
|------|-------|---------|
| `needs-triage` | `needs-triage` | Incoming issue that has not yet been categorised |
| `needs-info` | `needs-info` | Triage decided more information is needed from the reporter |
| `ready-for-agent` | `ready-for-agent` | Triage decided this is agent-ready work (an `implement` ticket) |
| `ready-for-human` | `ready-for-human` | Triage decided this needs human judgment, not agent work |
| `wontfix` | `wontfix` | Triage decided this will not be worked on |

Because wenshu uses local markdown, the "label" is a state field at the top of each issue file (e.g. `state: needs-triage`), not a tracker label. The `triage` skill reads / writes this field.
