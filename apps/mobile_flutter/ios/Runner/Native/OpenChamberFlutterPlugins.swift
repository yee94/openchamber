import Flutter
import UIKit
import Vision
import VisionKit
import AVFoundation
import Security
import WidgetKit

enum OpenChamberPluginRegistry {
  static func register(with registrar: FlutterPluginRegistrar, messenger: FlutterBinaryMessenger) {
    OpenChamberSecureStorePlugin.register(with: messenger)
    OpenChamberQrPlugin.register(with: messenger)
    OpenChamberLiveActivityPlugin.register(with: messenger)
    OpenChamberSharePlugin.register(with: messenger)
    OpenChamberDeepLinkPlugin.register(with: messenger)
    OpenChamberHapticsPlugin.register(with: messenger)
    OpenChamberPushPlugin.register(with: messenger)
    OpenChamberWidgetSnapshotPlugin.register(with: messenger)
    registrar.register(OpenChamberComposerFactory(messenger: messenger), withId: "openchamber/composer_view")
    registrar.register(OpenChamberTabBarFactory(messenger: messenger), withId: "openchamber/tab_bar_view")
  }
}

final class OpenChamberSecureStorePlugin: NSObject {
  static let service = "com.yee94.openchamber.secure"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "openchamber/secure_store", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any]
      let key = args?["key"] as? String ?? ""
      switch call.method {
      case "read":
        result(read(key))
      case "write":
        let value = args?["value"] as? String ?? ""
        do {
          try write(key, value)
          result(nil)
        } catch {
          result(FlutterError(code: "write_failed", message: "Secure write failed", details: nil))
        }
      case "delete":
        delete(key)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func read(_ key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func write(_ key: String, _ value: String) throws {
    delete(key)
    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let status = SecItemAdd(query as CFDictionary, nil)
    if status != errSecSuccess {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }

  private static func delete(_ key: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
  }
}

final class OpenChamberQrPlugin: NSObject {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "openchamber/qr_scanner", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "scan" else {
        result(FlutterMethodNotImplemented)
        return
      }
      Task { @MainActor in
        presentScanner(result: result)
      }
    }
  }

  @MainActor
  private static func presentScanner(result: @escaping FlutterResult) {
    guard let root = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController else {
      result(FlutterError(code: "no_window", message: "No window", details: nil))
      return
    }
    if #available(iOS 16.0, *), DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
      let scanner = DataScannerViewController(
        recognizedDataTypes: [.barcode(symbologies: [.qr])],
        qualityLevel: .balanced,
        recognizesMultipleItems: false,
        isHighFrameRateTrackingEnabled: false,
        isHighlightingEnabled: true
      )
      let coordinator = OpenChamberDataScanCoordinator(scanner: scanner, result: result)
      scanner.delegate = coordinator
      objc_setAssociatedObject(scanner, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
      root.present(scanner, animated: true) {
        Task { @MainActor in
          try? scanner.startScanning()
        }
      }
      return
    }
    result(FlutterError(code: "unavailable", message: "QR scanner unavailable", details: nil))
  }
}

@available(iOS 16.0, *)
@MainActor
final class OpenChamberDataScanCoordinator: NSObject, DataScannerViewControllerDelegate {
  private let scanner: DataScannerViewController
  private let result: FlutterResult
  private var finished = false

  init(scanner: DataScannerViewController, result: @escaping FlutterResult) {
    self.scanner = scanner
    self.result = result
  }

  func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
    guard case .barcode(let barcode) = item, let payload = barcode.payloadStringValue, !finished else { return }
    finished = true
    dataScanner.stopScanning()
    dataScanner.dismiss(animated: true) {
      self.result(payload)
    }
  }

  func dataScannerDidZoom(_ dataScanner: DataScannerViewController) {}
}

final class OpenChamberLiveActivityPlugin: NSObject {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "openchamber/live_activity", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      Task {
        do {
          switch call.method {
          case "start":
            let id = try await OpenChamberLiveActivityManager.start(request(from: args))
            result(id)
          case "update":
            try await OpenChamberLiveActivityManager.update(request(from: args))
            result(nil)
          case "end":
            try await OpenChamberLiveActivityManager.end(request(from: args))
            result(nil)
          case "supported":
            result(OpenChamberLiveActivityManager.isSupported())
          default:
            result(FlutterMethodNotImplemented)
          }
        } catch {
          result(FlutterError(code: "live_activity", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private static func request(from args: [String: Any]) -> OpenChamberLiveActivityRequest {
    OpenChamberLiveActivityRequest(
      sessionId: args["sessionId"] as? String ?? "",
      startedAt: args["startedAt"] as? Double,
      status: args["status"] as? String ?? "working",
      eventVersion: args["eventVersion"] as? Int ?? 0,
      updatedAt: args["updatedAt"] as? Double ?? Date().timeIntervalSince1970,
      endedAt: args["endedAt"] as? Double,
      dismissalSeconds: args["dismissalSeconds"] as? Double
    )
  }
}

final class OpenChamberSharePlugin: NSObject {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "openchamber/share", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "pending":
        let envelopes = (try? OpenChamberShareStore.pending()) ?? []
        result(envelopes.map { env in
          [
            "operationID": env.operationID,
            "serverInstanceID": env.serverInstanceID,
            "assistantID": env.assistantID,
            "text": env.text as Any,
          ]
        })
      case "updateCatalog":
        let entries = call.arguments as? [[String: Any]] ?? []
        do {
          try OpenChamberShareStore.updateCatalog(entries)
          result(nil)
        } catch {
          result(FlutterError(code: "catalog", message: error.localizedDescription, details: nil))
        }
      case "acknowledge":
        let id = (call.arguments as? [String: Any])?["operationID"] as? String ?? ""
        try? OpenChamberShareStore.acknowledge(id)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

final class OpenChamberDeepLinkPlugin: NSObject {
  static var pending: String?
  private static var channel: FlutterMethodChannel?

  static func register(with messenger: FlutterBinaryMessenger) {
    let next = FlutterMethodChannel(name: "openchamber/deep_link", binaryMessenger: messenger)
    channel = next
    next.setMethodCallHandler { call, result in
      if call.method == "takeInitial" {
        let value = pending
        pending = nil
        result(value)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    if let pending {
      next.invokeMethod("opened", arguments: pending)
    }
  }

  static func open(_ url: URL) {
    pending = url.absoluteString
    channel?.invokeMethod("opened", arguments: url.absoluteString)
  }
}

final class OpenChamberComposerFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    OpenChamberComposerPlatformView(frame: frame, viewId: viewId, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class OpenChamberComposerPlatformView: NSObject, FlutterPlatformView {
  private let viewRef: OpenChamberComposerView
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    viewRef = OpenChamberComposerView(frame: frame)
    channel = FlutterMethodChannel(name: "openchamber/composer_\(viewId)", binaryMessenger: messenger)
    super.init()
    viewRef.onSend = { [weak self] text in self?.channel.invokeMethod("send", arguments: text) }
    viewRef.onStop = { [weak self] in self?.channel.invokeMethod("stop", arguments: nil) }
    viewRef.onAttach = { [weak self] in self?.channel.invokeMethod("attach", arguments: nil) }
    viewRef.onText = { [weak self] text in self?.channel.invokeMethod("text", arguments: text) }
    viewRef.onOccupancy = { [weak self] height in self?.channel.invokeMethod("occupancy", arguments: height) }
    viewRef.onAutocomplete = { [weak self] text in self?.channel.invokeMethod("autocomplete", arguments: text) }
    channel.setMethodCallHandler { [weak self] call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "apply":
        self?.viewRef.apply(
          text: args["text"] as? String,
          placeholderText: args["placeholder"] as? String,
          canSend: args["canSend"] as? Bool ?? false,
          canAbort: args["canAbort"] as? Bool ?? false,
          attachments: args["attachments"] as? [String] ?? [],
          autocompleteRows: args["autocomplete"] as? [String] ?? [],
          visible: args["visible"] as? Bool ?? true
        )
        result(nil)
      case "warm":
        self?.viewRef.warm()
        result(nil)
      case "hide":
        self?.viewRef.hideImmediately()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { viewRef }
}

final class OpenChamberTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    OpenChamberTabBarPlatformView(frame: frame, viewId: viewId, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class OpenChamberTabBarPlatformView: NSObject, FlutterPlatformView {
  private let viewRef: OpenChamberTabBarView
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    viewRef = OpenChamberTabBarView(frame: frame)
    channel = FlutterMethodChannel(name: "openchamber/tab_bar_\(viewId)", binaryMessenger: messenger)
    super.init()
    viewRef.onSelect = { [weak self] id in self?.channel.invokeMethod("select", arguments: id) }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      if call.method == "apply" {
        let args = call.arguments as? [String: Any] ?? [:]
        let rawItems = args["items"] as? [[String: String]] ?? []
        let items = rawItems.compactMap { item -> (id: String, label: String, symbol: String)? in
          guard let id = item["id"], let label = item["label"], let symbol = item["symbol"] else { return nil }
          return (id, label, symbol)
        }
        self.viewRef.apply(items: items, selectedId: args["selectedId"] as? String ?? "projects")
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { viewRef }

  func attach(to parent: UIViewController) {
    viewRef.attach(to: parent)
  }
}

final class OpenChamberHapticsPlugin: NSObject {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "openchamber/haptics", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "impact" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let strength = (call.arguments as? [String: Any])?["strength"] as? String ?? "light"
      let style: UIImpactFeedbackGenerator.FeedbackStyle
      switch strength {
      case "medium": style = .medium
      case "heavy": style = .heavy
      default: style = .light
      }
      UIImpactFeedbackGenerator(style: style).impactOccurred()
      result(nil)
    }
  }
}

final class OpenChamberPushPlugin: NSObject {
  static var token: String?
  static var pending: FlutterResult?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "openchamber/push", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "requestToken" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if let token {
        result(["token": token, "platform": "ios"])
        return
      }
      pending = result
      Task { @MainActor in
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  static func didRegister(token: String) {
    self.token = token
    pending?(["token": token, "platform": "ios"])
    pending = nil
  }

  static func didFail() {
    pending?(nil)
    pending = nil
  }
}

final class OpenChamberWidgetSnapshotPlugin: NSObject {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "openchamber/widget_snapshot", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "write" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let json = call.arguments as? String ?? ""
      UserDefaults(suiteName: "group.com.yee94.openchamber")?.set(json, forKey: "widgetSnapshot")
      if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadAllTimelines()
      }
      result(nil)
    }
  }
}
