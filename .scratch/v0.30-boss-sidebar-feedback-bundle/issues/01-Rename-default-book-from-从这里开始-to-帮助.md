# Ticket 01 — Rename default book from 从这里开始 to 帮助

> Spec: ../spec.md
> Boss OOB: 2026-08-31 (= boss in office manual APP verify)

## Acceptance

 echo "- Default shelf '从这里开始' contains one book titled '帮助' (not '从这里开始')
- Rename via BookStore seed or migration";;
02) echo "- Status bar shows actual count of shelves + books from filesystem
- 书架: N = count of shelves in shelves/
- 书: N = count of books across all shelves";;
03) echo "- Sub-folder row (世界观 / 角色 / etc.) shows .md count badge
- Click sub-folder → preview pane shows that folder's .md files";;
04) echo "- List section spacing 30PT → 10PT (boss target)
- Use SwiftUI .listSectionSpacing(10) or Section header padding adjustment";;
05) echo "- Click sidebar row → preview pane switches to scoped view
- Click shelf → preview shows all books in shelf
- Click book → preview shows book's folder contents
- Click reference category → preview shows category-scoped entities";;
06) echo "- EntityCategory gains '其它' catch-all (= currently 'Z 综合性图书')
- EntityClassifier.swift: when no category matches, route to .其他
- reference-library/entities/其它/ directory auto-created";;
esac)

## Q34 progress

| Step | Status |
|---|---|
| 1. grill | done (in spec.md) |
| 2. spec | done (in spec.md) |
| 3. tickets | done (this file) |
| 4. implement | pending |
| 5. code-review 双轴 | pending |
| 6. hard violation 修法 | pending |
| 7. domain-modeling | pending (= depends on entity type changes) |
| 8. Q22 真验证 | pending |
