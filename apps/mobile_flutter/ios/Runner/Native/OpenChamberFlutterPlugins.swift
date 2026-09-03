import Flutter
import UIKit
import Vision
import VisionKit
import AVFoundation
import Security
import WidgetKit
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

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
    OpenChamberMediaPlugin.register(with: messenger)
    OpenChamberVirtualAssetPlugin.register(with: messenger)
    OpenChamberExternalBrowserPlugin.register(with: messenger)
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
    viewRef.onDictate = { [weak self] in self?.channel.invokeMethod("dictate", arguments: nil) }
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
      if call.method == "setBadge" {
        let args = call.arguments as? [String: Any]
        let count = args?["count"] as? Int ?? 0
        Task { @MainActor in
          UIApplication.shared.applicationIconBadgeNumber = count
          result(nil)
        }
        return
      }
      guard call.method == "write" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let json = call.arguments as? String ?? ""
      UserDefaults(suiteName: "group.com.yee94.openchamber")?.set(json, forKey: "widgetSnapshot")
      if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadAllTimelines()
      }
      if let data = json.data(using: .utf8),
         let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let count = object["attentionCount"] as? Int {
        Task { @MainActor in
          UIApplication.shared.applicationIconBadgeNumber = count
        }
      }
      result(nil)
    }
  }
}

final class OpenChamberMediaPlugin: NSObject {
  static let maxBytes = 32 * 1024 * 1024
  static var pending: FlutterResult?
  static var coordinator: OpenChamberPhotoPickerCoordinator?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "openchamber/media", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "pickMedia":
        let limit = (call.arguments as? [String: Any])?["limit"] as? Int ?? 8
        Task { @MainActor in
          presentPicker(limit: max(1, min(limit, 100)), result: result)
        }
      case "transcode":
        let args = call.arguments as? [String: Any] ?? [:]
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let jpeg = try transcodeHeic(
              dataBase64: args["data"] as? String ?? "",
              mime: (args["mime"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              quality: args["quality"] as? Double ?? 0.9
            )
            result(["data": jpeg.base64EncodedString(), "mime": "image/jpeg"])
          } catch {
            result(FlutterError(code: "transcode", message: error.localizedDescription, details: nil))
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @MainActor
  private static func presentPicker(limit: Int, result: @escaping FlutterResult) {
    guard let root = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController else {
      result(FlutterError(code: "no_window", message: "No window", details: nil))
      return
    }
    var config = PHPickerConfiguration()
    config.selectionLimit = limit
    config.filter = .images
    let picker = PHPickerViewController(configuration: config)
    let host = OpenChamberPhotoPickerCoordinator { files in
      pending = nil
      coordinator = nil
      result(["cancelled": files.isEmpty, "files": files])
    }
    pending = result
    coordinator = host
    picker.delegate = host
    root.present(picker, animated: true)
  }

  private static func transcodeHeic(dataBase64: String, mime: String, quality: Double) throws -> Data {
    guard mime == "image/heic" || mime == "image/heif" else {
      throw OpenChamberMediaError.unsupportedMime
    }
    var payload = dataBase64
    if payload.lowercased().hasPrefix("data:"), let comma = payload.firstIndex(of: ",") {
      payload = String(payload[payload.index(after: comma)...])
    }
    guard let input = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters]), !input.isEmpty else {
      throw OpenChamberMediaError.invalidBase64
    }
    guard input.count <= maxBytes else { throw OpenChamberMediaError.tooLarge }
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(input as CFData, options) else {
      throw OpenChamberMediaError.decodeFailed
    }
    guard let uti = CGImageSourceGetType(source) as String? else {
      throw OpenChamberMediaError.notAnImage
    }
    let isHeif = UTType(uti)?.conforms(to: .heif) == true
      || uti.caseInsensitiveCompare(UTType.heic.identifier) == .orderedSame
      || uti.caseInsensitiveCompare("public.heif") == .orderedSame
    guard isHeif else { throw OpenChamberMediaError.notHeic }
    guard let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
      throw OpenChamberMediaError.decodeFailed
    }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
      throw OpenChamberMediaError.encodeFailed
    }
    let clamped = min(max(quality.isNaN || quality.isInfinite ? 0.9 : quality, 0.0), 1.0)
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: clamped] as CFDictionary)
    guard CGImageDestinationFinalize(destination), output.length > 0 else {
      throw OpenChamberMediaError.encodeFailed
    }
    return output as Data
  }
}

enum OpenChamberMediaError: LocalizedError {
  case unsupportedMime, invalidBase64, tooLarge, notAnImage, notHeic, decodeFailed, encodeFailed
  var errorDescription: String? {
    switch self {
    case .unsupportedMime: return "Unsupported image type"
    case .invalidBase64: return "Image data is empty or invalid base64"
    case .tooLarge: return "Image exceeds maximum size"
    case .notAnImage: return "Input is not a decodable image"
    case .notHeic: return "Input is not HEIC/HEIF"
    case .decodeFailed: return "Could not decode HEIC/HEIF image"
    case .encodeFailed: return "Could not encode JPEG"
    }
  }
}

@MainActor
final class OpenChamberPhotoPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
  private let finish: ([[String: Any]]) -> Void

  init(finish: @escaping ([[String: Any]]) -> Void) {
    self.finish = finish
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    if results.isEmpty {
      finish([])
      return
    }
    Task.detached {
      var files: [[String: Any]] = []
      for result in results {
        guard result.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { continue }
        let data = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
          result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { bytes, _ in
            continuation.resume(returning: bytes)
          }
        }
        guard let data, !data.isEmpty, data.count <= OpenChamberMediaPlugin.maxBytes else { continue }
        let name = result.itemProvider.suggestedName ?? "image.jpg"
        let mime = Self.mime(for: result.itemProvider)
        files.append([
          "name": name.contains(".") ? name : "\(name).jpg",
          "mimeType": mime,
          "size": data.count,
          "dataBase64": data.base64EncodedString(),
        ])
      }
      await MainActor.run {
        self.finish(files)
      }
    }
  }

  nonisolated private static func mime(for provider: NSItemProvider) -> String {
    if provider.hasItemConformingToTypeIdentifier(UTType.heic.identifier) { return "image/heic" }
    if provider.hasItemConformingToTypeIdentifier("public.heif") { return "image/heif" }
    if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) { return "image/png" }
    return "image/jpeg"
  }
}

final class OpenChamberVirtualAssetPlugin: NSObject {
  private static let lock = NSLock()
  private static var assets: [String: Data] = [:]

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "openchamber/virtual_asset", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      let assetId = args["assetId"] as? String ?? ""
      switch call.method {
      case "create":
        guard assetId.range(of: "^[A-Za-z0-9_-]{8,80}$", options: .regularExpression) != nil else {
          result(FlutterError(code: "invalid_id", message: "Invalid assetId", details: nil))
          return
        }
        lock.lock()
        assets[assetId] = Data()
        lock.unlock()
        result(["assetId": assetId, "url": "openchamber-asset://v/\(assetId)"])
      case "append":
        let chunk = args["chunk"] as? String ?? ""
        guard let data = Data(base64Encoded: chunk, options: [.ignoreUnknownCharacters]) else {
          result(FlutterError(code: "invalid_chunk", message: "Invalid chunk", details: nil))
          return
        }
        lock.lock()
        if var current = assets[assetId] {
          current.append(data)
          assets[assetId] = current
          lock.unlock()
          result(nil)
        } else {
          lock.unlock()
          result(FlutterError(code: "unknown", message: "Unknown asset", details: nil))
        }
      case "finish":
        result(nil)
      case "cancel":
        lock.lock()
        assets.removeValue(forKey: assetId)
        lock.unlock()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Official Capacitor name is OpenChamberExternalBrowser (`open` + http(s) URL).
final class OpenChamberExternalBrowserPlugin: NSObject {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "openchamber/external_browser", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "open" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let raw = ((call.arguments as? [String: Any])?["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard let url = URL(string: raw),
            let scheme = url.scheme?.lowercased(),
            (scheme == "http" || scheme == "https"),
            url.host != nil
      else {
        result(FlutterError(code: "invalid_url", message: "An http(s) URL is required.", details: nil))
        return
      }
      Task { @MainActor in
        UIApplication.shared.open(url, options: [:]) { opened in
          if opened {
            result(nil)
          } else {
            result(FlutterError(code: "unavailable", message: "The browser is unavailable.", details: nil))
          }
        }
      }
    }
  }
}
