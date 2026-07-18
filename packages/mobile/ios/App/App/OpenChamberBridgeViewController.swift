import Capacitor

class OpenChamberBridgeViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(OpenChamberHapticsPlugin())
    }
}
