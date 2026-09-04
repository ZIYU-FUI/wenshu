//
//  KanbanRole.swift · Wenshu · v0.23 ticket 013.006 (hermes gap 6)
//
//  Boss 2026-08-23 拍: hermes _require_orchestrator_tool parity.
//  Source: github.com/NousResearch/hermes-agent/blob/main/tools/kanban_tools.py:467
//
//  Hermes pattern: workers (sub-agents dispatched by main) can ONLY do:
//    kanban_complete / kanban_block / kanban_heartbeat / kanban_comment
//  Orchestrators (main agent) can do: kanban_create / kanban_request_review / etc.
//
//  wenshu impl: KanbanRole enum + guard at write sites.
//

import Foundation

/// Identity of the agent calling kanban operations.
/// Mirrors hermes 'HERMES_KANBAN_TASK' env var marker (orchestrator vs worker context).
public enum KanbanRole: Sendable, Equatable {
    /// Main agent (orchestrator). Can do all kanban ops.
    case orchestrator
    /// Sub-agent (worker). Can only do restricted ops.
    case worker(taskId: String)

    /// Display name (for debug / UI).
    public var displayName: String {
        switch self {
        case .orchestrator: return "orchestrator"
        case .worker(let taskId): return "worker(\(taskId.prefix(8)))"
        }
    }

    /// True if this role is allowed to CREATE new tasks.
    /// Per hermes: orchestrator only.
    public var canCreate: Bool {
        if case .orchestrator = self { return true }
        return false
    }

    /// True if this role is allowed to COMPLETE / BLOCK assigned tasks.
    /// Per hermes: worker (only their assigned task).
    public var canTransitionOwnedTask: Bool {
        switch self {
        case .orchestrator: return true  // orchestrator can transition any task
        case .worker: return true         // worker can transition their own task
        }
    }

    /// True if this role is allowed to REQUEST REVIEW on a task.
    /// Per hermes: orchestrator only (worker can block, not request review).
    public var canRequestReview: Bool {
        if case .orchestrator = self { return true }
        return false
    }

    /// True if this role is allowed to DELETE a task.
    /// Per hermes: orchestrator only.
    public var canDelete: Bool {
        if case .orchestrator = self { return true }
        return false
    }
}

/// Permission policy for kanban operations.
/// Mirrors hermes _require_orchestrator_tool guard.
public enum KanbanRoleGuard {

    /// Check if a role can perform an operation.
    /// Returns nil if allowed; returns reason string if blocked.
    public static func checkPermission(role: KanbanRole, op: KanbanOp) -> String? {
        switch op {
        case .create:
            guard role.canCreate else {
                return blockReason(role: role, op: op, why: "create is orchestrator-only (hermes _require_orchestrator_tool)")
            }
        case .transitionOwned:
            guard role.canTransitionOwnedTask else {
                return blockReason(role: role, op: op, why: "transition denied for this role")
            }
        case .requestReview:
            guard role.canRequestReview else {
                return blockReason(role: role, op: op, why: "request review is orchestrator-only")
            }
        case .delete:
            guard role.canDelete else {
                return blockReason(role: role, op: op, why: "delete is orchestrator-only")
            }
        }
        return nil
    }

    private static func blockReason(role: KanbanRole, op: KanbanOp, why: String) -> String {
        return "(role '\(role.displayName)' blocked from '\(op.rawValue)': \(why). boss 8/23 拍: hermes _require_orchestrator_tool parity)"
    }
}

/// Kanban operation types (mirrors hermes handler names).
public enum KanbanOp: String, Sendable {
    case create            // kanban_create (orchestrator only)
    case transitionOwned   // kanban_complete / kanban_block / kanban_heartbeat (any role, on owned task)
    case requestReview     // kanban_request_review (orchestrator only)
    case delete            // kanban_delete (orchestrator only)
}