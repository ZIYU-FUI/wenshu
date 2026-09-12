# Ticket 001 — strip `@State var inspectorVisible = true` to SwiftUI default

## Rule
NavigationSplitShell.swift currently has `@State private var inspectorVisible: Bool = true` hardcoded as the initial value. Replace with no initializer — SwiftUI defaults `.inspector(isPresented:)` to `false` on first launch; user reveals it via the inspector chevron rendered automatically by the modifier.

## Diff scope
`Sources/WenshuApp/UI/Layout/NavigationSplitShell.swift` — only line 71:
- Before: `@State private var inspectorVisible: Bool = true`
- After: `@State private var inspectorVisible: Bool = false`

## Why
Apple NSV inspector modifier owns its own visibility state on macOS 14+. The hardcoded `true` was a v0.48 boss OOB that pre-set the inspector visible. Per boss 2026-09-10 "\u8d70 Apple \u9ed8\u8ba4\u884c\u4e3a", let SwiftUI default behavior take over.

## Verify
- swift build → exit 0
- launch app → right column starts hidden
- click inspector chevron on column header → right column reveals with the same Tools/Dynamic content
