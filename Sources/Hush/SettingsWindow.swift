import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var licenseManager = LicenseManager.shared

    var body: some View {
        TabView {
            modesTab
                .tabItem {
                    Label("Modes", systemImage: "textformat")
                }

            parametresTab
                .tabItem {
                    Label("Paramètres", systemImage: "gear")
                }

            licenceTab
                .tabItem {
                    Label("Licence", systemImage: "key.fill")
                }
        }
        .frame(width: 500, height: 680)
    }

    // MARK: - Modes Tab

    private var modesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mode de correction")
                    .font(.title2.bold())

                Text("Choisissez comment Hush traite votre texte.")
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(CorrectionMode.allCases) { mode in
                        modeCard(mode)
                    }
                }

                if settings.currentMode == .custom {
                    customPromptEditor
                }
            }
            .padding(24)
        }
    }

    private func modeCard(_ mode: CorrectionMode) -> some View {
        Button {
            settings.currentMode = mode
        } label: {
            HStack(spacing: 14) {
                Text(mode.icon)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.label)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if settings.currentMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(settings.currentMode == mode ? Color.blue.opacity(0.08) : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(settings.currentMode == mode ? Color.blue.opacity(0.4) : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var customPromptEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Votre instruction personnalisée")
                    .font(.headline)
                Spacer()
                Button("Réinitialiser") {
                    settings.customPrompt = AppSettings.defaultCustomPrompt
                }
                .font(.caption)
                .buttonStyle(.link)
            }

            Text("Ce prompt sera envoyé au modèle IA comme instruction système.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: Binding(
                get: { settings.customPrompt },
                set: { settings.customPrompt = String($0.prefix(1000)) }
            ))
                .font(.system(.body, design: .monospaced))
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Text("\(settings.customPrompt.count)/1000 caractères")
                    .font(.caption2)
                    .foregroundColor(settings.customPrompt.count >= 1000 ? .red : .gray)
                if settings.customPrompt.count >= 1000 {
                    Text("— limite atteinte")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Licence Tab

    @State private var licenseActivating: Bool = false
    @State private var licenseMessage: String = ""

    private var licenceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Licence")
                    .font(.title2.bold())

                // Current state
                GroupBox("État de la licence") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            statusIcon
                            Text(licenseManager.stateDescription)
                                .font(.headline)
                        }

                        if case .trial(let daysLeft) = licenseManager.licenseState {
                            ProgressView(value: Double(7 - daysLeft), total: 7)
                                .tint(daysLeft <= 2 ? .red : .blue)
                            Text("\(daysLeft) jour\(daysLeft > 1 ? "s" : "") d'essai restant\(daysLeft > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }

                // Purchase button
                if licenseManager.licenseState != .valid {
                    GroupBox("Acheter Hush") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Hush — Licence à vie")
                                        .font(.headline)
                                    Text("24,99€ — Paiement unique, jusqu'à 3 appareils")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("7 jours d'essai gratuit inclus")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                                Spacer()
                                Button("Acheter Hush") {
                                    if let url = URL(string: LicenseManager.stripeCheckoutURL) {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(8)
                    }
                }

                // Restore
                GroupBox("Restaurer") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("D\u{00e9}j\u{00e0} achet\u{00e9} Hush sur cet appareil ?")
                            .font(.callout)

                        Button("Restaurer la licence") {
                            licenseActivating = true
                            licenseMessage = ""
                            Task {
                                let success = await licenseManager.restore()
                                await MainActor.run {
                                    licenseActivating = false
                                    licenseMessage = success
                                        ? "Licence restaur\u{00e9}e avec succ\u{00e8}s !"
                                        : "Aucune licence trouv\u{00e9}e pour cet appareil."
                                }
                            }
                        }
                        .disabled(licenseActivating)
                    }
                    .padding(8)
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch licenseManager.licenseState {
        case .valid:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
        case .trial:
            Image(systemName: "clock.fill")
                .foregroundStyle(.blue)
        case .expired:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .unlicensed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Paramètres Tab

    private var parametresTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Paramètres")
                    .font(.title2.bold())

                GroupBox("Moteur IA") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button {
                                settings.useLocalModel = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.useLocalModel ? "circle" : "checkmark.circle.fill")
                                        .foregroundColor(settings.useLocalModel ? .gray : .blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Cloud (OpenRouter)")
                                            .font(.headline)
                                        Text("Rapide, fiable, requiert une clé API")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                settings.useLocalModel = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.useLocalModel ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(settings.useLocalModel ? .blue : .gray)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Local")
                                            .font(.headline)
                                        Text("Privé, hors-ligne")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if settings.useLocalModel {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.orange)
                                Text("Le modèle local sera disponible prochainement.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(8)
                }

                GroupBox("Détection") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Délai de pause")
                            Spacer()
                            Picker("", selection: $settings.pauseDelay) {
                                Text("1s").tag(1.0 as TimeInterval)
                                Text("2s").tag(2.0 as TimeInterval)
                                Text("3s").tag(3.0 as TimeInterval)
                                Text("5s").tag(5.0 as TimeInterval)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }

                        HStack {
                            Text("Mots minimum")
                            Spacer()
                            Picker("", selection: $settings.minimumWordCount) {
                                Text("2").tag(2)
                                Text("3").tag(3)
                                Text("4").tag(4)
                                Text("6").tag(6)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Mode actif") {
                    HStack {
                        Text("\(settings.currentMode.icon) \(settings.currentMode.label)")
                            .font(.headline)
                        Spacer()
                        Text("Changez dans l'onglet Modes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }

                GroupBox("Traitement") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Mode")
                            Spacer()
                            Picker("", selection: $settings.useLocalModel) {
                                Text("Cloud").tag(false)
                                Text("Local").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }
                        HStack {
                            Text("Latence moyenne")
                            Spacer()
                            Text(settings.useLocalModel ? "Variable" : "~1.1s")
                                .foregroundStyle(.secondary)
                        }
                        if settings.useLocalModel {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.orange)
                                Text("Le mode local sera disponible prochainement.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(8)
                }

                GroupBox("Statistiques") {
                    HStack {
                        Text("Corrections cette session")
                        Spacer()
                        Text("\(settings.correctionCount)")
                            .font(.title3.bold())
                            .foregroundStyle(.blue)
                    }
                    .padding(8)
                }

                GroupBox("Contact") {
                    VStack(alignment: .leading, spacing: 10) {
                        contactRow(icon: "envelope.fill", text: "Support", subject: "Support Hush")
                        contactRow(icon: "lightbulb.fill", text: "Demande de fonctionnalit\u{00e9}", subject: "Demande de fonctionnalit\u{00e9} Hush")
                    }
                    .padding(8)
                }

                GroupBox("Confidentialit\u{00e9}") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(.green)
                            Text("Transparence sur vos donn\u{00e9}es")
                                .font(.headline)
                        }
                        Text("En mode Cloud, vos textes sont envoy\u{00e9}s via une connexion chiffr\u{00e9}e (HTTPS) aux serveurs d\u{2019}OpenRouter, qui les achemine vers le mod\u{00e8}le IA (Ministral 3B). Hush ne poss\u{00e8}de aucun serveur \u{2014} nous ne voyons jamais vos donn\u{00e9}es.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(5)
                        Text("Ni Hush, ni OpenRouter ne stockent vos textes. Ils sont trait\u{00e9}s en m\u{00e9}moire puis imm\u{00e9}diatement supprim\u{00e9}s apr\u{00e8}s la correction.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        Text("L\u{2019}original est toujours copi\u{00e9} dans votre presse-papiers avant chaque correction (Cmd+V pour r\u{00e9}cup\u{00e9}rer).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack(spacing: 4) {
                            Image(systemName: "desktopcomputer")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("Pour une confidentialit\u{00e9} absolue, activez le mod\u{00e8}le local : vos donn\u{00e9}es ne quittent jamais votre Mac.")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(8)
                }
            }
            .padding(24)
        }
    }

    private func contactRow(icon: String, text: String, subject: String) -> some View {
        Button {
            let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
            if let url = URL(string: "mailto:abdoul@appbiz.studio?subject=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                Text(text)
                    .font(.callout)
                Spacer()
                Text("abdoul@appbiz.studio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Controller to manage the settings window lifecycle.
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Hush — Paramètres"
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = newWindow
    }
}
