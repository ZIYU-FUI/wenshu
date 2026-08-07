// LayoutShellViewModel.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01
//
// Owns the in-memory `LayoutSnapshot` for the 5-zone shell + bridges it to
// `WenshuStoreActor` for .ws persistence.
//
// Responsibilities:
// 1. On `.load()` (called from `.task` on first appear): read the saved
//    snapshot from disk and apply it (fall back to defaults if missing
//    or malformed).
// 2. On every user mutation (chevron click, splitter drag): update
//    `snapshot` immediately so SwiftUI re-renders, and debounce a write
//    to disk so the drag gesture doesn't slam CoreData on every pixel.
// 3. The reset button rewrites the canonical default to disk so the next
//    cold launch (装机 user 8/7 实机验) still restores to defaults.
//
// Threading: @MainActor — every published mutation originates here, and
// the View layer reads `snapshot` directly in `body`. Persistence is
// awaited on the actor; we don't block the main thread.

import Foundation
import SwiftUI

@MainActor
final class LayoutShellViewModel: ObservableObject {

    // MARK: - Published state

    /// Single source of truth that the View layer reads. Always starts
    /// at `.default` so the first paint never reads from disk (cheap +
    /// deterministic; if the disk read returns the same default, no flash).
    @Published private(set) var snapshot: LayoutSnapshot = .default

    /// `true` after the first `.load()` completes — drives whether the
    /// toolbar shows the "reset to defaults" affordance. We don't gate the
    /// View on this to keep the layout responsive during cold launch.
    @Published private(set) var isLoaded: Bool = false

    // MARK: - Init

    private let store: WenshuStoreActor
    private var saveTask: Task<Void, Never>?

    init(store: WenshuStoreActor = .shared) {
        self.store = store
    }

    // MARK: - Load (cold launch)

    /// Read the persisted snapshot from `.ws`. Caller invokes this from
    /// `.task` — runs once after the first render. Errors fall back to
    /// defaults so a corrupted row never bricks the shell.
    func load() async {
        do {
            if let raw = try await store.loadLayoutState() {
                snapshot = LayoutSnapshot(
                    collapsed: LayoutSnapshot.decodeCollapsed(raw.panelStatesJSON),
                    ratios: LayoutSnapshot.decodeRatios(raw.panelRatiosJSON)
                )
            }
        } catch {
            FileHandle.standardError.write(Data(
                "LayoutShellViewModel.load: \(error)\n".utf8
            ))
        }
        isLoaded = true
    }

    // MARK: - Panel collapse toggle (chevron click)

    func toggle(_ panel: PanelID) {
        var snap = snapshot
        switch panel {
        case .topLeft:
            snap.collapsed.topLeft.toggle()
        case .topCenter:
            snap.collapsed.topCenter.toggle()
        case .topRight:
            snap.collapsed.topRight.toggle()
        case .bottomLeft:
            snap.collapsed.bottomLeft.toggle()
        case .bottomRight:
            snap.collapsed.bottomRight.toggle()
        }
        snapshot = snap
        scheduleSave()
    }

    // MARK: - Splitter drag handlers

    /// Splitter at `upperSplitterIndex` (0 or 1) in the upper row was
    /// dragged by `delta` pixels (positive = pulled right). We update
    /// ratios[index] and ratios[index+1] (the two panels left/right of
    /// the splitter) such that their sum is preserved and each stays
    /// within [5%, 95%].
    ///
    /// `totalWidth` is the upper row's full width in points (post-toolbar).
    /// Available width excludes the 2 splitter bars themselves.
    func adjustUpperColumn(splitterIndex: Int, delta: CGFloat, totalWidth: CGFloat) {
        guard splitterIndex == 0 || splitterIndex == 1 else { return }
        let left = splitterIndex
        let right = splitterIndex + 1
        let available = totalWidth - 2 * LayoutSnapshot.splitterPixels
        guard available > 0 else { return }
        let deltaRatio = Double(delta / available)
        var ratios = snapshot.ratios
        let sum = ratios[left] + ratios[right]
        guard sum > 0 else { return }
        let proposed = ratios[left] + deltaRatio
        let clamped = max(0.05, min(0.95, proposed))
        ratios[left] = clamped
        ratios[right] = max(0.05, sum - clamped)
        snapshot.ratios = ratios
        scheduleSave()
    }

    /// The horizontal splitter between upper and lower bands was dragged
    /// by `delta` pixels (positive = pulled down). Updates ratios[3]
    /// (lower band's fraction of total height).
    func adjustBottomHeight(delta: CGFloat, totalHeight: CGFloat) {
        guard totalHeight > 0 else { return }
        let deltaRatio = Double(delta / totalHeight)
        var ratios = snapshot.ratios
        ratios[3] = max(0.10, min(0.90, ratios[3] + deltaRatio))
        snapshot.ratios = ratios
        scheduleSave()
    }

    /// The single horizontal splitter in the lower band (between 下左 and
    /// 下右) was dragged by `delta` pixels (positive = pulled right).
    /// Updates ratios[4] (bottomLeft's fraction of lower-band width).
    func adjustLowerColumn(delta: CGFloat, totalWidth: CGFloat) {
        let available = totalWidth - LayoutSnapshot.splitterPixels
        guard available > 0 else { return }
        let deltaRatio = Double(delta / available)
        var ratios = snapshot.ratios
        let proposed = ratios[4] + deltaRatio
        ratios[4] = max(0.05, min(0.95, proposed))
        snapshot.ratios = ratios
        scheduleSave()
    }

    // MARK: - Reset

    func resetToDefaults() async {
        snapshot = .default
        await saveImmediately()
    }

    // MARK: - Persistence (debounced)

    /// Debounce writes so a continuous drag gesture (60+ onChanged events
    /// per second) only triggers one CoreData `save()` at the gesture's
    /// tail. Cancels any pending write and starts a fresh 250ms timer.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            await self?.saveImmediately()
        }
    }

    private func saveImmediately() async {
        do {
            try await store.saveLayoutState(
                panelStatesJSON: LayoutSnapshot.encodeCollapsed(snapshot.collapsed),
                panelRatiosJSON: LayoutSnapshot.encodeRatios(snapshot.ratios)
            )
        } catch {
            FileHandle.standardError.write(Data(
                "LayoutShellViewModel.saveImmediately: \(error)\n".utf8
            ))
        }
    }
}

// MARK: - Panel identity

/// Stable identifier for a panel slot in the 5-zone shell. Order matches
/// the `ratios` array index layout in `LayoutSnapshot`.
enum PanelID: Hashable {
    case topLeft
    case topCenter
    case topRight
    case bottomLeft
    case bottomRight

    /// Display title for the gutter / header bar.
    var title: String {
        switch self {
        case .topLeft: return "项目管理"
        case .topCenter: return "文档"
        case .topRight: return "检视"
        case .bottomLeft: return "聊天"
        case .bottomRight: return "状态"
        }
    }

    /// SF Symbol for the empty-state glyph (placeholder content).
    var symbolName: String {
        switch self {
        case .topLeft: return "folder"
        case .topCenter: return "doc.text"
        case .topRight: return "sidebar.right"
        case .bottomLeft: return "bubble.left.and.bubble.right"
        case .bottomRight: return "checklist"
        }
    }
}
