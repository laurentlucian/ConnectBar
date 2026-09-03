import Foundation

enum ASCError: LocalizedError {
    case missingCLI
    case failed(String)
    case invalidOutput
    case timedOut

    var errorDescription: String? {
        switch self {
        case .missingCLI: "asc is not installed"
        case .failed(let message): message
        case .invalidOutput: "asc returned unreadable data"
        case .timedOut: "asc timed out. Try again."
        }
    }
}

protocol ASCServing: Sendable {
    func apps() async throws -> [StoreApp]
    func signals(for app: StoreApp) async throws -> [Signal]
}

struct ASCClient: ASCServing {
    let executable: URL

    init() throws {
        let candidates = [
            "/opt/homebrew/bin/asc",
            "/usr/local/bin/asc",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/asc"
        ]
        guard let path = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) else {
            throw ASCError.missingCLI
        }
        executable = URL(fileURLWithPath: path)
    }

    func apps() async throws -> [StoreApp] {
        let data = try await run(["apps", "list", "--limit", "200", "--output", "json"])
        return try ASCParser.apps(from: data)
    }

    func signals(for app: StoreApp) async throws -> [Signal] {
        async let status = run([
            "status", "--app", app.id,
            "--include", "builds,testflight,appstore,submission,review",
            "--output", "json"
        ])
        async let reviews = run([
            "reviews", "--app", app.id, "--sort", "-createdDate",
            "--limit", "20", "--output", "json"
        ])
        return try await ASCParser.signals(status: status, reviews: reviews, app: app)
    }

    private func run(_ arguments: [String]) async throws -> Data {
        try await ProcessRunner.run(executable: executable, arguments: arguments)
    }
}

enum ProcessRunner {
    static func run(executable: URL, arguments: [String], timeout: TimeInterval = 30) async throws -> Data {
        try await Task.detached {
            let process = Process()
            let output = OutputBuffer()
            let errors = OutputBuffer()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            stdoutPipe.fileHandleForReading.readabilityHandler = { output.append($0.availableData) }
            stderrPipe.fileHandleForReading.readabilityHandler = { errors.append($0.availableData) }
            try process.run()

            let timedOut = LockedFlag()
            let deadline = DispatchWorkItem {
                if process.isRunning {
                    timedOut.set()
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)
            process.waitUntilExit()
            deadline.cancel()
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            output.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            errors.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

            if timedOut.value { throw ASCError.timedOut }
            guard process.terminationStatus == 0 else {
                let message = String(data: errors.data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw ASCError.failed(message?.isEmpty == false ? message! : "asc failed")
            }
            guard !output.data.isEmpty else { throw ASCError.invalidOutput }
            return output.data
        }.value
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = false

    func set() {
        lock.lock()
        storage = true
        lock.unlock()
    }

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

struct MockASCClient: ASCServing {
    func apps() async throws -> [StoreApp] {
        [StoreApp(id: "123", name: "Orbit", bundleID: "com.example.orbit")]
    }

    func signals(for app: StoreApp) async throws -> [Signal] {
        [
            Signal(id: "build-108", appID: app.id, appName: app.name, kind: .processing,
                   severity: .active, title: "Build 108 processing", detail: "Uploaded 8m ago", occurredAt: .now.addingTimeInterval(-480)),
            Signal(id: "submission-24", appID: app.id, appName: app.name, kind: .submission,
                   severity: .active, title: "2.4 waiting for review", detail: "Submitted 3h ago", occurredAt: .now.addingTimeInterval(-10_800)),
            Signal(id: "review-demo", appID: app.id, appName: app.name, kind: .review,
                   severity: .warning, title: "New 1-star review", detail: "Crashes after the update", occurredAt: .now.addingTimeInterval(-3_600))
        ]
    }
}
