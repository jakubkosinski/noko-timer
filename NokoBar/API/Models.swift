import Foundation

struct NokoUser: Codable, Equatable, Sendable {
    let id: Int
    let email: String
    let firstName: String
    let lastName: String
    let profileImageUrl: String?
    let role: String?
    let state: String?

    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
}

struct NokoProject: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let name: String
    let color: String?
    let billingIncrement: Int?
    let enabled: Bool?
}

struct NokoTag: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let name: String
    let formattedName: String?
    let billable: Bool?
}

enum TimerState: String, Codable, Sendable {
    case pending, running, paused, stopped
}

struct TimerProject: Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let color: String?
}

struct NokoTimer: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let state: TimerState
    let seconds: Int
    let date: String?
    let description: String?
    let project: TimerProject

    var isActive: Bool { state == .running || state == .paused }
}

struct EntryTag: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}

struct EntryProject: Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let color: String?
}

struct NokoEntry: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let date: String          // yyyy-MM-dd
    let minutes: Int
    let description: String?
    let tags: [EntryTag]?
    var project: EntryProject?
}

struct APIErrorBody: Codable, Sendable {
    let code: String?
    let message: String?
}

enum NokoError: Error, Equatable, LocalizedError {
    case unauthorized
    case notFound
    case rateLimited
    case server(status: Int, code: String?, message: String?)
    case invalidResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return String(localized: "error.unauthorized")
        case .notFound:
            return String(localized: "error.notFound")
        case .rateLimited:
            return String(localized: "error.rateLimited")
        case .server(let status, let code, let message):
            if code == "cannot_create_tags" { return String(localized: "error.cannotCreateTags") }
            return message ?? "HTTP \(status)"
        case .invalidResponse:
            return String(localized: "error.invalidResponse")
        case .transport(let m):
            return m
        }
    }
}
