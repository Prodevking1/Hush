import Foundation
import Combine
import CryptoKit
import IOKit

/// Manages the full license lifecycle: trial, activation, validation, and enforcement.
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    // MARK: - Public State

    @Published var licenseState: LicenseState = .unknown

    enum LicenseState: Equatable {
        case unknown
        case valid
        case expired
        case trial(daysLeft: Int)
        case unlicensed
    }

    // MARK: - Configuration

    static let licenseServerURL = "https://api.tryhush.app"
    static let stripeCheckoutURL = "https://buy.stripe.com/14AaEW2M46j9dkb88HbEA03"

    private static let trialDurationDays = 7
    private static let gracePeriodDays = 7
    private static let onlineValidationIntervalHours: Double = 72

    // Ed25519 public key for local JWT verification (base64-encoded, placeholder)
    private static let ed25519PublicKeyBase64 = "jTGFYkzoQMNCttP8RGoJzvn8Vx19OtrK/eQWtwMPwzc="

    // Keychain keys
    private static let keychainJWT = "hush_license_jwt"
    private static let keychainInstallDate = "hush_install_date"
    private static let keychainLastOnlineValidation = "hush_last_online_validation"

    // MARK: - Computed Properties

    /// Quick check whether the app should allow full functionality.
    var isLicensed: Bool {
        // Recalculate hardware ID every time (anti-crack)
        switch licenseState {
        case .valid:
            return verifyStoredJWTHardwareId()
        case .trial(let daysLeft):
            return daysLeft > 0
        case .unknown, .expired, .unlicensed:
            return false
        }
    }

    /// Days remaining in trial, or nil if not in trial.
    var trialDaysLeft: Int? {
        if case .trial(let days) = licenseState {
            return days
        }
        return nil
    }

    // MARK: - Init

    private init() {
        ensureInstallDate()
    }

    // MARK: - Hardware ID

    /// Generates a SHA256 hash from IOPlatformSerialNumber + IOPlatformUUID via IOKit.
    /// Recalculated each time (not cached) as anti-crack measure.
    var hardwareId: String {
        let serial = platformProperty(key: kIOPlatformSerialNumberKey) ?? "unknown-serial"
        let uuid = platformProperty(key: kIOPlatformUUIDKey) ?? "unknown-uuid"
        let combined = "\(serial):\(uuid)"
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func platformProperty(key: String) -> String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }

        let value = IORegistryEntryCreateCFProperty(
            platformExpert,
            key as CFString,
            kCFAllocatorDefault,
            0
        )
        return value?.takeRetainedValue() as? String
    }

    // MARK: - Install Date (Trial)

    private func ensureInstallDate() {
        if KeychainHelper.readDate(key: Self.keychainInstallDate) == nil {
            KeychainHelper.saveDate(key: Self.keychainInstallDate, date: Date())
            Log.info("First launch — trial period started")
        }
    }

    private var installDate: Date {
        KeychainHelper.readDate(key: Self.keychainInstallDate) ?? Date()
    }

    private func computeTrialDaysLeft() -> Int {
        let elapsed = Date().timeIntervalSince(installDate)
        let elapsedDays = Int(elapsed / 86400)
        return max(0, Self.trialDurationDays - elapsedDays)
    }

    // MARK: - Activation

    /// Activate a license by sending hardware_id + session_id to the license server.
    /// On success, stores the JWT in Keychain.
    func activate(sessionId: String) async -> Bool {
        let hwId = hardwareId

        guard let url = URL(string: "\(Self.licenseServerURL)/activate") else {
            Log.error("Invalid license server URL")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: String] = [
            "hardware_id": hwId,
            "session_id": sessionId,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                Log.error("License activation: invalid response")
                return false
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? ""
                Log.error("License activation failed (\(httpResponse.statusCode)): \(errorBody.prefix(200))")
                return false
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let jwt = json["token"] as? String else {
                Log.error("License activation: missing token in response")
                return false
            }

            // Store JWT in Keychain
            KeychainHelper.saveString(key: Self.keychainJWT, value: jwt)
            KeychainHelper.saveDate(key: Self.keychainLastOnlineValidation, date: Date())

            await MainActor.run {
                self.licenseState = .valid
            }

            Log.success("License activated successfully")
            return true

        } catch {
            Log.error("License activation network error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Validation

    /// Validate the current license state.
    /// 1. Check for stored JWT and verify locally (signature + hardware_id match).
    /// 2. If >72h since last online validation, revalidate online.
    /// 3. Grace period: 7 days offline before blocking.
    /// 4. Fall back to trial if no JWT.
    func validate() {
        // Check for stored JWT
        guard let jwt = KeychainHelper.readString(key: Self.keychainJWT) else {
            // No JWT — check trial
            let daysLeft = computeTrialDaysLeft()
            if daysLeft > 0 {
                licenseState = .trial(daysLeft: daysLeft)
                Log.info("Trial mode: \(daysLeft) day(s) remaining")
            } else {
                licenseState = .unlicensed
                Log.warn("Trial expired — license required")
            }
            return
        }

        // Local JWT verification
        guard verifyJWTLocally(jwt) else {
            Log.warn("Local JWT verification failed")
            licenseState = .unlicensed
            return
        }

        // Check hardware_id in JWT payload matches current device
        guard verifyJWTHardwareId(jwt) else {
            Log.warn("Hardware ID mismatch — license not valid for this device")
            licenseState = .unlicensed
            return
        }

        // Check if online revalidation is needed
        let lastOnline = KeychainHelper.readDate(key: Self.keychainLastOnlineValidation)
        let hoursSinceLastValidation: Double
        if let lastOnline = lastOnline {
            hoursSinceLastValidation = Date().timeIntervalSince(lastOnline) / 3600
        } else {
            hoursSinceLastValidation = .infinity
        }

        if hoursSinceLastValidation > Self.onlineValidationIntervalHours {
            // Need online revalidation
            Task {
                let online = await validateOnline(jwt: jwt)
                await MainActor.run {
                    if online {
                        self.licenseState = .valid
                        KeychainHelper.saveDate(key: Self.keychainLastOnlineValidation, date: Date())
                        Log.success("Online license validation successful")
                    } else {
                        // Check grace period
                        let graceDays = self.gracePeriodDaysLeft(lastOnline: lastOnline)
                        if graceDays > 0 {
                            self.licenseState = .valid
                            Log.warn("Offline — grace period: \(graceDays) day(s) remaining")
                        } else {
                            self.licenseState = .expired
                            Log.error("Grace period expired — online validation required")
                        }
                    }
                }
            }

            // While waiting for online check, allow usage if within grace period
            let graceDays = gracePeriodDaysLeft(lastOnline: lastOnline)
            if graceDays > 0 {
                licenseState = .valid
            } else {
                licenseState = .expired
            }
        } else {
            // Recent online validation — license is valid
            licenseState = .valid
            Log.info("License valid (last online check: \(String(format: "%.0f", hoursSinceLastValidation))h ago)")
        }
    }

    /// Dispersed license check — call from multiple places (anti-crack).
    func quickCheck() -> Bool {
        let hwId = hardwareId  // Always recalculate
        guard let jwt = KeychainHelper.readString(key: Self.keychainJWT) else {
            return computeTrialDaysLeft() > 0
        }
        return verifyJWTLocally(jwt) && verifyJWTHardwareId(jwt)
    }

    // MARK: - Restore

    /// Attempt to restore a license for the current device by contacting the server.
    func restore() async -> Bool {
        let hwId = hardwareId

        guard let url = URL(string: "\(Self.licenseServerURL)/restore") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: String] = ["hardware_id": hwId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let jwt = json["token"] as? String else {
                Log.warn("License restore: no license found for this device")
                return false
            }

            KeychainHelper.saveString(key: Self.keychainJWT, value: jwt)
            KeychainHelper.saveDate(key: Self.keychainLastOnlineValidation, date: Date())

            await MainActor.run {
                self.licenseState = .valid
            }

            Log.success("License restored successfully")
            return true

        } catch {
            Log.error("License restore error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Online Validation

    private func validateOnline(jwt: String) async -> Bool {
        let hwId = hardwareId

        guard let url = URL(string: "\(Self.licenseServerURL)/validate") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let body: [String: String] = ["hardware_id": hwId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            Log.warn("Online validation failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - JWT Verification

    /// Verify JWT signature locally using embedded Ed25519 public key.
    /// JWT format: header.payload.signature (base64url encoded)
    private func verifyJWTLocally(_ jwt: String) -> Bool {
        let parts = jwt.split(separator: ".").map(String.init)
        guard parts.count == 3 else {
            Log.warn("Invalid JWT format")
            return false
        }

        // Decode public key
        guard let publicKeyData = Data(base64Encoded: Self.ed25519PublicKeyBase64) else {
            Log.warn("Invalid Ed25519 public key")
            return false
        }

        do {
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)

            // The signed data is "header.payload"
            let signedData = Data("\(parts[0]).\(parts[1])".utf8)

            // Decode signature from base64url
            guard let signatureData = base64URLDecode(parts[2]) else {
                Log.warn("Invalid JWT signature encoding")
                return false
            }

            return publicKey.isValidSignature(signatureData, for: signedData)

        } catch {
            Log.warn("Ed25519 verification error: \(error.localizedDescription)")
            return false
        }
    }

    /// Verify the hardware_id claim in the JWT payload matches the current device.
    private func verifyJWTHardwareId(_ jwt: String) -> Bool {
        guard let payload = decodeJWTPayload(jwt),
              let storedHwId = payload["hardware_id"] as? String else {
            return false
        }
        return storedHwId == hardwareId
    }

    /// Convenience: verify stored JWT hardware ID.
    private func verifyStoredJWTHardwareId() -> Bool {
        guard let jwt = KeychainHelper.readString(key: Self.keychainJWT) else {
            return false
        }
        return verifyJWTHardwareId(jwt)
    }

    /// Decode JWT payload (middle part) to a dictionary.
    private func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".").map(String.init)
        guard parts.count == 3 else { return nil }

        guard let payloadData = base64URLDecode(parts[1]) else { return nil }

        return try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
    }

    /// Decode base64url string to Data.
    private func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Pad to multiple of 4
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(contentsOf: String(repeating: "=", count: 4 - remainder))
        }

        return Data(base64Encoded: base64)
    }

    // MARK: - Grace Period

    private func gracePeriodDaysLeft(lastOnline: Date?) -> Int {
        guard let lastOnline = lastOnline else { return 0 }
        let elapsed = Date().timeIntervalSince(lastOnline)
        let elapsedDays = Int(elapsed / 86400)
        return max(0, Self.gracePeriodDays - elapsedDays)
    }

    // MARK: - License State Description

    var stateDescription: String {
        switch licenseState {
        case .unknown:
            return "Inconnu"
        case .valid:
            return "Active"
        case .expired:
            return "Expir\u{00e9}e — validation en ligne requise"
        case .trial(let daysLeft):
            return "Essai — \(daysLeft) jour\(daysLeft > 1 ? "s" : "") restant\(daysLeft > 1 ? "s" : "")"
        case .unlicensed:
            return "Non licenci\u{00e9}e"
        }
    }
}
