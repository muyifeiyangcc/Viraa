import SnapKit
import UIKit

final class OtherProfileController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let userID: String
  private let header = UIView(), table = UITableView(frame: .zero, style: .plain)
  private let overlay = StateOverlayView(), actionsView = UIView()
  private let followButton = UIButton(type: .system), messageButton = UIButton(type: .system)
  private var showingMeets = false, posts: [Post] = [], meets: [Meet] = []

  init(userID: String) {
    self.userID = userID
    super.init(nibName: nil, bundle: nil)
    hidesBottomBarWhenPushed = true
  }

  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    configureTopBar()
    configureActions()
    configureTable()
    NotificationCenter.default.addObserver(
      self, selector: #selector(refresh), name: .appDataChanged, object: nil)
    refresh()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: false)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(false, animated: false)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard let profile = table.tableHeaderView, profile.frame.width != table.bounds.width else {
      return
    }
    profile.frame.size.width = table.bounds.width
    table.tableHeaderView = profile
  }

  private func configureTopBar() {
    let back = UIButton(type: .custom)
    let more = UIButton(type: .system)
    back.setImage(UIImage(named: "image/back")?.withRenderingMode(.alwaysOriginal), for: .normal)
    back.contentHorizontalAlignment = .left
    back.addTarget(self, action: #selector(backTap), for: .touchUpInside)
    more.tintColor = .black
    more.setImage(
      UIImage(
        systemName: "ellipsis",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .bold)),
      for: .normal)
    more.addTarget(self, action: #selector(moreTap), for: .touchUpInside)
    view.addSubview(header)
    header.addSubview(back)
    header.addSubview(more)
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
    more.snp.makeConstraints {
      $0.trailing.equalToSuperview().inset(18)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(40)
    }
  }

  private func configureTable() {
    table.backgroundColor = .white
    table.separatorStyle = .none
    table.showsVerticalScrollIndicator = false
    table.rowHeight = UITableView.automaticDimension
    table.estimatedRowHeight = 475
    table.contentInset.bottom = 88
    table.register(PostCell.self, forCellReuseIdentifier: "profile-post")
    table.register(MeetCardCell.self, forCellReuseIdentifier: MeetCardCell.reuseIdentifier)
    table.dataSource = self
    table.delegate = self
    view.addSubview(table)
    view.addSubview(overlay)
    table.snp.makeConstraints {
      $0.top.equalTo(header.snp.bottom)
      $0.leading.trailing.bottom.equalToSuperview()
    }
    overlay.snp.makeConstraints { $0.edges.equalTo(table) }
    overlay.onRetry = { AppRepository.shared.recoverFromParsingError() }
    view.bringSubviewToFront(actionsView)
  }

  private func configureActions() {
    actionsView.backgroundColor = .white
    followButton.backgroundColor = AppTheme.blue
    followButton.setTitleColor(.white, for: .normal)
    followButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
    followButton.layer.cornerRadius = 24
    followButton.addTarget(self, action: #selector(followTap), for: .touchUpInside)
    messageButton.backgroundColor = AppTheme.surface
    messageButton.setTitle("Message", for: .normal)
    messageButton.setTitleColor(AppTheme.ink, for: .normal)
    messageButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
    messageButton.layer.cornerRadius = 24
    messageButton.addTarget(self, action: #selector(messageTap), for: .touchUpInside)
    view.addSubview(actionsView)
    actionsView.addSubview(followButton)
    actionsView.addSubview(messageButton)
    actionsView.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview()
      $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(6)
      $0.height.equalTo(67)
    }
    followButton.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(20)
      $0.top.equalToSuperview().offset(9)
      $0.height.equalTo(49)
      $0.width.equalTo(messageButton)
    }
    messageButton.snp.makeConstraints {
      $0.leading.equalTo(followButton.snp.trailing).offset(8)
      $0.trailing.equalToSuperview().inset(20)
      $0.top.height.equalTo(followButton)
    }
  }

  @objc private func refresh() {
    guard AppRepository.shared.state != .parsingError else {
      overlay.render(.parsingError, emptyText: "")
      return
    }
    guard let user = AppRepository.shared.user(userID),
      !AppRepository.shared.blocked.contains(userID)
    else {
      overlay.render(.empty, emptyText: "This profile is unavailable")
      return
    }
    overlay.render(.content, emptyText: "")
    posts = AppRepository.shared.visiblePosts(authorID: userID)
    meets = AppRepository.shared.visibleMeets(hostID: userID)
    table.tableHeaderView = profileHeader(user)
    updateFollowButton()
    table.reloadData()
  }

  private func profileHeader(_ user: User) -> UIView {
    let profile = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 232))
    profile.backgroundColor = .white
    let avatar = UIImageView()
    avatar.clipsToBounds = true
    avatar.layer.cornerRadius = 43
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
    let name = UIFactory.label(user.name, size: 22, weight: .semibold)
    let bio = UIFactory.label(user.bio, size: 16, color: AppTheme.secondary, lines: 2)
    let likes = posts.reduce(0) {
      $0 + AppRepository.shared.filteredLikeCount(postID: $1.id)
    }
    let likesStat = statistic("\(likes)", "Likes")
    let followersStat = statistic(
      compactCount(AppRepository.shared.followersCount(userID: userID)), "Followers")
    let followingStat = statistic(
      compactCount(AppRepository.shared.followingCount(userID: userID)), "Following")
    followersStat.isUserInteractionEnabled = true
    followingStat.isUserInteractionEnabled = true
    followersStat.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(openFollowers)))
    followingStat.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(openFollowing)))
    let stats = UIStackView(arrangedSubviews: [likesStat, followersStat, followingStat])
    stats.distribution = .fillEqually
    let segment = UISegmentedControl(items: ["Drops", "Host a Water Meet"])
    segment.selectedSegmentIndex = showingMeets ? 1 : 0
    segment.selectedSegmentTintColor = .white
    segment.backgroundColor = AppTheme.surface
    segment.setTitleTextAttributes(
      [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: AppTheme.ink], for: .normal)
    segment.setTitleTextAttributes(
      [.font: UIFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: AppTheme.ink],
      for: .selected)
    segment.addTarget(self, action: #selector(segmentTap(_:)), for: .valueChanged)
    [avatar, name, bio, stats, segment].forEach(profile.addSubview)
    avatar.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(26)
      $0.top.equalToSuperview().offset(3)
      $0.width.height.equalTo(86)
    }
    name.snp.makeConstraints {
      $0.leading.equalTo(avatar.snp.trailing).offset(19)
      $0.top.equalTo(avatar).offset(10)
      $0.trailing.equalToSuperview().inset(20)
    }
    bio.snp.makeConstraints {
      $0.leading.trailing.equalTo(name)
      $0.top.equalTo(name.snp.bottom).offset(3)
    }
    stats.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(5)
      $0.top.equalToSuperview().offset(112)
      $0.height.equalTo(45)
    }
    segment.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.top.equalToSuperview().offset(170)
      $0.height.equalTo(48)
    }
    return profile
  }

  private func statistic(_ value: String, _ caption: String) -> UIView {
    let container = UIView()
    let number = UIFactory.label(value, size: 17, weight: .semibold)
    number.textAlignment = .center
    let label = UIFactory.label(caption, size: 11, color: AppTheme.secondary)
    label.textAlignment = .center
    container.addSubview(number)
    container.addSubview(label)
    number.snp.makeConstraints {
      $0.top.leading.trailing.equalToSuperview()
      $0.height.equalTo(23)
    }
    label.snp.makeConstraints {
      $0.top.equalTo(number.snp.bottom)
      $0.leading.trailing.bottom.equalToSuperview()
    }
    return container
  }

  private func compactCount(_ value: Int) -> String {
    guard value >= 1000 else { return "\(value)" }
    return String(format: "%.1fK", Double(value) / 1000)
  }

  private func updateFollowButton() {
    let following = AppRepository.shared.isFollowing(userID)
    followButton.setTitle(following ? "Following" : "Follow", for: .normal)
    followButton.backgroundColor =
      following ? UIColor(red: 0.91, green: 0.95, blue: 1, alpha: 1) : AppTheme.blue
    followButton.setTitleColor(following ? AppTheme.blue : .white, for: .normal)
    followButton.layer.borderWidth = following ? 1 : 0
    followButton.layer.borderColor = following ? AppTheme.blue.cgColor : UIColor.clear.cgColor
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    showingMeets ? max(meets.count, 1) : max(posts.count, 1)
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if showingMeets {
      guard meets.indices.contains(indexPath.row) else { return emptyCell("No meets yet") }
      let meet = meets[indexPath.row]
      let cell =
        tableView.dequeueReusableCell(
          withIdentifier: MeetCardCell.reuseIdentifier, for: indexPath) as! MeetCardCell
      cell.configure(meet)
      cell.joinAction = { AppRepository.shared.join(meetID: meet.id) }
      return cell
    }
    guard posts.indices.contains(indexPath.row) else { return emptyCell("No drops yet") }
    let cell =
      tableView.dequeueReusableCell(withIdentifier: "profile-post", for: indexPath)
      as! PostCell
    let post = posts[indexPath.row]
    cell.render(post)
    cell.likeAction = { AppRepository.shared.toggleLike(postID: $0) }
    cell.authorAction = nil
    return cell
  }

  private func emptyCell(_ title: String) -> UITableViewCell {
    let cell = UITableViewCell()
    cell.selectionStyle = .none
    cell.textLabel?.text = title
    cell.textLabel?.font = .systemFont(ofSize: 15)
    cell.textLabel?.textColor = AppTheme.secondary
    cell.textLabel?.textAlignment = .center
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if !showingMeets, posts.indices.contains(indexPath.row) {
      navigationController?.pushViewController(
        PostDetailController(postID: posts[indexPath.row].id), animated: true)
    }
  }

  private func requireLogin() -> Bool {
    guard AppRepository.shared.isAuthenticated else {
      presentSignInRequired()
      return false
    }
    return true
  }

  @objc private func backTap() { navigationController?.popViewController(animated: true) }

  @objc private func segmentTap(_ sender: UISegmentedControl) {
    showingMeets = sender.selectedSegmentIndex == 1
    table.reloadData()
  }

  @objc private func followTap() {
    guard requireLogin() else { return }
    AppRepository.shared.toggleFollow(userID: userID)
  }

  @objc private func openFollowers() {
    navigationController?.pushViewController(
      UserRelationListController(mode: .followers, userID: userID), animated: true)
  }

  @objc private func openFollowing() {
    navigationController?.pushViewController(
      UserRelationListController(mode: .following, userID: userID), animated: true)
  }

  @objc private func messageTap() {
    guard requireLogin() else { return }
    guard AppRepository.shared.mutuallyFollows(userID) else {
      presentBottomSheet(
        title: "Connect to Chat", message: "Follow each other to unlock messages.",
        primary: "OK", secondary: nil
      ) { _ in }
      return
    }
    navigationController?.pushViewController(
      ChatController(conversation: AppRepository.shared.conversation(with: userID)), animated: true)
  }

  @objc private func moreTap() {
    guard requireLogin() else { return }
    presentChoiceSheet(options: ["Report", "Block"]) { [weak self] selection in
      guard let self, let selection else { return }
      if selection == 0 {
        self.navigationController?.pushViewController(
          ReportController(targetID: self.userID), animated: true)
      } else {
        AppRepository.shared.block(userID: self.userID)
        self.navigationController?.popViewController(animated: true)
      }
    }
  }
}

final class MeetDetailController: ScrollPageController {
  private let meetID: String, overlay = StateOverlayView()
  init(meetID: String) {
    self.meetID = meetID
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    configureSecondary(title: "")
    view.addSubview(overlay)
    overlay.snp.makeConstraints { $0.edges.equalTo(view.safeAreaLayoutGuide) }
    overlay.onRetry = { AppRepository.shared.recoverFromParsingError() }
    NotificationCenter.default.addObserver(
      self, selector: #selector(refresh), name: .appDataChanged, object: nil)
    render()
  }
  @objc private func refresh() {
    content.arrangedSubviews.forEach { $0.removeFromSuperview() }
    render()
  }
  private func render() {
    guard AppRepository.shared.state != .parsingError else {
      overlay.render(.parsingError, emptyText: "")
      return
    }
    guard let m = AppRepository.shared.visibleMeets().first(where: { $0.id == meetID }) else {
      overlay.render(.empty, emptyText: "This activity is unavailable")
      return
    }
    overlay.render(.content, emptyText: "")
    let cover = UIImageView()
    if let asset = m.cover {
      cover.image = MediaStore.shared.thumbnail(for: asset)
    } else {
      cover.image = UIImage(named: "Meet")
    }
    cover.contentMode = .scaleAspectFill
    cover.clipsToBounds = true
    cover.layer.cornerRadius = 24
    cover.snp.makeConstraints { $0.height.equalTo(280) }
    content.addArrangedSubview(cover)
    content.addArrangedSubview(UIFactory.label(m.title, size: 24, weight: .semibold))
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    content.addArrangedSubview(
      UIFactory.label(
        "\(formatter.string(from:m.date))\n\(m.participantIDs.count) people · \(max(0,m.capacity-m.participantIDs.count)) spots left\nMeet at \(m.meetingPoint)",
        size: 16, color: AppTheme.secondary, lines: 0))
    if let host = AppRepository.shared.user(m.hostID) {
      let hostButton = UIFactory.button(
        "Hosted by \(host.name)", background: .white, foreground: AppTheme.ink)
      hostButton.addAction(
        UIAction { _ in
          self.navigationController?.pushViewController(
            OtherProfileController(userID: m.hostID), animated: true)
        }, for: .touchUpInside)
      content.addArrangedSubview(hostButton)
    }
    let join = UIFactory.button(
      m.participantIDs.contains(AppRepository.shared.currentUserID ?? "")
        ? "Leave Trip" : "Join Trip", background: AppTheme.blue)
    join.addTarget(self, action: #selector(joinTap), for: .touchUpInside)
    content.addArrangedSubview(join)
  }
  @objc private func joinTap() {
    guard AppRepository.shared.isAuthenticated else {
      presentSignInRequired()
      return
    }
    AppRepository.shared.join(meetID: meetID)
  }
}
