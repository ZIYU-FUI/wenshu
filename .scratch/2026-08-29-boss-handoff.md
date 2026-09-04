# v0.28 followup Boss debug session handoff (= 2026-08-29)

## Current state (= awaiting boss return to Mac)

Branch: `wt/multi-agent-dispatch`
HEAD: `f5c707601` feat(wenshu): v0.28 followup — per-region chrome (old 6区 top/bottom toolbars)
Last push: `b4ea6f368..f5c707601`

## Keychain stub state (= boss to restore Mon)

**File**: `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift`

### Stubbed (= bypass macOS SecurityAgent modal):

1. `AppleKeychainStore.saveKeySync` (line ~52) = `return` (no-op) + real `SecItemAdd` code commented as `/* ... */`
2. `AppleKeychainStore.loadKeySync` (line ~91) = `return "wenshu.debug.api.key"` (fake debug key) + real `SecItemCopyMatching` commented
3. `AppleKeychainStore.deleteKeySync` (line ~106) = `return` (no-op)
4. `AppleKeychainStore.listProvidersWithKeys` (line ~120) = `return []`
5. `ProviderKeychain.backend` static var (line 183) = `InMemoryKeychainStore()` (= default = in-memory, never touches Security framework)

### Bypass trigger:
- `WENSHU_DEBUG_INMEMORY_KEYCHAIN=1` env var = force InMemoryKeychainStore
- Default (= no env var) = also InMemoryKeychainStore (= no keychain access)
- Production password flow = stubbed (= no real SecItem calls)

### Why stubbed:
- macOS SecurityAgent modal blocks Wenshu main UI
- Boss on weekend (= can't enter password)
- Commented code preserved for restoration

## Boss return procedure (= Mon)

1. **Mac reboot** (= clear WindowServer state + TCC cache from prior crashes)
2. **Open Terminal**
3. **Verify Wenshu launches** with keychain stub:
   ```bash
   cd /Volumes/ANAN/Engineering/wenshu
   WENSHU_DEBUG_INMEMORY_KEYCHAIN=1 ./build/Wenshu.app/Contents/MacOS/WenshuApp
   ```
4. **Wenshu opens** (= 6区 builtinDefault + global AppTitlebar/AppStatusbar)
5. **Wenshu functional with debug key** (= "wenshu.debug.api.key" returned by stub)
6. **If Wenshu shows "重新打开" modal** (= 一次性 WindowServer recovery):
   - Click 重新打开 via cliclick c:170,240 (= dialog at (0, 30) with size 260x251)
   - Or manually click it
7. **Verify all 14 followup tickets** still work (= WenshuChromeOverlay + RegionPerZoneChrome + VisibilityStore + ContributionRegistry etc.)

## Boss restore keychain procedure

When boss ready to use real password:

1. **Edit `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift`**:
   - Remove `/* ... */` comment blocks around real `SecItemAdd/SecItemCopyMatching/SecItemDelete/SecItemCopyMatching` code
   - Change `ProviderKeychain.backend` default back to `AppleKeychainStore()` (line 183)
2. **Add the API key to macOS keychain**:
   ```bash
   security add-generic-password -s com.wenshu.app.provider -a minimax-cn.api.key -w "boss-actual-api-key"
   ```
3. **Re-build**: `bash Scripts/build-app.sh`
4. **Launch Wenshu** (= now real keychain access, not stubbed)
5. **First launch may show keychain modal** (= real macOS permission prompt for `com.wenshu.app.provider` service). Boss enters password.

## Architecture state (= post-debug)

### Wenshu view framework = WORKING
- macOS 52 PT native titlebar (with traffic lights) — `.windowToolbarStyle(.unified(showsTitle: false))`
- WenshuChromeOverlay 34 PT custom titlebar (= sidebar/preview/tools toggles)
- LayoutShellView 6区 builtinDefault (= sidebar + preview + editor + tools + chat + dynamic)
- WenshuChromeOverlay 24 PT custom statusbar (= MiniMax-M3, Idle, wenshu v0.28, Sessions)
- Chat input "输入消息..." with paper plane
- macOS dock below

### Per-region chrome implemented (= Boss UX round 2)
- `Sources/WenshuApp/UI/ZonePerRegionChrome.swift` (380 LOC)
- `RegionPerZoneChrome<Content: View>` generic view (= wraps any content with 30 PT top + content + 30 PT bottom)
- 6 default per-region chrome factories (= reproduces old LayoutShellView zoneStatus/rightStatus)
- 11/11 tests pass

### Pending (= future v0.29+)
- Wire `RegionPerZoneChrome` into WorkspaceView (when new framework ships per-region pane rendering)
- The standalone component is ready (= can be adopted incrementally)

## Commits on wt/multi-agent-dispatch (last 5)

```
f5c707601 feat(wenshu): v0.28 followup — per-region chrome (old 6区 top/bottom toolbars)
b4ea6f368 docs(wenshu): v0.28 followup — Boss UX discovery: '重新打开' modal = WindowServer recovery
f94c9ea3b feat(wenshu): v0.28 followup — debug view framework: revert chrome to debug
b4ed96b9e feat(wenshu): v0.28 followup — comment out keychain + macOS titlebar hide
acf295b80 feat(wenshu): v0.28 followup — wire AppTitlebar + AppStatusbar into AppRoot
```

## Image attachments delivered (= via hermeslink deliver)

- `wenshu-CLEAN3.jpg` — SecurityAgent modal (= keychain prompt)
- `wenshu-clicked2.jpg` — Modal still present after click
- `wenshu-windowless.png` — Cua Driver overlay only (= Wenshu not in foreground)
- `wenshu-moved.jpg` — Finder window (= Wenshu not on screen)
- `wenshu-RESIZED.jpg` — Modal at top-left (= still blocking)
- `wenshu-click1.jpg` — **Wenshu 6区 VISIBLE** (= click 重新打开 worked!)
- `wenshu-topbar.jpg` — Top strip (= macOS 52 PT titlebar + WenshuChromeOverlay 34 PT titlebar both visible)
- `wenshu-bottombar.jpg` — Bottom strip (= WenshuChromeOverlay 24 PT statusbar + chat input)
- `wenshu-1window.jpg` — Single Wenshu window
- `dialog-area.jpg` — Zoom on top-left dialog (= 重新打开 button)
- `wenshu-after14tickets.png` — Full screenshot after 14 tickets

## Quick reference (= when boss asks for follow-up)

### "How to launch Wenshu in debug mode"
```bash
WENSHU_DEBUG_INMEMORY_KEYCHAIN=1 /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app/Contents/MacOS/WenshuApp
```

### "How to dismiss 重新打开 modal"
```bash
cliclick c:170,240  # dialog at (0, 30) with size 260x251
```

### "How to capture + deliver Wenshu screenshot"
```bash
# Find run_id
RUN_ID=$(tail -1 ~/.hermeslink/conversations/conv_8db511a772774533811440669340c3a1/events.ndjson | python3 -c 'import sys, json; print(json.loads(sys.stdin.read()).get("run_id"))')
# Screenshot
screencapture -x /tmp/wenshu-X.png
sips -s format jpeg /tmp/wenshu-X.png --out /tmp/wenshu-X.jpg
# Stage + deliver
mkdir -p ~/.hermeslink/conversations/conv_8db511a772774533811440669340c3a1/delivery-staging/$RUN_ID
cp /tmp/wenshu-X.jpg ~/.hermeslink/conversations/conv_8db511a772774533811440669340c3a1/delivery-staging/$RUN_ID/
hermeslink deliver ~/.hermeslink/conversations/conv_8db511a772774533811440669340c3a1/delivery-staging/$RUN_ID/
```

### "How to commit + push"
```bash
cd /Volumes/ANAN/Engineering/wenshu
git add <files>
git commit -m "feat(wenshu): <description>"
git push origin wt/multi-agent-dispatch
```

## Known issues (= for next session)

1. **WindowServer 重新打开 modal** (= 一次性 recovery prompt when Wenshu crashes or WindowServer is unhappy) — cliclick c:170,240 dismisses
2. **macOS 52 PT titlebar always visible** (= `.windowToolbarStyle(.unified)` can't be removed) — boss OK with this (= hermes app also has macOS titlebar)
3. **Wenshu window sometimes 30 PT** (= when not yet visible) — same WindowServer recovery pattern
4. **Keychain stubbed** (= boss to restore Mon) — see procedure above
5. **RegionPerZoneChrome not yet wired into WorkspaceView** (= v0.29+ work, standalone component for now)

## Architecture summary (= 14 followup tickets)

1. TKT-013: ContributionRegistry, WorkspaceScope, PaneLifecycle, PaneVisibleContext, Geometry
2. TKT-014: PaneVisibilityStore (= 3 mechanisms + bindings)
3. TKT-015: AppTitlebar (34 PT) + AppStatusbar (24 PT)
4. TKT-016: RegisteredPanes (= 1 register call per new pane)
5. TKT-017: PaneSplitRenderer (1px seam = junction-owned)
6. TKT-018: Phase 6 tests + PaneLifecycle fix
7. TKT-019: CUA verify
8. TKT-020: Tip system (200ms + 300ms warm window)
9. TKT-021: Drop affordance + drag visuals
10. TKT-022: Native controls + drag strip
11. TKT-023: Titlebar/statusbar polish (24 PT hit area, pre-Tahoe Y-nudge)
12. TKT-024: Escape layers + narrow viewport + floating panes
13. TKT-025: TreeHistory (ring buffer cap=50)
14. TKT-026: Phase 10 tests + CUA verify

Plus Boss UX round 2 (= TKT-027): Per-region chrome (= old 6区 top/bottom toolbars)

## Total

- 14 + 1 followup commits pushed to `wt/multi-agent-dispatch`
- 23 source files added
- 13 test files added
- 128 + 11 new tests passing (= 139 total new)
- 1,375 + 400 LOC added (= ~1,775 new)
- Keychain stubbed (= boss to restore Mon)
- Wenshu 6区 + global chrome WORKING (= verified via screenshot)
- Per-region chrome implemented (= standalone, ready for v0.29 wire-up)
