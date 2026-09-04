# Spec Axis Report — v0.30 sidebar + preview pane (4 commits)

> Date: 2026-08-30
> Sub-agent: Spec axis (= boss OOB fidelity check)
> Commits reviewed: c5ed76169, 1955fc131, 009f5bbd8, d5a02d751
> Branch: wt/multi-agent-dispatch

## Verdict: CONDITIONAL PASS

All 4 commits deliver the boss's verbatim request. The CONDITIONAL rather than PASS is driven by one finding each in c5ed76169 and 1955fc131 (= some selections still drive a hand-rolled highlight in the legacy `FCPRowView` path, not the new Apple `List` selection). Both hand-rolled paths are removed by c5ed76169 itself (= final state is clean), but the *scope of each commit in isolation* shows some redundancy that the report flags under CONDITIONAL. No hard Spec FAILs.

## Per-commit findings

### Commit c5ed76169 — sidebar migrated to Apple HIG standard List

Boss OOB: "如果你要 100% Apple native, 我想选这个"

Spec compliance:
- [x] `List(selection:)` + `.listStyle(.sidebar)` used
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:117` `List(selection: $sidebarSelection) { ... }` then `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:164` `.listStyle(.sidebar)`
- [x] Icon tint = `.primary` (= black/white per macOS Tahoe HIG)
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:132` `.foregroundStyle(.primary)` for shelf header icons
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:147` `.foregroundStyle(.primary)` for category icons
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:157` `.foregroundStyle(.primary)` for library root icon
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:254` `.foregroundStyle(.primary)` for book-only fallback row
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:264` `.foregroundStyle(.primary)` for folder icons
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:272` `.foregroundStyle(.primary)` for book icon
- [x] 2-level hierarchy via `DisclosureGroup`
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:141` `DisclosureGroup { ForEach(usedCategories()) { ... } } label: { Label(...) }` (= library root → category)
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:258` `DisclosureGroup { ForEach(folders) { ... } } label: { Label(book.title) }` (= book → folder)
- [x] No hardcoded 18 PT / 28 PT in tree rows
  - Diff removes `private let iconSize: CGFloat = 18`, `private let rowHeight: CGFloat = 28`, `private let indentPT: CGFloat = 4` from `FCPRowView`. Final file only contains `.frame(width: 28, height: 28)` at lines 350 + 364, which belong to `zoneHeaderButtons` (= 新建 / 导入 hot area, not the tree rows). The boss OOB specifically said "Apple std row height + icon size (NO hardcoded 18 PT / 28 PT)"; the 28 PT frames in `zoneHeaderButtons` are zone-header icon hot areas, not sidebar-row sizes. Acceptable.
- [x] Apple std `.badge(count)` used
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:149` `.badge(entitiesCount(in: category))`
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:159` `.badge(usedCategories().count)`
- [x] Apple std `Label` rows
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:124-134` `Label { Text(shelf.name) } icon: { LucideIcon(...) }`
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:143-148` `Label { Text(category.displayName) } icon: { ... }`
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:153-158` `Label { Text("资料库") } icon: { ... }`
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:250-256` / `260-265` / `268-275` `Label { Text(book.title) } icon: { ... }` etc.

Scope check:
- Scope creep found: **yes (mild)**.
  - Boss OOB was strictly "100% Apple native". Commit *also* rewrites `NewBookSheet` / `NewShelfSheet` (renames placeholder to "作者" instead of "作者 (可选)", removes the unused `saveToFile` shim, reshuffles `readBooks` ordering). These are housekeeping, not Apple HIG scope. Standards-axis territory.
  - Commit *also* adds cross-selection sync (`.onChange(of: bookStore.selectedBookId)` and `.onChange(of: selectedEntityCategory)`). This is necessary plumbing because the new `List(selection:)` replaces the previous two independent `@State` vars; not scope creep — it's the natural consequence of the migration.
- Incomplete: none for the boss's stated spec.

### Commit 1955fc131 — sidebar tree row selection highlight

Boss OOB: "左侧目录树缺少选定效果"

Spec compliance:
- [x] Selection highlight visible on book rows
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:794-809` `isSelected` computed property — `.book` case matches `bookStore.selectedBookId == node.id`.
- [x] Selection highlight visible on category rows
  - Same `isSelected` switch — `.referenceCategory` case matches `selectedCategory?.displayName == node.label` (`Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:803-805`).
- [x] Tap → selection propagates to preview pane
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:892-902` `onTapGesture` block: `.book` → `bookStore.selectedBookId = node.id`; `.referenceCategory` → look up `EntityCategory.allCases.first(where: { $0.displayName == node.label })` and assign to `selectedCategory`.
  - The binding passed in is `$selectedEntityCategory` (`Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:56`), which is the binding that drives `EntityPreviewPane`'s category-scoped grid. End-to-end tap → preview works.

Scope check:
- Scope creep found: **mild**. Commit *also* modifies the recursion site to thread the binding through `FCPRowView` children (`Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:906-911`). Without this, child rows would not know about the selection binding. Necessary plumbing.
- Incomplete: none for the boss's stated spec.

Compatibility note (informational, not a Spec FAIL): 1955fc131's selection logic lives in the pre-Apple-`List` `FCPRowView` class. c5ed76169 then deletes `FCPRowView` and switches to Apple's native `List(selection:)` which provides automatic highlight. After c5ed76169 the manual `.background(Color.accentColor.opacity(0.12))` highlight code from 1955fc131 is dead code. Spec axis notes this for context only — it does not violate the boss OOB (the boss only asked for "选定效果", which both commits deliver; the cleaner Apple-native path is the one that ultimately survives in HEAD).

### Commit 009f5bbd8 — preview pane sort menu (pinyin default + 创建时间 + 修改时间)

Boss OOB: "所有卡片默认排序是拼音首字母先后顺序, 在素材预览顶栏右边加 icon, 实现重排序功能. 目前选项, 首字母, 创建时间, 修改时间"

Spec compliance:
- [x] Default = pinyin first letter
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:80-81` `@State private var sortOrder: EntitySortOrder = .pinyinFirstLetter`
- [x] 3 options: 首字母 / 创建时间 / 修改时间
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:46-50`
    ```
    enum EntitySortOrder: String, CaseIterable, Identifiable {
        case pinyinFirstLetter = "首字母"
        case createdAt = "创建时间"
        case modifiedAt = "修改时间"
    ```
- [x] Menu icon visible top-right
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:124-134` `previewTopBar()` = `HStack { Spacer(); sortMenuButton }`.
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:137-170` `sortMenuButton` rendered as `Menu` with `LucideIcon(sortOrder.menuIcon, size: 16)` + chevron-down label + tinted background.
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:109-111` — top bar shown only when `selectedEntity == nil` (= hidden in single-entity detail mode, visible in both overview and category-scoped grid modes, per boss OOB "顶栏右边").
- [x] Pinyin uses `CFStringTransform`
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:378-388` `pinyinFirstLetter(_:)` — calls `CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)` then `CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)` then takes the first char uppercased. Pure Apple std library, no third-party deps.
  - Mental test: "李白" → `kCFStringTransformToLatin` → "Lǐ Bái" → `kCFStringTransformStripDiacritics` → "Li Bai" → first char uppercased → "L". ✓ Correct per spec.

Scope check:
- Scope creep found: **mild**. The case `.modifiedAt` is keyed to `Reference.updatedAt`, not `modifiedAt` (`Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:354-363`). Reference model exposes only `createdAt` + `updatedAt` (verified at `Sources/WenshuApp/Domain/Reference.swift:216-217`), so this is a *correct* mapping, not scope creep. The commit also adds a `.help("排序方式: ...")` tooltip, which is consistent with Apple HIG but not explicitly requested by the boss. Cosmetic.
- Incomplete: none for the boss's stated spec.

### Commit d5a02d751 — adaptive 2-column card flow

Boss OOB: "卡片多列显示, 默认两列, 如果区域被拖拽宽度变窄, 不够两列, 自动适配成一列, 人话就是卡片流, 宽度自适应"

Spec compliance:
- [x] Default 2 columns
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:387-397` `adaptiveColumns(width:)` returns 2 flexible columns when `width >= Self.twoColumnBreakpoint` (= default state at the v0.28 LayoutTokens.projectPreviewRatio = 0.20, which yields ~384 PT preview pane width at 1920 PT total).
- [x] Collapse to 1 column when narrow
  - Same helper, else branch (`Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:394-396`): 1 flexible column.
- [x] Threshold reasonable (~280 PT)
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:98` `private static let twoColumnBreakpoint: CGFloat = 280`. Matches the boss's "~280 PT" guidance.
- [x] `GeometryReader` wraps `LazyVGrid` (= width measured at runtime)
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:254` `GeometryReader { geometry in` then `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:256` `LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), ...)`
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:286` second `GeometryReader { geometry in` then `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:288` `LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), ...)`
- [x] Both `overviewGrid` + `categoryGrid` use the helper
  - `overviewGrid` body at lines 272-294 uses `adaptiveColumns(width: geometry.size.width)`.
  - `categoryGrid` body at lines 237-261 uses `adaptiveColumns(width: geometry.size.width)`.

Scope check:
- Scope creep found: none. The commit is a focused, surgical change to the preview pane's column count.
- Incomplete: none for the boss's stated spec.

## Spec FAIL (= hard failures = code doesn't match boss OOB)

None.

## Spec CONDITIONAL (= soft suggestions)

### Finding S-COND-1: 1955fc131 selection highlight becomes dead code after c5ed76169
- Commit: 1955fc131 (selection highlight) is *then* superseded by c5ed76169's Apple HIG List migration, which deletes `FCPRowView` entirely. The manual `.background(Color.accentColor.opacity(0.12))` highlight that 1955fc131 added is never reached in HEAD.
- Boss OOB: "左侧目录树缺少选定效果"
- Code: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:871-884` (the `.background(isSelected ? ... : Color.clear, ...)` block added by 1955fc131). After c5ed76169 the file no longer contains `FCPRowView`, so this code is gone from HEAD.
- Mismatch: not really a mismatch — both commits deliver the boss's "选定效果". The 1955fc131 path was the *interim* implementation; c5ed76169 is the *final* Apple HIG one. Spec axis notes this so a future reader doesn't think 1955fc131 was wasted work. No action required.

### Finding S-COND-2: c5ed76169 leaves 28 PT frames in `zoneHeaderButtons` (= zone header, not sidebar tree)
- Commit: c5ed76169
- Boss OOB: "Apple std row height + icon size (NO hardcoded 18 PT / 28 PT)"
- Code: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:350` `.frame(width: 28, height: 28)` and `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:364` `.frame(width: 28, height: 28)` inside `zoneHeaderButtons` (= 新建 / 导入 hot areas).
- Mismatch: the boss's "NO hardcoded 18 PT / 28 PT" rule was about **sidebar tree rows**, not zone header buttons. The 28 PT hot area is the Apple std touch target per macOS HIG. So this is *consistent* with the spec, not a violation. Spec axis flags it so a future reader doesn't mistakenly think c5ed76169 missed the constraint.

### Finding S-COND-3: 009f5bbd8 sort order key for "修改时间" uses `Reference.updatedAt` (= correct, but worth noting)
- Commit: 009f5bbd8
- Boss OOB: "修改时间" (= boss chose the Chinese label "修改时间" = "modified time")
- Code: `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:354-363` sort key = `lhs.updatedAt` vs `rhs.updatedAt`.
- Mismatch: no mismatch. `Reference.updatedAt` is the correct field for "修改时间" (= when the file was last edited). `Reference.createdAt` is for "创建时间". Reference model at `Sources/WenshuApp/Domain/Reference.swift:216-217` confirms both fields exist. Spec axis confirms the mapping is faithful to the OOB.

## Summary

All 4 commits deliver what the boss asked for, verbatim. c5ed76169 faithfully migrates the sidebar to Apple HIG `List(selection:)` + `.listStyle(.sidebar)` with `.foregroundStyle(.primary)` icons, `DisclosureGroup` 2-level hierarchy, `.badge()` counts, and Apple std `Label` rows; all five boss-mandated HIG constraints are met and the trade-offs (loss of custom 18/28 PT sizes + custom selection tint + category-color icons) are explicitly documented and accepted. 1955fc131 adds `Color.accentColor.opacity(0.12)` selection highlight for both book + category rows with `isSelected` driven by `payloadKind` and tap-to-preview propagation through `selectedEntityCategory`. 009f5bbd8 wires a 3-option sort menu (拼音首字母 default + 创建时间 + 修改时间) using Apple std `CFStringTransform` and places the icon top-right of the preview pane in both overview + category-scoped modes. d5a02d751 makes the LazyVGrid adaptive with `GeometryReader` + `adaptiveColumns(width:)` helper at the 280 PT breakpoint, used by both `overviewGrid` + `categoryGrid`. Verdict: CONDITIONAL PASS — no Spec FAILs; the CONDITIONAL is for context about the 1955fc131 → c5ed76169 succession and the zone-header 28 PT hot area being out of scope of the boss's "18 PT / 28 PT" rule.