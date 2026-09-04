# 03 — sidebar icons follow macOS sidebar icon size preference

**What to build:**

Boss 2026-08-30 OOB '目录树有一个按文字从这里开始, 那个应该是没用的,
正式的从这里开始缺少 ICON' + '试一下 Apple 系统设置 → General →
Sidebar icon size = 改 Small/Medium/Large 看 sidebar 是否跟随' =

2 bugs:

1. Book row was rendering as text-only (= missing icon). Root cause:
   `'book.closed'` is NOT a valid Lucide icon name. LucideIcon helper
   falls back to `Color.clear` (= invisible).
2. Sidebar icons didn't follow system sidebar icon size preference.
   My v0.30 rewrite hardcoded `size: 14` on every icon (= ignores
   `NSTableViewDefaultSizeMode` system preference).

Fix:
- Bug 1: change `'book.closed'` → `'book'` (= correct Lucide canonical
  name).
- Bug 2: add new helper `LucideIconSidebar(_:)` that reads
  `NSTableViewDefaultSizeMode` from `NSGlobalDomain` (= Apple 系统设置
  storage location) and maps to PT size:
  - Small (rawValue 1) → 12 PT
  - Medium (rawValue 2) → 14 PT (default)
  - Large (rawValue 3) → 18 PT
- Update all sidebar tree icon call sites to use `LucideIconSidebar(name)`
  instead of `LucideIcon(name, size: 14)`.

**Blocked by:** None (= independent of 01 + 02, but logically
follows since the sidebar layout is already validated after 02).

**Status:** ready-for-agent (= already committed as `0012d857c`,
this ticket documents the commit after-the-fact per Q5.6 partial
commit 接管规范).

## Fix specification

### Part 1 — book row icon

1. In `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`,
   locate `bookRowWithFolders(_ book:)` (~line 235).
2. Find the 2 occurrences of `LucideIcon("book.closed", size: 14)`
   (= one in `if folders.isEmpty` branch, one in `DisclosureGroup`
   `label`).
3. Replace both with `Lucide("book", size: ...)` (= see Part 2 below
   for size helper).

### Part 2 — system-preference icon size

1. In `Sources/WenshuApp/Views/LucideIcon.swift`, add new public
   helper:
   ```swift
   public func wenshuSidebarIconSize() -> CGFloat {
       let raw = UserDefaults.standard.integer(forKey: "NSTableViewDefaultSizeMode")
       switch raw {
       case 1: return 12   // Small
       case 3: return 18   // Large
       default: return 14 // Medium (= 2 OR 0 unset)
       }
   }

   @ViewBuilder
   public func LucideIconSidebar(_ name: String) -> some View {
       LucideIcon(name, size: wenshuSidebarIconSize())
   }
   ```
2. In `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`,
   update 5 call sites to use `LucideIconSidebar(name)`:
   - Shelf header icon (= `square-dashed-mouse-pointer` or `books.vertical.fill`)
   - Reference library root icon (= `square-library`)
   - Category row icons (= `category.icon`)
   - Book row icon (= `book`)
   - Folder row icons (= `folder.icon`)
3. Remove all `size: 14` from sidebar LucideIcon calls.

## Acceptance

- [ ] Book row in sidebar tree shows the `book` Lucide icon (= not
  text-only)
- [ ] `wenshuSidebarIconSize()` returns correct size per system
  preference
- [ ] `LucideIconSidebar(_:)` helper exists in LucideIcon.swift
- [ ] 5 sidebar call sites use `LucideIconSidebar`
- [ ] Build exit 0
- [ ] **Verified**: Small mode icons visibly smaller than Medium;
  Medium smaller than Large. Tested with `defaults write
  NSGlobalDomain NSTableViewDefaultSizeMode -int 1/2/3`.

## Out-of-scope (= NOT in this ticket)

- Settings UI to override the system preference (= boss may want a
  wenshu-specific setting later, but no OOB yet).
- Other icon sizes in the app (= toolbar icons, tab bar icons). All
  sidebar icons use the helper; other zones can adopt later.
