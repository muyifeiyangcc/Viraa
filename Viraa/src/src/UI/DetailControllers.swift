import AVFoundation
import SnapKit
import UIKit

private final class ReportReasonButton: UIControl {
  let reason: String
  private let titleLabel = UIFactory.label(size: 14)
  private let ring = UIView(), fill = UIView()

  init(reason: String) {
    self.reason = reason
    super.init(frame: .zero)
    backgroundColor = AppTheme.surface
    layer.cornerRadius = 17
    titleLabel.text = reason
    ring.layer.borderWidth = 2
    ring.layer.borderColor = AppTheme.secondary.cgColor
    ring.layer.cornerRadius = 10
    fill.backgroundColor = AppTheme.blue
    fill.layer.cornerRadius = 10
    fill.isHidden = true
    addSubview(titleLabel)
    addSubview(ring)
    ring.addSubview(fill)
    titleLabel.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(16)
      $0.centerY.equalToSuperview()
      $0.trailing.lessThanOrEqualTo(ring.snp.leading).offset(-12)
    }
    ring.snp.makeConstraints {
      $0.trailing.equalToSuperview().inset(16)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(20)
    }
    fill.snp.makeConstraints { $0.edges.equalToSuperview() }
    snp.makeConstraints { $0.height.equalTo(52) }
  }

  required init?(coder: NSCoder) { fatalError() }

  func setSelected(_ selected: Bool) {
    backgroundColor =
      selected ? UIColor(red: 0.91, green: 0.95, blue: 1, alpha: 1) : AppTheme.surface
    titleLabel.font = .systemFont(ofSize: 14, weight: selected ? .semibold : .regular)
    ring.layer.borderColor = selected ? AppTheme.blue.cgColor : AppTheme.secondary.cgColor
    ring.layer.borderWidth = selected ? 0 : 2
    fill.isHidden = !selected
  }
}

final class ReportController: UIViewController {
  private let targetID: String
  private let reasons = [
    "Spam or scam", "Harassment or bullying", "Hate speech", "Nudity or sexual content",
    "Dangerous activity", "False water or safety information", "Other",
  ]
  private let reasonStack = UIStackView()
  private var selected: String? = "False water or safety information"

  init(targetID: String) {
    self.targetID = targetID
    super.init(nibName: nil, bundle: nil)
    hidesBottomBarWhenPushed = true
  }

  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    configurePage()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: false)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(false, animated: false)
  }

  private func configurePage() {
    let back = UIButton(type: .custom)
    back.setImage(UIImage(named: "image/back")?.withRenderingMode(.alwaysOriginal), for: .normal)
    back.contentHorizontalAlignment = .left
    back.addTarget(self, action: #selector(backTap), for: .touchUpInside)
    let title = UIFactory.label("Report", size: 27, weight: .regular)
    let subtitle = UIFactory.label(
      "Why are you reporting this?", size: 16, color: AppTheme.secondary)
    reasonStack.axis = .vertical
    reasonStack.spacing = 12
    for reason in reasons {
      let button = ReportReasonButton(reason: reason)
      button.setSelected(reason == selected)
      button.addTarget(self, action: #selector(selectReason(_:)), for: .touchUpInside)
      reasonStack.addArrangedSubview(button)
    }
    let submit = UIFactory.button("Submit report")
    submit.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
    submit.addTarget(self, action: #selector(submitTap), for: .touchUpInside)
    [back, title, subtitle, reasonStack, submit].forEach(view.addSubview)
    back.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide)
      $0.leading.equalToSuperview().offset(20)
      $0.width.height.equalTo(44)
    }
    title.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide).offset(53)
      $0.leading.equalToSuperview().offset(20)
      $0.height.equalTo(34)
    }
    subtitle.snp.makeConstraints {
      $0.top.equalTo(title.snp.bottom).offset(-1)
      $0.leading.equalTo(title)
      $0.height.equalTo(23)
    }
    reasonStack.snp.makeConstraints {
      $0.top.equalTo(subtitle.snp.bottom).offset(20)
      $0.leading.trailing.equalToSuperview().inset(20)
    }
    submit.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.bottom.equalTo(view.safeAreaLayoutGuide)
      $0.height.equalTo(52)
    }
  }

  @objc private func backTap() { navigationController?.popViewController(animated: true) }

  @objc private func selectReason(_ sender: ReportReasonButton) {
    selected = sender.reason
    for case let button as ReportReasonButton in reasonStack.arrangedSubviews {
      button.setSelected(button === sender)
    }
  }

  @objc private func submitTap() {
    guard let selected else { return }
    AppRepository.shared.report(targetID: targetID, reason: selected)
    showMessage("Report Submitted", "Thank you for helping keep the community safe.") {
      self.navigationController?.popViewController(animated: true)
    }
  }
}

private final class SettingsRowButton: UIControl {
  init(title: String, showsChevron: Bool, color: UIColor = AppTheme.ink) {
    super.init(frame: .zero)
    let label = UIFactory.label(title, size: 15, color: color)
    addSubview(label)
    label.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(16)
      $0.centerY.equalToSuperview()
    }
    if showsChevron {
      let chevron = UIImageView(
        image: UIImage(
          systemName: "chevron.right",
          withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)))
      chevron.tintColor = AppTheme.secondary
      addSubview(chevron)
      chevron.snp.makeConstraints {
        $0.trailing.equalToSuperview().inset(19)
        $0.centerY.equalToSuperview()
        $0.width.equalTo(7)
        $0.height.equalTo(12)
      }
    }
  }

  required init?(coder: NSCoder) { fatalError() }
}

final class SettingsController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    hidesBottomBarWhenPushed = true
    configurePage()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: false)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(false, animated: false)
  }

  private func configurePage() {
    let back = UIButton(type: .custom)
    back.setImage(UIImage(named: "image/back")?.withRenderingMode(.alwaysOriginal), for: .normal)
    back.contentHorizontalAlignment = .left
    back.addTarget(self, action: #selector(backTap), for: .touchUpInside)
    let title = UIFactory.label("Settings", size: 27, weight: .regular)
    let account = UIFactory.label("ACCOUNT", size: 11, color: AppTheme.secondary)
    let privacy = SettingsRowButton(title: "Privacy", showsChevron: true)
    let agreement = SettingsRowButton(title: "Terms of Service", showsChevron: true)
    let blacklist = SettingsRowButton(title: "Blacklist", showsChevron: true)
    let logout = SettingsRowButton(title: "Log Out", showsChevron: false)
    let delete = SettingsRowButton(
      title: "Delete Account", showsChevron: false, color: AppTheme.danger)
    privacy.addTarget(self, action: #selector(privacyTap), for: .touchUpInside)
    agreement.addTarget(self, action: #selector(agreementTap), for: .touchUpInside)
    blacklist.addTarget(self, action: #selector(blacklistTap), for: .touchUpInside)
    logout.addTarget(self, action: #selector(logoutTap), for: .touchUpInside)
    delete.addTarget(self, action: #selector(deleteAccountTap), for: .touchUpInside)
    [back, title, account, privacy, agreement, blacklist, logout, delete].forEach(view.addSubview)
    back.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide)
      $0.leading.equalToSuperview().offset(20)
      $0.width.height.equalTo(44)
    }
    title.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide).offset(53)
      $0.leading.equalToSuperview().offset(20)
      $0.height.equalTo(34)
    }
    account.snp.makeConstraints {
      $0.top.equalTo(title.snp.bottom).offset(7)
      $0.leading.equalTo(title)
      $0.height.equalTo(16)
    }
    privacy.snp.makeConstraints {
      $0.top.equalTo(account.snp.bottom).offset(17)
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.height.equalTo(52)
    }
    agreement.snp.makeConstraints {
      $0.top.equalTo(privacy.snp.bottom)
      $0.leading.trailing.equalTo(privacy)
      $0.height.equalTo(52)
    }
    blacklist.snp.makeConstraints {
      $0.top.equalTo(agreement.snp.bottom)
      $0.leading.trailing.equalTo(privacy)
      $0.height.equalTo(52)
    }
    logout.snp.makeConstraints {
      $0.top.equalTo(blacklist.snp.bottom)
      $0.leading.trailing.equalTo(privacy)
      $0.height.equalTo(52)
    }
    delete.snp.makeConstraints {
      $0.top.equalTo(logout.snp.bottom)
      $0.leading.trailing.equalTo(privacy)
      $0.height.equalTo(52)
    }
  }

  @objc private func backTap() { navigationController?.popViewController(animated: true) }

  @objc private func privacyTap() {
    navigationController?.pushViewController(
      PolicyController(title: "Privacy Policy"), animated: true)
  }

  @objc private func agreementTap() {
    navigationController?.pushViewController(
      PolicyController(title: "Terms of Service"), animated: true)
  }

  @objc private func blacklistTap() {
    navigationController?.pushViewController(BlacklistController(), animated: true)
  }

  @objc private func logoutTap() {
    presentBottomSheet(title: "Sign Out", message: "Are you sure you want to sign out?") { ok in
      if ok {
        AppRepository.shared.signOut()
        self.view.window?.rootViewController = UINavigationController(
          rootViewController: LoginLandingController())
      }
    }
  }

  @objc private func deleteAccountTap() {
    presentBottomSheet(
      title: "Delete Account", message: "Are you sure you want to delete this account? All data will be cleared after deletion and cannot be recovered.", primary: "Delete"
    ) { ok in
      if ok {
        AppRepository.shared.deleteAccount()
        self.view.window?.rootViewController = UINavigationController(
          rootViewController: LoginLandingController())
      }
    }
  }
}

final class EditProfileController: UIViewController, MediaPickerDelegate, UITextViewDelegate,
  UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
  private let header = UIView(), titleLabel = UIFactory.label("Edit Profile", size: 27)
  private let avatar = UIImageView(), cameraButton = UIButton(type: .custom)
  private let nameField = UITextField(), bioView = UITextView(), bioPlaceholder = UILabel()
  private let saveButton = UIFactory.button("Save"), picker = MediaPickerService()
  private var avatarAsset: MediaAsset?, dirty = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    hidesBottomBarWhenPushed = true
    picker.delegate = self
    configurePage()
    loadProfile()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: false)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(false, animated: false)
  }

  private func configurePage() {
    let back = UIButton(type: .custom)
    back.setImage(UIImage(named: "image/back")?.withRenderingMode(.alwaysOriginal), for: .normal)
    back.contentHorizontalAlignment = .left
    back.addTarget(self, action: #selector(backTap), for: .touchUpInside)
    view.addSubview(header)
    header.addSubview(back)
    view.addSubview(titleLabel)
    avatar.clipsToBounds = true
    avatar.layer.cornerRadius = 55.5
    avatar.isUserInteractionEnabled = true
    avatar.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(showAvatarOptions)))
    view.addSubview(avatar)
    cameraButton.backgroundColor = AppTheme.blue
    cameraButton.layer.cornerRadius = 17
    cameraButton.setImage(
      UIImage(named: "image/camera")?.withRenderingMode(.alwaysOriginal), for: .normal)
    cameraButton.imageView?.contentMode = .scaleAspectFit
    cameraButton.addTarget(self, action: #selector(showAvatarOptions), for: .touchUpInside)
    view.addSubview(cameraButton)
    nameField.backgroundColor = AppTheme.surface
    nameField.layer.cornerRadius = 17
    nameField.placeholder = "Please name"
    nameField.font = .systemFont(ofSize: 15)
    nameField.textColor = AppTheme.ink
    nameField.setLeftPadding(16)
    nameField.addTarget(self, action: #selector(changed), for: .editingChanged)
    view.addSubview(nameField)
    bioView.backgroundColor = AppTheme.surface
    bioView.layer.cornerRadius = 17
    bioView.font = .systemFont(ofSize: 15)
    bioView.textColor = AppTheme.ink
    bioView.textContainerInset = .init(top: 17, left: 12, bottom: 12, right: 12)
    bioView.textContainer.lineFragmentPadding = 4
    bioView.delegate = self
    bioPlaceholder.text = "Tell us about yourself"
    bioPlaceholder.font = .systemFont(ofSize: 15)
    bioPlaceholder.textColor = AppTheme.secondary
    bioView.addSubview(bioPlaceholder)
    bioPlaceholder.snp.makeConstraints {
      $0.top.equalToSuperview().offset(17)
      $0.leading.equalToSuperview().offset(16)
    }
    view.addSubview(bioView)
    saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
    saveButton.addTarget(self, action: #selector(saveTap), for: .touchUpInside)
    view.addSubview(saveButton)
    header.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide)
      $0.leading.trailing.equalToSuperview()
      $0.height.equalTo(53)
    }
    back.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(20)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(44)
    }
    titleLabel.snp.makeConstraints {
      $0.top.equalTo(header.snp.bottom)
      $0.leading.equalToSuperview().offset(20)
      $0.height.equalTo(34)
    }
    avatar.snp.makeConstraints {
      $0.top.equalTo(titleLabel.snp.bottom).offset(17)
      $0.leading.equalToSuperview().offset(20)
      $0.width.height.equalTo(111)
    }
    cameraButton.snp.makeConstraints {
      $0.trailing.equalTo(avatar).offset(1)
      $0.bottom.equalTo(avatar).offset(-4)
      $0.width.height.equalTo(34)
    }
    nameField.snp.makeConstraints {
      $0.top.equalTo(avatar.snp.bottom).offset(24)
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.height.equalTo(52)
    }
    bioView.snp.makeConstraints {
      $0.top.equalTo(nameField.snp.bottom).offset(16)
      $0.leading.trailing.equalTo(nameField)
      $0.height.equalTo(92)
    }
    saveButton.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.bottom.equalTo(view.safeAreaLayoutGuide)
      $0.height.equalTo(52)
    }
  }

  private func loadProfile() {
    let user = AppRepository.shared.currentUser
    if let asset = user?.avatar, let image = MediaStore.shared.thumbnail(for: asset) {
      avatar.image = image
      avatar.contentMode = .scaleAspectFill
      avatar.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    } else {
      avatar.image = UIImage(systemName: "person.crop.circle.fill")
      avatar.tintColor = UIColor(white: 0.62, alpha: 1)
      avatar.contentMode = .scaleAspectFit
      avatar.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    nameField.text = user?.name
    bioView.text = user?.bio
    bioPlaceholder.isHidden = !(bioView.text ?? "").isEmpty
  }

  @objc private func changed() { dirty = true }

  func textViewDidChange(_ textView: UITextView) {
    dirty = true
    bioPlaceholder.isHidden = !textView.text.isEmpty
  }

  @objc private func showAvatarOptions() {
    view.endEditing(true)
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
      showMessage("Photo Unavailable", "The captured photo could not be saved.")
      return
    }
    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "profile-camera-\(UUID().uuidString).jpg")
    do {
      try data.write(to: temporaryURL, options: .atomic)
      defer { try? FileManager.default.removeItem(at: temporaryURL) }
      applyAvatar(try MediaStore.shared.importFile(temporaryURL, kind: .image))
    } catch {
      showMessage("Photo Unavailable", "The captured photo could not be saved.")
    }
  }

  func mediaPicker(_ picker: MediaPickerService, didFinish assets: [MediaAsset]) {
    guard let asset = assets.first else { return }
    applyAvatar(asset)
  }

  private func applyAvatar(_ asset: MediaAsset) {
    avatarAsset.map(MediaStore.shared.delete)
    avatarAsset = asset
    avatar.image = MediaStore.shared.thumbnail(for: asset)
    avatar.contentMode = .scaleAspectFill
    avatar.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    dirty = true
  }

  func mediaPicker(_ picker: MediaPickerService, didFail message: String) {
    showMessage("Media Unavailable", message)
  }

  @objc private func backTap() {
    guard dirty else {
      navigationController?.popViewController(animated: true)
      return
    }
    presentBottomSheet(
      title: "Discard Changes?", message: "Your edits have not been saved.", primary: "Discard"
    ) { confirmed in
      if confirmed {
        self.avatarAsset.map(MediaStore.shared.delete)
        self.navigationController?.popViewController(animated: true)
      }
    }
  }

  @objc private func saveTap() {
    let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      showMessage("Name Required", "Please enter your name.")
      return
    }
    AppRepository.shared.updateProfile(
      name: name, bio: bioView.text, location: AppRepository.shared.currentUser?.location,
      avatar: avatarAsset)
    avatarAsset = nil
    dirty = false
    navigationController?.popViewController(animated: true)
  }
}
