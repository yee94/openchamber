import UIKit

/// Chrome-only `UITabBarController`. iOS 26 paints liquid glass + selected
/// lens only when a tab bar is owned by a tab controller. Flutter still owns
/// the four root pages. Older iOS uses the system translucent `UITabBar`.
final class OpenChamberTabBarView: UIView, UITabBarControllerDelegate {
  var onSelect: ((String) -> Void)?

  static var supportsLiquidGlass: Bool {
    if #available(iOS 26.0, *) { return true }
    return NSClassFromString("UIGlassEffect") != nil
  }

  static let dockHeight: CGFloat = 49

  let chrome = OpenChamberTabBarChromeController()
  private var items: [(id: String, label: String, symbol: String)] = []
  private var applying = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
    backgroundColor = .clear
    chrome.delegate = self
    chrome.tabBar.isTranslucent = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    chrome.tabBar.point(inside: convert(point, to: chrome.tabBar), with: event)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if let parent = parentViewController {
      attach(to: parent)
    }
  }

  private var parentViewController: UIViewController? {
    var responder: UIResponder? = self
    while let current = responder {
      if let controller = current as? UIViewController { return controller }
      responder = current.next
    }
    return nil
  }

  func attach(to parent: UIViewController) {
    guard chrome.parent !== parent else { return }
    parent.addChild(chrome)
    addSubview(chrome.view)
    chrome.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      chrome.view.topAnchor.constraint(equalTo: topAnchor),
      chrome.view.bottomAnchor.constraint(equalTo: bottomAnchor),
      chrome.view.leadingAnchor.constraint(equalTo: leadingAnchor),
      chrome.view.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
    chrome.didMove(toParent: parent)
  }

  func apply(items next: [(id: String, label: String, symbol: String)], selectedId: String) {
    applying = true
    if items.map(\.id) != next.map(\.id) || items.map(\.label) != next.map(\.label) {
      items = next
      chrome.viewControllers = next.map { item in
        let page = UIViewController()
        page.view.backgroundColor = .clear
        page.view.isUserInteractionEnabled = false
        page.tabBarItem = UITabBarItem(
          title: item.label,
          image: UIImage(systemName: item.symbol),
          selectedImage: UIImage(systemName: item.symbol)
        )
        page.tabBarItem.accessibilityIdentifier = item.id
        page.tabBarItem.accessibilityLabel = item.label
        return page
      }
    }
    if let match = chrome.viewControllers?.first(where: { $0.tabBarItem.accessibilityIdentifier == selectedId }) {
      chrome.selectedViewController = match
    }
    applying = false
  }

  func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
    guard !applying, let id = viewController.tabBarItem.accessibilityIdentifier else { return }
    onSelect?(id)
  }
}

final class OpenChamberTabBarChromeController: UITabBarController {
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    view.isOpaque = false
    for subview in view.subviews where subview !== tabBar {
      subview.backgroundColor = .clear
      subview.isOpaque = false
    }
  }
}
