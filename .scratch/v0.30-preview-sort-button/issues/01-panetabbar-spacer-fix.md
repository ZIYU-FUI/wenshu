# Ticket 1: fix PaneTabBar inner HStack Spacer collapse

## Goal
Fix PaneTabBar.body's inner HStack to give the Spacer(minLength: 0)
real horizontal space to consume (= so the trailing button is pushed
to the right edge of the RegionTabBar instead of sitting immediately
after the last tab).

## Root cause (= bug pattern)
The inner HStack in PaneTabBar.body (= wrapping the ForEach tabs +
Spacer + trailing() call) had only intrinsic width (= sum of children).
When the inner HStack's children were tabs (28 PT each) + Spacer +
trailing button (28 PT), the HStack's intrinsic width was ~56 PT (= no
slack for Spacer to expand). So `Spacer(minLength: 0)` collapsed to
zero width and the trailing button rendered immediately after the last
tab with no gap (= "compressed against the left side of the tab bar").

## Fix
Add `.frame(maxWidth: .infinity)` to the inner HStack so it expands to
fill the outer RegionTabBar's full width (RegionTabBar.body already
has `.frame(maxWidth: .infinity, alignment: .leading)` on its outer
HStack). With the inner HStack now full-width, the Spacer has real
horizontal space to expand into, pushing the trailing button to the
right edge.

## Acceptance criteria
1. `swift build` exit 0 (= no new errors/warnings introduced).
2. After fix: preview pane trailing button (= list-ordered icon for
   sort) renders at the right edge of preview pane top bar.
3. After fix: editor pane trailing button (= expand/shrink icon)
   renders at the right edge of editor pane top bar.

## Files touched
- `Sources/WenshuApp/UI/PaneTabBar.swift` — add `.frame(maxWidth: .infinity)`
  modifier to the inner HStack in `body` (one-line addition).

## Diff summary
```swift
// before:
HStack(spacing: 0) {
    ForEach(items) { ... }
    if !(Trailing.self == EmptyView.self) {
        Spacer(minLength: 0)
        trailing()
    }
}
.padding(.leading, DesignTokens.chromePaddingLeading)

// after:
HStack(spacing: 0) {
    ForEach(items) { ... }
    if !(Trailing.self == EmptyView.self) {
        Spacer(minLength: 0)
        trailing()
    }
}
.padding(.leading, DesignTokens.chromePaddingLeading)
.frame(maxWidth: .infinity)  // <- NEW: lets Spacer expand
```

## Verification commands
```bash
cd /Volumes/ANAN/Engineering/wenshu
swift build 2>&1 | tail -3  # expect: "Build complete!"
bash Scripts/build-app.sh 2>&1 | tail -1  # expect: "done. open with: open ..."
# Open app, switch to reference library overview (= sort visible at right of preview pane top bar)
defaults write com.wenshu.app wenshu.sidebarSelection -string '{"referenceCategory":"__root__","kind":"referenceCategory"}'
open /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app
```