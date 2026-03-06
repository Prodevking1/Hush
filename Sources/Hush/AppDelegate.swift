import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var keystrokeMonitor: KeystrokeMonitor?
    private let focusedTextReader = FocusedTextReader()
    private let textReplacer = TextReplacer()
    private let correctionEngine = CorrectionEngine()
    private let settingsController = SettingsWindowController()
    private let onboardingController = OnboardingWindowController()
    private let paywallController = PaywallWindowController()
    private let settings = AppSettings.shared
    private let licenseManager = LicenseManager.shared

    private var isProcessing = false
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("========================================")
        Log.info("  Hush starting up")
        Log.info("  Mode: \(settings.currentMode.icon) \(settings.currentMode.label)")
        Log.info("  Clipboard backup: enabled")
        Log.info("========================================")

        // Register URL scheme handler for hush:// deep links
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURL(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        // Register as default handler for hush:// URL scheme (programmatic, for SPM builds)
        if let bundleId = Bundle.main.bundleIdentifier {
            LSSetDefaultHandlerForURLScheme("hush" as CFString, bundleId as CFString)
        }

        // Validate license on launch
        licenseManager.validate()
        Log.info("  License: \(licenseManager.stateDescription)")

        // Set app icon from bundled resource
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }

        observeSettings()

        if !settings.hasCompletedOnboarding {
            // Show onboarding first — menu bar and monitoring start after onboarding completes
            onboardingController.show()
        } else {
            setupMenuBar()
            startAfterOnboarding()
        }
    }

    // MARK: - URL Scheme Handler

    @objc private func handleURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "hush",
              url.host == "activate",
              let sessionId = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "session_id" })?.value
        else { return }

        Task {
            let success = await LicenseManager.shared.activate(sessionId: sessionId)
            await MainActor.run {
                if success {
                    Log.success("License activated via deep link!")
                    paywallController.dismiss()
                }
            }
        }
    }

    // MARK: - Paywall

    private func showPaywall() {
        paywallController.show()
    }

    // MARK: - Post-Onboarding Start

    func startAfterOnboarding() {
        // Ensure menu bar is set up (first time after onboarding)
        if statusItem == nil {
            setupMenuBar()
        }
        switch licenseManager.licenseState {
        case .valid, .trial:
            startMonitoring()
        case .expired, .unlicensed:
            showPaywall()
        case .unknown:
            licenseManager.validate()
            if licenseManager.isLicensed {
                startMonitoring()
            } else {
                showPaywall()
            }
        }
    }

    // MARK: - Settings Observation

    private func observeSettings() {
        settings.$currentMode
            .dropFirst()
            .sink { [weak self] mode in
                Log.info("Mode changed to: \(mode.icon) \(mode.label)")
                self?.updateMenuBarIcon()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        settings.$pauseDelay
            .dropFirst()
            .sink { [weak self] delay in
                self?.keystrokeMonitor?.updatePauseDelay(delay)
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        settings.$isActive
            .dropFirst()
            .sink { [weak self] active in
                self?.keystrokeMonitor?.isPaused = !active
                Log.info(active ? "Resumed — monitoring keystrokes" : "Paused — corrections disabled")
                self?.updateMenuBarIcon()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        settings.$minimumWordCount
            .dropFirst()
            .sink { [weak self] count in
                self?.focusedTextReader.minimumWordCount = count
                Log.info("Minimum word count changed to \(count)")
            }
            .store(in: &cancellables)

        // Start monitoring after onboarding completes
        settings.$hasCompletedOnboarding
            .dropFirst()
            .filter { $0 == true }
            .sink { [weak self] _ in
                self?.startAfterOnboarding()
            }
            .store(in: &cancellables)

        // Observe license state changes to show/dismiss paywall
        licenseManager.$licenseState
            .dropFirst()
            .sink { [weak self] state in
                switch state {
                case .valid:
                    self?.paywallController.dismiss()
                    self?.startMonitoring()
                case .trial:
                    break // Continue normally
                case .expired, .unlicensed:
                    self?.keystrokeMonitor?.stop()
                    self?.showPaywall()
                case .unknown:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarIcon()
        rebuildMenu()
    }

    private func updateMenuBarIcon() {
        if let button = statusItem.button {
            button.title = settings.isActive ? settings.currentMode.icon : "\u{23f8}"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // Status line
        let status = settings.isActive
            ? "\(settings.currentMode.icon) \(settings.currentMode.label)"
            : "\u{23f8} En pause"
        let statusItem = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle
        let toggleItem = NSMenuItem(
            title: settings.isActive ? "Pause" : "Reprendre",
            action: #selector(toggleActive),
            keyEquivalent: "p"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Count
        let countItem = NSMenuItem(title: "Corrections: \(settings.correctionCount)", action: nil, keyEquivalent: "")
        countItem.isEnabled = false
        menu.addItem(countItem)

        menu.addItem(NSMenuItem.separator())

        // Licence
        let licenseTitle: String
        switch licenseManager.licenseState {
        case .valid:
            licenseTitle = "Licence: Active"
        case .trial(let daysLeft):
            licenseTitle = "Essai: \(daysLeft) jour\(daysLeft > 1 ? "s" : "") restant\(daysLeft > 1 ? "s" : "")"
        case .expired:
            licenseTitle = "Licence: Expir\u{00e9}e"
        case .unlicensed:
            licenseTitle = "Licence: Non activ\u{00e9}e"
        case .unknown:
            licenseTitle = "Licence: V\u{00e9}rification..."
        }

        let licenseItem = NSMenuItem(
            title: licenseTitle,
            action: #selector(openSettings),
            keyEquivalent: "l"
        )
        licenseItem.target = self
        menu.addItem(licenseItem)

        menu.addItem(NSMenuItem.separator())

        // Param\u{00e8}tres
        let paramItem = NSMenuItem(
            title: "Param\u{00e8}tres...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        paramItem.target = self
        menu.addItem(paramItem)

        // Quit
        menu.addItem(NSMenuItem(title: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        self.statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleActive() {
        settings.isActive.toggle()
    }

    @objc private func openSettings() {
        settingsController.show()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Don't start if already running
        if keystrokeMonitor != nil { return }

        if !AXIsProcessTrusted() {
            Log.warn("Accessibility permission not granted — requesting...")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }

        keystrokeMonitor = KeystrokeMonitor(pauseDelay: settings.pauseDelay) { [weak self] in
            self?.onTypingPauseDetected()
        }

        if keystrokeMonitor?.start() == true {
            Log.success("Ready — type anywhere and pause for \(settings.pauseDelay)s")
        } else {
            Log.error("Failed to start — grant Accessibility permission and restart")
        }
    }

    // MARK: - Correction Pipeline

    private func onTypingPauseDetected() {
        guard !isProcessing else {
            Log.skip("Already processing — skipping")
            return
        }
        isProcessing = true

        let mode = settings.currentMode

        Log.info("\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}")
        Log.step("PAUSE DETECTED — mode: \(mode.icon) \(mode.label)")

        Log.step("Step 1/3: Reading focused text field...")
        let readResult = focusedTextReader.read()

        switch readResult {
        case .failure(let error):
            Log.skip("Pipeline aborted: \(error)")
            isProcessing = false
            return

        case .success(let fieldInfo):
            Log.success("Read text from \(fieldInfo.appName) [\(fieldInfo.role)]")

            // Backup original text to clipboard before AI processing
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(fieldInfo.text, forType: .string)
            Log.info("Original text copied to clipboard as backup")

            Log.step("Step 2/3: Sending to \(mode.label) engine...")

            Task {
                let corrected = await correctionEngine.correct(text: fieldInfo.text, mode: mode)

                await MainActor.run {
                    Log.step("Step 3/3: Replacing text in field...")

                    let replaced = textReplacer.replace(
                        in: fieldInfo.element,
                        originalText: fieldInfo.text,
                        newText: corrected
                    )

                    if replaced {
                        settings.correctionCount += 1
                        Log.success("Correction #\(settings.correctionCount) complete! [\(mode.icon) \(mode.shortLabel)]")
                    }

                    Log.info("\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}")
                    isProcessing = false
                }
            }
        }
    }
}
