# Ticket 009 — strip hardcoded CGFloat / Color / font-size literals from NavigationSplitShell.swift

## Rule
Audit NavigationSplitShell.swift for hardcoded numeric literals (e.g. .frame(height: 38), .padding(12), Color.gray.opacity(0.5), .font(.system(size: 14))). Replace with DesignTokens / ContentStyles / IconStyles equivalents per ComponentIndex.md Levels 1-4.

## Diff scope
`Sources/WenshuApp/UI/Layout/NavigationSplitShell.swift` — all hardcoded literals in ShellSidebarColumn / ShellMiddleColumn / ShellContentColumn / ShellDetailColumn / ShellPlaceholder bodies.

## Why
Iron-rule 6 = no magic numbers in view code. Iron-rule 1 = no hardcoded colors. ComponentIndex §1.1 DesignTokens = the single source of truth. Boss 9/7 'ui \u4e0e\u529f\u80fd\u5206\u79bb' = STYLES files own all visual constants.

## Verify
- swift build → exit 0
- grep NavigationSplitShell.swift for `padding(`, `frame(width:`, `frame(height:`, `font(.system(size:` → zero hardcoded literals outside DesignTokens references
