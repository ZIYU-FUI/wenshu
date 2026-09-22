// LazySidebarSheets.swift · Wenshu · v1.68
//
// Boss 2026-09-22 OOB 'UI 与功能分离, UI 是 UI, 加载的内容是内容,
// 不要混合写大文件': extracted from LazySidebarView.swift (= the
// 957-LOC file that the v1.64 / v1.65 sidebar rewrite produced).
//
// This file owns the sidebar's 4 sheet views (= the SwiftUI modal
// sheets LazySidebarView shows when the user clicks the sidebar
// bottom '+' button, or right-clicks a shelf / book and chooses
// Rename / Delete). Each sheet is its own View (= focused, single-
// purpose UI). Their bodies are inline surface
//
// What lives here:
//   - LazyNewBookSheet       : sheet for creating a new Book
//   - LazyNewShelfSheet      : sheet for creating a new Bookshelf
//   - LazyNewChoiceSheet     : chooser sheet (= New Book / New Shelf)
//   - LazyRenameItemSheet    : sheet for renaming a shelf or book
//
// What does NOT live here:
//   - business logic (= LazySidebarFileOps).
//   - state persistence (= LazySidebarState).
//   - view body composition (= LazySidebarView).

import SwiftUI

struct LazyNewBookSheet: View {
    let targetShelfId: UUID
    let targetShelfName: String
    let availableShelves: [(id: UUID, name: String)]
    let onSave: (Book) -> Void
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var shelfId: UUID
    @State private var selectedIcon: String = "book"
    @Environment(\.dismiss) private var dismiss

    init(
        targetShelfId: UUID,
        targetShelfName: String,
        availableShelves: [(id: UUID, name: String)],
        onSave: @escaping (Book) -> Void
    ) {
        self.targetShelfId = targetShelfId
        self.targetShelfName = targetShelfName
        self.availableShelves = availableShelves
        self.onSave = onSave
        _shelfId = State(initialValue: targetShelfId)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("标题", text: $title).textFieldStyle(.roundedBorder)
                TextField("作者", text: $author).textFieldStyle(.roundedBorder)
                Picker("归属书架", selection: $shelfId) {
                    ForEach(availableShelves, id: \.id) { shelf in
                        Text(shelf.name).tag(shelf.id)
                    }
                }
                TextField("图标名 (SF Symbols 6)", text: $selectedIcon)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            .navigationTitle("新建书")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let book = Book(
                            title: title, author: author,
                            icon: selectedIcon, shelfId: shelfId
                        )
                        onSave(book)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 360, idealHeight: 420)
    }
}

struct LazyNewShelfSheet: View {
    let existingNames: [String]
    let onSave: (String, String) -> Void
    @State private var name: String = ""
    @State private var selectedIcon: String = "books.vertical"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("书架名", text: $name).textFieldStyle(.roundedBorder)
                TextField("图标名 (SF Symbols 6)", text: $selectedIcon)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            .navigationTitle("新建书架")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(name, selectedIcon)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 200, idealHeight: 240)
    }
}

struct LazyNewChoiceSheet: View {
    let onNewBook: () -> Void
    let onNewShelf: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            HStack(spacing: 12) {
                Button { onNewBook() } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "book.badge.plus")
                            .font(.system(size: 32, weight: .regular))
                        Text("新建书").font(.body)
                    }
                    .frame(width: 120, height: 120)
                }
                .buttonStyle(.bordered)

                Button { onNewShelf() } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 32, weight: .regular))
                        Text("新建书架").font(.body)
                    }
                    .frame(width: 120, height: 120)
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .navigationTitle("新建")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .frame(minWidth: 280, idealWidth: 320, minHeight: 180, idealHeight: 200)
    }
}

struct LazyRenameItemSheet: View {
    let title: String
    let originalName: String
    let existingNames: [String]
    let onSave: (String) -> Void

    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        originalName: String,
        existingNames: [String],
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.originalName = originalName
        self.existingNames = existingNames
        self.onSave = onSave
        _name = State(initialValue: originalName)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                TextField("新名字", text: $name).textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button("保存") {
                    onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 160, idealHeight: 200)
    }
}