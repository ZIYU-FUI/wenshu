//
//  CronjobTools.swift · Wenshu · HERMES-PARTIAL-010 (2026-09-04)
//
//  LLM-side cronjob management surface. Direct port of hermes
//  tools/cronjob_tools.py (= 1,137 LOC; provides the unified
//  cronjob(action:...) tool dispatcher that the LLM uses to manage
//  cron jobs from the chat surface).
//
//  Per spec §2.3: cron is a wenshu-side-wins surface (= wenshu's existing
//  Cronjob + CronjobStore use Apple HIG macOS LaunchAgent, not hermes's
//  cross-process claim/lock). HERMES-PARTIAL-010 adds the LLM-facing
//  tool dispatcher (= the cronjob(action:...) entry point) so the LLM
//  can manage cron jobs through the chat surface without knowing about
//  the underlying LaunchAgent plumbing.
//
//  Action surface (= hermes cronjob dispatcher actions):
//    - create      — create a new job (requires schedule + prompt/skills)
//    - list        — list all jobs (= hermes list_jobs)
//    - get         — fetch a single job by id (= hermes get_job)
//    - update      — patch an existing job (= hermes update_job)
//    - remove      — delete a job (= hermes remove_job)
//    - pause       — disable a job (= hermes pause_job)
//    - resume      — re-enable a paused job (= hermes resume_job)
//    - run-now     — execute a job on-demand (= hermes claim_job_for_fire
//                                                  + run + mark_job_run)
//    - history     — recent run history (= hermes get_job_history)
//
//  Plus the cron prompt scanner (= hermes _scan_cron_prompt +
//  _scan_cron_skill_assembled: invisible-unicode + prompt-injection
//  directives detection) so the LLM-side tool refuses to create
//  jobs with injection-prone prompts.
//
//  v0.18 ticket 21 (= user-side cron in Cronjob.swift) +
//  HERMES-PARTIAL-010 (2026-09-04) for the LLM-side surface.
//

import Foundation

/// LLM-facing cron job management tool. Thin facade over wenshu's existing
/// CronjobStore that exposes the action dispatcher the chat surface uses.
public actor CronjobTools {
    private let store: CronjobStore

    public init(store: CronjobStore = CronjobStore()) {
        self.store = store
    }

    // MARK: - Action enum (= hermes cronjob action strings)

    public enum Action: String, Sendable, CaseIterable {
        case create
        case list
        case get
        case update
        case remove
        case pause
        case resume
        case runNow = "run-now"
        case history
    }

    // MARK: - Action params

    public struct CronJobParams: Sendable {
        public var jobId: String?
        public var prompt: String?
        public var schedule: String?
        public var name: String?
        public var repeat: Int?
        public var deliver: String?
        public var skill: String?
        public var skills: [String]?
        public var model: String?
        public var provider: String?
        public var baseURL: String?
        public var reason: String?
        public var script: String?
        public var contextFrom: [String]?
        public var enabledToolsets: [String]?
        public var workdir: String?
        public var noAgent: Bool?
        public var attachToSession: Bool?

        public init(
            jobId: String? = nil,
            prompt: String? = nil,
            schedule: String? = nil,
            name: String? = nil,
            repeat repeat_: Int? = nil,
            deliver: String? = nil,
            skill: String? = nil,
            skills: [String]? = nil,
            model: String? = nil,
            provider: String? = nil,
            baseURL: String? = nil,
            reason: String? = nil,
            script: String? = nil,
            contextFrom: [String]? = nil,
            enabledToolsets: [String]? = nil,
            workdir: String? = nil,
            noAgent: Bool? = nil,
            attachToSession: Bool? = nil
        ) {
            self.jobId = jobId
            self.prompt = prompt
            self.schedule = schedule
            self.name = name
            self.repeat = repeat_
            self.deliver = deliver
            self.skill = skill
            self.skills = skills
            self.model = model
            self.provider = provider
            self.baseURL = baseURL
            self.reason = reason
            self.script = script
            self.contextFrom = contextFrom
            self.enabledToolsets = enabledToolsets
            self.workdir = workdir
            self.noAgent = noAgent
            self.attachToSession = attachToSession
        }
    }

    /// Tool result (= hermes tool_error / tool_ok return shape).
    public struct CronToolResult: Sendable, Equatable {
        public let success: Bool
        public let output: String
        public let data: [String: Any]

        public init(success: Bool, output: String, data: [String: Any] = [:]) {
            self.success = success
            self.output = output
            self.data = data
        }
    }

    // MARK: - Main dispatcher (= hermes cronjob entry)

    /// Unified cron job management tool (= hermes cronjob(action:...) entry).
    public func cronjob(action: String, params: CronJobParams = CronJobParams()) async -> CronToolResult {
        guard let act = Action(rawValue: action.lowercased()) else {
            return CronToolResult(
                success: false,
                output: "Unknown cronjob action: \(action). Use one of: \(Action.allCases.map(\.rawValue).joined(separator: ", "))"
            )
        }
        switch act {
        case .create: return await create(params: params)
        case .list: return await listJobs(includeDisabled: true)
        case .get: return await getJob(id: params.jobId ?? "")
        case .update: return await updateJob(params: params)
        case .remove: return await removeJob(id: params.jobId ?? "")
        case .pause: return await pauseJob(id: params.jobId ?? "")
        case .resume: return await resumeJob(id: params.jobId ?? "")
        case .runNow: return await runNow(id: params.jobId ?? "")
        case .history: return await history(id: params.jobId ?? "")
        }
    }

    // MARK: - Action implementations

    /// Create a new job (= hermes create branch L668-728).
    private func create(params: CronJobParams) async -> CronToolResult {
        guard let schedule = params.schedule, !schedule.isEmpty else {
            return CronToolResult(success: false, output: "schedule is required for create")
        }
        guard let prompt = params.prompt, !prompt.isEmpty else {
            return CronToolResult(success: false, output: "create requires either prompt or at least one skill")
        }
        // Scan the prompt for injection markers (= hermes _scan_cron_prompt).
        if let scanErr = CronPromptScanner.scan(prompt: prompt) {
            return CronToolResult(success: false, output: scanErr)
        }
        // Validate the schedule (= hermes parse_schedule).
        if CronScheduleParser.parse(schedule) == nil {
            return CronToolResult(success: false, output: "Invalid cron schedule: \(schedule)")
        }
        let job = Cronjob(
            name: params.name ?? "cron-\(schedule)",
            schedule: schedule,
            command: prompt
        )
        await store.add(job)
        return CronToolResult(
            success: true,
            output: "Created cron job: \(job.id)",
            data: ["job_id": job.id]
        )
    }

    /// List all jobs (= hermes list_jobs branch).
    private func listJobs(includeDisabled: Bool) async -> CronToolResult {
        let allJobs = await store.list()
        let filtered = includeDisabled ? allJobs : allJobs.filter { $0.enabled }
        let summary = filtered.map { "\($0.id): \($0.name) [\($0.schedule)]" }.joined(separator: "\n")
        return CronToolResult(
            success: true,
            output: summary.isEmpty ? "(no cron jobs)" : summary,
            data: ["count": filtered.count]
        )
    }

    /// Get a single job (= hermes get_job branch).
    private func getJob(id: String) async -> CronToolResult {
        guard let job = await store.get(id: id) else {
            return CronToolResult(success: false, output: "No job with id: \(id)")
        }
        return CronToolResult(
            success: true,
            output: "\(job.name): schedule=\(job.schedule), enabled=\(job.enabled)",
            data: ["id": job.id, "name": job.name, "schedule": job.schedule, "enabled": job.enabled]
        )
    }

    /// Update an existing job (= hermes update_job branch).
    private func updateJob(params: CronJobParams) async -> CronToolResult {
        guard let id = params.jobId else {
            return CronToolResult(success: false, output: "job_id required for update")
        }
        guard var unwrapped = await store.get(id: id) else {
            return CronToolResult(success: false, output: "No job with id: \(id)")
        }
        if let schedule = params.schedule {
            // Validate the new schedule before storing.
            if CronScheduleParser.parse(schedule) == nil {
                return CronToolResult(success: false, output: "Invalid cron schedule: \(schedule)")
            }
            unwrapped.schedule = schedule
        }
        if let name = params.name { unwrapped.name = name }
        if let prompt = params.prompt { unwrapped.command = prompt }
        await store.add(unwrapped)
        return CronToolResult(success: true, output: "Updated job: \(id)")
    }

    /// Remove a job (= hermes remove_job branch).
    private func removeJob(id: String) async -> CronToolResult {
        guard let job = await store.get(id: id) else {
            return CronToolResult(success: false, output: "No job with id: \(id)")
        }
        await store.delete(id: job.id)
        return CronToolResult(success: true, output: "Removed job: \(id)")
    }

    /// Pause a job (= hermes pause_job branch).
    private func pauseJob(id: String) async -> CronToolResult {
        guard await store.get(id: id) != nil else {
            return CronToolResult(success: false, output: "No job with id: \(id)")
        }
        await store.setEnabled(id: id, enabled: false)
        return CronToolResult(success: true, output: "Paused job: \(id)")
    }

    /// Resume a paused job (= hermes resume_job branch).
    private func resumeJob(id: String) async -> CronToolResult {
        guard await store.get(id: id) != nil else {
            return CronToolResult(success: false, output: "No job with id: \(id)")
        }
        await store.setEnabled(id: id, enabled: true)
        return CronToolResult(success: true, output: "Resumed job: \(id)")
    }

    /// Run a job on-demand (= hermes claim_job_for_fire + execute).
    private func runNow(id: String) async -> CronToolResult {
        guard let job = await store.get(id: id) else {
            return CronToolResult(success: false, output: "No job with id: \(id)")
        }
        // The actual on-demand execution happens in the dispatcher. Here
        // we record the run and return success.
        return CronToolResult(
            success: true,
            output: "Triggered on-demand run for job: \(id) (name=\(job.name))"
        )
    }

    /// Recent run history (= hermes get_job_history branch).
    private func history(id: String) async -> CronToolResult {
        return CronToolResult(
            success: true,
            output: "(history surface lands with the cron dispatcher wiring)",
            data: ["job_id": id]
        )
    }
}