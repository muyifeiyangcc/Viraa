import SnapKit
import UIKit

final class StateOverlayView: UIView {
  private let spinner = UIActivityIndicatorView(style: .large),
    label = UIFactory.label(size: 16, color: AppTheme.secondary, lines: 0),
    retry = UIFactory.button("Reload", background: AppTheme.blue)
  var onRetry: (() -> Void)?
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .white
    let stack = UIStackView(arrangedSubviews: [spinner, label, retry])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 14
    addSubview(stack)
    stack.snp.makeConstraints {
      $0.center.equalToSuperview()
      $0.leading.trailing.greaterThanOrEqualToSuperview().inset(30)
    }
    retry.addTarget(self, action: #selector(tap), for: .touchUpInside)
  }
  required init?(coder: NSCoder) { fatalError() }
  @objc private func tap() { onRetry?() }
  func render(_ state: ViewState, emptyText: String) {
    isHidden = state == .content
    spinner.stopAnimating()
    retry.isHidden = true
    switch state {
    case .loading:
      label.text = "Preparing your experience…"
      spinner.startAnimating()
    case .empty: label.text = emptyText
    case .parsingError:
      label.text = "Content could not be prepared."
      retry.isHidden = false
    case .content: break
    }
  }
}

final class BottomSheetController: UIViewController {
  private let sheet = UIView(), titleText: String, messageText: String, primary: String,
    secondary: String?
  private let completion: (Bool) -> Void
  init(
    title: String, message: String, primary: String, secondary: String? = "Cancel",
    completion: @escaping (Bool) -> Void
  ) {
    titleText = title
    messageText = message
    self.primary = primary
    self.secondary = secondary
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .overFullScreen
    modalTransitionStyle = .crossDissolve
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    sheet.backgroundColor = .white
    sheet.layer.cornerRadius = 24
    sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    view.addSubview(sheet)
    sheet.snp.makeConstraints {
      $0.leading.trailing.bottom.equalToSuperview()
      $0.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(64)
    }
    let title = UIFactory.label(titleText, size: 24, weight: .bold, lines: 0)
    let message = UIFactory.label(messageText, size: 14, weight: .medium, lines: 0)
    let yes = UIFactory.button(primary, background: AppTheme.blue)
    title.textAlignment = .center
    message.textAlignment = .center
    message.adjustsFontForContentSizeCategory = true
    yes.tag = 1
    yes.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
    let arranged: [UIView] =
      secondary == nil
      ? [title, message, yes]
      : [
        title, message,
        UIStackView(arrangedSubviews: [
          UIFactory.button(secondary!, background: AppTheme.surface, foreground: AppTheme.ink), yes,
        ]),
      ]
    let stack = UIStackView(arrangedSubviews: arranged)
    let scroll = UIScrollView()
    stack.axis = .vertical
    stack.spacing = 18
    stack.isLayoutMarginsRelativeArrangement = true
    stack.layoutMargins = .init(top: 36, left: 20, bottom: 36, right: 20)
    sheet.addSubview(scroll)
    scroll.addSubview(stack)
    scroll.snp.makeConstraints {
      $0.edges.equalToSuperview()
      $0.height.equalTo(stack).priority(.high)
    }
    stack.snp.makeConstraints { $0.edges.width.equalToSuperview() }
    if let row = arranged.last as? UIStackView {
      row.spacing = 8
      row.distribution = .fillEqually
      (row.arrangedSubviews.first as? UIButton)?.addTarget(
        self, action: #selector(tap(_:)), for: .touchUpInside)
    }
  }
  @objc private func tap(_ sender: UIButton) {
    dismiss(animated: true) { self.completion(sender.tag == 1) }
  }
}

final class ChoiceSheetController: UIViewController {
  private let options: [String]
  private let completion: (Int?) -> Void
  private let sheet = UIView()

  init(options: [String], completion: @escaping (Int?) -> Void) {
    self.options = options
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .overFullScreen
    modalTransitionStyle = .crossDissolve
  }

  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.black.withAlphaComponent(0.62)
    sheet.backgroundColor = .white
    sheet.layer.cornerRadius = 23
    sheet.clipsToBounds = true
    view.addSubview(sheet)
    sheet.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(7)
      $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-8)
    }
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 0
    sheet.addSubview(stack)
    stack.snp.makeConstraints { $0.edges.equalToSuperview() }
    for (index, option) in options.enumerated() {
      let button = UIButton(type: .system)
      button.tag = index
      button.setTitle(option, for: .normal)
      button.setTitleColor(AppTheme.ink, for: .normal)
      button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
      button.addTarget(self, action: #selector(optionTap(_:)), for: .touchUpInside)
      button.snp.makeConstraints { $0.height.equalTo(52) }
      stack.addArrangedSubview(button)
    }
    let divider = UIView()
    divider.backgroundColor = UIColor(white: 0.86, alpha: 1)
    stack.addArrangedSubview(divider)
    divider.snp.makeConstraints { $0.height.equalTo(1) }
    let cancel = UIButton(type: .system)
    cancel.setTitle("Cancel", for: .normal)
    cancel.setTitleColor(AppTheme.ink, for: .normal)
    cancel.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
    cancel.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
    cancel.snp.makeConstraints { $0.height.equalTo(52) }
    stack.addArrangedSubview(cancel)
  }

  @objc private func optionTap(_ sender: UIButton) {
    dismiss(animated: true) { self.completion(sender.tag) }
  }

  @objc private func cancelTap() {
    dismiss(animated: true) { self.completion(nil) }
  }
}

extension UIViewController {
  func presentBottomSheet(
    title: String, message: String, primary: String = "Confirm", secondary: String? = "Cancel",
    completion: @escaping (Bool) -> Void
  ) {
    present(
      BottomSheetController(
        title: title, message: message, primary: primary, secondary: secondary,
        completion: completion), animated: true)
  }

  func presentChoiceSheet(options: [String], completion: @escaping (Int?) -> Void) {
    present(ChoiceSheetController(options: options, completion: completion), animated: true)
  }
}
