# 01 — EntityType enum + strict 2D taxonomy schema

**What to build:**

Boss 2026-08-30 OOB '实体智能分类实现... 实体如何定义，是不是有规则'
chose option A = add explicit EntityType schema. Pre-fix: `Reference` had
`category` (= 中图法 taxonomy) but no narrative role classification.

Fix: add `EntityType` enum + `Reference.entityType` field.

**Blocked by:** None (= can start independently).

**Status:** ready-for-agent (= already committed as `32fafec3c`, this
ticket documents the commit after-the-fact per Q5.6 partial commit 接管
规范).

## Fix specification

### New file: `Sources/WenshuApp/Domain/EntityType.swift`

9-case enum:
```swift
enum EntityType: String, CaseIterable {
    case character, location, event, concept, artifact, organization, era, work, other

    var displayName: String { ... }  // 2-char Chinese: 人物/地点/事件/概念/物品/组织/朝代/作品/其他
    var icon: String { ... }         // SF Symbol name per type
    var shortName: String { ... }    // 1-char (deprecated, kept for future tight-UI)
    var promptNumber: Int { ... }    // 1-9 for LLM classification prompts
}
```

### Modified: `Sources/WenshuApp/Domain/Reference.swift`

- Add `entityType: EntityType = .other` field (= backward compatible default)
- Update `init(from decoder:)` + `encode(to encoder:)` for Codable
- Field accepts both Int (= LLM output format) and String (= human-readable
  rawValue) during decode (= dual-format per migration precedent)

### Modified: 4 other files

- `FileSystemReferenceStore.swift`: pass entityType in save/replace
- `LibraryMigrator.swift`: existing migrator unchanged (= existing entities
  decode with default = .other)
- `EntityClassifier.swift`: returns `(category, entityType)` tuple; keyword
  pass returns .other for type (= keyword doesn't infer narrative role)
- LLM prompt enhanced to return type number alongside category letter

## Acceptance

- [x] EntityType enum has 9 cases
- [x] Reference.entityType defaults to .other
- [x] Existing entities decode without error (= backward compat)
- [x] New entities can set entityType via LLM or manual UI
- [x] Build exit 0

## Out-of-scope

- LLM-based type classification (= phase 2; keyword classifier first per
  boss 8/30 OOB)
- UI to manually set entityType (= v0.31+; current data flow = LLM-set only)
