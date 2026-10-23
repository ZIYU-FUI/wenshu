//
//  InspectorStatusOutputSheet.swift
//  wenshu
//
//  The read-only output panel of one sub-agent task.
//
//  It has the shape of the chat area's conversation and none of its
//  powers: the sub-agent's text arrives into it, and there is no way
//  to say anything back. The chat's own message part renders the
//  text, so the panel reads as the conversation the task came from.
//

import SwiftUI

/// One task's output, read-only.
struct InspectorStatusOutputSheet: View {
    /// The page's mirror (= the sheet reads the live record, so a
    /// running task's text keeps growing while the sheet is open).
    let model: InspectorStatusModel
    /// The task whose output this sheet shows.
    let taskID: String

    @Environment(\.dismiss) private var dismiss

    /// The live task (= the snapshot the card opened with, refreshed).
    private var task: InspectorStatusTask? {
        model.tasks.first { $0.id == taskID }
    }

    var body: some View {
        NavigationStack {
            content
                .padding(DesignTokens.spacingStandard)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle(task?.agentName ?? "")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "inspector.status.sheet.close")) {
                    dismiss()
                }
            }
        }
    }

    /// The output body (= the task's text in the chat's own bubble).
    private var content: some View {
        ScrollView {
            ChatTextPartView(
                text: task?.output ?? "",
                isStreaming: task?.state == .running
            )
            .padding(DesignTokens.spacingModerate)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ChatSurfaceShape()
                    .fill(Color(nsColor: ChatUserBubblePalette.surface))
            )
            .foregroundStyle(ChatUserBubblePalette.text)
            .textSelection(.enabled)
        }
    }
}
