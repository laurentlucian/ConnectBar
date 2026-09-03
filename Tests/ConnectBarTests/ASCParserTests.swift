import Foundation
import Testing
@testable import ConnectBar

@Test func parsesAppsFromJSONAPI() throws {
    let data = Data(#"{"data":[{"type":"apps","id":"1","attributes":{"name":"Orbit","bundleId":"com.example.orbit"}}]}"#.utf8)
    #expect(try ASCParser.apps(from: data) == [StoreApp(id: "1", name: "Orbit", bundleID: "com.example.orbit")])
}

@Test func ranksFailureBeforeReviewAndProcessing() throws {
    let app = StoreApp(id: "1", name: "Orbit", bundleID: nil)
    let status = Data(#"{"data":[{"id":"b1","attributes":{"version":"108","processingState":"PROCESSING"}},{"id":"v1","attributes":{"version":"2.4","appVersionState":"REJECTED"}}]}"#.utf8)
    let reviews = Data(#"{"data":[{"type":"customerReviews","id":"r1","attributes":{"rating":1,"title":"Crash","createdDate":"2026-09-01T10:00:00Z"}}]}"#.utf8)
    let signals = try ASCParser.signals(status: status, reviews: reviews, app: app)
    #expect(signals.map(\.kind) == [.failure, .review, .processing])
    #expect(signals[1].detail == "Crash")
}

@Test func deduplicatesNestedJSONAPIResources() throws {
    let data = Data(#"{"data":[{"type":"apps","id":"1","attributes":{"name":"Orbit"}}],"included":[{"type":"apps","id":"1","attributes":{"name":"Orbit"}}]}"#.utf8)
    #expect(try ASCParser.apps(from: data).count == 1)
}
