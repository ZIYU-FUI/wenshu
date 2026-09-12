# Ticket 002 — land real outline view in middle column top sub-area

## Rule
Replace the hardcoded `Text("\u5927\u7eb2")` + `ForEach(appState.openTabs)` placeholder in ShellMiddleColumn top sub-area with a real outline view. Use NewLibraryOutlineView scoped to the currently-selected book (= reads `appState.selectedBookID`).

If `selectedBookID == nil` show Apple HIG `ContentUnavailableView` (= Xcode's "No Selection" pattern).

## Diff scope
`Sources/WenshuApp/UI/Layout/NavigationSplitShell.swift` ShellMiddleColumn body, ~50 lines.

## Why
Boss 9/10 second OOB 'NAV default 3 columns + sub-areas = visual 5 columns'. The top sub-area of the middle column = outline = the 2nd visible column from the left in the visual 5-column layout.

## Verify
- swift build → exit 0
- select a book in sidebar → middle column top shows that book's chapters tree
- deselect sidebar → middle column top shows ContentUnavailableView "No book selected"
