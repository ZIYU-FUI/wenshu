# 002 — ChatView ModelMenu Section-grouped picker

> Parent spec: `.scratch/2026-08-23-provider-model-picker/spec.md`.
> Depends on: 001.
> 1 commit. Modifies ChatView.swift + App.swift (chat zone Menu).

## What to build

Replace flat `availableModels: [String]` with `availableSections: [AvailableProviderModels]`.
Update Menu rendering to use Sections.

## Implementation outline

ChatView (Sources/WenshuApp/Views/Chat/ChatView.swift line 73):
```swift
// Before
public var availableModels: [String] = []

// After
public var availableSections: [AvailableProviderModels] = []
public var currentModel: String = ... // existing
```

loadAvailableModels():
```swift
public func loadAvailableModels() async {
    availableSections = AvailableModelsDiscovery.loadFromKeychain()
    // Optional: merge live-fetched models per provider section
    recomputeContextUsed()
}
```

ChatZoneTab/ChatView Menu (App.swift line 1310):
```swift
// Before
Menu {
    ForEach(availableModels, id: \.self) { entry in
        Button(entry) { currentModel = entry }
    }
}

// After
Menu {
    ForEach(availableSections, id: \.provider.slug) { section in
        Section(section.provider.name) {
            ForEach(section.models, id: \.self) { model in
                Button {
                    currentModel = model
                } label: {
                    HStack {
                        Text(model)
                        if model == currentModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
}
```

## Acceptance criteria

- [ ] ChatView.availableSections exists
- [ ] loadAvailableModels populates availableSections from discovery
- [ ] Menu renders Sections grouped by provider name
- [ ] Each Section's models selectable
- [ ] Checkmark shows next to currentModel (Apple HIG menu selection pattern)
- [ ] Selection still writes to UserDefaults "wenshu.llm.model" (existing)
- [ ] swift build + tests pass