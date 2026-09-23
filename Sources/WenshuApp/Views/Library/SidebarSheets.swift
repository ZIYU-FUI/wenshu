//
//  SidebarSheets.swift · Wenshu · v1.69y boss 2026-09-23 OOB
//
//  Restores the create + rename sheets that were deleted when
//  NewLibraryOutlineView.swift (2466 LOC) was removed in v1.69e
//  (= the MVVM sidebar-split commit). The Apple HIG canonical
//  path for sidebar "new" workflows = `.sheet(item:)` triggered
//  by a `appState.choiceRequestCount` observer (= the toolbar
//  Menu's New buttons all flip the same shared counter, the
//  sidebar body observes via `.onChange(of:)`, and presents the
//  appropriate sheet).
//
//  Each sheet in this file is a focused View (= accepts a small
//  set of inputs + an `onSave` closure + optional `onCancel`).
//  No sheet reads SidebarService or BookStore directly (= the
//  caller passes in availableShelves, targetShelfName, etc.) =
//  sheets are unit-testable in isolation (= the v1.69y ticket
//  adds a source-level SidebarCreateDeleteRenameTests to verify
//  the public API).
//
//  SidebarContextMenu.swift (next file in this ticket) hosts
//  the right-click menu builder = the .contextMenu(forSelectionType:)
//  Apple macOS HIG canonical hook.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - PendingDelete (deletion confirmation sheet state)

/// v1.69y boss 2026-09-23 OOB: pending deletion (= shows the
/// "Are you sure?" `.alert` before the destructive
/// `SidebarService.deleteShelf(id:)` / `deleteBook(id:)`
/// fires). Mirrors the v1.0.0-m1 legacy NewLibraryOutlineView's
/// `PendingDelete` (= same shape; = Identifiable so
/// `.alert(item:)` presents by id).
struct SidebarPendingDelete: Identifiable, Equatable {
    enum Kind: Equatable { case shelf, book }
    let kind: Kind
    let itemId: UUID
    let itemName: String
    var id: UUID { itemId }
}

// MARK: - RenamingTarget (rename sheet state)

/// v1.69y boss 2026-09-23 OOB: pending rename (= shows the
/// `RenameItemSheet` (= a focused single-field sheet with
/// validation = duplicate name check + reserved name check).
struct SidebarRenamingTarget: Identifiable, Equatable {
    enum Kind: Equatable { case shelf, book }
    let kind: Kind
    let itemId: UUID
    let originalName: String
    /// v1.69y: optional `shelfId` (= only used for `.book` renames
    /// to know which shelf dir to walk to find `book.json`).
    let shelfId: UUID?
    var id: UUID { itemId }
}

// MARK: - NewChoiceSheet

/// v1.69y boss 2026-09-23 OOB: the first sheet in the New
/// workflow (= "what do you want to create?"). On pick, fires
/// `onCreate(.shelf)` or `onCreate(.book)` (= the caller
/// observes and flips the next sheet's `isPresented` binding).
/// Mirrors the v1.0.0-m1 legacy NewLibraryOutlineView's
/// `NewChoiceSheet` (= same UX: two large tappable cards).
struct NewChoiceSheet: View {
    enum Choice: Equatable { case shelf, book }
    let onCreate: (Choice) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(WenshuI18n.t("auto2.newlibraryoutlineview.l1560.h95494717"))
                .font(.title2.weight(.semibold))
                .padding(.top, 16)
            HStack(spacing: 16) {
                NewChoiceCard(
                    title: WenshuI18n.t("new_choice_shelf_title"),
                    subtitle: WenshuI18n.t("new_choice_shelf_subtitle"),
                    systemImage: "books.vertical.fill",
                    tint: .accentColor
                ) {
                    onCreate(.shelf)
                }
                NewChoiceCard(
                    title: WenshuI18n.t("new_choice_book_title"),
                    subtitle: WenshuI18n.t("new_choice_book_subtitle"),
                    systemImage: "book.closed.fill",
                    tint: .accentColor
                ) {
                    onCreate(.book)
                }
            }
            .padding(.horizontal, 24)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button(WenshuI18n.t("auto.shared.cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 480, minHeight: 280)
    }
}

/// v1.69y: single tappable card for NewChoiceSheet (= a large
/// icon + title + subtitle in a rounded rectangle that highlights
/// on hover).
private struct NewChoiceCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.tint.opacity(hovering ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.tint.opacity(hovering ? 0.5 : 0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - NewShelfSheet

/// v1.69y: single-field sheet for creating a new shelf (= name
/// only). Mirrors the v1.0.0-m1 legacy NewShelfSheet (= same UX:
/// single TextField + Cancel + Save buttons + live duplicate-name
/// validation against `existingNames`).
struct NewShelfSheet: View {
    let onSave: (String) -> Void
    let onCancel: () -> Void
    let existingNames: [String]

    @State private var name: String = ""
    @Environment(\.dismiss) private var dismiss

    /// v1.69y: reserved shelf names (= same set the v1.0.0-m1
    /// legacy `renameShelf` enforces). The reference library uses
    /// the name `资料库` as its display name; reusing that name for
    /// a user shelf would shadow the reference root.
    static let reservedNames: Set<String> = [
        WenshuI18n.t("library.sidebar.reference_root"),
        "资料库", "参考库", "reference library"
    ]

    /// v1.69y: live validation result (= shown in the Save
    /// button's `.disabled` + a small caption under the
    /// TextField). Mirrors the legacy `nameError` /
    /// `isNameValid` pair.
    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameError: String? {
        if trimmed.isEmpty { return nil }  // empty = not yet a "name" = no error
        if Self.reservedNames.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            return WenshuI18n.t("new_shelf_sheet_reserved_error")
        }
        if existingNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return WenshuI18n.t("new_shelf_sheet_duplicate_error")
        }
        return nil
    }

    private var isNameValid: Bool {
        !trimmed.isEmpty && nameError == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(WenshuI18n.t("new_shelf_sheet_name_field"), text: $name)
                    .textFieldStyle(.roundedBorder)
                if let error = nameError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
            .navigationTitle(WenshuI18n.t("new_shelf_sheet_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(WenshuI18n.t("auto.shared.cancel"), action: onCancel)
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(WenshuI18n.t("auto.shared.save")) {
                        onSave(trimmed)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isNameValid)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 200)
    }
}

// MARK: - NewBookSheet

/// v1.69y: full-form sheet for creating a new book (= title +
/// author + shelf picker + SF Symbols 6 icon picker). Mirrors the
/// v1.0.0-m1 legacy NewBookSheet (= same Form shape + SF Symbols
/// picker UX = scrollable 8-wide LazyVGrid + tap-to-select with
/// `.tint` highlight on the selected cell).
struct NewBookSheet: View {
    let onSave: (NewBookInput) -> Void
    let onCancel: () -> Void
    let targetShelfId: UUID
    let targetShelfName: String
    let availableShelves: [(id: UUID, name: String)]

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var shelfId: UUID
    @State private var selectedIcon: String = "book"

    init(
        onSave: @escaping (NewBookInput) -> Void,
        onCancel: @escaping () -> Void,
        targetShelfId: UUID,
        targetShelfName: String,
        availableShelves: [(id: UUID, name: String)]
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
        self.targetShelfId = targetShelfId
        self.targetShelfName = targetShelfName
        self.availableShelves = availableShelves
        _shelfId = State(initialValue: targetShelfId)
    }

    /// v1.69y: persisted input (= what the caller writes to
    /// disk via SidebarService.createBook(input:)).
    struct NewBookInput: Equatable {
        let title: String
        let author: String
        let shelfId: UUID
        let icon: String
    }

    private var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// v1.69y: curated SF Symbols 6 names (= the v1.0.0-m1
    /// legacy NewBookSheet's `allSFSymbols` list; = same
    /// ~150-icon subset covering all 16 SF Symbols 6 categories
    /// = book / folder / arrow / etc.).
    private var allSFSymbols: [String] {
        [
            "plus", "minus", "xmark", "checkmark",
            "chevron.left", "chevron.right", "chevron.up", "chevron.down",
            "arrow.left", "arrow.right", "arrow.up", "arrow.down",
            "magnifyingglass", "trash", "folder", "folder.badge.plus",
            "document", "document.badge.plus", "book", "book.closed",
            "book.pages", "books.vertical", "book.badge.plus", "person",
            "person.2", "person.3", "brain", "calendar",
            "ellipsis", "ellipsis.circle", "gear", "gearshape",
            "link", "play", "pause", "stop",
            "wand.and.stars", "wand.and.sparkles", "house", "building",
            "lightbulb", "paintpalette", "function", "atom",
            "leaf", "globe", "bell", "bell.badge",
            "tag", "star", "heart", "flag",
            "key", "lock", "shield", "bolt",
            "sun.max", "moon", "cloud", "flame",
            "pencil", "highlighter", "eraser", "paperclip",
            "envelope", "phone", "message", "message.circle",
            "camera", "photo", "music.note", "tv",
            "display", "square", "circle", "plus.circle",
            "info.circle", "sparkles", "ruler", "graduationcap",
            "bookmark", "list.bullet", "rectangle.grid.2x2", "eye",
            "hand.thumbsup", "hand.thumbsdown", "car", "creditcard",
            "hammer", "wrench.and.screwdriver"
        ].sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(WenshuI18n.t("new_book_sheet_title_field"), text: $title)
                    .textFieldStyle(.roundedBorder)
                TextField(WenshuI18n.t("new_book_sheet_author_field"), text: $author)
                    .textFieldStyle(.roundedBorder)
                Picker(WenshuI18n.t("new_book_sheet_shelf_picker"), selection: $shelfId) {
                    ForEach(availableShelves, id: \.id) { shelf in
                        Text(shelf.name).tag(shelf.id)
                    }
                }
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.tint.opacity(0.15))
                                .frame(width: DesignTokens.surfaceSizeMedium, height: DesignTokens.surfaceSizeMedium)
                            Image(systemName: selectedIcon).font(.system(size: 32, weight: .regular))
                                .foregroundStyle(Color.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WenshuI18n.t("new_book_sheet_icon_label"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(selectedIcon)
                                .font(.system(.caption, design: .monospaced))
                        }
                        Spacer()
                    }
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                            spacing: 8
                        ) {
                            ForEach(allSFSymbols, id: \.self) { iconName in
                                Button {
                                    selectedIcon = iconName
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedIcon == iconName
                                                  ? AnyShapeStyle(.tint.opacity(0.25))
                                                  : AnyShapeStyle(Color.clear))
                                            .frame(
                                                width: DesignTokens.toolbarButtonCompact,
                                                height: DesignTokens.toolbarButtonCompact
                                            )
                                        Image(systemName: iconName)
                                            .font(.system(size: 18, weight: .regular))
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 220)
            }
            }
            .padding(20)
            .navigationTitle(WenshuI18n.t("new_book_sheet_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(WenshuI18n.t("auto.shared.cancel"), action: onCancel)
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(WenshuI18n.t("auto.shared.save")) {
                        onSave(NewBookInput(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                            shelfId: shelfId,
                            icon: selectedIcon
                        ))
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isTitleValid)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 520)
    }
}

// MARK: - RenameItemSheet

/// v1.69y: single-field sheet for renaming a shelf or book.
/// Validation = duplicate-name check (against `otherNames`) +
/// reserved-name check (= same reservedNames set as
/// NewShelfSheet).
struct RenameItemSheet: View {
    let kind: SidebarRenamingTarget.Kind
    let originalName: String
    let otherNames: [String]
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""

    init(
        kind: SidebarRenamingTarget.Kind,
        originalName: String,
        otherNames: [String],
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.kind = kind
        self.originalName = originalName
        self.otherNames = otherNames
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: originalName)
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameError: String? {
        if trimmed.isEmpty { return nil }
        if trimmed.caseInsensitiveCompare(originalName) == .orderedSame { return nil }  // unchanged = OK
        if NewShelfSheet.reservedNames.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            return WenshuI18n.t("rename_item_sheet_reserved_error")
        }
        if otherNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return WenshuI18n.t("rename_item_sheet_duplicate_error")
        }
        return nil
    }

    private var isNameValid: Bool {
        !trimmed.isEmpty && nameError == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(WenshuI18n.t("rename_item_sheet_name_field"), text: $name)
                    .textFieldStyle(.roundedBorder)
                if let error = nameError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
            .navigationTitle(WenshuI18n.t("rename_item_sheet_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(WenshuI18n.t("auto.shared.cancel"), action: onCancel)
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(WenshuI18n.t("auto.shared.save")) {
                        onSave(trimmed)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isNameValid)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 200)
    }
}