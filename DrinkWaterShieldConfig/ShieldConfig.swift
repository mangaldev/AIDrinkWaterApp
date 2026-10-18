import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen shown in place of any blocked app.
class ShieldConfig: ShieldConfigurationDataSource {
    private var config: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.systemBlue.withAlphaComponent(0.3),
            icon: UIImage(systemName: "drop.fill"),
            title: ShieldConfiguration.Label(text: "Drink some water first", color: .white),
            subtitle: ShieldConfiguration.Label(text: "Open DrinkWater and show the camera you're drinking.", color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Open DrinkWater", color: .white),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration { config }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { config }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { config }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { config }
}
