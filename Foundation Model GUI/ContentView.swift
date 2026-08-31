import AppKit
import Combine
import SwiftUI

@MainActor
private final class ComposerState: ObservableObject {
    @Published var draft = ""
}

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: ChatStore
    @EnvironmentObject private var controller: ChatController
    @StateObject private var composer = ComposerState()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            if let session = store.selectedSession {
                conversation(session)
            } else {
                ContentUnavailableView {
                    Label(
                        L10nKey.noConversation.value(settings.language),
                        systemImage: "bubble.left.and.bubble.right"
                    )
                } description: {
                    Text(L10nKey.startConversation.value(settings.language))
                } actions: {
                    Button(L10nKey.newConversation.value(settings.language)) {
                        createSession()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            if store.sessions.isEmpty {
                createSession()
            }
            await controller.checkLicense()
        }
        .sheet(isPresented: $controller.showsLicense) {
            LicenseView()
                .environmentObject(settings)
                .environmentObject(controller)
        }
    }

    private var sidebar: some View {
        List(selection: $store.selectedID) {
            ForEach(store.sortedSessions) { session in
                SessionRow(session: session)
                    .tag(session.id)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteSession(id: session.id)
                        } label: {
                            Label(
                                L10nKey.deleteConversation.value(settings.language),
                                systemImage: "trash"
                            )
                        }
                        .disabled(controller.isRunning)
                    }
            }
            .onDelete { offsets in
                guard !controller.isRunning else { return }
                let sessions = store.sortedSessions
                for index in offsets where sessions.indices.contains(index) {
                    store.deleteSession(id: sessions[index].id)
                }
            }
        }
        .navigationTitle(L10nKey.conversations.value(settings.language))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createSession) {
                    Label(L10nKey.newConversation.value(settings.language), systemImage: "square.and.pencil")
                }
                .help(L10nKey.newConversation.value(settings.language))
            }
        }
    }

    private func conversation(_ session: ChatSession) -> some View {
        VStack(spacing: 0) {
            MessagesView(
                session: session,
                isRunning: controller.runningSessionID == session.id
            )
            Divider()
            composer(session: session)
        }
        .navigationTitle(session.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if controller.isRunning {
                    Button(action: controller.cancel) {
                        Label(L10nKey.stop.value(settings.language), systemImage: "stop.fill")
                    }
                }
                SettingsLink {
                    Label(L10nKey.settings.value(settings.language), systemImage: "gearshape")
                }
            }
        }
    }

    private func composer(session: ChatSession) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    L10nKey.messagePlaceholder.value(settings.language),
                    text: $composer.draft,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1...7)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onSubmit {
                    send(sessionID: session.id)
                }

                Button {
                    send(sessionID: session.id)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                }
                .buttonStyle(.plain)
                .disabled(composer.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.isRunning)
                .help(L10nKey.send.value(settings.language))
            }

            HStack(spacing: 8) {
                Image(systemName: session.model == .system ? "desktopcomputer" : "cloud")
                    .foregroundStyle(session.model == .system ? Color.secondary : Color.blue)

                Picker(
                    L10nKey.model.value(settings.language),
                    selection: Binding(
                        get: { session.model },
                        set: { store.setModel($0, for: session.id) }
                    )
                ) {
                    ForEach(AFMModel.allCases) { model in
                        Text(model.selectorName(language: settings.language)).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
                .disabled(controller.isRunning)

                Text(session.model.detail(language: settings.language))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(14)
        .background(.bar)
    }

    private func createSession() {
        _ = store.createSession(defaultModel: settings.defaultModel, language: settings.language)
        composer.draft = ""
    }

    private func send(sessionID: UUID) {
        let prompt = composer.draft
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        composer.draft = ""
        Task {
            await controller.send(prompt, sessionID: sessionID, settings: settings)
        }
    }
}

private struct SessionRow: View {
    @EnvironmentObject private var settings: AppSettings
    let session: ChatSession

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: session.model == .system ? "desktopcomputer" : "cloud")
                .foregroundStyle(session.model == .system ? Color.secondary : Color.blue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .lineLimit(1)
                    .fontWeight(.medium)
                Text(session.model.displayName(language: settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct MessagesView: View {
    @EnvironmentObject private var settings: AppSettings
    let session: ChatSession
    let isRunning: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if session.messages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: session.model == .system ? "desktopcomputer" : "cloud")
                                .font(.system(size: 34))
                                .foregroundStyle(.secondary)
                            Text(L10nKey.startConversation.value(settings.language))
                                .font(.title3.weight(.medium))
                            Text(session.model == .system
                                 ? L10nKey.privacyLocal.value(settings.language)
                                 : L10nKey.privacyPCC.value(settings.language))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: 500)
                        .padding(.top, 80)
                    }

                    ForEach(session.messages) { message in
                        MessageBubble(
                            message: message,
                            isActivelyGenerating: isRunning && message.id == session.messages.last?.id
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: session.messages) { _, messages in
                if let id = messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct MessageBubble: View {
    @EnvironmentObject private var settings: AppSettings
    let message: ChatMessage
    let isActivelyGenerating: Bool

    private var visibleContent: String {
        message.role == .assistant ? TerminalText.responseContent(message.content) : message.content
    }

    private var visibleThinking: String {
        TerminalText.userFacingDetails(message.thinking)
    }

    private var markdownContent: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: visibleContent, options: options))
            ?? AttributedString(visibleContent)
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user { Spacer(minLength: 100) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if !visibleContent.isEmpty {
                    Text(markdownContent)
                        .textSelection(.enabled)
                        .foregroundStyle(message.role == .user ? .white : (message.isError ? .red : .primary))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            message.role == .user ? Color.blue : Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                        )
                }

                if message.role == .assistant && isActivelyGenerating {
                    ThinkingIndicator()
                }

                if message.role == .assistant && !visibleThinking.isEmpty {
                    DisclosureGroup {
                        Text(visibleThinking)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    } label: {
                        Label(L10nKey.thinking.value(settings.language), systemImage: "brain.head.profile")
                            .font(.caption)
                    }
                    .frame(maxWidth: 620, alignment: .leading)
                    .padding(.horizontal, 6)
                }

                if let duration = message.duration {
                    Text("\(L10nKey.responseTime.value(settings.language)): \(duration.responseTimeText(language: settings.language))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                }
            }
            .frame(maxWidth: 680, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant { Spacer(minLength: 100) }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ThinkingIndicator: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.45)) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.45) % 3
            HStack(spacing: 9) {
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(.blue)

                Text(L10nKey.processing.value(settings.language))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4, height: 4)
                            .opacity(index == phase ? 1 : 0.22)
                            .scaleEffect(index == phase ? 1.25 : 0.85)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: phase)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(.thinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.blue.opacity(0.16), lineWidth: 1)
            }
        }
    }
}

private struct LicenseView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ChatController
    @Environment(\.dismiss) private var dismiss

    private let command = "sudo fm license"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L10nKey.licenseTitle.value(settings.language), systemImage: "checkmark.seal")
                .font(.title2.bold())

            Text(L10nKey.licenseExplanation.value(settings.language))
                .foregroundStyle(.secondary)

            GroupBox(L10nKey.terminalInstruction.value(settings.language)) {
                HStack {
                    Text(command)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button(L10nKey.copyCommand.value(settings.language), action: copyCommand)
                    Button(L10nKey.openTerminal.value(settings.language), action: openTerminal)
                }
                .padding(.top, 4)
            }

            GroupBox("Apple Foundation Models CLI Legal Notice & Terms") {
                ScrollView {
                    Text(controller.licenseText.isEmpty ? "—" : controller.licenseText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(minHeight: 230)
            }

            HStack {
                Button(L10nKey.close.value(settings.language)) { dismiss() }
                Spacer()
                Button(L10nKey.checkAgain.value(settings.language)) {
                    Task { await controller.checkLicense() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 760, height: 570)
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    private func openTerminal() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings()
        let store = ChatStore()
        ContentView()
            .environmentObject(settings)
            .environmentObject(store)
            .environmentObject(ChatController(store: store))
    }
}
