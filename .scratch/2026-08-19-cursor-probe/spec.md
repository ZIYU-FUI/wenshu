# Cursor minimal verification — verify SwiftUI `.pointerStyle` works on macOS 27

> 老板 2026-08-19 拍 "check official docs to confirm macOS 27 fix"
> Root-cause report v2: `cursor-investigation-report-v2.md`
> Recommended Plan A: fall back to SwiftUI `.pointerStyle(.columnResize() / .rowResize())`

## Goal

Write a minimal SwiftUI case to verify SwiftUI `.pointerStyle(.columnResize())` / `.rowResize()` work as the truth-source on macOS 27, without depending on NSViewRepresentable / NSResponder / NSTrackingArea.

If work → fall back to SwiftUI paradigm. Rewrite NativeSplitter (delete `SplitterHitArea` NSView + `WenshuCursorController`).
If not work → go to candidate D NSWindow subclassing.

## SwiftUI Cursor Probe (report L431–455 full code)

```swift
import SwiftUI

@main
struct CursorProbe: App {
    var body: some Scene {
        WindowGroup { CursorProbeView() }
            .windowStyle(.titleBar)
            .defaultSize(width: 800, height: 400)
    }
}

struct CursorProbeView: View {
    @State private var offset: CGFloat = 200
    var body: some View {
        HStack(spacing: 0) {
            Color.red.frame(width: offset, height: 400)
            Color.clear
                .frame(width: 6, height: 400)
                .pointerStyle(.columnResize())
                .onContinuousHover { phase in
                    print("hover phase: \(phase)")
                }
            Color.blue.frame(maxWidth: .infinity, maxHeight: 400)
        }
    }
}
```

## Run steps

1. `swift /Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-19-cursor-probe/CursorProbe.swift`
2. Hover mouse over 6 PT transparent strip (middle `clear` region).
3. ✅ cursor switches to ↔ double arrow → candidate A works.
4. ❌ cursor does not switch → SwiftUI `.pointerStyle` truly has a bug inside macOS 27 + NSHostingView subtree. Go to candidate D NSWindow subclassing.

## Acceptance criteria

- [ ] SwiftUI `.pointerStyle(.columnResize())` works on 6 PT `clear` strip (cursor becomes ↔).
- [ ] SwiftUI `.pointerStyle(.rowResize())` works the same way (老板 8/19 拍 6 drag lines; D_h uses rowResize).
- [ ] No dependency on NSViewRepresentable / NSResponder / NSTrackingArea.
- [ ] `swift build` exit 0.
- [ ] 老板 self-launches binary to verify (this environment has no GUI).

## Out of Scope

- Do not touch wenshu NativeSplitter.
- Do not rewrite `SplitterHitArea` NSView.
- Do not rewrite `WenshuCursorController`.

## Further Notes

- Root-cause report v2 full text = `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-19-dh-fixes-3/cursor-investigation-report-v2.md`.
- Report L416–475 = Verdict for 老板.
- 5 candidate fix ranking + recommended plan.