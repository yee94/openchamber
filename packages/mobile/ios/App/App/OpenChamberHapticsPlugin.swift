import Capacitor
import UIKit

@objc(OpenChamberHapticsPlugin)
class OpenChamberHapticsPlugin: CAPPlugin, CAPBridgedPlugin {
    let identifier = "OpenChamberHapticsPlugin"
    let jsName = "OpenChamberHaptics"
    let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "impactLight", returnType: CAPPluginReturnNone)
    ]

    private var impactGenerator: UIImpactFeedbackGenerator?

    @objc func impactLight(_ call: CAPPluginCall) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if self.impactGenerator == nil {
                self.impactGenerator = UIImpactFeedbackGenerator(style: .light)
                self.impactGenerator?.prepare()
            }

            self.impactGenerator?.impactOccurred()
            self.impactGenerator?.prepare()
        }
    }
}
