# Ticket 2: Unify all 6 zones' top bars (ZoneContentTabBar + ChatZoneTopChrome + DynamicZoneTabBar)

## Goal
Make all 6 zones' top bars visually identical in structure:
- Same height (30 PT) [already true via RegionTabBar]
- Same background (.regularMaterial) [already true]
- Same bottom 1 PT separator [already true]
- Same horizontal padding (18 PT leading + 18 PT trailing)
- Same tab icon size (18 PT) inside 28 PT hot area
- Same selected-state underline (1 PT capsule)
- **Trailing buttons at consistent right edge** (= 18 PT from right,
  with same icon size)

## Root cause
- `ZoneContentTabBar` trailing button: no explicit trailing padding
- `ChatZoneTopChrome` trailing button: has `.padding(.trailing,
  DesignTokens.chromePaddingTrailing)` (= inconsistent with others)
- `DynamicZoneTabBar`: no trailing button (= OK, but visually
  asymmetric compared to other zones)

## Fix approach
1. **Standardize trailing padding**: add `.padding(.trailing,
   DesignTokens.chromePaddingTrailing)` to all trailing button
   containers (PaneTabBar's Trailing ViewBuilder output).
2. **Decide trailing policy**:
   - All zones with trailing button: same icon size (18 PT), same
     padding, same hover tint.
   - All zones without trailing button: empty right edge (= no
     trailing slot, naturally).
3. **Verify visual consistency**: 6 screenshots side-by-side, all
   top bars must look the same in chrome structure.

## Acceptance criteria
1. All 6 zones' top bars have **identical** chrome structure
   (= same height, background, padding, separator, underline).
2. Trailing buttons (where present) sit at the same right-edge
   position with same icon size + hover behavior.
3. No zone has unique chrome behavior (e.g., extra padding only in
   chat zone).

## Files touched
- `Sources/WenshuApp/UI/PaneTabBar.swift` — add trailing padding to
  the inner HStack trailing slot (= applies to all callers).
- `Sources/WenshuApp/Views/Dynamic/ZoneContentView.swift` —
  ZoneContentTabBar.trailingButton wrapper.
- `Sources/WenshuApp/Views/Dynamic/DynamicZoneView.swift` —
  DynamicZoneTabBar trailing wrapper (if any).
- `Sources/WenshuApp/Views/Workspace/PaneRenderer.swift` —
  ChatZoneTopChrome trailing wrapper (= remove the redundant
  .padding(.trailing) since PaneTabBar now handles it).

## Verification commands
```bash
cd /Volumes/ANAN/Engineering/wenshu
swift build 2>&1 | tail -3
# Launch + capture 6-zone screenshot for visual diff
```