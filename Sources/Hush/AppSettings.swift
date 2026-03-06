import Foundation
import Combine

/// Shared settings observable across menu bar and settings window.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var currentMode: CorrectionMode {
        didSet { UserDefaults.standard.set(currentMode.rawValue, forKey: "correctionMode") }
    }

    @Published var pauseDelay: TimeInterval {
        didSet { UserDefaults.standard.set(pauseDelay, forKey: "pauseDelay") }
    }

    @Published var isActive: Bool {
        didSet { UserDefaults.standard.set(isActive, forKey: "isActive") }
    }

    @Published var minimumWordCount: Int {
        didSet { UserDefaults.standard.set(minimumWordCount, forKey: "minimumWordCount") }
    }

    @Published var customPrompt: String {
        didSet { UserDefaults.standard.set(customPrompt, forKey: "customPrompt") }
    }

    @Published var apiKey: String {
        didSet {
            let _ = KeychainHelper.saveString(key: "openRouterApiKey", value: apiKey)
            // Clean up old UserDefaults storage
            UserDefaults.standard.removeObject(forKey: "openRouterApiKey")
        }
    }

    @Published var useLocalModel: Bool {
        didSet { UserDefaults.standard.set(useLocalModel, forKey: "useLocalModel") }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    @Published var correctionCount: Int = 0

    /// Whether the app is currently in trial mode (computed from LicenseManager).
    var isTrialMode: Bool {
        if case .trial = LicenseManager.shared.licenseState {
            return true
        }
        return false
    }

    static let defaultCustomPrompt = """
    You are a helpful text assistant. Detect the language of the input text automatically. \
    Return ONLY the modified text, with no explanations, no notes, no prefix, no quotes. \
    Preserve the original language.
    """

    /// Bundled API key — set your own OpenRouter key here or configure in Keychain.
    private static let bundledApiKey = ""

    private init() {
        let savedMode = UserDefaults.standard.string(forKey: "correctionMode") ?? CorrectionMode.correction.rawValue
        self.currentMode = CorrectionMode(rawValue: savedMode) ?? .correction
        self.pauseDelay = UserDefaults.standard.object(forKey: "pauseDelay") as? TimeInterval ?? 2.0
        self.isActive = UserDefaults.standard.object(forKey: "isActive") as? Bool ?? true
        self.minimumWordCount = UserDefaults.standard.object(forKey: "minimumWordCount") as? Int ?? 4
        self.customPrompt = UserDefaults.standard.string(forKey: "customPrompt") ?? Self.defaultCustomPrompt
        // Migrate API key from UserDefaults to Keychain if needed
        if let legacyKey = UserDefaults.standard.string(forKey: "openRouterApiKey"), !legacyKey.isEmpty {
            let _ = KeychainHelper.saveString(key: "openRouterApiKey", value: legacyKey)
            UserDefaults.standard.removeObject(forKey: "openRouterApiKey")
            self.apiKey = legacyKey
        } else {
            let stored = KeychainHelper.readString(key: "openRouterApiKey") ?? ""
            if stored.isEmpty {
                // Provision bundled key on first launch
                let _ = KeychainHelper.saveString(key: "openRouterApiKey", value: Self.bundledApiKey)
                self.apiKey = Self.bundledApiKey
            } else {
                self.apiKey = stored
            }
        }
        self.useLocalModel = UserDefaults.standard.object(forKey: "useLocalModel") as? Bool ?? false
        self.hasCompletedOnboarding = UserDefaults.standard.object(forKey: "hasCompletedOnboarding") as? Bool ?? false
    }
}
