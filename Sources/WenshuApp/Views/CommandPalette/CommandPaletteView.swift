//
//  CommandPaletteView.swift · Wenshu · CHATBOX-002 (2026-09-04)
//
//  ⌘K command palette — modal SwiftUI sheet that lists every registered
//  CommandPaletteItem from CommandPaletteRegistry.shared, filtered by
//  the user's query.
//
//  CHATBOX-002 (2026-09-04, boss OOB 'B'): hermes commands.py +
//  slash_registry.py parity. Single search box at the top + scrollable
//  list below + click-to-invoke.
//
//  Design choices:
//    - Modal sheet (= Apple HIG macOS command palette convention; same
//      shape as Slack's / VS Code's ⌘P). Not a separate NSWindow —
//      sheets inherit the parent window's focus + key state, so the
//      TextField auto-focuses correctly.
//    - @State query + @ObservedObject registry = the SwiftUI view
//      reads the actor's snapshot synchronously via `.task` (= the
//      actor hop happens inside the SwiftUI task body).
//    - 600 × 400 PT frame = canonical palette size per Apple HIG
//      (smaller than a typical dialog, large enough for ~6 visible
//      rows + the search field).
//    - Empty query shows ALL items; the registry sorts by category
//      then title (= deterministic list).
//
//  No third-party dependency (= Apple stack exclusive per AGENTS.md
//  §11.1).
//

import SwiftUI
import AppKit

/// ⌘K palette model — drives the sheet and bridges the actor to SwiftUI.
///
/// Why a separate @Observable model instead of @State in the view:
///   - The view needs to refresh when the registry changes (= when a
///     plugin registers a new skill at runtime). @Observable gives us
///     cheap re-renders without manual @Published bookkeeping.
///   - The view's `@State private var query` is per-view-instance; the
///     model is shared between the App.swift menu (posts to it) and the
///     SwiftUI sheet (reads from it).
@MainActor
@Observable
public final class CommandPaletteModel {
    public var query: String = ""
    public var isVisible: Bool = false
    public var items: [CommandPaletteItem] = []
    public var selectedIndex: Int = 0

    private let registry: CommandPaletteRegistry

    public init(registry: CommandPaletteRegistry = .shared) {
        self.registry = registry
    }

    /// Show the palette (= called from ⌘K menu item).
    public func show() {
        isVisible = true
        query = ""
        selectedIndex = 0
        Task { await reload() }
    }

    /// Hide the palette (= called after an item is invoked OR the user
    /// dismisses with Esc).
    public func hide() {
        isVisible = false
        query = ""
    }

    /// Reload items from the registry (= respects current query).
    public func reload() async {
        let filtered = await registry.itemsMatching(query)
        // Sort by category then title (= deterministic order; same
        // shape as Apple's macOS Spotlight palette).
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.category != rhs.category { return lhs.category < rhs.category }
            return lhs.title.lowercased() < rhs.title.lowercased()
        }
        items = sorted
        if selectedIndex >= items.count { selectedIndex = 0 }
    }

    /// Filter by current query (= called on every keystroke from the
    /// SwiftUI .onChange handler).
    public func filter(by query: String) async {
        self.query = query
        await reload()
    }

    /// Invoke the item at the given index (= dispatch the action).
    public func invoke(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        let item = items[index]
        CommandPaletteController.dispatch(action: item.action)
        hide()
    }

    /// Move the selection up (= arrow key binding).
    public func moveSelection(_ delta: Int) {
        guard !items.isEmpty else { return }
        var next = (selectedIndex + delta) % items.count
        if next < 0 { next += items.count }
        selectedIndex = next
    }
}

/// ⌘K palette view (= SwiftUI sheet body).
public struct CommandPaletteView: View {
    @State private var model: CommandPaletteModel
    @FocusState private var queryFocused: Bool

    public init(model: CommandPaletteModel = CommandPaletteModel()) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search field (Apple HIG TextField .plain = macOS 27 native
            // text-field render; no custom frame / border / Liquid Glass
            // paint = boss 2026-09-02 OOB 'let Apple defaults through').
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Type a command or skill name…", text: Binding(
                    get: { model.query },
                    set: { newValue in
                        Task { await model.filter(by: newValue) }
                    }
                ))
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($queryFocused)
                .onSubmit {
                    if !model.items.isEmpty {
                        model.invoke(at: model.selectedIndex)
                    }
                }
                if !model.query.isEmpty {
                    Button {
                        Task { await model.filter(by: "") }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Item list (= scrollable, max-height constrained).
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        CommandPaletteRow(
                            item: item,
                            isSelected: index == model.selectedIndex
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.invoke(at: index)
                        }
                    }
                }
            }
            .frame(maxHeight: 320)

            // Footer (= item count + shortcut hint).
            HStack {
                Text("\(model.items.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("⌘K to toggle · ↵ to invoke · esc to close")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 600, height: 400)
        // POLISH-LIQUIDGLASS-004: ⌘K palette sheet root uses Apple
        // .glassEffect(.regular) (= macOS 27 Tahoe Liquid Glass
        // material; same shape as the prior POLISH-LIQUIDGLASS-001/002/003
        // commits that glassed TopBar + Sidebar + Editor chrome + StatusBar).
        // Color.clear provides the glass layer size; the modifier applies
        // the canonical Apple Liquid Glass. No custom border or shadow
        // (= boss 2026-09-02 hard rule 'every color comes from an Apple
        // API'; .glassEffect already includes the canonical hairline +
        // depth shadow per Apple HIG).
        .background { Color.clear.glassEffect(.regular) }
        // Keyboard navigation: arrow keys move selection, return invokes,
        // esc dismisses. Uses Apple's SwiftUI .onKeyPress API (= macOS 14+
        // native; no custom key-event listener needed).
        .onKeyPress(.upArrow) {
            model.moveSelection(-1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            model.moveSelection(1)
            return .handled
        }
        .onKeyPress(.escape) {
            model.hide()
            return .handled
        }
        .onAppear {
            queryFocused = true
            Task { await model.reload() }
        }
    }
}

/// Single row in the ⌘K palette list.
private struct CommandPaletteRow: View {
    let item: CommandPaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Category badge (= "command" / "skill" / "navigate" /
            // "chat" / "custom"). SF Symbol fallback is acceptable here
            // because this is a debug/internal UX surface (= not the
            // user-facing app chrome).
            Image(systemName: categorySymbol)
                .foregroundStyle(categoryColor)
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let hint = item.shortcutHint {
                Text(hint)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            isSelected ?
                RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .selectedContentBackgroundColor).opacity(0.6)) :
                nil
        )
        .padding(.horizontal, 4)
    }

    private var categorySymbol: String {
        switch item.category {
        case "skill": return "wand.and.stars"
        case "navigate": return "arrow.right.circle"
        case "command": return "terminal"
        case "chat": return "bubble.left"
        case "custom": return "puzzlepiece"
        default: return "questionmark.circle"
        }
    }

    private var categoryColor: Color {
        switch item.category {
        case "skill": return .purple
        case "navigate": return .blue
        case "command": return .green
        case "chat": return .orange
        case "custom": return .pink
        default: return .secondary
        }
    }
}

/// Controller singleton — bridges the App.swift ⌘K menu (= SwiftUI
/// Commands block, no view access) to the SwiftUI sheet.
///
/// Per the boss 2026-09-02 standing rule, wenshu's .commands blocks
/// can't directly hold view models (= .commands body doesn't have
/// SwiftUI environment access). The pattern = post a NotificationCenter
/// event + the SwiftUI scene listens + drives the model.
///
/// Apple HIG alternative = .focusedSceneValue (= macOS 14+) could
/// carry a typed value from the .commands block to the active scene.
/// CHATBOX-002 keeps the NotificationCenter pattern (= already used by
/// 5+ zone-toggle items in App.swift) for consistency.
@MainActor
public enum CommandPaletteController {
    /// Show the palette (= ⌘K handler).
    public static func show() {
        NotificationCenter.default.post(name: .wenshuShowCommandPalette, object: nil)
    }

    /// Dispatch a palette action (= the SwiftUI sheet calls this when
    /// the user invokes an item). Routes through NotificationCenter so
    /// the right subsystem can react.
    public static func dispatch(action: CommandPaletteAction) {
        switch action {
        case let .invokeSkill(skillName, args):
            // CHATBOX-001 wire-up: post a NotificationCenter event the
            // ChatViewModel listens for (= routes through the same
            // parseAndInvoke path that /skill_name uses in the chat
            // TextField). Args are forwarded via userInfo for future
            // skill-arg parsing.
            NotificationCenter.default.post(
                name: .wenshuPaletteSkillInvoked,
                object: nil,
                userInfo: ["skillName": skillName, "args": args]
            )
        case let .openSettings(tab):
            NotificationCenter.default.post(
                name: .wenshuPaletteOpenSettings,
                object: nil,
                userInfo: ["tab": tab]
            )
        case let .navigateTo(destination):
            NotificationCenter.default.post(
                name: .wenshuPaletteNavigate,
                object: nil,
                userInfo: ["destination": destination]
            )
        case let .sendChatMessage(message):
            NotificationCenter.default.post(
                name: .wenshuPaletteSendChatMessage,
                object: nil,
                userInfo: ["message": message]
            )
        case let .custom(name):
            NotificationCenter.default.post(
                name: .wenshuPaletteCustomAction,
                object: nil,
                userInfo: ["name": name]
            )
        }
    }
}

/// NotificationCenter extension — central registry for palette events.
/// Mirrors the pattern of existing .wenshu* notifications in App.swift.
public extension Notification.Name {
    /// Posted by CommandPaletteController.show() (= ⌘K menu item).
    /// The active scene listens and shows the palette sheet.
    static let wenshuShowCommandPalette = Notification.Name("wenshuShowCommandPalette")
    /// Posted when a palette item invokes a skill.
    static let wenshuPaletteSkillInvoked = Notification.Name("wenshuPaletteSkillInvoked")
    /// Posted when a palette item opens the Settings window.
    static let wenshuPaletteOpenSettings = Notification.Name("wenshuPaletteOpenSettings")
    /// Posted when a palette item navigates to a zone / view.
    static let wenshuPaletteNavigate = Notification.Name("wenshuPaletteNavigate")
    /// Posted when a palette item sends a chat message.
    static let wenshuPaletteSendChatMessage = Notification.Name("wenshuPaletteSendChatMessage")
    /// Posted when a palette item triggers a custom action.
    static let wenshuPaletteCustomAction = Notification.Name("wenshuPaletteCustomAction")
}
