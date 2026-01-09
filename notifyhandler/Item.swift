import Foundation
import SwiftData

enum NotificationCategory: String, Codable {
    case info, warning, error, success
}

@Model
final class NotificationRecord {
    var id: UUID
    var title: String
    var body: String
    var category: String
    var timestamp: Date
    var extra: String
    var isRead: Bool

    init(title: String, body: String, category: NotificationCategory = .info, timestamp: Date = Date(), extra: [String: Any] = [:]) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.category = category.rawValue
        self.timestamp = timestamp
        self.extra = (try? JSONSerialization.data(withJSONObject: extra).base64EncodedString()) ?? ""
        self.isRead = false
    }
}

struct WebhookPayload: Decodable {
    let title: String
    let body: String
    let category: String?
    let timestamp: Int64?
    let extra: [String: AnyCodable]?
}

struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = ""
        }
    }
}
