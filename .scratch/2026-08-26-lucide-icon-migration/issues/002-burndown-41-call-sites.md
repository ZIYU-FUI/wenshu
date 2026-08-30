# 002 — burndown 41 SF Symbols call sites to WenshuIcon.image

First line = fact. Last line = fact.

## goal

Replace every `Image(systemName: "...")` call in `Sources/WenshuApp/` with `WenshuIcon.image(...)` (= or the equivalent extension method from ticket 001). Visual style stays as close to current behavior as possible: sizes preserved (= 18 PT in toolbar, etc.), `.foregroundStyle` chains preserved.

## deliverables

1. Zero `Image(systemName:)` call sites in `Sources/`. Verify with: `grep -rn 'Image(systemName:' Sources/WenshuApp/ ; echo $?` → 1 (= grep exits 1 when no match).
2. Zero `systemName` property declarations (= e.g. `ZoneIcon(systemName:)` in `App.swift:1483`) — rewire those to `WenshuIcon`.
3. Per-file migration list (= owner-friendly verification grid):

   - `Sources/WenshuApp/App.swift` — multiple toolbar / settings / tab icons
   - `Sources/WenshuApp/Views/Chat/ChatView.swift`
   - `Sources/WenshuApp/Views/Dynamic/DynamicZoneView.swift`
   - `Sources/WenshuApp/Views/Dynamic/ZoneContentView.swift`
   - `Sources/WenshuApp/Views/Library/LibraryOutlineView.swift`
   - `Sources/WenshuApp/Views/Library/BookOutlineView.swift`
   - `Sources/WenshuApp/Views/Library/LibraryRootView.swift`
   - `Sources/WenshuApp/Views/Kanban/SubAgentProgressView.swift`
   - `Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift`

4. For each icon: pick the closest Lucide equivalent. Where Lucide has no perfect match, prefer the **functionally closest** icon (= e.g. `sidebar.left` → `panel-left`, `bubble.left` → `message-circle`). Document per-icon Lucide substitutions in code comments.

## substitution cheat sheet (= starting point, refine during impl)

| SF Symbols    | Lucide name         | notes                                  |
|---------------|---------------------|----------------------------------------|
| key.fill      | key-round           | no `.fill` variant in Lucide, round key glyph      |
| key           | key-round           |                                          |
| checkmark     | check               |                                          |
| doc.badge.plus| file-plus           |                                          |
| folder        | folder              |                                          |
| square.and.arrow.down | download     |                                          |
| square.and.arrow.up   | upload       |                                          |
| sidebar.left  | panel-left          |                                          |
| eye.fill      | eye                 | Lucide has no `.fill`; main glyph       |
| wrench.and.screwdriver | wrench      | closest functional match               |
| bubble.left   | message-circle      |                                          |
| chart.bar     | chart-bar           |                                          |
| square.and.arrow.up (export) | share-node | export icon, share is the closest       |
| archivebox    | archive             |                                          |
| paperplane.fill| send                |                                          |
| person.crop.circle.badge.questionmark | user-round-cog | closest functional |
| brain         | brain               |                                          |
| chevron.up.chevron.down | chevrons-up-down |                              |
| cpu           | cpu                 |                                          |
| books.vertical| library             |                                          |
| books.vertical.fill | library      | Lucide has no fill                     |
| magnifyingglass| search             |                                          |
| slider.horizontal.3 | sliders-horizontal |                                  |

(= initials; final list per-call-site recorded in commit body)

## acceptance

- `swift build` exits 0
- `swift test` exits 0 (= no regression in `WenshuAppTests/`)
- `grep -rn 'Image(systemName:' Sources/WenshuApp/ ; echo done` returns `done` last (= grep exits 1 = no match)
- `grep -rn 'systemName' Sources/WenshuApp/ ; echo done` returns `done` last
- Visual sanity: spec-axis subagent (= assistant will run delegate_task) verifies the 41 sites all converted per the migration list above.

## risks

- **Substitution drift**: Lucide's glyphs do not 1:1 match SF Symbols. Visual regression possible. Mitigate by previewing each replacement via a temporary screenshot script (= same pattern as v0.24 ticket 015 series).
- **Forgotten `:fill` semantics**: Lucide has no `.fill` modifier. Where our SF Symbols used a filled variant to signal "on/active", we substitute the Lucide main glyph (which Lucide still renders as outline). Owner 2026-08-26 said toggle on/off fill semantics are deferred to a future ticket — this ticket does NOT add a fill treatment.

## source of truth

- spec: `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-26-lucide-icon-migration/spec.md` §4, §6
- ticket 001 must be merged first

The 41 call sites all route through `WenshuIcon.image(_:)` after ticket 002.
