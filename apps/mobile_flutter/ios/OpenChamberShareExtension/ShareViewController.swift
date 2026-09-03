import MobileCoreServices
import Social
import UIKit
import UniformTypeIdentifiers

/// Share extension for the Flutter host. Writes an inbox payload the Dart
/// share plugin consumes. Never silently substitutes a default assistant —
/// conversation extras are required to target a specific session.
final class ShareViewController: SLComposeServiceViewController {
  private var selectedConversationID: String?
  private var selectedConversationTitle: String?
  private var selectedDirectory: String?
  private var selectedRuntimeID: String?

  override func isContentValid() -> Bool {
    true
  }

  override func didSelectPost() {
    Task {
      await persistSharedItems()
      extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
  }

  override func configurationItems() -> [Any]! {
    let item = SLComposeSheetConfigurationItem()
    item?.title = "OpenChamber"
    item?.value = selectedConversationTitle ?? "Choose a chat"
    item?.tapHandler = { [weak self] in
      self?.presentConversationPicker()
    }
    return [item as Any]
  }

  private func presentConversationPicker() {
    let alert = UIAlertController(
      title: "Choose a chat",
      message: "Sharing requires an exact instance + assistant. OpenChamber will not pick a default.",
      preferredStyle: .actionSheet
    )
    let conversations = OpenChamberShareStore.loadConversations()
    if conversations.isEmpty {
      alert.message = "No saved chats yet. Open the app, connect an instance, then share again."
    }
    for conversation in conversations {
      alert.addAction(
        UIAlertAction(title: conversation.title, style: .default) { [weak self] _ in
          self?.selectedConversationID = conversation.id
          self?.selectedConversationTitle = conversation.title
          self?.selectedDirectory = conversation.directory
          self?.selectedRuntimeID = conversation.runtimeID
          self?.reloadConfigurationItems()
        }
      )
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
  }

  private func persistSharedItems() async {
    guard let conversationID = selectedConversationID, !conversationID.isEmpty else {
      return
    }
    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    var texts: [String] = []
    var urls: [String] = []
    if let contentText, !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      texts.append(contentText)
    }
    for item in items {
      for provider in item.attachments ?? [] {
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL
        {
          urls.append(url.absoluteString)
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                  let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String
        {
          texts.append(text)
        }
      }
    }
    OpenChamberShareStore.writeInbox(
      conversationID: conversationID,
      directory: selectedDirectory,
      runtimeID: selectedRuntimeID,
      texts: texts,
      urls: urls
    )
    if let url = URL(string: "openchamber://share-inbox") {
      var responder: UIResponder? = self
      while let current = responder {
        if let application = current as? UIApplication {
          application.open(url)
          break
        }
        responder = current.next
      }
    }
  }
}
