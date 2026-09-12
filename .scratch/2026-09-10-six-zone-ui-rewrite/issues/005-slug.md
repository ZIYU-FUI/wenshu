# Ticket 005 — land .fileImporter for new-library file open

## Rule
Replace the existing NSOpenPanel direct call in onboarding with SwiftUI `.fileImporter(isPresented:allowedContentTypes:onCompletion:)`. Per Apple HIG Inventory 2026-09-06 `.fileImporter` was 0 hits.

## Diff scope
Find the NSOpenPanel call site for library selection (= likely `Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift` or `Sources/WenshuApp/App/WenshuAppDelegate.swift`). Replace NSOpenPanel flow with `.fileImporter`.

## Why
Apple HIG macOS 14+: 'Use .fileImporter for the standard file picker UX'. Onboarding library selection = single-select = SwiftUI's standard picker is appropriate.

## Verify
- swift build → exit 0
- onboarding → "Select Library" opens the standard SwiftUI file importer (not the legacy NSOpenPanel panel)
