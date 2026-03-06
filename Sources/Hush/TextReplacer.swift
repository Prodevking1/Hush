import ApplicationServices
import Foundation

/// Replaces text in a focused AXUIElement field and supports undo via Cmd+Z.
final class TextReplacer {
    /// Stores the last original text for undo reference (logged only — real undo is Cmd+Z in app)
    private(set) var lastOriginalText: String?
    private(set) var lastCorrectedText: String?
    private(set) var lastFieldElement: AXUIElement?

    /// Replace the text in the given AXUIElement with new text.
    func replace(in element: AXUIElement, originalText: String, newText: String) -> Bool {
        // Don't replace if nothing changed
        if originalText == newText {
            Log.skip("Text unchanged — no replacement needed")
            return false
        }

        // Store for undo tracking
        lastOriginalText = originalText
        lastCorrectedText = newText
        lastFieldElement = element

        // Set the value via AXUIElement
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)

        if result == .success {
            Log.success("Text replaced successfully")
            Log.info("  Original: \"\(originalText.prefix(60))\(originalText.count > 60 ? "..." : "")\"")
            Log.info("  Replaced: \"\(newText.prefix(60))\(newText.count > 60 ? "..." : "")\"")
            return true
        } else {
            Log.error("Failed to replace text (AXError: \(result.rawValue))")

            // Fallback: use clipboard-based replacement
            return replaceViaClipboard(newText: newText)
        }
    }

    /// Fallback: select all → paste from clipboard
    private func replaceViaClipboard(newText: String) -> Bool {
        Log.step("Trying clipboard fallback (Cmd+A → Cmd+V)...")

        let pasteboard = NSPasteboard.general
        let oldClipboard = pasteboard.string(forType: .string)

        // Put new text on clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)

        // Cmd+A (select all)
        simulateKeyCombo(keyCode: 0x00, flags: .maskCommand) // 'a'
        usleep(50_000) // 50ms

        // Cmd+V (paste)
        simulateKeyCombo(keyCode: 0x09, flags: .maskCommand) // 'v'
        usleep(50_000)

        // Restore original clipboard
        if let old = oldClipboard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                pasteboard.clearContents()
                pasteboard.setString(old, forType: .string)
            }
        }

        Log.success("Clipboard fallback executed")
        return true
    }

    private func simulateKeyCombo(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDown.flags = flags
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUp.flags = flags
            keyUp.post(tap: .cghidEventTap)
        }
    }
}

// NSPasteboard needs AppKit
import AppKit
