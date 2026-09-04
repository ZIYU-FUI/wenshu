# ticket 002 substitution table (= source of truth for the burndown)

This file is the **single source of truth** for every literal `Image(systemName: "x")` migration in ticket 002. Keep it as a code-reviewable artifact; if a future contributor changes a substitution, they edit THIS file first then the call sites.

## scope (= 41 call sites across 9 files)

| # | file | line | old | new |
|---|------|------|-----|-----|
| 1 | App.swift | 464 | `Image(systemName: providersWithKeys.contains(p.slug) ? "key.fill" : "key")` | ternary over `WenshuIcon.image(.keyFill / .key, size:, foregroundStyle:)` |
| 2 | App.swift | 488 | `Image(systemName: "checkmark")` | `WenshuIcon.image(.checkmark, ...)` |
| 3 | App.swift | 601 | `Image(systemName: hasKey ? "key.fill" : "key")` | same ternary as #1 |
| 4 | App.swift | 696 | `Image(systemName: task.icon)` | `WenshuIcon.image(name: task.icon, ...)` (Layer 3 path) |
| 5 | App.swift | 1157 | `Image(systemName: "doc.badge.plus")` | `WenshuIcon.image(.docBadgePlus, ...)` |
| 6 | App.swift | 1163 | `Image(systemName: "folder")` | `WenshuIcon.image(.folder, ...)` |
| 7 | App.swift | 1169 | `Image(systemName: "square.and.arrow.down")` | `WenshuIcon.image(.squareAndArrowDown, ...)` |
| 8 | App.swift | 1197 | `Image(systemName: "sidebar.left")` | `WenshuIcon.image(.sidebarLeft, ...)` |
| 9 | App.swift | 1208 | `Image(systemName: "eye.fill")` | `WenshuIcon.image(.eyeFill, ...)` |
| 10 | App.swift | 1217 | `Image(systemName: "wrench.and.screwdriver")` | `WenshuIcon.image(.wrenchAndScrewdriver, ...)` |
| 11 | App.swift | 1224 | `Image(systemName: "bubble.left")` | `WenshuIcon.image(.bubbleLeft, ...)` |
| 12 | App.swift | 1231 | `Image(systemName: "chart.bar")` | `WenshuIcon.image(.chartBar, ...)` |
| 13 | App.swift | 1238 | `Image(systemName: "square.and.arrow.up")` | `WenshuIcon.image(.squareAndArrowUp, ...)` |
| 14 | App.swift | 1490 | `Image(systemName: systemName)` (= ZoneIcon body) | `WenshuIcon.image(name: systemName, ...)` (Layer 3 path; ZoneIcon stays string-keyed) |
| 15 | App.swift | 1514 | `ZoneIcon(systemName: iconNames[i], size: 18)` | unchanged signature; body uses Layer 3 path |
| 16 | App.swift | 1521 | `ZoneIcon(systemName: item.icon, size: 18)` | unchanged signature |
| 17 | App.swift | 2040 | `Image(systemName: "checkmark")` | `WenshuIcon.image(.checkmark, ...)` |
| 18 | App.swift | 2054 | `Image(systemName: "cpu")` | `WenshuIcon.image(.cpu, ...)` |
| 19 | App.swift | 2059 | `Image(systemName: "chevron.up.chevron.down")` | `WenshuIcon.image(.chevronUpChevronDown, ...)` |
| 20 | App.swift | 2158 | `Image(systemName: tab.icon)` | `WenshuIcon.image(name: tab.icon, ...)` (Layer 3) |
| 21 | App.swift | 2178 | `Image(systemName: "archivebox")` | `WenshuIcon.image(.archivebox, ...)` |
| 22 | App.swift | 2207 | `Image(systemName: icon)` | `WenshuIcon.image(name: icon, ...)` (Layer 3) |
| 23 | ChatView.swift | 365 | `Image(systemName: "paperplane.fill")` | `WenshuIcon.image(.paperplaneFill, ...)` |
| 24 | ChatView.swift | 420 | `Image(systemName: sourceIcon)` | `WenshuIcon.image(name: sourceIcon, ...)` (Layer 3) |
| 25 | ChatView.swift | 433 | `Image(systemName: "person.crop.circle.badge.questionmark")` | `WenshuIcon.image(.personCropCircleBadgeQuestionmark, ...)` |
| 26 | ChatView.swift | 457 | `Image(systemName: "brain")` | `WenshuIcon.image(.brain, ...)` |
| 27 | DynamicZoneView.swift | 78 | `Image(systemName: tab.icon)` | `WenshuIcon.image(name: tab.icon, ...)` (Layer 3) |
| 28 | ZoneContentView.swift | 132 | `Image(systemName: item.icon)` | `WenshuIcon.image(name: item.icon, ...)` (Layer 3) |
| 29 | SubAgentProgressView.swift | 129 | `Image(systemName: "circle.dashed")` | `WenshuIcon.image(.circleDashed, ...)` |
| 30 | SubAgentProgressView.swift | 132 | `Image(systemName: "checkmark.circle.fill")` | `WenshuIcon.image(.checkmarkCircleFill, ...)` |
| 31 | SubAgentProgressView.swift | 135 | `Image(systemName: "xmark.circle.fill")` | `WenshuIcon.image(.xmarkCircleFill, ...)` |
| 32 | SubAgentProgressView.swift | 138 | `Image(systemName: "circle")` | `WenshuIcon.image(.circle, ...)` |
| 33 | LibraryOutlineView.swift | 199 | `Image(systemName: firstShelfHasBooks ? "books.vertical" : "books.vertical.fill")` | ternary over `WenshuIcon.image(.booksVertical / .booksVerticalFill, ...)` |
| 34 | LibraryOutlineView.swift | 296 | `Image(systemName: "books.vertical")` | `WenshuIcon.image(.booksVertical, ...)` |
| 35 | LibraryOutlineView.swift | 340 | `Image(systemName: "book")` | `WenshuIcon.image(.book, ...)` |
| 36 | LibraryOutlineView.swift | 367 | `Image(systemName: category.icon)` | `WenshuIcon.image(name: category.icon, ...)` (Layer 3) |
| 37 | BookOutlineView.swift | 71 | `Image(systemName: category.icon)` | `WenshuIcon.image(name: category.icon, ...)` (Layer 3) |
| 38 | BookOutlineView.swift | 123 | `Image(systemName: "book.pages")` | `WenshuIcon.image(.book, ...)` (Lucide has no `book.pages`; closest = `.book`) |
| 39 | BookOutlineView.swift | 144 | `Image(systemName: document.category.icon)` | `WenshuIcon.image(name: document.category.icon, ...)` (Layer 3) |
| 40 | LibraryRootView.swift | 142 | `Image(systemName: "text.book.closed")` | `WenshuIcon.image(.textBookClosed, ...)` |

## substitution rationale (= the SF→Lucide map in one place)

Used to populate `var lucideIcon: LucideIcon` in `WenshuIcon.swift`. Same rationale, condensed here for code-review traceability:

```
SF Symbols            WenshuIcon case             LucideIcon case
─────────────────     ────────────────────────    ─────────────────────────
key                   .key                        .key
key.fill              .keyFill                    .keyRound       (no .fill in Lucide)
checkmark             .checkmark                  .check
doc.badge.plus        .docBadgePlus               .filePlus
folder                .folder                     .folder
square.and.arrow.down .squareAndArrowDown         .squareArrowDown
square.and.arrow.up   .squareAndArrowUp           .share
sidebar.left          .sidebarLeft                .panelLeft
eye.fill              .eyeFill                    .eye
wrench.and.screwdriver.wrenchAndScrewdriver       .wrench
bubble.left           .bubbleLeft                 .messageCircle
chart.bar             .chartBar                   .chartBar
archivebox            .archivebox                 .archive
cpu                   .cpu                        .cpu
chevron.up.chevron.down .chevronUpChevronDown     .chevronsUpDown
paperplane.fill       .paperplaneFill             .send
person.fill           .personFill                 .user
person.crop.circle... .personCropCircleBadge...   .userRoundCog
brain                 .brain                      .brain
text.book.closed.fill .textBookClosedFill         .bookText
exclamationmark.triangle .exclamationmarkTriangle .triangleAlert
rectangle.split.3x1   .rectangleSplit3x1          .rectangleVertical
checklist             .checklist                  .listChecks
book                  .book                       .book
book.pages            (no case → use .book)       .book            (closest)
books.vertical        .booksVertical              .library
books.vertical.fill   .booksVerticalFill          .library         (no .fill in Lucide)
magnifyingglass       .magnifyingglass            .search
text.book.closed      .textBookClosed             .bookText
circle.dashed         .circleDashed               .circleDashed
checkmark.circle.fill .checkmarkCircleFill        .circleCheckBig
xmark.circle.fill     .xmarkCircleFill            .circleX
circle                .circle                     .circle
```

## substitutions to defer (= out of ticket 002 scope)

The 9 string-typed icon fields listed below stay on the Layer 3 path; promoting them to `WenshuIcon` enum fields is a separate refactor (= scope creep, lots of initializer changes, Q46 risk):

1. `Tab.icon: String` in App.swift:353 — drives `Label(tab.rawValue, systemImage: tab.icon)` and `Image(systemName: tab.icon)` in 2 places
2. `KanbanItem.icon: String` in App.swift:750, 1553, 2203 — drives 4 call sites
3. `Task.icon: String` in App.swift:1887
4. `DynamicTab.icon: String` in DynamicZoneView.swift:28
5. `ZoneItem.icon: String` in ZoneContentView.swift:33, 108
6. `BookCategory.icon: String` in Document.swift:76 (= 3 call sites in LibraryOutlineView / BookOutlineView)
7. `sourceIcon` computed in ChatView.swift:476 (= already 3 string fields there)
8. `iconNames: [String]` in App.swift:1500 (= icon placeholder row in zone toolbar)
9. `ZoneIcon(systemName: String, size: CGFloat)` struct in App.swift:1483 (= the wrapper itself)

All 9 fields route through `WenshuIcon.image(name: ...)` (= Layer 3 fallback) until a future ticket migrates them to typed enum fields.

## acceptance

- `grep -rn 'systemName:' Sources/WenshuApp/Views/ Sources/WenshuApp/App.swift` returns 0 (= all 41 sites migrated; the string-field declarations listed in "substitutions to defer" stay on the `iconNames: [String]` / `tab.icon: String` etc. fields, but those are property decls, not `systemName:` call sites, so they don't show up in the grep).
- `grep -rn 'WenshuIcon.image' Sources/WenshuApp/Views/ Sources/WenshuApp/App.swift` returns ≥ 41.
- `swift build` exits 0.
- `swift test` exits 0.
- Visual sanity per spec-axis (= icon should look like Lucide, not SF Symbols; same color and size).

## risks

- **Layer 3 string fallback path renders `Lucide(.circleQuestionMark)` if the icon name string ever changes shape between SF Symbols and Lucide**. This is acceptable because the layer 3 glyph is a visible Lucide missing-icon placeholder, NOT a crash. Owner can spot-check by renaming any `icon: String` field value to "garbage" = `WenshuIcon.image(name: "garbage")` renders the placeholder, doesn't crash.
- **Multiple SF Symbols map to the same WenshuIcon case** (= e.g. `key.fill` and `key` both fold into `.keyFill / .key` semantic aliases). This is intentional — Lucide has no `.fill` distinction.
- **Owner's red box verification** depends on macOS visible-icons comparison; ticket 002 doesn't substitute visible visuals for an automated test (= screenshot diff at run time is out of scope per Q28).
