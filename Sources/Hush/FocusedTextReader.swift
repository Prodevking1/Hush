import ApplicationServices
import AppKit
import Foundation

/// Reads text from the currently focused text field using AXUIElement.
struct FocusedFieldInfo {
    let appName: String
    let appBundleID: String?
    let role: String
    let text: String
    let element: AXUIElement
}

enum FocusedTextReaderError: Error, CustomStringConvertible {
    case noFocusedApp
    case noFocusedElement
    case notATextField(role: String)
    case secureTextField
    case noTextValue
    case excludedApp(name: String)
    case textTooShort(wordCount: Int)
    case urlField

    var description: String {
        switch self {
        case .noFocusedApp: return "No focused application"
        case .noFocusedElement: return "No focused UI element"
        case .notATextField(let role): return "Not a text field (role: \(role))"
        case .secureTextField: return "Secure text field (password) — skipped"
        case .noTextValue: return "Element has no text value"
        case .excludedApp(let name): return "App '\(name)' is excluded"
        case .textTooShort(let count): return "Text too short (\(count) words, need ≥4)"
        case .urlField: return "URL/address bar field — skipped"
        }
    }
}

final class FocusedTextReader {
    /// Apps excluded by default (code editors, terminal, etc.)
    static let defaultExcludedBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.microsoft.VSCode",
        "com.jetbrains.intellij",
        "com.jetbrains.AppCode",
        "com.apple.dt.Xcode",
        "dev.warp.warp-stable",
        "com.github.Electron",  // Generic Electron fallback
    ]

    /// Roles that indicate a text input field
    static let textFieldRoles: Set<String> = [
        "AXTextField",
        "AXTextArea",
        "AXComboBox",
    ]

    /// Subroles that indicate URL bar
    static let urlSubroles: Set<String> = [
        "AXURLTextField",
        "AXSearchField",
    ]

    var excludedBundleIDs: Set<String>
    var minimumWordCount: Int

    init(excludedBundleIDs: Set<String> = FocusedTextReader.defaultExcludedBundleIDs, minimumWordCount: Int = 4) {
        self.excludedBundleIDs = excludedBundleIDs
        self.minimumWordCount = minimumWordCount
    }

    func read() -> Result<FocusedFieldInfo, FocusedTextReaderError> {
        // 1. Get the frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return .failure(.noFocusedApp)
        }

        let pid = frontApp.processIdentifier
        let appName = frontApp.localizedName ?? "Unknown"
        let bundleID = frontApp.bundleIdentifier

        Log.detect("Focused app: \(appName) (pid: \(pid), bundle: \(bundleID ?? "nil"))")

        // 2. Check if app is excluded
        if let bid = bundleID, excludedBundleIDs.contains(bid) {
            return .failure(.excludedApp(name: appName))
        }

        // 3. Get the focused UI element via AXUIElement
        let appElement = AXUIElementCreateApplication(pid)
        var focusedValue: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)

        guard focusResult == .success, let focused = focusedValue else {
            return .failure(.noFocusedElement)
        }

        let element = focused as! AXUIElement

        // 4. Get the role
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = (roleValue as? String) ?? "Unknown"

        Log.detect("Element role: \(role)")

        // 5. Check for secure text field (password)
        if role == "AXSecureTextField" {
            return .failure(.secureTextField)
        }

        // 6. Check it's a text field
        guard Self.textFieldRoles.contains(role) else {
            return .failure(.notATextField(role: role))
        }

        // 7. Check for URL subrole
        var subroleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleValue)
        if let subrole = subroleValue as? String {
            Log.detect("Element subrole: \(subrole)")
            if Self.urlSubroles.contains(subrole) {
                return .failure(.urlField)
            }
        }

        // 8. Read the text value
        var textValue: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textValue)

        guard textResult == .success, let text = textValue as? String, !text.isEmpty else {
            return .failure(.noTextValue)
        }

        // 9. Check minimum word count
        let wordCount = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        Log.detect("Text read: \(wordCount) words — \"\(text.prefix(80))\(text.count > 80 ? "..." : "")\"")

        if wordCount < minimumWordCount {
            return .failure(.textTooShort(wordCount: wordCount))
        }

        return .success(FocusedFieldInfo(
            appName: appName,
            appBundleID: bundleID,
            role: role,
            text: text,
            element: element
        ))
    }
}
