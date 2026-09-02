//
//  BackupView.swift · Wenshu · v0.22 ticket h09 (hermes replica, frontend mount)
//  Replica of hermes backup UI.
//

import SwiftUI

/// Standalone backup view, presented as sheet from Settings (or toolbar).
public struct BackupView: View {
    public init() {}

    public var body: some View {
        // v0.22 h09: placeholder backup UI. Real backup list / restore in follow-up.
        VStack(alignment: .leading, spacing: 8) {
            Text("Backup")
                .font(.headline)
            Text("Replica of hermes backup (BackupTools struct)")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        // v0.24 boss验收fix: flexible sizing (zone size controlled by splitter, not view).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}