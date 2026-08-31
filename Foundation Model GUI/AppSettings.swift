import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    @Published var defaultModel: AFMModel {
        didSet { defaults.set(defaultModel.rawValue, forKey: Keys.defaultModel) }
    }

    @Published var customInstructions: String {
        didSet { defaults.set(customInstructions, forKey: Keys.customInstructions) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let language = "uiLanguage"
        static let defaultModel = "defaultModel"
        static let customInstructions = "customInstructions"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .japanese
        defaultModel = AFMModel(rawValue: defaults.string(forKey: Keys.defaultModel) ?? "") ?? .system
        customInstructions = defaults.string(forKey: Keys.customInstructions) ?? ""
    }
}
