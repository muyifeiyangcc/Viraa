import SnapKit
import UIKit

enum UserRelationListMode: Equatable {
  case followers, following, blocked

  var title: String {
    switch self {
    case .followers: return "Followers"
    case .following: return "Following"
    case .blocked: return "Blocked Users"
    }
  }
}

private final class RelationUserCell: UITableViewCell {
  static let reuseIdentifier = "relation-user"
  var action: (() -> Void)?
  private let avatar = UIImageView(), nameLabel = UIFactory.label(size: 20, weight: .semibold)
  private let actionButton = UIButton(type: .system)

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    backgroundColor = .white
    avatar.clipsToBounds = true
    avatar.layer.cornerRadius = 25
    actionButton.titleLabel?.font = .systemFont(ofSize: 13)
    actionButton.layer.cornerRadius = 17
    actionButton.addTarget(self, action: #selector(actionTap), for: .touchUpInside)
    contentView.addSubview(avatar)
    contentView.addSubview(nameLabel)
    contentView.addSubview(actionButton)
    avatar.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(18)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(50)
    }
    nameLabel.snp.makeConstraints {
      $0.leading.equalTo(avatar.snp.trailing).offset(17)
      $0.centerY.equalToSuperview()
      $0.trailing.lessThanOrEqualTo(actionButton.snp.leading).offset(-12)
    }
    actionButton.snp.makeConstraints {
      $0.trailing.equalToSuperview().inset(18)
      $0.centerY.equalToSuperview()
      $0.height.equalTo(34)
      $0.width.greaterThanOrEqualTo(66)
    }
  }

  required init?(coder: NSCoder) { fatalError() }

  func configure(user: User, mode: UserRelationListMode) {
    nameLabel.text = user.name
    if let asset = user.avatar, let image = MediaStore.shared.thumbnail(for: asset) {
      avatar.image = image
      avatar.contentMode = .scaleAspectFill
      avatar.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    } else {
      avatar.image = UIImage(systemName: "person.crop.circle.fill")
      avatar.tintColor = UIColor(white: 0.62, alpha: 1)
      avatar.contentMode = .scaleAspectFit
      avatar.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    if mode == .blocked {
      configureButton(title: "Unblock", selected: true)
    } else {
      let following = AppRepository.shared.isFollowing(user.id)
      configureButton(title: following ? "Following" : "Follow", selected: following)
    }
  }

  private func configureButton(title: String, selected: Bool) {
    actionButton.setTitle(title, for: .normal)
    actionButton.contentEdgeInsets = .init(top: 0, left: 14, bottom: 0, right: 14)
    actionButton.backgroundColor = selected ? AppTheme.surface : AppTheme.blue
    actionButton.setTitleColor(selected ? AppTheme.ink : .white, for: .normal)
  }

  @objc private func actionTap() { action?() }
}

class UserRelationListController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let mode: UserRelationListMode, userID: String?
  private let header = UIView(), titleLabel: UILabel,
    table = UITableView(frame: .zero, style: .plain)
  private var users: [User] = []

  init(mode: UserRelationListMode, userID: String?) {
    self.mode = mode
    self.userID = userID
    titleLabel = UIFactory.label(mode.title, size: 27, weight: .regular)
    super.init(nibName: nil, bundle: nil)
    hidesBottomBarWhenPushed = true
  }

  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    configurePage()
    NotificationCenter.default.addObserver(
      self, selector: #selector(reload), name: .appDataChanged, object: nil)
    reload()
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
    table.backgroundColor = .white
    table.separatorStyle = .none
    table.showsVerticalScrollIndicator = false
    table.rowHeight = 72
    table.dataSource = self
    table.delegate = self
    table.register(RelationUserCell.self, forCellReuseIdentifier: RelationUserCell.reuseIdentifier)
    view.addSubview(table)
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
    table.snp.makeConstraints {
      $0.top.equalTo(titleLabel.snp.bottom).offset(7)
      $0.leading.trailing.bottom.equalToSuperview()
    }
  }

  @objc private func reload() {
    switch mode {
    case .followers:
      users = AppRepository.shared.followerUsers(
        userID: userID ?? AppRepository.shared.currentUserID ?? "")
    case .following:
      users = AppRepository.shared.followingUsers(
        userID: userID ?? AppRepository.shared.currentUserID ?? "")
    case .blocked:
      users = AppRepository.shared.blocked.compactMap { AppRepository.shared.user($0) }
    }
    table.reloadData()
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    max(users.count, 1)
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard users.indices.contains(indexPath.row) else {
      let cell = UITableViewCell()
      cell.selectionStyle = .none
      cell.textLabel?.text = emptyText()
      cell.textLabel?.font = .systemFont(ofSize: 15)
      cell.textLabel?.textColor = AppTheme.secondary
      cell.textLabel?.textAlignment = .center
      return cell
    }
    let user = users[indexPath.row]
    let cell =
      tableView.dequeueReusableCell(
        withIdentifier: RelationUserCell.reuseIdentifier, for: indexPath) as! RelationUserCell
    cell.configure(user: user, mode: mode)
    cell.action = { [weak self] in self?.performAction(user) }
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard users.indices.contains(indexPath.row), mode != .blocked else { return }
    navigationController?.pushViewController(
      OtherProfileController(userID: users[indexPath.row].id), animated: true)
  }

  private func performAction(_ user: User) {
    if mode == .blocked {
      AppRepository.shared.unblock(userID: user.id)
    } else {
      AppRepository.shared.toggleFollow(userID: user.id)
    }
  }

  private func emptyText() -> String {
    switch mode {
    case .followers: return "No followers yet"
    case .following: return "Not following anyone yet"
    case .blocked: return "No blocked users"
    }
  }

  @objc private func backTap() { navigationController?.popViewController(animated: true) }
}

final class BlacklistController: UserRelationListController {
  init() { super.init(mode: .blocked, userID: nil) }
  required init?(coder: NSCoder) { fatalError() }
}
