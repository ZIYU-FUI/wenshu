# 02 — cursor switch ↕/↔ (老板 2026-08-20 拍)

**What to build:**
老板 2026-08-20 拍 "mouse still does not change shape". Fix ticket 02.

After fix:
- Delete commit f65bb3292's `.pointerStyle` attached to the ZStack parent (wrong location, NSViewRepresentable bridging SplitterHitAreaRepresentable cannot pass through the SwiftUI cursor system)
- Attach it to NativeSplitter body's Rectangle visually (inside the SwiftUI view tree)
- SwiftUI `.pointerStyle` modifier penetrates the NSViewRepresentable bridge into the SwiftUI view tree, NSHostingView takes over cursor events → SwiftUI PointerStyle system works

**Blockers:** ticket 01 fix complete (same priority).

**Acceptance:**
- swift build exit 0
- 老板 mouse hover D_h drag line → cursor switches to ↕ up-down arrow
- 老板 mouse hover D_v 5 vertical drag lines → cursor switches to ↔ left-right arrow
- 老板 mouse leaves → cursor reverts
- Do not touch: hermes / 6-zone layout framework / drag line visuals (1 PT fill / 3 PT hover / 1 PT hit area / system color / no rounded ends) / WenshuCore 14 ground-truth modules / ChatView