import Foundation

struct StoreApp: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let bundleID: String?
}

enum SignalKind: String, Codable, Sendable {
    case failure, submission, processing, review, feedback, info
}

enum Severity: Int, Codable, Comparable, Sendable {
    case info, active, warning, critical
    static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct Signal: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let appID: String
    let appName: String
    let kind: SignalKind
    let severity: Severity
    let title: String
    let detail: String?
    let occurredAt: Date?

    var isAttention: Bool { severity >= .warning || kind == .review }
}

struct Snapshot: Codable, Sendable {
    var signals: [Signal] = []
    var refreshedAt: Date?
}

enum ConnectionState: Equatable {
    case loading, ready, missingCLI, unauthenticated, failed(String)
}
