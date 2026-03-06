import SwiftUI

struct PaywallView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
               let iconImage = NSImage(contentsOf: iconURL) {
                Image(nsImage: iconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(18)
                    .padding(.bottom, 24)
            }

            Text("Votre essai est termin\u{00e9}")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.bottom, 8)

            Text("Continuez \u{00e0} \u{00e9}crire sans fautes avec Hush.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            // Price card
            VStack(spacing: 12) {
                Text("24,99\u{20ac}")
                    .font(.system(size: 48, weight: .bold, design: .rounded))

                Text("Paiement unique \u{2014} licence \u{00e0} vie")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Fran\u{00e7}ais & anglais", systemImage: "checkmark.circle.fill")
                    Label("Fonctionne dans toutes vos apps", systemImage: "checkmark.circle.fill")
                    Label("Jusqu\u{2019}\u{00e0} 3 Mac", systemImage: "checkmark.circle.fill")
                    Label("Mises \u{00e0} jour incluses", systemImage: "checkmark.circle.fill")
                }
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .padding(.bottom, 28)

            // Buy button
            Button(action: {
                if let url = URL(string: LicenseManager.stripeCheckoutURL) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("Acheter Hush")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 12)

            // Guarantee
            HStack(spacing: 6) {
                Image(systemName: "shield.checkered")
                    .font(.caption)
                Text("Garantie satisfait ou rembours\u{00e9} 30 jours")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            Spacer()

            // Restore
            Button("D\u{00e9}j\u{00e0} achet\u{00e9} ? Restaurer la licence") {
                Task {
                    isLoading = true
                    let _ = await licenseManager.restore()
                    isLoading = false
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(.blue)
            .buttonStyle(.plain)
            .disabled(isLoading)
            .padding(.bottom, 24)
        }
        .frame(width: 420, height: 580)
        .padding(24)
    }
}

// MARK: - Paywall Window Controller

final class PaywallWindowController {
    private var window: NSWindow?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = PaywallView()
        let hostingView = NSHostingView(rootView: view)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Hush \u{2014} Activez votre licence"
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.level = .floating

        NSApp.activate(ignoringOtherApps: true)
        self.window = newWindow
    }

    func dismiss() {
        window?.close()
        window = nil
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }
}
