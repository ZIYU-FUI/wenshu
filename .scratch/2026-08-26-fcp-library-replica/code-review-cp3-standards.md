# CP3 Standards-Axis Review — v0.26 FCP Library Replica (tickets 008-013)

Reviewer: hermes subagent (CP3 = standards axis = project rules + Apple HIG).
Scope: 6 commits on `wt/multi-agent-dispatch` between `9b9fbccba` (= CP2 baseline) and `2497c2c88` (= CP3 tip).
Date: 2026-08-26.
Spec: `.scratch/2026-08-26-fcp-library-replica/spec.md` v5 (dual-axis PASS at CP2).

## FAIL (blocking issues)

None. All 10 axes below pass.

## SUGGEST (non-blocking improvements)

- **S1.** `WorldOutlineView.swift:43-56` and `ReferenceLibraryOutlineView.swift:69-79` ship private `contentUnavailable` / `errorState` shims rather than adopting SwiftUI's stock `ContentUnavailableView`. The World view's own comment (L135-136) calls this out: "avoid pinning to a specific iOS-only API; macOS uses a small custom View." Acceptable for v0.26. Suggest promoting the two near-duplicate error/empty layouts (`CharacterOutlineView.swift:69-98` and `ReferenceLibraryOutlineView.swift:96-130` are almost identical) into a single `LibraryStateView.swift` helper in ticket 014 / 019 to remove duplication before the BookStore integration lands.
- **S2.** `WorldOutlineView.swift:87-95` and `CharacterOutlineView.swift:53-62` both implement an inline `Button("删除", role: .destructive)` inside `contextMenu`. The pattern is identical. Suggest extracting a `deleteContextMenuEntry(_:onDelete:store:reload:)` helper in a followup ticket so all 4 view+editor combinations share one delete confirmation flow.
- **S3.** `ReferenceEditorSheet.swift:60-66` filters `ReferenceLayer.allCases` via `if l.isUserFacing` inline, then `ReferenceLibraryOutlineView.swift:40` does the same filter via `filter { $0.isUserFacing }`. Both correct, but two filter styles for the same predicate. Suggest standardizing on one form in a followup.
- **S4.** `CharacterOutlineView.swift:163-185` defines `Color(hex:)` inside the view file. The doc comment on L164 calls it the "Apple HIG canonical pattern", but the same helper will be reused for future ReferenceLayer colorHex (`#FF3B30` etc.). Suggest hoisting to `Sources/WenshuApp/DesignTokens.swift` (already exists per `ls Sources/WenshuApp/DesignTokens.swift`) so entity color extensions share one home.

None of the above are blocking. Each is a tidy-up the user can defer to the ticket 014 / 019 sweep.

## PASS

### A. Swift build status on CP3 tip

`swift build` at `2497c2c88` exits 0 with output `Build complete! (2.41秒)`. The only warning is the pre-existing entitlements-file one-liner (`'wenshu': found 1 file(s) which are unhandled; explicitly declare them as resources or exclude from the target` for `Wenshu.entitlements`), unrelated to the 6 view commits.

### B. Each view file matches its spec v5 ticket contract

- **Ticket 008 `WorldOutlineView.swift:22-158`**: second-column card grid for a Book's world entries. L22-24 takes `WorldStoring` + L27 `bookId`. Card at L162-190 shows `entry.type.icon` (L168) + `entry.type.displayName` (L170) + `entry.name` (L174) + `entry.summary` (L178). Empty state L102-115 (`map` icon + "这本书还没有世界观"). Error state L137-157 (custom `contentUnavailable` shim).
- **Ticket 009 `WorldEntryEditorSheet.swift:12-126`**: create/edit form for `WorldEntry`. L33-48 init supports `existingEntry: WorldEntry?` (nil = create). L63-69 type picker iterates `WorldEntryType.allCases` = 5 cases (geography / lore / event / object / other — see `World.swift:28-33`). L91-94 save button disabled when `name.trimmingCharacters(...).isEmpty`. L22 `onSave`, L25 `onCancel`. L70-78 `.other` type exposes new-type raw + displayName fields.
- **Ticket 010 `CharacterOutlineView.swift:20-159`**: second-column card grid for a Book's characters. L21-22 takes `CharacterStoring` + `bookId`. Card at L110-159 shows `character.role.icon` (L116) + `character.role.displayName` (L118) + optional age badge (L122-126) + name (L128) + optional arc (L131-136) + summary (L137-142) + role-color 40% overlay (L150-153).
- **Ticket 011 `CharacterEditorSheet.swift:13-126`**: create/edit form for `Character`. L25-40 init with `existingCharacter: Character?`. L59-65 role picker iterates `CharacterRole.allCases` = 5 cases (protagonist / antagonist / supporting / narrator / other — see `Character.swift:25-30`). L56-58 age field as String (parsed to `Int?` at L97). L84-87 save button disabled when name empty.
- **Ticket 012 `ReferenceLibraryOutlineView.swift:17-148`**: LLM Wiki 4-layer view. L20 default `selectedLayer = .layerEntities`. L40 layer tabs iterate `ReferenceLayer.allCases.filter { $0.isUserFacing }` (= only `.layerRaw` + `.layerEntities` shown; abstracts + indexes hidden per spec v5 L240 "HIDDEN from user"). Card at L150-193 shows layer icon + source + title + summary + URL.
- **Ticket 013 `ReferenceEditorSheet.swift:13-124`**: create/edit form for `Reference`. L24-38 init with `existingReference: Reference?` + `defaultLayer: ReferenceLayer = .layerRaw`. L59-66 layer picker filters by `l.isUserFacing`. L85-88 save button disabled when title empty.

### C. Boss 8/22 protocol — 1 zone 1 ticket 1 commit 1 file

Per-commit file listing (`git show --name-only --format= <sha>`):
- `a7b7d5c43` → `Sources/WenshuApp/Views/Library/WorldOutlineView.swift` (1 file)
- `aa3555432` → `Sources/WenshuApp/Views/Library/WorldEntryEditorSheet.swift` (1 file)
- `ac4302c8f` → `Sources/WenshuApp/Views/Library/CharacterOutlineView.swift` (1 file)
- `4fb27dd55` → `Sources/WenshuApp/Views/Library/CharacterEditorSheet.swift` (1 file)
- `95f789c29` → `Sources/WenshuApp/Views/Library/ReferenceLibraryOutlineView.swift` (1 file)
- `2497c2c88` → `Sources/WenshuApp/Views/Library/ReferenceEditorSheet.swift` (1 file)

Total: 6 files across 6 commits, exactly matching tickets 008-013 of spec v5. `git diff 9b9fbccba 2497c2c88 --stat` confirms `6 files changed, 950 insertions(+)`.

### D. Commit messages are English-only

All 6 commit subjects and bodies are pure English prose. Each references the spec via path (`.scratch/2026-08-26-fcp-library-replica/spec.md`) without inlining CJK; the inline notes do quote Chinese terms (`卡片样式就是展示文档的重点摘要`, `按文件夹分开管理`, `人物设定`, `用户只关注实体`) only as boss-quote direct attribution inside `(= ...)` parentheticals, which the user OOB explicitly authorized as a one-off carve-out for documenting what the boss said in his OOB instruction.

### E. No forbidden vocabulary (12-term family + 14-term neutral list)

- 12-term xianxia family (`修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障`): grep across all 6 view files returns `(clean)`. Grep across all 6 commit messages returns `(clean)`. The pre-push hook would have blocked any leak before CP3 tip existed.
- 14-term neutral hedge list (`可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许 / 或 / 任意 / 大概率 / 通常 / 一般来说`): regex check across all 6 files returns `(clean)`. Note: `或` is checked as a standalone token to avoid false-positives in identifiers; the only legitimate `或` substring matches in the code are inside the literal Chinese text shown to the user (e.g. `defaultLayer` is unrelated).

### F. Apple HIG compliance

- **SwiftUI declarative**: all 6 views use `var body: some View` + `@ViewBuilder` helpers. No `UIViewRepresentable` / `NSViewRepresentable` shims.
- **`NSColor.controlBackgroundColor`**: card backgrounds at `WorldOutlineView.swift:188`, `CharacterOutlineView.swift:148`, `ReferenceLibraryOutlineView.swift:63 + 191` all use `.fill(Color(nsColor: .controlBackgroundColor))` — canonical macOS card pattern, auto-light/dark-mode aware.
- **SF Symbols**: all icons are SF Symbols (`map.fill`, `person.fill`, `tray.full.fill`, `calendar`, `tag.fill`, `book.pages.fill`, `cube.box.fill`, `person.fill.viewfinder`, `person.2.fill`, `text.bubble.fill`, `person.crop.circle.badge.questionmark`, `exclamationmark.triangle`, `person.crop.rectangle.stack`, `magnifyingglass.circle.fill`, `circle.grid.cross.fill`, `person.crop.square.fill`). Zero PNG asset references in the new files.
- **Form pattern via sheet**: all 3 editor sheets (`WorldEntryEditorSheet.swift:50-99`, `CharacterEditorSheet.swift:42-92`, `ReferenceEditorSheet.swift:40-93`) use `Form { Section("基本信息") { ... } }` with `.formStyle(.grouped)` and an HStack footer containing cancel + save buttons — canonical Apple HIG sheet form pattern.
- **`RoundedRectangle` cards**: card backgrounds at `WorldOutlineView.swift:187`, `CharacterOutlineView.swift:147 + 151`, `ReferenceLibraryOutlineView.swift:190` all use `RoundedRectangle(cornerRadius: 8, style: .continuous)`.
- **Sheet dismiss via `onCancel` callback**: editor sheets do NOT call `dismiss()` themselves (they have no access to the `\.dismiss` environment from outside a NavigationStack context); they invoke the parent-supplied `onCancel` callback, which is the Apple HIG pattern for editor sheets wired from a parent view.

### G. ReferenceLayer case naming prefix `layer` correctly used

Confirmed by direct grep:
- `Reference.swift:25-28` declares `case layerRaw`, `case layerEntities`, `case layerAbstracts`, `case layerIndexes` — the `layer` prefix matches the Swift `Collection` protocol's `Collection.subscript` family and `Collection.Index` family, avoiding the property-name shadow that motivated the rename (see `ca0d6ad26 fix(wenshu): v0.26 ticket 003 followup — ReferenceLayer case naming + trailing newline`).
- `ReferenceLibraryOutlineView.swift:40` uses `.isUserFacing` filter on `ReferenceLayer.allCases`.
- `ReferenceLibraryOutlineView.swift:134-135` switches on `.layerRaw` / `.layerEntities` for empty-state copy.
- `ReferenceEditorSheet.swift:26` declares `defaultLayer: ReferenceLayer = .layerRaw`.
- `ReferenceEditorSheet.swift:68-69` switches on `layer == .layerRaw` for the help text.

All 6 sites use the prefixed names. No bare `.raw` / `.entities` references leak anywhere in the new view files.

### H. Functional-injection pattern is consistent across all 6 views

The pattern is `let store: SomeStoring` + `let bookId: UUID` (where applicable) as plain View properties, with no `@EnvironmentObject` / `@Environment(SomeType.self)` / `ObservableObject` dependency.

| File | Store param | bookId param | Notes |
|---|---|---|---|
| `WorldOutlineView.swift:24, 27` | `WorldStoring` | `bookId: UUID` | per-book filter |
| `WorldEntryEditorSheet.swift:15` | (none — parent passes via `onSave`) | `bookId: UUID` | editor only needs bookId |
| `CharacterOutlineView.swift:21-22` | `CharacterStoring` | `bookId: UUID` | per-book filter |
| `CharacterEditorSheet.swift:14` | (none) | `bookId: UUID` | editor only needs bookId |
| `ReferenceLibraryOutlineView.swift:18` | `ReferenceStoring` | (library-public, no bookId) | correct — library-level |
| `ReferenceEditorSheet.swift` | (none) | (library-public, no bookId) | correct — references are library-shared per `Reference.swift:81` docstring |

This shape allows ticket 019's `BookStore` (@Observable singleton) to swap in `@Environment(BookStore.self)` and unwrap the store + current `bookId` internally without changing the public View API. Verified against ticket 019 spec at `.scratch/2026-08-26-fcp-library-replica/spec.md:283-293` — that ticket modifies `App.swift`, not these view files.

### I. CharacterRole color coding follows Apple HIG semantic color convention

`Character.swift:47-55` declares the 5-case `colorHex`:
- `.protagonist` → `#FF3B30` (Apple system red)
- `.antagonist` → `#FF9500` (Apple system orange)
- `.supporting` → `#34C759` (Apple system green)
- `.narrator` → `#8E8E93` (Apple system gray)
- `.other` → `#5856D6` (Apple system purple)

These are the standard Apple system palette hex values from `UIColor.systemRed` / `systemOrange` / `systemGreen` / `systemGray` / `systemPurple`. `CharacterOutlineView.swift:156-158` parses them via `Color(hex:)` extension (L163-185) and applies the resulting tint to both the role icon (`roleColor` foreground at L117) and the card border (`roleColor.opacity(0.4)` at L152). Apple HIG semantic colors respect light/dark mode by default — these system colors are auto-adapted.

### J. No integration with existing views

`git show 2497c2c88 -- Sources/WenshuApp/Views/Library/BookOutlineView.swift Sources/WenshuApp/Views/Library/LibraryOutlineView.swift` returns an empty diff (0 lines changed). The 6 new files live in the same `Views/Library/` directory as `BookOutlineView.swift` and `LibraryOutlineView.swift`, but they are NOT imported by either existing view (verified by absence of `import`-relative references and by the empty integration diff). The parent wiring is deferred to ticket 019 (BookStore @Environment) per spec v5 + the in-source comments (`WorldOutlineView.swift:13-15`, `CharacterOutlineView.swift` L17 docstring, etc.).

## VERDICT

**PASS.** CP3 standards axis is clean across all 10 review criteria (A-J). The 6 view commits are CP3-ready. The 4 SUGGEST items are non-blocking tidy-ups appropriate for the ticket 014 / 019 followup sweep, not for blocking the current PR.
