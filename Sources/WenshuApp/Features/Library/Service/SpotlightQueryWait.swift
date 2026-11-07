//
//  SpotlightQueryWait.swift
//
//  Waits for the system index without holding the thread that asked.
//
//  **⇒ WHY THIS FILE EXISTS.** = The wait used to be a
//  `DispatchGroup.wait()` **inside an actor** (= `CSSearchableIndexSearch`'s
//  own executor): = the index's answer decided when the actor came back,
//  = so a slow, = disabled, = or wedged index held every other caller on
//  that actor for as long as it liked. = The whole-suite test run had to
//  SKIP the index's own suite, = because that wait could hang.
//
//  **⇒ Now the wait is a CONTINUATION**: = the caller is SUSPENDED, =
//  not blocked; = the index answers on its own queue; = and the wait
//  ends on whichever comes first, = the answer, = the deadline, = or
//  the cancellation.
//
//  **⇒ The index is a SECONDARY source.** = The app's own mirror
//  answers immediately, = so a slow index costs the caller LATENCY, =
//  not the answer. = **⇒ Two seconds is long enough for a warm index, =
//  and short enough that an index which never answers does not hold the
//  app.** = The deadline is the whole point: = without it, "the index
//  did not answer" and "the app is frozen" are the same event.
//
//  **⇒ The wait is a SEAM, = so it can be tested without Spotlight.**
//  = `awaitOutcome` takes how to ask (= `start`), = how to stop
//  asking (= `cancel`), = and nothing else. = A test hands in an
//  index that never answers, = one that answers late, = and one that
//  answers at once, = and the three outcomes are measured. = The
//  production call site (= `CSSearchableIndexSearch`) is the only
//  thing that knows about `CSSearchQuery`.
//

import Foundation

/// How a system-index query ended.
enum SpotlightQueryOutcome: Sendable, Equatable {
    /// The index answered, = and the answer is the hits.
    case answered

    /// The index answered with an error (= the user turned the system
    /// indexer off, = or the query was invalid).
    case failed

    /// The index did not answer before the deadline.
    case timedOut

    /// The caller gave up before the index answered.
    case cancelled
}

/// Waits for the system index without holding the thread that asked.
enum SpotlightQueryWait {
    /// How long a system-index query may take before the app stops
    /// waiting for it.
    static let defaultTimeout: Duration = .seconds(2)

    /// Wait for the system index to answer.
    ///
    /// - Parameters:
    ///   - timeout: How long to wait for the answer.
    ///   - start: Asks the index. = The completion closure is called
    ///     with the outcome when the index answers (= `.answered` for
    ///     hits, = `.failed` for an error).
    ///   - cancel: Stops the index. = Called when the deadline wins
    ///     and when the caller is cancelled, = so the index stops
    ///     working on a question nobody is waiting for.
    /// - Returns: How the wait ended.
    static func awaitOutcome(
        timeout: Duration = defaultTimeout,
        start: @escaping @Sendable (@escaping @Sendable (SpotlightQueryOutcome) -> Void) -> Void,
        cancel: @escaping @Sendable () -> Void
    ) async -> SpotlightQueryOutcome {
        let gate = OutcomeGate()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                gate.install(continuation)
                // The task may already have been cancelled (= the
                // cancellation handler ran before the continuation was
                // installed). = **⇒ Asking an index nobody waits for
                // is the same defect as waiting for it too long.**
                guard !gate.isResolved else {
                    cancel()
                    return
                }
                start { outcome in
                    gate.resolve(outcome)
                }
                gate.armDeadline(timeout: timeout) {
                    if gate.resolve(.timedOut) {
                        cancel()
                    }
                }
            }
        } onCancel: {
            if gate.resolve(.cancelled) {
                cancel()
            }
        }
    }
}

/// The one-shot that ends a wait.
///
/// **⇒ Exactly one of {the index, = the deadline, = the cancellation}
/// finishes the wait.** = A continuation resumed twice traps, = so the
/// race needs a gate, = and the gate needs a lock (= the index answers
/// on its own queue, = the deadline on a task, = and the cancellation
/// on whatever thread noticed it).
private final class OutcomeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<SpotlightQueryOutcome, Never>?
    private var pending: SpotlightQueryOutcome?
    private var resolved = false
    private var deadline: Task<Void, Never>?

    /// Take the continuation (= the wait is now armed).
    func install(_ continuation: CheckedContinuation<SpotlightQueryOutcome, Never>) {
        lock.lock()
        guard !resolved else {
            let outcome = pending ?? .cancelled
            lock.unlock()
            continuation.resume(returning: outcome)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    /// Whether the wait is already over (= it was cancelled before
    /// the index was asked).
    var isResolved: Bool {
        lock.withLock { resolved }
    }

    /// Finish the wait, = if this call is the one that finishes it.
    ///
    /// - Returns: whether THIS call finished the wait (= the caller
    ///   uses it to decide whether to cancel the index).
    @discardableResult
    func resolve(_ outcome: SpotlightQueryOutcome) -> Bool {
        lock.lock()
        guard !resolved else {
            lock.unlock()
            return false
        }
        resolved = true
        pending = outcome
        let continuation = self.continuation
        self.continuation = nil
        let deadline = self.deadline
        self.deadline = nil
        lock.unlock()
        deadline?.cancel()
        continuation?.resume(returning: outcome)
        return true
    }

    /// Arm the deadline (= the wait ends even if the index never
    /// answers).
    func armDeadline(timeout: Duration, onTimeout: @escaping @Sendable () -> Void) {
        let task = Task {
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            onTimeout()
        }
        lock.lock()
        if resolved {
            lock.unlock()
            task.cancel()
            return
        }
        deadline = task
        lock.unlock()
    }
}
