import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ChatController

    var body: some View {
        Form {
            Section(L10nKey.general.value(settings.language)) {
                Picker(L10nKey.language.value(settings.language), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }

                Picker(L10nKey.defaultModel.value(settings.language), selection: $settings.defaultModel) {
                    ForEach(AFMModel.allCases) { model in
                        VStack(alignment: .leading) {
                            Text(model.displayName(language: settings.language))
                            Text(model.detail(language: settings.language))
                        }
                        .tag(model)
                    }
                }
            }

            Section(L10nKey.customInstructions.value(settings.language)) {
                TextEditor(text: $settings.customInstructions)
                    .font(.body)
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if settings.customInstructions.isEmpty {
                            Text(L10nKey.customInstructionsHint.value(settings.language))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                Text(L10nKey.customInstructionsFootnote.value(settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10nKey.fmCLI.value(settings.language)) {
                HStack {
                    Text("/usr/bin/fm")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(L10nKey.license.value(settings.language)) {
                        Task { await controller.showLicenseInformation() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
