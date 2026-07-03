import Foundation

enum APIError: LocalizedError {
    case notConfigured
    case server(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set your server URL and token in Settings."
        case .server(let m): return m
        case .decoding(let m): return "Bad response: \(m)"
        }
    }
}

/// Thin client for the Tally server. Reads the base URL + token from UserDefaults
/// so they can be changed in Settings without rebuilding.
enum AppConfig {
    // Used unless overridden in Settings. Change there and your value wins.
    // Real values live in the git-ignored Secrets.swift — never hardcode them here:
    // this file is committed to a public repo.
    static let defaultServerURL = Secrets.serverURL
    static let defaultToken = Secrets.token
}

struct APIClient {
    static var baseURL: String {
        let v = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        return v.isEmpty ? AppConfig.defaultServerURL : v
    }
    static var token: String {
        let v = UserDefaults.standard.string(forKey: "token") ?? ""
        return v.isEmpty ? AppConfig.defaultToken : v
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private static func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        let base = baseURL.trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty, !token.isEmpty, let url = URL(string: base + path) else {
            throw APIError.notConfigured
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 60

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.server("No response") }
        guard (200..<300).contains(http.statusCode) else {
            var serverMsg: String? = nil
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                serverMsg = (obj["error"] as? String) ?? (obj["detail"] as? String)
            }
            let prefix = http.statusCode == 429 ? "Rate limited (429)" : "Error \(http.statusCode)"
            throw APIError.server("\(prefix): \(serverMsg ?? "request failed")")
        }
        return data
    }

    private static func decode<T: Decodable>(_ data: Data, as: T.Type) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error.localizedDescription) }
    }

    // MARK: Endpoints

    static func estimate(text: String?, imageBase64: String?) async throws -> Estimate {
        let payload = EstimateRequest(
            text: text?.isEmpty == true ? nil : text,
            imageBase64: imageBase64,
            mediaType: imageBase64 == nil ? nil : "image/jpeg"
        )
        let data = try await request("/estimate", method: "POST", body: try encoder.encode(payload))
        return try decode(data, as: Estimate.self)
    }

    static func entries(date: String) async throws -> [Entry] {
        let data = try await request("/entries?date=\(date)")
        return try decode(data, as: [Entry].self)
    }

    static func addEntry(_ e: EntryCreate) async throws -> Entry {
        let data = try await request("/entries", method: "POST", body: try encoder.encode(e))
        return try decode(data, as: Entry.self)
    }

    static func updateEntry(id: String, _ e: EntryCreate) async throws -> Entry {
        let data = try await request("/entries/\(id)", method: "PUT", body: try encoder.encode(e))
        return try decode(data, as: Entry.self)
    }

    static func deleteEntry(id: String) async throws {
        _ = try await request("/entries/\(id)", method: "DELETE")
    }

    static func routines() async throws -> [Routine] {
        let data = try await request("/routines")
        return try decode(data, as: [Routine].self)
    }

    static func setRoutines(_ items: [RoutineInput]) async throws -> [Routine] {
        let data = try await request("/routines", method: "PUT", body: try encoder.encode(items))
        return try decode(data, as: [Routine].self)
    }

    static func settings() async throws -> Settings {
        let data = try await request("/settings")
        return try decode(data, as: Settings.self)
    }

    static func summary(days: Int = 7) async throws -> [DaySummary] {
        let data = try await request("/summary?days=\(days)")
        return try decode(data, as: [DaySummary].self)
    }

    static func weights(days: Int = 90) async throws -> [Weight] {
        let data = try await request("/weights?days=\(days)")
        return try decode(data, as: [Weight].self)
    }

    static func logWeight(value: Double, date: String) async throws -> Weight {
        struct Body: Codable { var value: Double; var date: String }
        let data = try await request("/weights", method: "POST", body: try encoder.encode(Body(value: value, date: date)))
        return try decode(data, as: Weight.self)
    }

    static func setGoal(_ goal: Int) async throws -> Settings {
        let data = try await request("/settings", method: "PUT", body: try encoder.encode(SettingsUpdate(goal: goal)))
        return try decode(data, as: Settings.self)
    }
}
