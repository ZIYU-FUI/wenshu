// WorkspaceScope.swift · Wenshu · v0.28 followup TKT-028-013
//
// Boss 2026-08-29 OOB 'verbatim port from hermes app' = port the workspace-scope
// pattern from Hermes Desktop verbatim. Owner keys are opaque exact
// strings (= never parsed, never inferred). Session workspaces use
// `null` (= established ambient behavior). Bots workspaces publish an
// exact route or a concise reason.
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/workspace-scope.ts
// = $workspaceMode atom + $workspaceOwnerKey atom + workspaceScopeKey()
// + sameNewSessionTarget() + setWorkspaceScope().

import Foundation
import Observation

/// Workspace surface a contribution belongs to. Affects which host
/// renders the contribution (= session workspace vs bots workspace).
public enum WorkspaceMode: String, Codable, Sendable {
    /// Default. Sessions use established ambient behavior.
    case sessions
    /// Per-bot workspace scoped by `ownerKey`.
    case bots
}

/// Default workspace mode when the host has not switched surfaces.
public let kDefaultWorkspaceMode: WorkspaceMode = .sessions

/// Exact route for a fresh session in the current workspace. Wenshu's
/// `.sessions` mode reuses the established ambient behavior (= no
/// route needed). `.bots` mode requires an exact owner key + reason.
public enum WorkspaceNewSessionTarget: Equatable {
    case blocked(message: String)
    case route(WorkspaceSessionRoute)
}

public struct WorkspaceSessionRoute: Equatable {
    public let connectionId: String
    public let mode: WorkspaceSessionTargetMode?
    public let profile: String
    public let targetProfile: String?

    public init(
        connectionId: String,
        mode: WorkspaceSessionTargetMode? = nil,
        profile: String,
        targetProfile: String? = nil
    ) {
        self.connectionId = connectionId
        self.mode = mode
        self.profile = profile
        self.targetProfile = targetProfile
    }
}

public enum WorkspaceSessionTargetMode: String, Codable, Sendable {
    case local
    case remote
}

/// One key for window-local active-pane memory. Owner keys stay opaque.
public func workspaceScopeKey(_ mode: WorkspaceMode, ownerKey: String?) -> String {
    switch mode {
    case .sessions:
        return "sessions"
    case .bots:
        return "bots:\(ownerKey ?? "")"
    }
}

/// Reactive store for the current workspace scope. Mutations are
/// batched via `setWorkspaceScope` (= one coherent presentation +
/// creation scope, never an intermediate mixed frame).
@MainActor
@Observable
public final class WorkspaceScopeStore {
    public private(set) var mode: WorkspaceMode = kDefaultWorkspaceMode
    public private(set) var ownerKey: String? = nil
    public private(set) var newSessionTarget: WorkspaceNewSessionTarget? = nil

    public init() {}

    /// Current scope key (= stable across re-renders unless mode or
    /// ownerKey change).
    public var scopeKey: String {
        workspaceScopeKey(mode, ownerKey: ownerKey)
    }

    /// Publish one coherent presentation + creation scope. Sessions
    /// always retains its existing ambient new-session behavior;
    /// alternate workspaces must state their intent (= either an
    /// exact route or a concise reason).
    public func set(
        mode: WorkspaceMode,
        ownerKey: String? = nil,
        newSessionTarget: WorkspaceNewSessionTarget? = nil
    ) {
        let isRehome = self.mode != mode || self.ownerKey != ownerKey
        self.mode = mode
        self.ownerKey = ownerKey
        // Sessions retains its ambient behavior on re-home (= pass
        // through the existing target if caller did not supply one).
        if mode == .sessions {
            self.newSessionTarget = newSessionTarget ?? self.newSessionTarget
        } else {
            self.newSessionTarget = newSessionTarget
        }
        if isRehome {
            // Future ticket: trigger soft re-home on mode switch (= wipe
            // gateway-bound stores). For now, just record the change.
        }
    }

    /// True iff a contribution belongs to the current workspace surface.
    public func contributesToWorkspace(_ c: Contribution) -> Bool {
        // Global contribution (= no workspaceMode) participates in every
        // workspace (= pre-existing behavior).
        guard let cwm = c.workspaceMode else { return true }
        if cwm != mode.rawValue { return false }
        // In `.bots` mode, compare ownerKey exactly.
        if mode == .bots {
            return c.workspaceOwnerKey == ownerKey
        }
        return true
    }
}