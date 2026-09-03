import Foundation
import Testing
@testable import ConnectBar

@Test func drainsLargeOutputWhileProcessRuns() async throws {
    let data = try await ProcessRunner.run(
        executable: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "head -c 1048576 /dev/zero"],
        timeout: 2
    )
    #expect(data.count == 1_048_576)
}

@Test func terminatesHungProcess() async {
    let start = ContinuousClock.now
    await #expect(throws: ASCError.self) {
        try await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "sleep 5"],
            timeout: 0.1
        )
    }
    #expect(start.duration(to: .now) < .seconds(1))
}
