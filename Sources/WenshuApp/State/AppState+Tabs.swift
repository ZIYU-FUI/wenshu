//
//  AppState+Tabs.swift · Wenshu · P2-06 (audit 2026-09-24)
//
//  P2-06 (audit 2026-09-24): extracted from `AppState.swift`
//  (= 56 LOC of openTabs persistence / restore). AppState was
//  689 LOC; this extension brings it down to ~630 LOC. The
//  `openTabs` / `activeTabId` vars (= the @Observable state itself)
//  stay in AppState (= the `didSet` body calls `self.persistOpenTabs()`
//  which lives here in the extension — Swift allows this because
//  methods declared in extensions on the same module + target are
//  visible to the class's own didSet body).
//

import Foundation

extension AppState {
    /// Persisted shape = PersistedEditorTab (= id + documentPath +
    /// draft + originalBody + mode). Tasks / file-watchers / dirty
    /// state are runtime-only (= recreated on launch when tabs are
    /// reloaded from disk).
    func persistOpenTabs() {
        let snapshot = openTabs.map {
            PersistedEditorTab(
                id: $0.id,
                documentPath: $0.documentPath,
                draft: $0.draft,
                originalBody: $0.originalBody,
                mode: $0.mode.rawValue,
                title: $0.title
            )
        }
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: AppState.openTabsKey)
        }
    }

    /// Restore openTabs from UserDefaults (= v0.40 boss 9/7). Called
    /// from init() so subsequent view code reads the restored state
    /// on the first render.
    func restoreOpenTabs() {
        guard let data = UserDefaults.standard.data(forKey: AppState.openTabsKey),
              let snapshot = try? JSONDecoder().decode([PersistedEditorTab].self, from: data) else {
            return
        }
        self.openTabs = snapshot.compactMap { p in
            guard let mode = EditorMode(rawValue: p.mode) else { return nil }
            return EditorTab(
                id: p.id,
                documentPath: p.documentPath,
                draft: p.draft,
                originalBody: p.originalBody,
                mode: mode,
                title: p.title
            )
        }
        if let activeIdStr = UserDefaults.standard.string(forKey: AppState.activeTabIdKey),
           let activeId = UUID(uuidString: activeIdStr),
           openTabs.contains(where: { $0.id == activeId }) {
            self.activeTabId = activeId
        } else if let first = openTabs.first {
            self.activeTabId = first.id
        }
    }
}
