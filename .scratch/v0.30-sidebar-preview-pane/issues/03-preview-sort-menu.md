# 03 — preview pane sort menu (pinyin default + 创建时间 + 修改时间)

**What to build:**

Boss 2026-08-30 OOB '所有卡片默认排序是拼音首字母先后顺序, 在素材预览
顶栏右边加 icon, 实现重排序功能. 目前选项, 首字母, 创建时间,
修改时间' = cards in preview pane need:
1. Default sort = pinyin first letter (= Chinese title alphabetical)
2. Sort menu icon in preview pane top-right
3. 3 sort options: 拼音首字母 (default) / 创建时间 / 修改时间

Pre-fix: cards always sorted by pinyin (= no user toggle).

**Blocked by:** None (= can start independently).

**Status:** ready-for-agent (= already committed as `009f5bbd8`,
this ticket documents the commit after-the-fact per Q5.6 partial
commit 接管规范).

## Fix specification

### File: `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`

1. **New enum `EntitySortOrder: String, CaseIterable, Identifiable`**:
   ```swift
   enum EntitySortOrder: String, CaseIterable, Identifiable {
       case pinyinFirstLetter = "首字母"
       case createdAt = "创建时间"
       case modifiedAt = "修改时间"

       var id: String { rawValue }

       var menuIcon: String {
           switch self {
           case .pinyinFirstLetter: return "arrow-down-a-z"
           case .createdAt: return "clock"
           case .modifiedAt: return "square-pen"
           }
       }
   }
   ```

2. **@State sortOrder: EntitySortOrder = .pinyinFirstLetter** (=
   boss default).

3. **`previewTopBar()` + `sortMenuButton`**:
   - HStack { Spacer + sortMenuButton }
   - `Menu { ForEach(EntitySortOrder.allCases) { Button ... } }
     label: { HStack { LucideIcon(sortOrder.menuIcon, 16pt) +
     chevron-down } }`
   - `.menuStyle(.borderlessButton)` + `.menuIndicator(.hidden)`

4. **`sortEntities(_:by:)` helper**:
   - `.pinyinFirstLetter` → sort by pinyinFirstLetter(title)
   - `.createdAt` → sort by Reference.createdAt descending
   - `.modifiedAt` → sort by Reference.updatedAt descending
   - Stable sort: id.uuidString tiebreaker

5. **`pinyinFirstLetter(_ title: String) -> String`**:
   - Uses Apple `CFStringTransform` (= no 3rd-party):
     - `kCFStringTransformToLatin` (CJK → latinized pinyin with
       diacritics: "李白" → "Lǐ Bái")
     - `kCFStringTransformStripDiacritics` (strip tone marks: "Lǐ Bái"
       → "Li Bai")
   - Take first character uppercased
   - Empty titles → "~"

6. **Update overviewGrid + categoryGrid** to call `sortEntities(allEntities,
   by: sortOrder)`.

7. **body** adds VStack with `previewTopBar()` (= hidden when
   `selectedEntity != nil`).

## Acceptance

- [x] Default sort = pinyin first letter (verified: C, D, H, L order)
- [x] Sort menu icon visible at preview pane top-right (= Lucide icon
  + chevron-down)
- [x] 3 menu options present (首字母/创建时间/修改时间)
- [x] Pinyin uses Apple std CFStringTransform (= no 3rd-party)
- [x] Stable sort: id.uuidString tiebreaker prevents visual shuffle
- [x] Build exit 0

## Out-of-scope

- Adding "按文件夹 / 按类别" grouping (= boss did not request).
- Custom sort orders (= boss specified 3 fixed options).
