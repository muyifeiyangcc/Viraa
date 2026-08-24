import SnapKit
import UIKit
import WebKit

final class LoginLandingController: UIViewController {
  private let checkbox = UIButton(type: .system)
  private var checked = false
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    let background = UIFactory.image("image/login", corner: 0)
    view.addSubview(background)
    background.snp.makeConstraints { $0.edges.equalToSuperview() }

    let guest = UIFactory.button("I’m New", background: .white, foreground: AppTheme.ink)
    let sign = UIFactory.button("Sign In By Email", background: AppTheme.blue)
    [guest, sign].forEach { button in
      var configuration = button.configuration
      configuration?.cornerStyle = .fixed
      configuration?.background.cornerRadius = 26
      button.configuration = configuration
      button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
    }
    guest.addTarget(self, action: #selector(guestTap), for: .touchUpInside)
    sign.addTarget(self, action: #selector(signTap), for: .touchUpInside)

    let signup = UIButton(type: .system)
    let signupText = NSMutableAttributedString(
      string: "Don’t have an account? ",
      attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.white])
    signupText.append(
      NSAttributedString(
        string: "Sign up",
        attributes: [
          .font: UIFont.systemFont(ofSize: 14), .foregroundColor: AppTheme.blue,
          .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]))
    signup.setAttributedTitle(signupText, for: .normal)
    signup.addTarget(self, action: #selector(signupTap), for: .touchUpInside)

    checkbox.setTitle("○", for: .normal)
    checkbox.setTitleColor(.white, for: .normal)
    checkbox.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
    checkbox.addTarget(self, action: #selector(checkTap), for: .touchUpInside)
    let agreement = UIFactory.label("By continuing you agree to our", size: 10, color: .white)
    let terms = UIButton(type: .system)
    let privacy = UIButton(type: .system)
    terms.setTitle("Terms of Service", for: .normal)
    privacy.setTitle("Privacy Policy", for: .normal)
    [terms, privacy].forEach {
      $0.setTitleColor(AppTheme.blue, for: .normal)
      $0.titleLabel?.font = .systemFont(ofSize: 10)
      $0.titleLabel?.textAlignment = .center
    }
    terms.addTarget(self, action: #selector(termsTap), for: .touchUpInside)
    privacy.addTarget(self, action: #selector(privacyTap), for: .touchUpInside)
    let andLabel = UIFactory.label("and", size: 10, color: .white)
    let agreementRow = UIStackView(arrangedSubviews: [checkbox, agreement, terms, andLabel])
    agreementRow.axis = .horizontal
    agreementRow.spacing = 3
    agreementRow.alignment = .center

    [guest, sign, signup, agreementRow, privacy].forEach { view.addSubview($0) }
    privacy.snp.makeConstraints {
      $0.centerX.equalToSuperview()
      $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(3)
      $0.height.equalTo(16)
    }
    agreementRow.snp.makeConstraints {
      $0.centerX.equalToSuperview()
      $0.bottom.equalTo(privacy.snp.top).offset(2)
      $0.height.equalTo(18)
    }
    checkbox.snp.makeConstraints { $0.width.height.equalTo(18) }
    signup.snp.makeConstraints {
      $0.centerX.equalToSuperview()
      $0.bottom.equalTo(agreementRow.snp.top).offset(-15)
      $0.height.equalTo(22)
    }
    sign.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.height.equalTo(52)
      $0.bottom.equalTo(signup.snp.top).offset(-17)
    }
    guest.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.height.equalTo(52)
      $0.bottom.equalTo(sign.snp.top).offset(-14)
    }
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: animated)
  }
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(false, animated: animated)
  }
  @objc private func guestTap() {
    AppRepository.shared.beginGuest()
    replaceRoot(MainTabController())
  }
  @objc private func signTap() {
    guard checked else {
      showMessage(
        "Agreement Required", "Please agree to the Terms of Service and Privacy Policy first.")
      return
    }
    navigationController?.pushViewController(EmailAuthController(mode: .signIn), animated: true)
  }
  @objc private func signupTap() {
    navigationController?.pushViewController(EmailAuthController(mode: .signUp), animated: true)
  }
  @objc private func checkTap() {
    checked.toggle()
    checkbox.setTitle(checked ? "●" : "○", for: .normal)
  }
  @objc private func privacyTap() {
    navigationController?.pushViewController(
      PolicyController(title: "Privacy Policy"), animated: true)
  }
  @objc private func termsTap() {
    navigationController?.pushViewController(
      PolicyController(title: "Terms of Service"), animated: true)
  }
  private func replaceRoot(_ root: UIViewController) {
    guard let window = view.window else { return }
    window.rootViewController = root
    UIView.transition(
      with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
  }
}

final class EmailAuthController: UIViewController {
  enum Mode { case signIn, signUp, reset }
  private let mode: Mode
  private let scroll = UIScrollView(), form = UIStackView()
  private let email = UIFactory.field("Email")
  private let password = UIFactory.field("Password", secure: true)
  private let confirmation = UIFactory.field("Password", secure: true)
  init(mode: Mode) {
    self.mode = mode
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    configureNavigation()
    form.axis = .vertical
    form.isLayoutMarginsRelativeArrangement = true
    form.layoutMargins = .init(top: 16, left: 20, bottom: 24, right: 20)
    scroll.alwaysBounceVertical = true
    view.addSubview(scroll)
    scroll.addSubview(form)

    let titleText =
      mode == .signIn
      ? "WELCOME BACK" : mode == .signUp ? "CREATE YOUR\nACCOUNT" : "FORGOT\nPASSWORD"
    let title = UIFactory.label(titleText, size: 32, weight: .bold, lines: 2)
    title.adjustsFontSizeToFitWidth = true
    title.minimumScaleFactor = 0.9
    form.addArrangedSubview(title)

    if mode != .reset {
      let subtitle = UIFactory.label(
        mode == .signIn ? "Sign in to keep exploring." : "Your next drop starts here.", size: 18,
        color: AppTheme.secondary)
      form.addArrangedSubview(subtitle)
      form.setCustomSpacing(mode == .signIn ? 28 : 28, after: subtitle)
    } else {
      form.setCustomSpacing(19, after: title)
    }

    form.addArrangedSubview(email)
    form.setCustomSpacing(17, after: email)
    addSecureField(password)
    if mode != .signIn {
      form.setCustomSpacing(17, after: password)
      addSecureField(confirmation)
    }

    if mode == .signIn {
      form.setCustomSpacing(14, after: password)
      let forgot = UIButton(type: .system)
      forgot.setTitle("Forgot Password?", for: .normal)
      forgot.setTitleColor(AppTheme.ink, for: .normal)
      forgot.titleLabel?.font = .systemFont(ofSize: 13, weight: .regular)
      forgot.contentHorizontalAlignment = .left
      forgot.addTarget(self, action: #selector(forgotTap), for: .touchUpInside)
      forgot.snp.makeConstraints { $0.height.equalTo(22) }
      form.addArrangedSubview(forgot)
    }

    let submitTitle = mode == .signUp ? "Sign up" : "Sign In"
    let submit = UIFactory.button(submitTitle)
    var submitConfiguration = submit.configuration
    submitConfiguration?.cornerStyle = .fixed
    submitConfiguration?.background.cornerRadius = 26
    submit.configuration = submitConfiguration
    submit.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
    submit.addTarget(self, action: #selector(submitTap), for: .touchUpInside)
    view.addSubview(submit)

    submit.snp.makeConstraints { make in
      make.leading.trailing.equalToSuperview().inset(20)
      make.height.equalTo(51)
      make.bottom.equalTo(view.safeAreaLayoutGuide).inset(8)
    }
    scroll.snp.makeConstraints { make in
      make.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
      make.bottom.equalTo(submit.snp.top).offset(-12)
    }
    form.snp.makeConstraints { make in
      make.edges.width.equalToSuperview()
      make.width.equalTo(scroll.frameLayoutGuide)
    }
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(false, animated: animated)
  }
  private func configureNavigation() {
    navigationItem.leftBarButtonItem = UIFactory.backBarButton(
      target: self, action: #selector(backTap))
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.shadowColor = .clear
    navigationController?.navigationBar.standardAppearance = appearance
    navigationController?.navigationBar.scrollEdgeAppearance = appearance
    navigationController?.navigationBar.compactAppearance = appearance
  }
  private func addSecureField(_ field: UITextField) {
    field.isSecureTextEntry = true
    let rightContainer = UIView(frame: CGRect(x: 0, y: 0, width: 52, height: 54))
    let eye = UIButton(type: .system)
    eye.tintColor = .black
    let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
    eye.setImage(
      UIImage(systemName: "eye.slash", withConfiguration: symbolConfiguration), for: .normal)
    eye.frame = CGRect(x: 8, y: 0, width: 36, height: 54)
    eye.imageView?.contentMode = .center
    eye.addAction(
      UIAction { _ in
        field.isSecureTextEntry.toggle()
        eye.setImage(
          UIImage(
            systemName: field.isSecureTextEntry ? "eye.slash" : "eye",
            withConfiguration: symbolConfiguration), for: .normal)
      }, for: .touchUpInside)
    rightContainer.addSubview(eye)
    field.rightView = rightContainer
    field.rightViewMode = .always
    form.addArrangedSubview(field)
  }
  @objc private func backTap() { navigationController?.popViewController(animated: true) }
  @objc private func forgotTap() {
    navigationController?.pushViewController(EmailAuthController(mode: .reset), animated: true)
  }
  @objc private func submitTap() {
    guard let e = email.text, e.contains("@"), let p = password.text, p.count >= 8 else {
      showMessage("Check Details", "Enter a valid email and a password of at least 8 characters.")
      return
    }
    if mode != .signIn && p != confirmation.text {
      showMessage("Check Details", "The passwords do not match.")
      return
    }
    switch mode {
    case .signIn:
      if AppRepository.shared.signIn(email: e, password: p) {
        enter()
      } else {
        showMessage(
          "Unable to Sign In",
          "The account or password is incorrect, or this account is unavailable.")
      }
    case .signUp:
      if AppRepository.shared.register(email: e, password: p) {
        navigationController?.pushViewController(ProfileSetupController(), animated: true)
      } else {
        showMessage("Account Exists", "Please use a different email.")
      }
    case .reset:
      if AppRepository.shared.resetPassword(email: e, password: p) {
        navigationController?.popViewController(animated: true)
      } else {
        showMessage("Account Not Found", "Please check the email and try again.")
      }
    }
  }
  private func enter() { view.window?.rootViewController = MainTabController() }
}

final class ProfileSetupController: UIViewController, MediaPickerDelegate,
  UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
  private let scroll = UIScrollView(), canvas = UIView()
  private let nameField = UIFactory.field("Nickname"), dateButton = UIButton(type: .custom)
  private let avatar = UIImageView(), cameraButton = UIButton(type: .custom)
  private let picker = MediaPickerService(), datePicker = UIDatePicker()
  private var gender: Gender = .man, avatarAsset: MediaAsset?
  private var man: UIButton!, madam: UIButton!
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    picker.delegate = self
    navigationItem.leftBarButtonItem = UIFactory.backBarButton(
      target: self, action: #selector(backTap))
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.shadowColor = .clear
    navigationController?.navigationBar.standardAppearance = appearance
    navigationController?.navigationBar.scrollEdgeAppearance = appearance
    scroll.alwaysBounceVertical = true
    view.addSubview(scroll)
    scroll.addSubview(canvas)

    let title = UIFactory.label("COMPLETE YOUR\nPROFILE", size: 32, weight: .bold, lines: 2)
    let subtitle = UIFactory.label(
      "Help nearby explorers know who they’re\nmeeting.", size: 18, color: AppTheme.secondary,
      lines: 2)
    avatar.image = UIImage(systemName: "person.crop.circle.fill")
    avatar.tintColor = UIColor(red: 205 / 255, green: 208 / 255, blue: 213 / 255, alpha: 1)
    avatar.contentMode = .scaleAspectFit
    avatar.clipsToBounds = true
    avatar.isUserInteractionEnabled = true
    avatar.layer.cornerRadius = 56
    avatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickAvatar)))
    cameraButton.backgroundColor = AppTheme.blue
    cameraButton.layer.cornerRadius = 17
    cameraButton.setImage(UIImage(named: "image/camera"), for: .normal)
    cameraButton.addTarget(self, action: #selector(pickAvatar), for: .touchUpInside)

    datePicker.datePickerMode = .date
    datePicker.maximumDate = Date()
    dateButton.backgroundColor = AppTheme.surface
    dateButton.layer.cornerRadius = 17
    dateButton.contentHorizontalAlignment = .left
    dateButton.setTitle("Date of birth", for: .normal)
    dateButton.setTitleColor(.placeholderText, for: .normal)
    dateButton.titleLabel?.font = .systemFont(ofSize: 14)
    dateButton.contentEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16)
    dateButton.addTarget(self, action: #selector(showDatePicker), for: .touchUpInside)

    man = genderButton(
      title: "Man", image: "image/man",
      selectedColor: UIColor(red: 30 / 255, green: 131 / 255, blue: 194 / 255, alpha: 1), tag: 0)
    madam = genderButton(
      title: "Madam", image: "image/female",
      selectedColor: UIColor(red: 177 / 255, green: 71 / 255, blue: 110 / 255, alpha: 1), tag: 1)
    let genderRow = UIStackView(arrangedSubviews: [man, madam])
    genderRow.spacing = 15
    genderRow.distribution = .fillEqually

    let save = UIFactory.button("Sign In")
    var saveConfiguration = save.configuration
    saveConfiguration?.cornerStyle = .fixed
    saveConfiguration?.background.cornerRadius = 26
    save.configuration = saveConfiguration
    save.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
    save.addTarget(self, action: #selector(saveTap), for: .touchUpInside)

    [title, subtitle, avatar, cameraButton, nameField, dateButton, genderRow, save].forEach {
      canvas.addSubview($0)
    }
    scroll.snp.makeConstraints { $0.edges.equalTo(view.safeAreaLayoutGuide) }
    canvas.snp.makeConstraints { make in
      make.edges.width.equalToSuperview()
      make.width.equalTo(scroll.frameLayoutGuide)
      make.height.greaterThanOrEqualTo(scroll.frameLayoutGuide)
    }
    title.snp.makeConstraints {
      $0.top.equalToSuperview().offset(16)
      $0.leading.trailing.equalToSuperview().inset(20)
    }
    subtitle.snp.makeConstraints {
      $0.top.equalTo(title.snp.bottom).offset(8)
      $0.leading.trailing.equalToSuperview().inset(20)
    }
    avatar.snp.makeConstraints {
      $0.top.equalTo(subtitle.snp.bottom).offset(18)
      $0.leading.equalToSuperview().offset(20)
      $0.width.height.equalTo(112)
    }
    cameraButton.snp.makeConstraints {
      $0.width.height.equalTo(34)
      $0.trailing.bottom.equalTo(avatar).offset(1)
    }
    nameField.snp.makeConstraints {
      $0.top.equalTo(avatar.snp.bottom).offset(14)
      $0.leading.trailing.equalToSuperview().inset(20)
    }
    dateButton.snp.makeConstraints {
      $0.top.equalTo(nameField.snp.bottom).offset(14)
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.height.equalTo(54)
    }
    genderRow.snp.makeConstraints {
      $0.top.equalTo(dateButton.snp.bottom).offset(15)
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.height.equalTo(54)
    }
    save.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.height.equalTo(51)
      $0.top.greaterThanOrEqualTo(genderRow.snp.bottom).offset(40)
      $0.bottom.equalToSuperview().inset(8)
    }
    updateGenderAppearance()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(false, animated: animated)
  }
  private func genderButton(title: String, image: String, selectedColor: UIColor, tag: Int)
    -> UIButton
  {
    let button = UIButton(type: .custom)
    button.tag = tag
    button.layer.cornerRadius = 17
    button.backgroundColor = tag == 0 ? selectedColor : AppTheme.surface
    let icon = UIImageView(image: UIImage(named: image))
    let label = UIFactory.label(title, size: 16, color: tag == 0 ? .white : AppTheme.secondary)
    icon.isUserInteractionEnabled = false
    label.isUserInteractionEnabled = false
    button.addSubview(icon)
    button.addSubview(label)
    icon.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(8)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(38)
    }
    label.snp.makeConstraints {
      $0.trailing.equalToSuperview().inset(16)
      $0.centerY.equalToSuperview()
    }
    button.addTarget(self, action: #selector(genderTap(_:)), for: .touchUpInside)
    return button
  }
  @objc private func genderTap(_ sender: UIButton) {
    gender = sender.tag == 0 ? .man : .madam
    updateGenderAppearance()
  }
  private func updateGenderAppearance() {
    man.backgroundColor =
      gender == .man
      ? UIColor(red: 30 / 255, green: 131 / 255, blue: 194 / 255, alpha: 1) : AppTheme.surface
    madam.backgroundColor =
      gender == .madam
      ? UIColor(red: 177 / 255, green: 71 / 255, blue: 110 / 255, alpha: 1) : AppTheme.surface
    (man.subviews.compactMap { $0 as? UILabel }.first)?.textColor =
      gender == .man ? .white : AppTheme.secondary
    (madam.subviews.compactMap { $0 as? UILabel }.first)?.textColor =
      gender == .madam ? .white : AppTheme.secondary
  }
  @objc private func showDatePicker() {
    let sheet = DatePickerSheetController(selectedDate: datePicker.date, maximumDate: Date()) {
      [weak self] date in
      guard let self else { return }
      self.datePicker.date = date
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      self.dateButton.setTitle(formatter.string(from: date), for: .normal)
      self.dateButton.setTitleColor(AppTheme.ink, for: .normal)
    }
    present(sheet, animated: true)
  }
  @objc private func backTap() { navigationController?.popViewController(animated: true) }
  @objc private func pickAvatar() {
    presentChoiceSheet(options: ["Take Photo", "Choose from Library"]) { [weak self] selection in
      guard let self, let selection else { return }
      if selection == 0 {
        self.openCamera()
      } else {
        self.picker.present(from: self, limit: 1, imagesOnly: true)
      }
    }
  }
  private func openCamera() {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      showMessage("Camera Unavailable", "The camera is not available on this device.")
      return
    }
    let camera = UIImagePickerController()
    camera.sourceType = .camera
    camera.cameraCaptureMode = .photo
    camera.delegate = self
    present(camera, animated: true)
  }
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
  }
  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    picker.dismiss(animated: true)
    guard let image = info[.originalImage] as? UIImage,
      let data = image.jpegData(compressionQuality: 0.9)
    else {
      showMessage("Media Unavailable", "The selected photo could not be saved.")
      return
    }
    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "camera-\(UUID().uuidString).jpg")
    do {
      try data.write(to: temporaryURL, options: .atomic)
      let asset = try MediaStore.shared.importFile(temporaryURL, kind: .image)
      try? FileManager.default.removeItem(at: temporaryURL)
      setAvatar(asset)
    } catch {
      try? FileManager.default.removeItem(at: temporaryURL)
      showMessage("Media Unavailable", "The selected photo could not be saved.")
    }
  }
  private func setAvatar(_ asset: MediaAsset) {
    avatarAsset.map(MediaStore.shared.delete)
    avatarAsset = asset
    avatar.contentMode = .scaleAspectFill
    avatar.layer.cornerRadius = 56
    avatar.clipsToBounds = true
    avatar.image = MediaStore.shared.thumbnail(for: asset)
    avatar.tintColor = nil
  }
  func mediaPicker(_ picker: MediaPickerService, didFinish assets: [MediaAsset]) {
    guard let asset = assets.first else { return }
    setAvatar(asset)
  }
  func mediaPicker(_ picker: MediaPickerService, didFail message: String) {
    showMessage("Media Unavailable", message)
  }
  @objc private func saveTap() {
    guard let n = nameField.text, !n.isEmpty else {
      showMessage("Profile Incomplete", "Please enter a nickname.")
      return
    }
    AppRepository.shared.updateProfile(
      name: n, bio: "Ready for the next water adventure.", gender: gender,
      birthDate: datePicker.date, avatar: avatarAsset)
    avatarAsset = nil
    view.window?.rootViewController = MainTabController()
  }
}

private final class DatePickerSheetController: UIViewController {
  private let selectedDate: Date, maximumDate: Date, completion: (Date) -> Void
  private let picker = UIDatePicker()
  init(selectedDate: Date, maximumDate: Date, completion: @escaping (Date) -> Void) {
    self.selectedDate = selectedDate
    self.maximumDate = maximumDate
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .pageSheet
    if let sheet = sheetPresentationController {
      if #available(iOS 16.0, *) {
        sheet.detents = [.custom { _ in 360 }]
      } else {
        sheet.detents = [.medium()]
      }
      sheet.prefersGrabberVisible = true
      sheet.preferredCornerRadius = 24
    }
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    let title = UIFactory.label("Date of birth", size: 20, weight: .semibold)
    let cancel = UIButton(type: .system)
    let done = UIButton(type: .system)
    cancel.setTitle("Cancel", for: .normal)
    done.setTitle("Done", for: .normal)
    cancel.setTitleColor(AppTheme.secondary, for: .normal)
    done.setTitleColor(AppTheme.blue, for: .normal)
    done.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
    cancel.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
    done.addTarget(self, action: #selector(doneTap), for: .touchUpInside)
    picker.datePickerMode = .date
    picker.preferredDatePickerStyle = .wheels
    picker.maximumDate = maximumDate
    picker.date = min(selectedDate, maximumDate)
    view.addSubview(title)
    view.addSubview(cancel)
    view.addSubview(done)
    view.addSubview(picker)
    title.snp.makeConstraints {
      $0.top.equalToSuperview().offset(30)
      $0.centerX.equalToSuperview()
    }
    cancel.snp.makeConstraints {
      $0.centerY.equalTo(title)
      $0.leading.equalToSuperview().offset(20)
      $0.width.equalTo(60)
      $0.height.equalTo(44)
    }
    done.snp.makeConstraints {
      $0.centerY.equalTo(title)
      $0.trailing.equalToSuperview().offset(-20)
      $0.width.equalTo(60)
      $0.height.equalTo(44)
    }
    picker.snp.makeConstraints {
      $0.top.equalTo(title.snp.bottom).offset(14)
      $0.leading.trailing.equalToSuperview().inset(12)
      $0.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-8)
    }
  }
  @objc private func cancelTap() { dismiss(animated: true) }
  @objc private func doneTap() {
    let date = picker.date
    dismiss(animated: true) { self.completion(date) }
  }
}

final class PolicyController: UIViewController, WKNavigationDelegate {
  private let policyURL: URL

  override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

  init(title: String) {
    let address =
      title == "Privacy Policy"
      ? "https://sites.google.com/view/viraa-perfect/privacy"
      : "https://sites.google.com/view/viraa-perfect/users"
    policyURL = URL(string: address)!
    super.init(nibName: nil, bundle: nil)
    self.title = title
    hidesBottomBarWhenPushed = true
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    navigationController?.setNavigationBarHidden(false, animated: false)
    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = .white
    appearance.shadowColor = .clear
    appearance.titleTextAttributes = [.foregroundColor: AppTheme.ink]
    navigationController?.navigationBar.standardAppearance = appearance
    navigationController?.navigationBar.scrollEdgeAppearance = appearance
    navigationController?.navigationBar.compactAppearance = appearance
    navigationController?.navigationBar.tintColor = AppTheme.ink
    navigationItem.leftBarButtonItem = UIFactory.backBarButton(
      target: self, action: #selector(back))
    let web = WKWebView()
    view.addSubview(web)
    web.snp.makeConstraints { $0.edges.equalTo(view.safeAreaLayoutGuide) }
    web.load(URLRequest(url: policyURL))
  }
  @objc private func back() { navigationController?.popViewController(animated: true) }
}
