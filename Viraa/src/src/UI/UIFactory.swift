import SnapKit
import UIKit

enum UIFactory {
  static func label(
    _ text: String = "", size: CGFloat = 14, weight: UIFont.Weight = .regular,
    color: UIColor = AppTheme.ink, lines: Int = 1
  ) -> UILabel {
    let v = UILabel()
    v.text = text
    v.font = .systemFont(ofSize: size, weight: weight)
    v.textColor = color
    v.numberOfLines = lines
    return v
  }
  static func button(
    _ title: String, background: UIColor = AppTheme.ink, foreground: UIColor = .white
  ) -> UIButton {
    var config = UIButton.Configuration.filled()
    config.title = title
    config.baseBackgroundColor = background
    config.baseForegroundColor = foreground
    config.cornerStyle = .capsule
    config.contentInsets = .init(top: 15, leading: 20, bottom: 15, trailing: 20)
    let b = UIButton(configuration: config)
    b.titleLabel?.font = .systemFont(ofSize: 16)
    return b
  }
  static func field(_ placeholder: String, secure: Bool = false) -> UITextField {
    let f = UITextField()
    f.placeholder = placeholder
    f.isSecureTextEntry = secure
    f.backgroundColor = AppTheme.surface
    f.layer.cornerRadius = 17
    f.font = .systemFont(ofSize: 14)
    f.setLeftPadding(16)
    f.snp.makeConstraints { $0.height.equalTo(54) }
    return f
  }
  static func image(_ name: String, corner: CGFloat = 26) -> UIImageView {
    let v = UIImageView(image: UIImage(named: name))
    v.contentMode = .scaleAspectFill
    v.clipsToBounds = true
    v.layer.cornerRadius = corner
    return v
  }
  static func backBarButton(target: Any?, action: Selector) -> UIBarButtonItem {
    let button = UIButton(type: .custom)
    button.backgroundColor = .clear
    button.setImage(UIImage(named: "image/back")?.withRenderingMode(.alwaysOriginal), for: .normal)
    button.contentHorizontalAlignment = .left
    button.addTarget(target, action: action, for: .touchUpInside)
    button.snp.makeConstraints { $0.width.height.equalTo(44) }
    let item = UIBarButtonItem(customView: button)
    if #available(iOS 26.0, *) { item.hidesSharedBackground = true }
    return item
  }
}
extension UITextField {
  func setLeftPadding(_ value: CGFloat) {
    leftView = UIView(frame: CGRect(x: 0, y: 0, width: value, height: 1))
    leftViewMode = .always
  }
}
extension UIViewController {
  func showMessage(
    _ title: String, _ message: String, action: String = "OK", handler: (() -> Void)? = nil
  ) {
    presentBottomSheet(title: title, message: message, primary: action, secondary: nil) { _ in
      handler?()
    }
  }
  func showConfirm(
    _ title: String, _ message: String, destructive: Bool = false, confirm: @escaping () -> Void
  ) {
    presentBottomSheet(title: title, message: message, primary: "Confirm", secondary: "Cancel") {
      if $0 { confirm() }
    }
  }

  func presentSignInRequired() {
    presentBottomSheet(
      title: "Sign In Required",
      message: "To ensure the normal operation of the function, please sign in to your account first.",
      primary: "Sign In",
      secondary: "Cancel"
    ) { [weak self] confirmed in
      guard confirmed, let window = self?.view.window else { return }
      window.rootViewController = UINavigationController(
        rootViewController: LoginLandingController())
    }
  }
}

class ScrollPageController: UIViewController {
  let scroll = UIScrollView()
  let content = UIStackView()
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    scroll.alwaysBounceVertical = true
    view.addSubview(scroll)
    scroll.addSubview(content)
    content.axis = .vertical
    content.spacing = 16
    content.isLayoutMarginsRelativeArrangement = true
    content.layoutMargins = .init(top: 20, left: 20, bottom: 36, right: 20)
    scroll.snp.makeConstraints { $0.edges.equalTo(view.safeAreaLayoutGuide) }
    content.snp.makeConstraints { $0.edges.width.equalToSuperview() }
    let h = content.heightAnchor.constraint(
      greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor)
    h.priority = .defaultLow
    h.isActive = true
  }
  func configureSecondary(title: String) {
    self.title = title
    navigationItem.leftBarButtonItem = UIFactory.backBarButton(
      target: self, action: #selector(back))
    hidesBottomBarWhenPushed = true
  }
  @objc private func back() { navigationController?.popViewController(animated: true) }
}
