import Foundation
import os
import TrayOpsCore

/// Scripted ``ProcessRunner`` for deterministic tests. Stubs are matched by the
/// executable's basename and (optionally) exact arguments, in insertion order.
/// Records every invocation for assertions. Thread-safe via an unfair lock, so
/// it is safely `Sendable`.
public final class FakeProcessRunner: ProcessRunner {
    public struct Invocation: Equatable, Sendable {
        public let executable: String
        public let args: [String]
    }

    public enum FakeProcessError: Error, Equatable {
        case noStub(tool: String, args: [String])
    }

    private struct Rule: Sendable {
        let tool: String
        let args: [String]?
        let output: ProcessOutput
    }

    private struct State: Sendable {
        var rules: [Rule] = []
        var invocations: [Invocation] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    public init() {}

    /// Registers a stub. When `args` is nil any arguments match.
    public func stub(
        tool: String,
        args: [String]? = nil,
        exitCode: Int32 = 0,
        stdout: String = "",
        stderr: String = ""
    ) {
        let rule = Rule(
            tool: tool,
            args: args,
            output: ProcessOutput(exitCode: exitCode, stdout: stdout, stderr: stderr)
        )
        state.withLock { $0.rules.append(rule) }
    }

    public var invocations: [Invocation] {
        state.withLock { $0.invocations }
    }

    public func run(_ executable: String, _ args: [String], environment: [String: String]?) async throws -> ProcessOutput {
        try state.withLock { state in
            let tool = (executable as NSString).lastPathComponent
            state.invocations.append(Invocation(executable: executable, args: args))

            for rule in state.rules where rule.tool == tool {
                if rule.args == nil || rule.args == args {
                    return rule.output
                }
            }
            throw FakeProcessError.noStub(tool: tool, args: args)
        }
    }
}
