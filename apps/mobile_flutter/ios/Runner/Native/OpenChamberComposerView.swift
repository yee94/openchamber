import UIKit

/// Always-on UIKit composer. iOS 26 uses `UIGlassEffect`; older iOS uses
/// system material blur — not a fake glass clone.
/// Occupancy reported to Flutter is the collapsed pill height only.
final class OpenChamberComposerView: UIView, UITextViewDelegate {
  static let collapsedOccupancy: CGFloat = 56

  var onSend: ((String) -> Void)?
  var onStop: (() -> Void)?
  var onAttach: (() -> Void)?
  var onText: ((String) -> Void)?
  var onOccupancy: ((CGFloat) -> Void)?
  var onAutocomplete: ((String) -> Void)?

  private let card = OpenChamberGlassBackdrop()
  private let textView = UITextView()
  private let placeholder = UILabel()
  private let attachButton = UIButton(type: .system)
  private let sendButton = UIButton(type: .system)
  private let attachmentStrip = UIScrollView()
  private let attachmentStack = UIStackView()
  private let autocomplete = OpenChamberComposerAutocomplete()
  private var canAbort = false
  private var attachments: [String] = []
  private var lastOccupancy: CGFloat = -1

  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
    backgroundColor = .clear
    build()
    applyCollapsed()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func apply(
    text: String?,
    placeholderText: String?,
    canSend: Bool,
    canAbort nextAbort: Bool,
    attachments nextAttachments: [String],
    autocompleteRows: [String],
    visible: Bool
  ) {
    isHidden = !visible
    if let text, textView.text != text, textView.markedTextRange == nil {
      textView.text = text
    }
    if let placeholderText { placeholder.text = placeholderText }
    canAbort = nextAbort
    attachments = nextAttachments
    refreshAttachments()
    autocomplete.apply(rows: autocompleteRows)
    sendButton.setImage(UIImage(systemName: nextAbort ? "stop.fill" : "arrow.up"), for: .normal)
    sendButton.isEnabled = nextAbort || canSend || !(textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    placeholder.isHidden = !(textView.text ?? "").isEmpty
    emitOccupancy()
  }

  func warm() {
    isHidden = false
    applyCollapsed()
    emitOccupancy()
  }

  func hideImmediately() {
    textView.resignFirstResponder()
    isHidden = true
    lastOccupancy = -1
    onOccupancy?(0)
  }

  private func build() {
    addSubview(card)
    card.translatesAutoresizingMaskIntoConstraints = false
    attachButton.setImage(UIImage(systemName: "plus"), for: .normal)
    attachButton.accessibilityIdentifier = "composer-attach"
    attachButton.addTarget(self, action: #selector(attachTapped), for: .touchUpInside)
    sendButton.setImage(UIImage(systemName: "arrow.up"), for: .normal)
    sendButton.accessibilityIdentifier = "composer-send"
    sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    textView.delegate = self
    textView.backgroundColor = .clear
    textView.font = .preferredFont(forTextStyle: .body)
    textView.accessibilityIdentifier = "composer-field"
    placeholder.font = .preferredFont(forTextStyle: .body)
    placeholder.textColor = .secondaryLabel
    placeholder.isUserInteractionEnabled = false
    attachmentStack.axis = .horizontal
    attachmentStack.spacing = 8
    attachmentStrip.showsHorizontalScrollIndicator = false
    attachmentStrip.addSubview(attachmentStack)
    attachmentStack.translatesAutoresizingMaskIntoConstraints = false
    card.contentView.addSubview(attachmentStrip)
    card.contentView.addSubview(attachButton)
    card.contentView.addSubview(textView)
    card.contentView.addSubview(placeholder)
    card.contentView.addSubview(sendButton)
    addSubview(autocomplete)
    autocomplete.translatesAutoresizingMaskIntoConstraints = false
    attachButton.translatesAutoresizingMaskIntoConstraints = false
    sendButton.translatesAutoresizingMaskIntoConstraints = false
    textView.translatesAutoresizingMaskIntoConstraints = false
    placeholder.translatesAutoresizingMaskIntoConstraints = false
    attachmentStrip.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
      card.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8),
      card.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.collapsedOccupancy),
      attachButton.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 10),
      attachButton.centerYAnchor.constraint(equalTo: card.contentView.centerYAnchor),
      attachButton.widthAnchor.constraint(equalToConstant: 36),
      attachButton.heightAnchor.constraint(equalToConstant: 36),
      sendButton.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -10),
      sendButton.centerYAnchor.constraint(equalTo: card.contentView.centerYAnchor),
      sendButton.widthAnchor.constraint(equalToConstant: 36),
      sendButton.heightAnchor.constraint(equalToConstant: 36),
      attachmentStrip.leadingAnchor.constraint(equalTo: attachButton.trailingAnchor, constant: 8),
      attachmentStrip.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
      attachmentStrip.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 6),
      attachmentStrip.heightAnchor.constraint(equalToConstant: 0),
      textView.leadingAnchor.constraint(equalTo: attachButton.trailingAnchor, constant: 8),
      textView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
      textView.topAnchor.constraint(equalTo: attachmentStrip.bottomAnchor, constant: 2),
      textView.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -6),
      placeholder.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 4),
      placeholder.centerYAnchor.constraint(equalTo: textView.centerYAnchor),
      autocomplete.leadingAnchor.constraint(equalTo: card.leadingAnchor),
      autocomplete.trailingAnchor.constraint(equalTo: card.trailingAnchor),
      autocomplete.bottomAnchor.constraint(equalTo: card.topAnchor, constant: -8),
      autocomplete.heightAnchor.constraint(lessThanOrEqualToConstant: 180),
    ])
  }

  private func applyCollapsed() {
    card.setCornerRadius(28)
  }

  private func refreshAttachments() {
    attachmentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    for name in attachments {
      let chip = UILabel()
      chip.text = name
      chip.font = .preferredFont(forTextStyle: .caption1)
      chip.backgroundColor = UIColor.secondarySystemFill
      chip.layer.cornerRadius = 8
      chip.clipsToBounds = true
      attachmentStack.addArrangedSubview(chip)
    }
  }

  private func emitOccupancy() {
    // Homepage / chat occupancy is the collapsed pill only, even when expanded.
    let next = isHidden ? 0 : Self.collapsedOccupancy
    if abs(next - lastOccupancy) > 0.5 {
      lastOccupancy = next
      onOccupancy?(next)
    }
  }

  func textViewDidChange(_ textView: UITextView) {
    let text = textView.text ?? ""
    placeholder.isHidden = !text.isEmpty
    onText?(text)
    onAutocomplete?(text)
  }

  @objc private func sendTapped() {
    if canAbort {
      onStop?()
      return
    }
    onSend?(textView.text ?? "")
  }

  @objc private func attachTapped() {
    onAttach?()
  }
}

final class OpenChamberComposerAutocomplete: UIView {
  private let scroller = UIScrollView()
  private let stack = UIStackView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    isHidden = true
    stack.axis = .vertical
    stack.spacing = 4
    scroller.alwaysBounceVertical = true
    scroller.isScrollEnabled = true
    scroller.panGestureRecognizer.isEnabled = true
    addSubview(scroller)
    scroller.translatesAutoresizingMaskIntoConstraints = false
    scroller.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scroller.topAnchor.constraint(equalTo: topAnchor),
      scroller.bottomAnchor.constraint(equalTo: bottomAnchor),
      scroller.leadingAnchor.constraint(equalTo: leadingAnchor),
      scroller.trailingAnchor.constraint(equalTo: trailingAnchor),
      stack.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
      stack.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: scroller.frameLayoutGuide.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: scroller.frameLayoutGuide.trailingAnchor),
      stack.widthAnchor.constraint(equalTo: scroller.frameLayoutGuide.widthAnchor),
    ])
    layer.cornerRadius = 16
    clipsToBounds = true
    backgroundColor = .secondarySystemBackground
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func apply(rows: [String]) {
    stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    isHidden = rows.isEmpty
    for row in rows {
      let label = UILabel()
      label.text = row
      label.font = .preferredFont(forTextStyle: .body)
      label.numberOfLines = 1
      stack.addArrangedSubview(label)
    }
  }
}

final class OpenChamberGlassBackdrop: UIView {
  var contentView: UIView { blur.contentView }
  private let blur = UIVisualEffectView(effect: nil)

  override init(frame: CGRect) {
    super.init(frame: frame)
    blur.translatesAutoresizingMaskIntoConstraints = false
    blur.clipsToBounds = true
    addSubview(blur)
    NSLayoutConstraint.activate([
      blur.topAnchor.constraint(equalTo: topAnchor),
      blur.bottomAnchor.constraint(equalTo: bottomAnchor),
      blur.leadingAnchor.constraint(equalTo: leadingAnchor),
      blur.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
    setCornerRadius(28)
    refresh()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func setCornerRadius(_ radius: CGFloat) {
    layer.cornerRadius = radius
    blur.layer.cornerRadius = radius
  }

  private func refresh() {
    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: .regular)
      glass.isInteractive = true
      blur.effect = glass
      backgroundColor = .clear
      return
    }
    if let effectClass = NSClassFromString("UIGlassEffect") as? NSObject.Type {
      let effect = effectClass.init()
      blur.effect = effect as? UIVisualEffect
      if blur.effect != nil {
        backgroundColor = .clear
        return
      }
    }
    blur.effect = UIBlurEffect(style: .systemUltraThinMaterial)
    backgroundColor = .clear
  }
}
