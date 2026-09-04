# Ticket 1: Fix sort icon render in preview pane top bar

## Goal
Make `PreviewSortMenuButton` actually render at the right edge of
the preview pane top bar (= restore the visual promised by previous
commit adcab7c1b which compiled + passed review but did NOT render
the button visually — boss caught this via screenshot).

## Root cause hypothesis
Multiple possible causes (= need to verify with screenshot debug):

1. **Build cache staleness** (= boss may have been viewing an OLD
   build that didn't have the .frame(maxWidth: .infinity) fix).
   FIX: full clean rebuild + verify with screenshot diff.

2. **AnyView wrapping erases PreviewSortMenuButton's intrinsic size**
   (= the Button has no fixed width, AnyView defaults to 0, trailing
   collapses). FIX: add `.frame(width: 28, height: 28)` to the
   Button's content OR use Color.clear base like PaneIconTab.

3. **PaneTabBar's trailing slot is being clipped by the outer
   RegionTabBar's `.frame(maxWidth: .infinity, alignment: .leading)`**
   (= alignment .leading positions the HStack at the left, but the
   inner Spacer + trailing pattern requires the Spacer to push
   trailing to the right edge). FIX: change RegionTabBar alignment
   to .center OR change inner HStack layout.

4. **Trailing closure is being skipped** (= the `if !(Trailing.self
   == EmptyView.self)` check evaluates to false because Trailing is
   `_ConditionalContent<AnyView, EmptyView>` which has no `==` with
   `EmptyView`). FIX: replace conditional check with unconditional
   trailing() call + let EmptyView's zero-width collapse.

## Debug approach
Add a red border + yellow fill to PreviewSortMenuButton's outer
container (= visible debug marker). Capture screenshot at preview
pane top bar area. Determine:
- Is the red border visible (= button is rendered)?
- Is the yellow fill visible (= button has non-zero size)?
- Where is the button positioned (= left edge, middle, right edge)?

## Fix (per debug result)
After identifying which root cause matches, apply minimal fix:
- If cause 1: full rebuild + re-verify
- If cause 2: add explicit frame to PreviewSortMenuButton
- If cause 3: fix RegionTabBar alignment
- If cause 4: remove conditional check in PaneTabBar

## Acceptance criteria
1. Screenshot shows list-ordered icon at the right edge of preview
   pane top bar (clearly visible, not collapsed).
2. Click on sort icon cycles through 3 sort orders (preserved
   behavior from adcab7c1b).
3. Editor's expand icon ALSO visible at right edge of editor pane
   top bar (= the same fix applies to both since both use the same
   trailing slot mechanism).

## Files touched
- Likely Sources/WenshuApp/UI/PaneTabBar.swift (most likely)
- OR Sources/WenshuApp/UI/RegionTabBar.swift (alignment fix)
- OR Sources/WenshuApp/Views/Workspace/WorkspaceView.swift
  (PreviewSortMenuButton explicit frame)

## Verification commands
```bash
cd /Volumes/ANAN/Engineering/wenshu
pkill -9 -f WenshuApp
rm -rf .build build
swift build 2>&1 | tail -3
bash Scripts/build-app.sh 2>&1 | tail -1
defaults write com.wenshu.app wenshu.sidebarSelection -string '{"referenceCategory":"__root__","kind":"referenceCategory"}'
open build/Wenshu.app
sleep 6
# Capture screenshot, verify preview pane top bar shows list-ordered icon
# at right edge.
```