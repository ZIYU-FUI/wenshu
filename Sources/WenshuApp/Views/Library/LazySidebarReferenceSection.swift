// LazySidebarReferenceSection.swift · Wenshu · v1.68
//
// Boss 2026-09-22 OOB 'UI 与功能分离, UI 是 UI, 加载的内容是内容,
// 不要混合写大文件': extracted from LazySidebarView.swift (= the
// 957-LOC file that the v1.64 / v1.65 sidebar rewrite produced).
//
// This file owns the REFERENCE LIBRARY SECTION rendering (= the
// disclosure root + nested entity categories whose discovery is
// filtered by `usedCategories()`).
//
// What lives here:
//   - LazySidebarReferenceSection : reference library section.
//
// What does NOT live here:
//   - business logic (= LazySidebarFileOps).
//   - state persistence (= LazySidebarState).
//   - view body composition (= LazySidebarView).
//
// v1.68 restore notes: the v1.67 LazySidebarView had
// `referenceLibrarySection` as a private computed property (= depended
// on @State + @Environment implicitly). Splitting it out (= making
// the disclosure state + selection callbacks explicit parameters)
// makes it reusable from any caller (= the v1.68 sidebar Apple HIG
// rewrite that lists the reference library as a separate List row).

import SwiftUI

struct LazySidebarReferenceSection: View {
    let isExpanded: Bool
    let categories: [EntityCategory]
    let selectedCategory: String?
    let onToggle: () -> Void
    let onSelectCategory: (String) -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Image(systemName: "books.vertical")
                    .frame(width: 18)
                Text("资料库")
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, DesignTokens.chromePaddingLeading)
            .frame(width: nil, height: DesignTokens.chromeHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        // v1.67 mutual-exclusion fix (= see LazySidebarBookRow for full
        // rationale): hoist the isExpanded check OUT of the parent
        // ForEach so LazyVStack sees N distinct view children instead
        // of one collapsed tuple.
        ForEach(categories) { category in
            if isExpanded {
                Button {
                    onSelectCategory(category.rawValue)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: category.icon)
                            .frame(width: 18)
                        Text(category.displayName)
                            .font(.body)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, DesignTokens.chromePaddingLeading)
                    .padding(.leading, 14)
                    .frame(width: nil, height: DesignTokens.chromeHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedCategory == category.rawValue
                                ? AnyShapeStyle(.tint)
                                : AnyShapeStyle(Color.clear))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                EmptyView()
            }
        }
    }
}