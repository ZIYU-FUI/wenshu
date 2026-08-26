// CharacterOutlineView.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Second-column card grid for a single Book's character entries. Book-
// private (= FCP Role pattern; each Book has its own character set;
// a "张三" in Book 1 is unrelated to a "张三" in Book 2).
//
// Per boss 2026-08-26 OOB '卡片样式就是展示文档的重点摘要' = card
// shows the character's role + name + summary (= 1-line description of
// who they are and what they want).
//
// Storage path (= per spec v5):
//   books/<book-uuid>/characters/<char-uuid>.md   <- markdown body
//   books/<book-uuid>/characters.json             <- structured index
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 010.

import SwiftUI

struct CharacterOutlineView: View {
    let store: CharacterStoring
    let bookId: UUID
    var onSelect: ((Character) -> Void)?
    var onDelete: ((Character) -> Void)?

    @State private var characters: [Character] = []
    @State private var loadError: String?

    var body: some View {
        Group {
            if let error = loadError {
                errorState(error)
            } else if characters.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .frame(minWidth: 280, minHeight: 200)
        .onAppear(perform: reload)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 12)],
                spacing: 12
            ) {
                ForEach(characters) { character in
                    CharacterCard(character: character)
                        .onTapGesture { onSelect?(character) }
                        .contextMenu {
                            Button("删除", role: .destructive) {
                                if let onDelete = onDelete {
                                    onDelete(character)
                                } else {
                                    try? store.deleteCharacter(id: character.id)
                                    reload()
                                }
                            }
                        }
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("这本书还没有角色")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("无法加载角色")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reload() {
        do {
            characters = try store.loadCharacters()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct CharacterCard: View {
    let character: Character

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: character.role.icon)
                    .foregroundStyle(roleColor)
                Text(character.role.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let age = character.age {
                    Text("\(age) 岁")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(character.name)
                .font(.headline)
                .lineLimit(2)
            if let arc = character.arc, !arc.isEmpty {
                Text(arc)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !character.summary.isEmpty {
                Text(character.summary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(roleColor.opacity(0.4), lineWidth: 1.5)
        )
    }

    private var roleColor: Color {
        Color(hex: character.role.colorHex) ?? .accentColor
    }
}

// MARK: - Color hex extension

extension Color {
    /// Apple HIG canonical pattern: parse '#RRGGBB' or '#AARRGGBB' into
    /// a SwiftUI Color. Returns nil if the input is malformed.
    init?(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard let v = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((v & 0xFF0000) >> 16) / 255
            g = Double((v & 0x00FF00) >> 8) / 255
            b = Double(v & 0x0000FF) / 255
            a = 1
        } else if s.count == 8 {
            r = Double((v & 0xFF000000) >> 24) / 255
            g = Double((v & 0x00FF0000) >> 16) / 255
            b = Double((v & 0x0000FF00) >> 8) / 255
            a = Double(v & 0x000000FF) / 255
        } else {
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}