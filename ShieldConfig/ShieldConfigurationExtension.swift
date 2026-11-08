import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Custom block screen shown when the user opens a locked app.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        unfoldShield(for: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        unfoldShield(for: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        unfoldShield(for: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        unfoldShield(for: webDomain.domain)
    }

    private func unfoldShield(for name: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            icon: UIImage(systemName: "rectangle.portrait.lefthalf.inset.filled"),
            title: .init(text: "Unfold to view", color: .label),
            subtitle: .init(text: "\(name ?? "This app") is locked while your iPhone is folded.", color: .secondaryLabel),
            primaryButtonLabel: .init(text: "OK", color: .white),
            primaryButtonBackgroundColor: .systemBlue
        )
    }
}
