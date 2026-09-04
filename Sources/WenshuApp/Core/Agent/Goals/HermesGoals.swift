//
// HermesGoals.swift · embedded Ralph goal loop
//
// Port of hermes_cli/goals.py's persistent goal behavior. The loop keeps a
// main agent working toward a goal and asks a separately configured auxiliary
// connector for a strict completion judgment after every turn.
//
// Persistence is intentionally filesystem-based: callers provide a library,
// book, or chapter directory and this type stores one JSON file per goal.
// The embedded agent runtime remains the source of truth for model execution.
//

import Foundation

public enum GoalsJudgment: Sendable, Equatable {
    case done(reason: String)
    case continue_(reason: String)
    case failed(reason: String)
}

public struct GoalsWork: Sendable, Equatable, Codable {
    public let goal: String
    public var work: String
    public var iterations: Int
    public var context: [String]

    public init(goal: String, work: String = "", iterations: Int = 0, context: [String] = []) {
        self.goal = goal
        self.work = work
        self.iterations = iterations
        self.context = context
    }
}

public struct GoalsRunResult: Sendable, Equatable {
    public let finalWork: String
    public let iterations: Int
    public let judgment: GoalsJudgment
    public let auxiliaryUsages: [LLMUsage]
    public let mainUsages: [LLMUsage]

    public init(finalWork: String, iterations: Int, judgment: GoalsJudgment,
                auxiliaryUsages: [LLMUsage], mainUsages: [LLMUsage]) {
        self.finalWork = finalWork
        self.iterations = iterations
        self.judgment = judgment
        self.auxiliaryUsages = auxiliaryUsages
        self.mainUsages = mainUsages
    }
}

public actor GoalsManager {
    private let mainConnector: any LLMConnector
    private let auxiliaryConnector: any LLMConnector
    private let runtime: RuntimeHelpers
    private let maxIterations: Int
    private let persistenceDirectory: URL
    private var persisted: [UUID: GoalsWork] = [:]

    public init(mainConnector: any LLMConnector,
                auxiliaryConnector: any LLMConnector,
                runtime: RuntimeHelpers,
                maxIterations: Int = 10,
                persistenceDirectory: URL? = nil) {
        self.mainConnector = mainConnector
        self.auxiliaryConnector = auxiliaryConnector
        self.runtime = runtime
        self.maxIterations = max(1, maxIterations)
        self.persistenceDirectory = persistenceDirectory ??
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Wenshu/Goals", isDirectory: true)
    }

    public func runGoal(_ goal: String) async throws -> GoalsRunResult {
        let cleanGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanGoal.isEmpty else { throw GoalsError.emptyGoal }
        var work = ""
        var mainUsages: [LLMUsage] = []
        var auxiliaryUsages: [LLMUsage] = []
        var judgment: GoalsJudgment = .continue_(reason: "No judgment yet")

        for iteration in 1...maxIterations {
            let prompt = iteration == 1 ? cleanGoal : continuationPrompt(goal: cleanGoal, work: work)
            let response = try await send(prompt: prompt, connector: mainConnector)
            work = response.blocks.map(\.textValue).joined()
            mainUsages.append(response.usage)
            judgment = try await judge(work: work, goal: cleanGoal)
            if case .done = judgment {
                return GoalsRunResult(finalWork: work, iterations: iteration, judgment: judgment,
                                      auxiliaryUsages: auxiliaryUsages, mainUsages: mainUsages)
            }
            if case .failed = judgment {
                return GoalsRunResult(finalWork: work, iterations: iteration, judgment: judgment,
                                      auxiliaryUsages: auxiliaryUsages, mainUsages: mainUsages)
            }
            if iteration == maxIterations { break }
            _ = await runtime.now()
        }
        judgment = .failed(reason: "Maximum goal iterations reached (\(maxIterations)).")
        return GoalsRunResult(finalWork: work, iterations: maxIterations, judgment: judgment,
                              auxiliaryUsages: auxiliaryUsages, mainUsages: mainUsages)
    }

    public func persistGoal(_ goalId: UUID, work: GoalsWork) throws {
        try FileManager.default.createDirectory(at: persistenceDirectory, withIntermediateDirectories: true)
        let url = persistenceDirectory.appendingPathComponent("\(goalId.uuidString).json")
        let data = try JSONEncoder().encode(work)
        try data.write(to: url, options: .atomic)
        persisted[goalId] = work
    }

    public func loadGoal(_ goalId: UUID) throws -> GoalsWork? {
        let url = persistenceDirectory.appendingPathComponent("\(goalId.uuidString).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return persisted[goalId] }
        return try JSONDecoder().decode(GoalsWork.self, from: Data(contentsOf: url))
    }

    public func judge(work: String, goal: String) async throws -> GoalsJudgment {
        let response = try await send(prompt: judgePrompt(work: work, goal: goal), connector: auxiliaryConnector)
        let raw = response.blocks.map(\.textValue).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return parseJudgment(raw)
    }

    private func send(prompt: String, connector: any LLMConnector) async throws -> LLMResponse {
        let options = LLMCallOptions(model: "unknown-model", maxTokens: 4096,
                                     systemPrompt: nil, temperature: 0)
        return try await connector.send(messages: [.user(prompt)], options: options)
    }

    private func continuationPrompt(goal: String, work: String) -> String {
        "[Continuing toward your standing goal]\nGoal: \(goal)\n\nCurrent work:\n\(work)\n\nTake the next concrete step."
    }

    private func judgePrompt(work: String, goal: String) -> String {
        """
        You are a strict goal judge. Goal: \(goal)

        Work product:
        \(work)

        Reply with one JSON object: {\"verdict\":\"done\"|\"continue\",\"reason\":\"...\"}.
        """
    }

    private func parseJudgment(_ raw: String) -> GoalsJudgment {
        let candidate = raw.firstIndex(of: "{").flatMap { start in
            raw[start...].firstIndex(of: "}").map { String(raw[start...$0]) }
        } ?? raw
        if let data = candidate.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let reason = (object["reason"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let verdict = (object["verdict"] as? String)?.lowercased()
            if verdict == "done" || (object["done"] as? Bool) == true { return .done(reason: reason) }
            if verdict == "continue" || (object["done"] as? Bool) == false { return .continue_(reason: reason) }
        }
        return .failed(reason: "Auxiliary judgment was not valid JSON.")
    }
}

public enum GoalsError: Error, LocalizedError, Sendable {
    case emptyGoal
    public var errorDescription: String? { "Goal text must not be empty." }
}
