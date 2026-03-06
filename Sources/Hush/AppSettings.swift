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

    @Published var apiKey: String

    @Published var useLocalModel: Bool {
        didSet { UserDefaults.standard.set(useLocalModel, forKey: "useLocalModel") }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    @Published var correctionCount: Int {
        didSet { UserDefaults.standard.set(correctionCount, forKey: "correctionCount") }
    }

    /// Whether the app is currently in trial mode (computed from LicenseManager).
    var isTrialMode: Bool {
        if case .trial = LicenseManager.shared.licenseState {
            return true
        }
        return false
    }

    static let defaultCustomPrompt = ""

    /// Bundled API key — XOR-obfuscated to avoid plain text in binary.
    /// See SETUP.md for instructions on encoding your own OpenRouter API key.
    private static let bundledApiKey: String = {
        let encoded: [UInt8] = [
            // Paste your XOR-0x5A encoded key here — see SETUP.md
        ]
        if encoded.isEmpty { return "" }
        return String(encoded.map { Character(UnicodeScalar($0 ^ 0x5A)) })
    }()

    private init() {
        let savedMode = UserDefaults.standard.string(forKey: "correctionMode") ?? CorrectionMode.correction.rawValue
        self.currentMode = CorrectionMode(rawValue: savedMode) ?? .correction
        self.pauseDelay = UserDefaults.standard.object(forKey: "pauseDelay") as? TimeInterval ?? 2.0
        self.isActive = UserDefaults.standard.object(forKey: "isActive") as? Bool ?? true
        self.minimumWordCount = UserDefaults.standard.object(forKey: "minimumWordCount") as? Int ?? 4
        self.customPrompt = UserDefaults.standard.string(forKey: "customPrompt") ?? Self.defaultCustomPrompt
        // API key: always use bundled XOR-decoded key — no Keychain needed
        self.apiKey = Self.bundledApiKey
        // Clean up any legacy Keychain/UserDefaults API key storage
        UserDefaults.standard.removeObject(forKey: "openRouterApiKey")
        self.correctionCount = UserDefaults.standard.integer(forKey: "correctionCount")
        self.useLocalModel = UserDefaults.standard.object(forKey: "useLocalModel") as? Bool ?? false
        self.hasCompletedOnboarding = UserDefaults.standard.object(forKey: "hasCompletedOnboarding") as? Bool ?? false
    }
}
