import Combine
import Foundation

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var sessions: [ChatSession] = []
    @Published var selectedID: UUID?

    let dataDirectory: URL
    private let sessionsFile: URL
    private let transcriptsDirectory: URL

    var selectedSession: ChatSession? {
        guard let selectedID else { return nil }
        return sessions.first(where: { $0.id == selectedID })
    }

    var sortedSessions: [ChatSession] {
        sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        dataDirectory = applicationSupport.appendingPathComponent("AFM Chat", isDirectory: true)
        sessionsFile = dataDirectory.appendingPathComponent("sessions.json")
        transcriptsDirectory = dataDirectory.appendingPathComponent("Transcripts", isDirectory: true)

        try? fileManager.createDirectory(at: transcriptsDirectory, withIntermediateDirectories: true)
        load()
        selectedID = sortedSessions.first?.id
    }

    @discardableResult
    func createSession(defaultModel: AFMModel, language: AppLanguage) -> UUID {
        let session = ChatSession(
            title: L10nKey.newConversation.value(language),
            model: defaultModel
        )
        sessions.append(session)
        selectedID = session.id
        save()
        return session.id
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: transcriptURL(for: id))
        if selectedID == id {
            selectedID = sortedSessions.first?.id
        }
        save()
    }

    func setModel(_ model: AFMModel, for sessionID: UUID) {
        mutateSession(id: sessionID) { session in
            session.model = model
            session.updatedAt = Date()
        }
        save()
    }

    @discardableResult
    func appendMessage(_ message: ChatMessage, to sessionID: UUID, persist: Bool = true) -> UUID {
        mutateSession(id: sessionID) { session in
            session.messages.append(message)
            session.updatedAt = Date()
        }
        if persist { save() }
        return message.id
    }

    func updateMessage(
        id messageID: UUID,
        in sessionID: UUID,
        content: String? = nil,
        thinking: String? = nil,
        duration: TimeInterval? = nil,
        isError: Bool? = nil,
        persist: Bool = false
    ) {
        mutateSession(id: sessionID) { session in
            guard let index = session.messages.firstIndex(where: { $0.id == messageID }) else { return }
            if let content { session.messages[index].content = content }
            if let thinking { session.messages[index].thinking = thinking }
            if let duration { session.messages[index].duration = duration }
            if let isError { session.messages[index].isError = isError }
            session.updatedAt = Date()
        }
        if persist { save() }
    }

    func setTitle(_ title: String, generated: Bool, for sessionID: UUID) {
        mutateSession(id: sessionID) { session in
            session.title = title
            session.hasGeneratedTitle = generated
            session.updatedAt = Date()
        }
        save()
    }

    func transcriptURL(for sessionID: UUID) -> URL {
        transcriptsDirectory.appendingPathComponent("\(sessionID.uuidString).json")
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sessions)
            try data.write(to: sessionsFile, options: .atomic)
        } catch {
            assertionFailure("Could not save chat sessions: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: sessionsFile) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var decodedSessions = try decoder.decode([ChatSession].self, from: data)
            var removedDiagnostics = false
            for sessionIndex in decodedSessions.indices {
                for messageIndex in decodedSessions[sessionIndex].messages.indices
                    where decodedSessions[sessionIndex].messages[messageIndex].role == .assistant {
                    let original = decodedSessions[sessionIndex].messages[messageIndex]
                    let cleanContent = TerminalText.responseContent(original.content)
                    let cleanThinking = TerminalText.userFacingDetails(original.thinking)
                    if cleanContent != original.content || cleanThinking != original.thinking {
                        decodedSessions[sessionIndex].messages[messageIndex].content = cleanContent
                        decodedSessions[sessionIndex].messages[messageIndex].thinking = cleanThinking
                        removedDiagnostics = true
                    }
                }
            }
            sessions = decodedSessions
            if removedDiagnostics { save() }
        } catch {
            // Preserve an unreadable file for manual recovery instead of overwriting it.
            let backup = sessionsFile.deletingPathExtension().appendingPathExtension("unreadable.json")
            try? FileManager.default.copyItem(at: sessionsFile, to: backup)
        }
    }

    private func mutateSession(id: UUID, mutation: (inout ChatSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        mutation(&sessions[index])
    }
}
