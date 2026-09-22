// LazySidebarState.swift · Wenshu · v1.68
//
// Boss 2026-09-22 OOB 'UI 与功能分离, UI 是 UI, 加载的内容是内容,
// 不要混合写大文件': extracted from LazySidebarView.swift (= the
// 957-LOC file that the v1.64 / v1.65 sidebar rewrite produced).
// This file owns the sidebar's persistence (= LazySidebarState + the
// 2 sheet-input targets + 1 kind enum). They are PURE data types:
// no SwiftUI imports (= the 'UI is UI, content is content' split).
//
// What lives here:
//   - LazySidebarState  : Codable persistence of disclosure + selection.
//   - LazyItemKind      : enum for shelf-vs-book sheet inputs.
//   - LazyRenamingTarget: Identifiable sheet input for rename.
//   - LazyPendingDelete : Identifiable sheet input for delete-confirmation.
//
// What does NOT live here:
//   - view body or sheet view rendering (= LazySidebarSheets.swift).
//   - row rendering (= LazySidebarRow.swift).
//   - file ops (= LazySidebarFileOps.swift).

import Foundation

/// Codable snapshot of the sidebar's interactive state (= which
/// shelves / books / reference-library disclosures are open + the
/// current selection). Persisted via `@AppStorage("wenshu.sidebarState")`.
struct LazySidebarState: Codable, Equatable {
    var shelfExpanded: [UUID: Bool]
    var bookExpanded: [UUID: Bool]
    var referenceLibraryExpanded: Bool
    var selection: SidebarItem?

    init(
        shelfExpanded: [UUID: Bool] = [:],
        bookExpanded: [UUID: Bool] = [:],
        referenceLibraryExpanded: Bool = false,
        selection: SidebarItem? = nil
    ) {
        self.shelfExpanded = shelfExpanded
        self.bookExpanded = bookExpanded
        self.referenceLibraryExpanded = referenceLibraryExpanded
        self.selection = selection
    }

    var jsonString: String {
        guard let data = try? JSONEncoder().encode(self),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }

    static func from(jsonString: String) -> LazySidebarState {
        guard !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let state = try? JSONDecoder().decode(LazySidebarState.self, from: data)
        else { return LazySidebarState() }
        return state
    }
}

/// Discriminator for the LazySidebarView's sheet / alert inputs.
enum LazyItemKind: String {
    case shelf
    case book
}

/// Identifiable input for the rename sheet (= the rename action
/// needs to know what kind of item + which id + originalName to
/// prefill the field).
struct LazyRenamingTarget: Identifiable {
    let id = UUID()
    let kind: LazyItemKind
    let itemId: UUID
    let originalName: String
}

/// Identifiable input for the delete-confirmation alert (= the
/// alert needs to know what kind + which item id + display name for
/// the confirm message).
struct LazyPendingDelete: Identifiable {
    let id = UUID()
    let kind: LazyItemKind
    let itemId: UUID
    let itemName: String
}