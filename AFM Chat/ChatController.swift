import Combine
import Foundation

@MainActor
final class ChatController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var runningSessionID: UUID?
    @Published var showsLicense = false
    @Published private(set) var licenseText = ""

    private let store: ChatStore
    private let service = FMService()

    init(store: ChatStore) {
        self.store = store
    }

    func checkLicense() async {
        guard service.isInstalled else { return }
        let agreed = await service.licenseStatus()
        if !agreed {
            licenseText = await service.licenseText()
            showsLicense = true
        } else {
            showsLicense = false
        }
    }

    func showLicenseInformation() async {
        licenseText = await service.licenseText()
        showsLicense = true
    }

    func send(_ rawPrompt: String, sessionID: UUID, settings: AppSettings) async {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isRunning, let session = store.sessions.first(where: { $0.id == sessionID }) else { return }

        let isFirstMessage = !session.messages.contains(where: { $0.role == .user })
        let model = session.model
        store.appendMessage(ChatMessage(role: .user, content: prompt), to: sessionID)
        let responseID = store.appendMessage(
            ChatMessage(role: .assistant, content: ""),
            to: sessionID
        )

        isRunning = true
        runningSessionID = sessionID
        defer {
            isRunning = false
            runningSessionID = nil
        }

        do {
            let result = try await service.respond(
                prompt: prompt,
                model: model,
                instructions: settings.customInstructions,
                transcriptURL: store.transcriptURL(for: sessionID),
                onOutput: { [weak self] output in
                    self?.store.updateMessage(id: responseID, in: sessionID, content: output)
                },
                onThinking: { [weak self] thinking in
                    self?.store.updateMessage(id: responseID, in: sessionID, thinking: thinking)
                }
            )
            store.updateMessage(
                id: responseID,
                in: sessionID,
                content: result.content,
                thinking: result.thinking,
                duration: result.duration,
                persist: true
            )

            if isFirstMessage {
                await generateTitle(for: sessionID, prompt: prompt, model: model)
            }
        } catch let failure as FMCommandFailure {
            if failure.appearsToRequireLicense {
                licenseText = await service.licenseText()
                showsLicense = true
            }
            let fallback = failure.appearsToBeUnavailable
                ? L10nKey.modelUnavailable.value(settings.language)
                : L10nKey.genericFailure.value(settings.language)
            let detail = failure.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            store.updateMessage(
                id: responseID,
                in: sessionID,
                content: detail.isEmpty ? fallback : "\(fallback)\n\n\(detail)",
                thinking: failure.thinkingDetails,
                isError: true,
                persist: true
            )
        } catch {
            let message = service.isInstalled
                ? "\(L10nKey.genericFailure.value(settings.language))\n\n\(error.localizedDescription)"
                : L10nKey.fmNotFound.value(settings.language)
            store.updateMessage(
                id: responseID,
                in: sessionID,
                content: message,
                isError: true,
                persist: true
            )
        }
    }

    func cancel() {
        service.cancel()
    }

    private func generateTitle(for sessionID: UUID, prompt: String, model: AFMModel) async {
        do {
            let title = try await service.generateTitle(for: prompt, model: model)
            guard !title.isEmpty else { return }
            store.setTitle(title, generated: true, for: sessionID)
        } catch {
            let fallback = String(prompt.replacingOccurrences(of: "\n", with: " ").prefix(36))
            store.setTitle(fallback, generated: false, for: sessionID)
        }
    }
}
