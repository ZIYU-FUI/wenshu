// App.swift · Wenshu (Wenshu) · v0.00.0 project baseline (2026-08-14 owner decision)
//
// Source of truth: @AGENTS.md + @CLAUDE.md + @wenshu-pour/architecture/CONTEXT.md
//
// v0.00.0 bootstrap (owner 17:30: "minimal code, use Apple's provided APIs, write our framework"):
//   - Minimal SwiftUI App entry point
//   - One window titled "文枢"
//   - 5-zone layout / wenshu assistant / implicit editorial / smart context picker = follow-up via /to-tickets
//   - No feature bloat (= Apple HIG / FCP-style / Apple-provided components first, follow-up via /implement)

import SwiftUI

@main
struct WenshuApp: App {
    var body: some Scene {
        WindowGroup("文枢") {
            // v0.00.0: 5-zone layout pending (= /to-tickets → /implement)
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

/// v0.00.0 placeholder view (= 5-zone layout rewrites this to LayoutShellView later)
struct ContentView: View {
    var body: some View {
        Text("文枢")
            .font(.largeTitle)
            .frame(minWidth: 800, minHeight: 600)
    }
}