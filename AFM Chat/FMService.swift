import Foundation

struct FMResponse {
    let content: String
    let thinking: String
    let duration: TimeInterval
}

struct FMCommandFailure: LocalizedError {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String

    var errorDescription: String? {
        let detail = standardError.isEmpty ? standardOutput : standardError
        let visibleDetail = TerminalText.userFacingDetails(detail)
        return visibleDetail.isEmpty ? "fm exited with status \(exitCode)." : visibleDetail
    }

    var thinkingDetails: String {
        TerminalText.userFacingDetails(standardError)
    }

    var appearsToRequireLicense: Bool {
        let text = (standardOutput + "\n" + standardError).lowercased()
        return text.contains("license") || text.contains("legal notice") || text.contains("terms")
    }

    var appearsToBeUnavailable: Bool {
        let text = (standardOutput + "\n" + standardError).lowercased()
        return text.contains("invalid for '--model")
            || text.contains("model unavailable")
            || text.contains("not available")
            || text.contains("availability")
    }
}

private nonisolated final class StreamCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private let update: @MainActor (String) -> Void

    init(update: @escaping @MainActor (String) -> Void) {
        self.update = update
    }

    func append(_ newData: Data) {
        guard !newData.isEmpty else { return }
        lock.lock()
        data.append(newData)
        let snapshot = data
        lock.unlock()
        let text = TerminalText.clean(String(decoding: snapshot, as: UTF8.self))
        Task { @MainActor in update(text) }
    }

    func snapshot() -> String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return TerminalText.clean(String(decoding: snapshot, as: UTF8.self))
    }
}

nonisolated enum TerminalText {
    private static let ansiExpression = try! NSRegularExpression(
        pattern: #"\u001B(?:\[[0-?]*[ -/]*[@-~]|\][^\u0007]*(?:\u0007|\u001B\\))"#
    )

    static func clean(_ input: String) -> String {
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        let withoutANSI = ansiExpression.stringByReplacingMatches(in: input, range: range, withTemplate: "")
        return withoutANSI
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    static func trimmed(_ input: String) -> String {
        clean(input).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func userFacingDetails(_ input: String) -> String {
        removingSessionDiagnostics(from: clean(input))
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func responseContent(_ input: String) -> String {
        removingSessionDiagnostics(from: clean(input))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removingSessionDiagnostics(from input: String) -> String {
        input
            .components(separatedBy: "\n")
            .filter { line in
                let normalized = line.trimmingCharacters(in: .whitespaces).lowercased()
                return !normalized.hasPrefix("creating session with")
            }
            .joined(separator: "\n")
    }
}

@MainActor
final class FMService {
    private let executableURL = URL(fileURLWithPath: "/usr/bin/fm")
    private var currentProcess: Process?

    var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: executableURL.path)
    }

    func respond(
        prompt: String,
        model: AFMModel,
        instructions: String,
        transcriptURL: URL,
        onOutput: @escaping @MainActor (String) -> Void,
        onThinking: @escaping @MainActor (String) -> Void
    ) async throws -> FMResponse {
        var arguments = ["respond", "--model", model.rawValue, "--verbose", "--stream"]
        let canResume = (try? transcriptURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 > 0
        if canResume {
            arguments += ["--resume", transcriptURL.path]
        } else if !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments += ["--instructions", instructions]
        }
        arguments += ["--save-transcript", transcriptURL.path]

        let start = Date()
        let result = try await run(
            arguments: arguments,
            input: prompt,
            onOutput: { rawOutput in
                onOutput(TerminalText.responseContent(rawOutput))
            },
            onErrorOutput: { rawOutput in
                onThinking(TerminalText.userFacingDetails(rawOutput))
            }
        )
        let elapsed = Date().timeIntervalSince(start)
        guard result.exitCode == 0 else {
            throw FMCommandFailure(
                exitCode: result.exitCode,
                standardOutput: result.output,
                standardError: result.errorOutput
            )
        }

        let content = TerminalText.responseContent(result.output)
        if content.isEmpty {
            throw FMCommandFailure(exitCode: 0, standardOutput: "", standardError: result.errorOutput)
        }
        return FMResponse(
            content: content,
            thinking: TerminalText.userFacingDetails(result.errorOutput),
            duration: elapsed
        )
    }

    func generateTitle(for firstPrompt: String, model: AFMModel) async throws -> String {
        let instruction = "Create a short conversation title from the user's first message. "
            + "Use the same language as the message, use no more than six words, and output only the title without quotes."
        let result = try await run(
            arguments: ["respond", "--model", model.rawValue, "--no-stream", "--instructions", instruction],
            input: firstPrompt
        )
        guard result.exitCode == 0 else {
            throw FMCommandFailure(
                exitCode: result.exitCode,
                standardOutput: result.output,
                standardError: result.errorOutput
            )
        }
        return sanitizeTitle(TerminalText.trimmed(result.output))
    }

    func licenseStatus() async -> Bool {
        guard isInstalled else { return false }
        guard let result = try? await run(arguments: ["license", "--status"], input: nil) else { return false }
        let output = (result.output + "\n" + result.errorOutput).lowercased()
        return result.exitCode == 0 && (output.contains("agreed") || output.contains("accepted"))
    }

    func licenseText() async -> String {
        guard isInstalled else { return "" }
        guard let result = try? await run(arguments: ["license", "--show"], input: nil) else { return "" }
        return TerminalText.trimmed(result.output.isEmpty ? result.errorOutput : result.output)
    }

    func cancel() {
        currentProcess?.terminate()
    }

    private struct CommandResult {
        let exitCode: Int32
        let output: String
        let errorOutput: String
    }

    private func run(
        arguments: [String],
        input: String?,
        onOutput: @escaping @MainActor (String) -> Void = { _ in },
        onErrorOutput: @escaping @MainActor (String) -> Void = { _ in }
    ) async throws -> CommandResult {
        guard isInstalled else {
            throw CocoaError(.executableNotLoadable)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["NO_COLOR"] = "1"
        environment["TERM"] = "dumb"
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe

        let outputCapture = StreamCapture(update: onOutput)
        let errorCapture = StreamCapture(update: onErrorOutput)
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            outputCapture.append(handle.availableData)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            errorCapture.append(handle.availableData)
        }

        currentProcess = process
        do {
            try process.run()
        } catch {
            currentProcess = nil
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            throw error
        }

        if let input, let data = input.data(using: .utf8) {
            try? inputPipe.fileHandleForWriting.write(contentsOf: data)
        }
        try? inputPipe.fileHandleForWriting.close()

        let exitCode = await withCheckedContinuation { continuation in
            process.terminationHandler = { terminatedProcess in
                continuation.resume(returning: terminatedProcess.terminationStatus)
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        outputCapture.append((try? outputPipe.fileHandleForReading.readToEnd()) ?? Data())
        errorCapture.append((try? errorPipe.fileHandleForReading.readToEnd()) ?? Data())
        currentProcess = nil

        return CommandResult(
            exitCode: exitCode,
            output: outputCapture.snapshot(),
            errorOutput: errorCapture.snapshot()
        )
    }

    private func sanitizeTitle(_ rawTitle: String) -> String {
        let firstLine = rawTitle.split(whereSeparator: \Character.isNewline).first.map(String.init) ?? rawTitle
        let trimmed = firstLine.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'“”‘’#*"))
        return String(trimmed.prefix(80))
    }
}
