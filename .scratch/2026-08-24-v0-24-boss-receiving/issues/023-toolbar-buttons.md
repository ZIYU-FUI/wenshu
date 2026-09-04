# Ticket 015.023 — macOS window toolbar buttons (3 left + 4 zone toggle + 1 export)

Boss 2026-08-25 tenth OOB: '标题栏需要加一系列按钮. 居左 3 个功能, 新建, 打开, 导入. 居右 5 个功能, 显示/隐藏 项目管理区, 显示/隐藏 工具区, 显示/隐藏 聊天区, 显示/隐藏 动态区. 编辑器永远不能隐藏. 这四个功能是一组. 最右加一个导出功能, 用于导出市面上常见的电子书格式'.

Boss image: composer-images/composer_2026-08-25_02-31-06-945_250fa6.png
shows macOS window title bar (= red box) where these buttons go.

## 现状
- Current `.toolbar { ToolbarItem(placement: .principal) { Text("文枢") } }`
  (= only center title, no left/right buttons).
- No zone visibility state (= all 6 zones always rendered).
- No export functionality.

## Fix (1 commit per boss 8/22; multi-file atomic-coupled similar to
commit 394d8be2f precedent = LayoutShellView + LayoutShellViewModel = tightly
coupled).

### Left (3 buttons, placement: .primaryAction):
- 新建 (new document/shelf/book) — SF Symbol: 'doc.badge.plus'
- 打开 (open existing .ws file) — SF Symbol: 'folder'
- 导入 (import external format) — SF Symbol: 'square.and.arrow.down'

### Right (5 buttons, placement: .automatic):
- 4 zone visibility toggles (1 group):
  - 项目管理区 toggle — SF Symbol: 'sidebar.left' (projectSidebar)
  - 工具区 toggle — SF Symbol: 'wrench.and.screwdriver' (specializedTools)
  - 聊天区 toggle — SF Symbol: 'bubble.left' (aiChat)
  - 动态区 toggle — SF Symbol: 'chart.bar' (aiDynamic)
  - Editor zone = always visible (= not toggleable per Boss拍)
- 导出 (export common e-book formats) — SF Symbol: 'square.and.arrow.up'
  (rightmost, separated from toggle group)

## Implementation plan

### Sources/WenshuApp/LayoutShellViewModel.swift:
1. Add @Observable properties:
   - var projectSidebarVisible: Bool = true
   - var specializedToolsVisible: Bool = true
   - var aiChatVisible: Bool = true
   - var aiDynamicVisible: Bool = true
   (editorVisible is always true — not toggleable.)
2. Add func toggleZone(slot: ZoneSlot) — toggle visibility for given slot.
3. Add func isZoneVisible(slot: ZoneSlot) -> Bool — query helper.
4. Persist via @AppStorage (= key per zone, e.g. 'wenshu.zoneVisible.projectSidebar').
5. Add func exportEbook(format: EbookFormat, destination: URL) -> placeholder
   for future ticket (= UI shows progress + saves to file). Future tickets
   implement actual format conversion (= PDF/EPUB/MOBI/TXT).

### Sources/WenshuApp/App.swift LayoutShellView body:
1. Update `.toolbar { ... }` to add ToolbarItemGroup(placement: .primaryAction)
   for left buttons (新建, 打开, 导入) and ToolbarItemGroup(placement: .automatic)
   for right buttons (4 zone toggles + export).
2. Each toggle button: Button { vm.toggleZone(slot: .projectSidebar) } label:
   { Image(systemName: 'sidebar.left') }.buttonStyle(.borderless).
   .foregroundStyle based on current visibility state.
3. Export button: Button { showExportSheet = true } label:
   { Image(systemName: 'square.and.arrow.up') }.
4. Conditional ZoneModule render: skip if !vm.isZoneVisible(slot:).
   Editor slot always rendered (= Boss拍).

### Sources/WenshuApp/App.swift new state for export sheet:
1. @State private var showExportSheet: Bool = false.
2. .sheet(isPresented: $showExportSheet) { ExportEbookSheet() } — UI for
   picking format + destination.
3. ExportEbookSheet placeholder view (future ticket implements actual
   format conversion logic).

## Per Boss 8/22 '1 zone 1 ticket 1 commit':
This ticket spans 2 files (App.swift + LayoutShellViewModel.swift)
because they're tightly coupled (= per Boss precedent commit 394d8be2f
covering App.swift + ChatSessionStore.swift for ticket 015.005).

## Out of scope (future tickets):
- Real export format conversion (PDF/EPUB/MOBI/TXT) logic.
- New shelf / new book / open .ws wizard implementation (= currently
  available via right-click context menu + onboarding).
- Import format parsing (.docx, .txt, .epub).

## Done criterion
- macOS window toolbar has 3 left buttons (新建, 打开, 导入) + 4 zone toggle
  buttons (sidebar/tools/chat/dynamic) + 1 export button.
- All 4 zone toggles work (click toggles visibility, persists across
  launches via @AppStorage).
- Editor zone always visible.
- Export button opens export sheet (= placeholder for now).
- 双轴 code-review PASS (per Boss 8/25 OOB '双轴每次都跑' protocol).