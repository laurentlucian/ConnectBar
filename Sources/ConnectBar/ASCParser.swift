import Foundation

enum ASCParser {
    static func apps(from data: Data) throws -> [StoreApp] {
        let root = try object(data)
        return dictionaries(in: root).compactMap { item in
            guard string(item, "type") == "apps" || item["bundleId"] != nil || item["bundleID"] != nil else { return nil }
            guard let id = string(item, "id") else { return nil }
            let attributes = item["attributes"] as? [String: Any] ?? item
            guard let name = string(attributes, "name") else { return nil }
            return StoreApp(id: id, name: name, bundleID: string(attributes, "bundleId") ?? string(attributes, "bundleID"))
        }
        .uniqued(by: \StoreApp.id)
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func signals(status: Data, reviews: Data, app: StoreApp) throws -> [Signal] {
        var result = statusSignals(from: try object(status), app: app)
        result += reviewSignals(from: try object(reviews), app: app)
        return result.uniqued(by: \Signal.id).sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            return ($0.occurredAt ?? .distantPast) > ($1.occurredAt ?? .distantPast)
        }
    }

    private static func statusSignals(from root: Any, app: StoreApp) -> [Signal] {
        return dictionaries(in: root).compactMap { item in
            let attributes = item["attributes"] as? [String: Any] ?? item
            let id = string(item, "id") ?? stableID(attributes)
            let build = string(attributes, "version") ?? string(attributes, "buildNumber")
            let state = ["processingState", "appVersionState", "state", "externalBuildState"]
                .compactMap { string(attributes, $0) }.first
            guard let state else { return nil }
            let normalized = state.uppercased()
            let date = date(attributes)

            if normalized.contains("FAIL") || normalized.contains("REJECT") || normalized.contains("INVALID") {
                return Signal(id: "status-\(id)-\(normalized)", appID: app.id, appName: app.name,
                              kind: .failure, severity: .critical,
                              title: build.map { "Build \($0) \(words(normalized))" } ?? words(normalized),
                              detail: nil, occurredAt: date)
            }
            if normalized.contains("PROCESS") || normalized.contains("UPLOAD") {
                return Signal(id: "status-\(id)-\(normalized)", appID: app.id, appName: app.name,
                              kind: .processing, severity: .active,
                              title: build.map { "Build \($0) \(words(normalized))" } ?? words(normalized),
                              detail: nil, occurredAt: date)
            }
            if normalized.contains("REVIEW") || normalized.contains("PENDING") {
                return Signal(id: "status-\(id)-\(normalized)", appID: app.id, appName: app.name,
                              kind: .submission,
                              severity: normalized.contains("REJECT") ? .critical : .active,
                              title: build.map { "\($0) \(words(normalized))" } ?? words(normalized),
                              detail: nil, occurredAt: date)
            }
            return nil
        }.uniqued { "\($0.kind.rawValue)|\($0.title)" }
    }

    private static func reviewSignals(from root: Any, app: StoreApp) -> [Signal] {
        dictionaries(in: root).compactMap { item in
            guard string(item, "type") == "customerReviews" || item["rating"] != nil || (item["attributes"] as? [String: Any])?["rating"] != nil else { return nil }
            let attributes = item["attributes"] as? [String: Any] ?? item
            guard let rating = integer(attributes, "rating"), let id = string(item, "id") else { return nil }
            let title = string(attributes, "title")
            let body = string(attributes, "body")
            return Signal(id: "review-\(id)", appID: app.id, appName: app.name,
                          kind: .review, severity: rating <= 2 ? .warning : .info,
                          title: "New \(rating)-star review",
                          detail: title ?? body, occurredAt: date(attributes))
        }
    }

    private static func object(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }

    private static func dictionaries(in value: Any) -> [[String: Any]] {
        if let dictionary = value as? [String: Any] {
            return [dictionary] + dictionary.values.flatMap(dictionaries)
        }
        if let array = value as? [Any] { return array.flatMap(dictionaries) }
        return []
    }

    private static func string(_ dictionary: [String: Any], _ key: String) -> String? {
        dictionary[key] as? String
    }

    private static func integer(_ dictionary: [String: Any], _ key: String) -> Int? {
        dictionary[key] as? Int ?? (dictionary[key] as? NSNumber)?.intValue
    }

    private static func date(_ dictionary: [String: Any]) -> Date? {
        let raw = ["createdDate", "uploadedDate", "submittedDate", "lastModifiedDate"]
            .compactMap { string(dictionary, $0) }.first
        return raw.flatMap { ISO8601DateFormatter().date(from: $0) }
    }

    private static func stableID(_ dictionary: [String: Any]) -> String {
        dictionary.keys.sorted().compactMap { key in string(dictionary, key).map { "\(key):\($0)" } }.joined(separator: "|")
    }

    private static func words(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "_", with: " ")
    }
}

private extension Array {
    func uniqued<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }

    func uniqued<Key: Hashable>(_ key: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert(key($0)).inserted }
    }
}
