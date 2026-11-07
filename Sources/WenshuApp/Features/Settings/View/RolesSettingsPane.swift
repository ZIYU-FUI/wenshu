//
//  RolesSettingsPane.swift
//
//  The six sub-agent roles, and what each one may do.
//
//  Why this pane exists: the multi-agent work gave the app six roles
//  (researcher / writer / analyst / librarian / archivist / auditor),
//  and they were reachable only through the model and the debug
//  surfaces. A user who asks "what is the researcher allowed to
//  write into my library?" had no answer in the app.
//
//  **⇒ It is READ-ONLY, = and that is the honest shape.** = The role
//  table is the app's contract with the model (= each role's prompt
//  and its tool subset), = and the prompt is what the app's own
//  guarantee is written in. = A pane that EDITED the table would be
//  offering to break the guarantee while showing it. = So the pane
//  states what the roles are, = and a user who wants a different
//  arrangement asks the app's author.
//
//  **⇒ The rows come from the registry, = never from a copy here.**
//  = `SubAgentRoleRegistry.roles` is the single table the runner
//  dispatches from, = so a pane that listed its own copy would be a
//  second table that could drift. = The count is asserted by a
//  tripwire (= the pane's own test), = because "six roles" is a
//  promise the multi-agent spec made.
//
//  Layout is Apple HIG macOS Settings: a grouped Form, one Section per
//  question, = the same shape as the agent pane's sections. Each role
//  is a row with its name, = the tools it may call, = and where it
//  runs. = The dispatch line is the part a user actually needs: = the
//  archivist and the auditor do not call a model at all, = they run
//  as the archive run and the audit run, = and a role table that
//  lists only names hides that.
//

import SwiftUI
import WenshuAgent

struct RolesSettingsPane: View {
    /// The role table (= the registry's own rows; = not a copy).
    private var roles: [SubAgentRole] {
        SubAgentRoleRegistry.roles
    }

    var body: some View {
        Form {
            rolesSection
            dispatchSection
        }
        .formStyle(.grouped)
    }

    // MARK: - The roles

    /// The six roles and the tools each may call.
    private var rolesSection: some View {
        Section {
            ForEach(roles, id: \.slug) { role in
                roleRow(role)
            }
        } header: {
            Text(String(localized: "settings.roles.section.roles"))
        } footer: {
            Text(String(localized: "settings.roles.section.roles.footer"))
        }
    }

    /// One role (= its name, = and the tools it may call).
    private func roleRow(_ role: SubAgentRole) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(role.displayLabel)
                .foregroundStyle(.primary)
            if role.toolNames.isEmpty {
                Text(String(localized: "settings.roles.noTools"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(role.toolNames.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, DesignTokens.spacingCaption)
    }

    // MARK: - The dispatch

    /// Where each role runs (= the part a role table of names hides).
    private var dispatchSection: some View {
        Section {
            ForEach(roles, id: \.slug) { role in
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingStandard) {
                    Text(role.slug)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(dispatchName(role.dispatch))
                        .foregroundStyle(.primary)
                }
            }
        } header: {
            Text(String(localized: "settings.roles.section.dispatch"))
        } footer: {
            Text(String(localized: "settings.roles.section.dispatch.footer"))
        }
    }

    /// The name of a dispatch (= the three the runner knows).
    private func dispatchName(_ dispatch: SubAgentRoleDispatch) -> String {
        switch dispatch {
        case .llmRun: return String(localized: "settings.roles.dispatch.llmRun")
        case .archiveRun: return String(localized: "settings.roles.dispatch.archiveRun")
        case .auditRun: return String(localized: "settings.roles.dispatch.auditRun")
        }
    }
}
