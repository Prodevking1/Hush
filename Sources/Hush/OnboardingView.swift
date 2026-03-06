import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var currentPage = 0
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var accessibilityTimer: Timer?
    var onComplete: () -> Void

    private let totalPages = 6
    private let pageLabels = ["Accueil", "Aperçu", "Vie privée", "Moteur", "Accessibilité", "Prêt"]

    var body: some View {
        VStack(spacing: 0) {
            // Stepper — numbered circles at top
            HStack(spacing: 0) {
                ForEach(0..<totalPages, id: \.self) { i in
                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(i <= currentPage ? Color.accentColor : Color.gray.opacity(0.18))
                                    .frame(width: 26, height: 26)
                                Text("\(i + 1)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(i <= currentPage ? .white : .gray)
                            }
                            Text(pageLabels[i])
                                .font(.system(size: 8, weight: i == currentPage ? .semibold : .regular))
                                .foregroundColor(i == currentPage ? .primary : .secondary)
                        }
                        if i < totalPages - 1 {
                            Rectangle()
                                .fill(i < currentPage ? Color.accentColor : Color.gray.opacity(0.18))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 16)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 8)

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                outcomePage.tag(1)
                privacyPage.tag(2)
                enginePage.tag(3)
                accessibilityPage.tag(4)
                setupPage.tag(5)
            }
            .tabViewStyle(.automatic)

            // Navigation bar
            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button("Retour") {
                        withAnimation(.easeInOut(duration: 0.25)) { currentPage -= 1 }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.gray)
                    .font(.callout)
                } else {
                    Spacer().frame(width: 50)
                }

                Spacer()

                if currentPage < totalPages - 1 {
                    Button("Suivant") {
                        withAnimation(.easeInOut(duration: 0.25)) { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    Button("Commencer l\u{2019}essai gratuit") {
                        if let url = URL(string: LicenseManager.stripeCheckoutURL) {
                            NSWorkspace.shared.open(url)
                        }
                        settings.hasCompletedOnboarding = true
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
        .frame(width: 560, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: currentPage) { newPage in
            if newPage == 4 {
                startAccessibilityPolling()
            } else {
                stopAccessibilityPolling()
            }
        }
        .onDisappear {
            stopAccessibilityPolling()
        }
    }

    // MARK: - Accessibility Polling

    private func startAccessibilityPolling() {
        accessibilityGranted = AXIsProcessTrusted()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let granted = AXIsProcessTrusted()
            DispatchQueue.main.async {
                accessibilityGranted = granted
            }
        }
    }

    private func stopAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Hush")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .padding(.bottom, 6)

            Text("Vous tapez. Hush perfectionne.")
                .font(.title3.weight(.medium))
                .foregroundColor(.gray)
                .padding(.bottom, 16)

            Text("7 jours d\u{2019}essai gratuit")
                .font(.subheadline.bold())
                .foregroundStyle(.blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(Color.blue.opacity(0.1))
                )
                .padding(.bottom, 24)

            Text("Fini les fautes embarrassantes dans vos emails,\nles tournures maladroites dans vos messages,\nles relectures qui cassent votre flow.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(5)
                .padding(.horizontal, 40)
                .padding(.bottom, 28)

            HStack(spacing: 20) {
                statPill(icon: "bolt.fill", value: "<1s", label: "par correction")
                statPill(icon: "globe", value: "FR & EN", label: "langues supportées")
                statPill(icon: "eye.slash.fill", value: "100%", label: "invisible")
            }

            // Coming soon teaser
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11))
                    .foregroundStyle(.purple)
                Text("Bientôt : Auto-complétion intelligente")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.purple)
                Text("— l\u{2019}IA devine et complète vos phrases")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.purple.opacity(0.08))
            )
            .padding(.top, 16)

            Spacer()
        }
        .padding(30)
    }

    // MARK: - Page 2: Outcome — Before/After

    private var outcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Le résultat, en un coup d\u{2019}oeil")
                .font(.title2.bold())
                .padding(.bottom, 6)

            Text("Français ou anglais, Hush détecte la langue et corrige.")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)

            VStack(spacing: 14) {
                beforeAfterRow(
                    lang: "FR",
                    before: "je vous envoi le document des que possible",
                    after: "Je vous envoie le document dès que possible."
                )
                beforeAfterRow(
                    lang: "EN",
                    before: "i wanted to inform you that the deployement is sheduled for wenesday",
                    after: "I wanted to inform you that the deployment is scheduled for Wednesday."
                )
                beforeAfterRow(
                    lang: "FR",
                    before: "merci bcp pr votre retour rapide c cool",
                    after: "Merci beaucoup pour votre retour rapide, c\u{2019}est super."
                )
            }

            // Auto-complete teaser
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10))
                        .foregroundStyle(.purple)
                    Text("Prochainement")
                        .font(.caption2.bold())
                        .foregroundStyle(.purple)
                }
                Text("Auto-complétion intelligente — l\u{2019}IA apprend vos habitudes\nd\u{2019}écriture et complète vos phrases en temps réel.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.purple.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.purple.opacity(0.15), lineWidth: 1)
            )
            .padding(.top, 14)

            Spacer()
        }
        .padding(30)
    }

    // MARK: - Page 3: Privacy

    private var privacyPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
                .padding(.bottom, 12)

            Text("Votre vie privée, notre priorité")
                .font(.title2.bold())
                .padding(.bottom, 6)

            Text("Hush lit vos champs de texte pour les corriger.\nVoici exactement ce qui se passe avec vos données.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(2)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 16) {
                privacyRow(
                    icon: "server.rack",
                    color: .blue,
                    title: "Vos textes transitent par les serveurs d\u{2019}OpenRouter",
                    detail: "En mode Cloud, OpenRouter achemine votre texte vers le modèle IA (Ministral 3B) via une connexion chiffrée HTTPS. Hush ne possède aucun serveur — nous ne voyons jamais vos données."
                )
                privacyRow(
                    icon: "xmark.bin.fill",
                    color: .green,
                    title: "Rien n\u{2019}est stocké, nulle part",
                    detail: "Ni par Hush, ni par OpenRouter. Votre texte est traité en mémoire puis immédiatement supprimé après correction."
                )
                privacyRow(
                    icon: "doc.on.clipboard.fill",
                    color: .orange,
                    title: "Filet de sécurité intégré",
                    detail: "L\u{2019}original est copié dans votre presse-papiers avant chaque correction. Cmd+V pour revenir en arrière."
                )
                privacyRow(
                    icon: "desktopcomputer",
                    color: .purple,
                    title: "Pour plus de confidentialité : le modèle local",
                    detail: "Téléchargez un modèle local et vos données ne quittent jamais votre Mac. Zéro connexion, zéro transit."
                )
            }

            Spacer()
        }
        .padding(30)
    }

    // MARK: - Page 4: Engine choice

    private var enginePage: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Choisissez votre moteur")
                .font(.title2.bold())
                .padding(.bottom, 6)

            Text("Deux approches, un même résultat impeccable.\nVous pourrez changer à tout moment.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(2)
                .padding(.bottom, 20)

            VStack(spacing: 12) {
                engineCard(
                    selected: !settings.useLocalModel,
                    icon: "bolt.fill",
                    title: "Cloud",
                    subtitle: "Correction en ~1 seconde",
                    detail: "Propulsé par Ministral 3B via OpenRouter. Ultra-rapide, fiable.",
                    badge: "Recommandé",
                    badgeColor: .blue
                ) {
                    settings.useLocalModel = false
                }

                engineCard(
                    selected: settings.useLocalModel,
                    icon: "desktopcomputer",
                    title: "Local",
                    subtitle: "Vos données restent sur votre Mac",
                    detail: "Idéal si la confidentialité absolue est votre priorité.",
                    badge: "Bientôt",
                    badgeColor: .orange
                ) {
                    settings.useLocalModel = true
                }
            }

            if settings.useLocalModel {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Le modèle local arrive dans une prochaine mise à jour. En attendant, le mode Cloud est disponible.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 12)
            }

            Spacer()
        }
        .padding(30)
    }

    // MARK: - Page 5: Accessibility

    private var accessibilityPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: accessibilityGranted ? "checkmark.shield.fill" : "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundStyle(accessibilityGranted ? .green : .orange)
                .padding(.bottom, 12)

            Text(accessibilityGranted ? "Accessibilité activée !" : "Hush a besoin de votre permission")
                .font(.title2.bold())
                .padding(.bottom, 6)

            Text("Pour lire et corriger vos textes automatiquement,\nHush utilise les fonctions d\u{2019}accessibilité de macOS.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(2)
                .padding(.bottom, 24)

            if !accessibilityGranted {
                // Step-by-step guide
                VStack(alignment: .leading, spacing: 14) {
                    accessibilityStep(number: "1", text: "Cliquez sur le bouton ci-dessous")
                    accessibilityStep(number: "2", text: "Dans la liste, trouvez Hush")
                    accessibilityStep(number: "3", text: "Activez le toggle à côté de Hush")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                Button(action: {
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                    AXIsProcessTrustedWithOptions(options)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                        Text("Ouvrir les réglages d\u{2019}accessibilité")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 12)

                Text("Hush détectera automatiquement l\u{2019}activation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Permission accordée")
                            .font(.headline)
                        Text("Hush peut maintenant lire et corriger vos textes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.green.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
            }

            Spacer()
        }
        .padding(30)
    }

    // MARK: - Page 6: Setup

    private var setupPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .padding(.bottom, 12)

            Text("Tout est prêt.")
                .font(.title2.bold())
                .padding(.bottom, 6)

            Text("Dans quelques secondes, chaque texte que vous\ntaperez sera automatiquement perfectionné.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(2)
                .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 10) {
                checklistRow(done: accessibilityGranted, text: "Accessibilité activée")
                checklistRow(done: true, text: "Français et anglais détectés automatiquement")
                checklistRow(done: true, text: "Moteur de correction configuré")
                checklistRow(done: true, text: "7 jours d\u{2019}essai gratuit inclus")
            }

            Spacer()
        }
        .padding(30)
    }

    // MARK: - Components

    private func statPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.blue)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(width: 120, height: 72)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }

    private func beforeAfterRow(lang: String, before: String, after: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                Text(lang)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(lang == "EN" ? Color.blue : Color.indigo))
                Text(before)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .strikethrough(true, color: .red.opacity(0.4))
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 9))
                    .foregroundColor(.green)
                    .frame(width: 22)
                Text(after)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }

    private func privacyRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .lineSpacing(1)
            }
        }
    }

    private func engineCard(selected: Bool, icon: String, title: String, subtitle: String, detail: String, badge: String, badgeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundColor(selected ? .blue : .gray)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(badge)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(badgeColor))
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? .blue : .gray.opacity(0.3))
                    .font(.title3)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.blue.opacity(0.06) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Color.blue.opacity(0.35) : Color.gray.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func accessibilityStep(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.orange))
            Text(text)
                .font(.callout)
        }
    }

    private func checklistRow(done: Bool, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(done ? .green : .gray.opacity(0.4))
                .font(.system(size: 14))
            Text(text)
                .font(.callout)
        }
    }
}

// MARK: - Window Controller

final class OnboardingWindowController {
    private var window: NSWindow?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = OnboardingView {
            self.window?.close()
        }
        let hostingView = NSHostingView(rootView: onboardingView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Bienvenue dans Hush"
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = newWindow
    }
}
