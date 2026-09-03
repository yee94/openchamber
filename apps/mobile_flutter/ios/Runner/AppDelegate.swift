import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "OpenChamberNative") {
      OpenChamberPluginRegistry.register(with: registrar, messenger: registrar.messenger())
    }
    if let url = launchOptions?[.url] as? URL {
      OpenChamberDeepLinkPlugin.pending = url.absoluteString
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    OpenChamberPushPlugin.didRegister(token: token)
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    OpenChamberPushPlugin.didFail()
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    OpenChamberDeepLinkPlugin.open(url)
    return true
  }
}
