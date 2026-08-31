import Foundation

enum AFMModel: String, Codable, CaseIterable, Identifiable {
    case system
    case pcc

    var id: String { rawValue }

    func displayName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.system, .japanese): "ローカル"
        case (.system, .english): "Local"
        case (.pcc, _): "Private Cloud Computing"
        }
    }

    func detail(language: AppLanguage) -> String {
        switch (self, language) {
        case (.system, .japanese): "このMac上で処理"
        case (.system, .english): "Processed on this Mac"
        case (.pcc, .japanese): "Appleのプライベートクラウドで処理"
        case (.pcc, .english): "Processed by Apple's private cloud"
        }
    }

    func selectorName(language: AppLanguage) -> String {
        "\(displayName(language: language))（\(rawValue)）"
    }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case japanese
    case english

    var id: String { rawValue }
    var displayName: String { self == .japanese ? "日本語" : "English" }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var role: MessageRole
    var content: String
    var thinking: String = ""
    var createdAt: Date = Date()
    var duration: TimeInterval?
    var isError: Bool = false
}

struct ChatSession: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var model: AFMModel
    var messages: [ChatMessage] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var hasGeneratedTitle: Bool = false
}
