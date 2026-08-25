import SnapKit
import UIKit

private final class ViraaTabBarView: UIView {
  var selection: ((Int) -> Void)?
  private var itemButtons: [UIButton] = []
  private let addButton = UIButton(type: .custom)
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .white
    layer.cornerRadius = 32
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.10
    layer.shadowOffset = .init(width: 0, height: 5)
    layer.shadowRadius = 18

    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.alignment = .fill
    stack.isUserInteractionEnabled = true
    addSubview(stack)
    stack.snp.makeConstraints {
      $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8))
    }

    for visualIndex in 0..<5 {
      let container = UIView()
      container.isUserInteractionEnabled = true
      stack.addArrangedSubview(container)
      if visualIndex == 2 {
        addButton.backgroundColor = AppTheme.blue
        addButton.layer.cornerRadius = 28
        addButton.setImage(
          UIImage(
            systemName: "plus",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)),
          for: .normal)
        addButton.tintColor = .white
        addButton.tag = visualIndex
        addButton.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
        container.addSubview(addButton)
        addButton.snp.makeConstraints {
          $0.center.equalToSuperview()
          $0.width.height.equalTo(56)
        }
      } else {
        let assetIndex = visualIndex < 2 ? visualIndex + 1 : visualIndex
        let button = UIButton(type: .custom)
        button.tag = visualIndex
        button.setImage(
          UIImage(named: "tab\(assetIndex)")?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.setImage(
          UIImage(named: "tab\(assetIndex)_sel")?.withRenderingMode(.alwaysOriginal),
          for: .selected)
        button.imageView?.contentMode = .scaleAspectFit
        button.adjustsImageWhenHighlighted = false
        button.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
        container.addSubview(button)
        button.snp.makeConstraints {
          $0.center.equalToSuperview()
          $0.width.equalTo(50)
          $0.height.equalTo(52)
        }
        itemButtons.append(button)
      }
    }
    setSelected(index: 0)
  }
  required init?(coder: NSCoder) { fatalError() }
  func setSelected(index: Int) {
    for button in itemButtons { button.isSelected = button.tag == index }
  }
  @objc private func tap(_ sender: UIButton) { selection?(sender.tag) }
}

final class MainTabController: UITabBarController, UINavigationControllerDelegate {
  private let customTabBar = ViraaTabBarView()
  private var previousVisualIndex = 0
  override func viewDidLoad() {
    super.viewDidLoad()
    hideSystemTabBar()
    viewControllers = [
      nav(HomeController()), nav(MeetsController()), nav(MessagesController()), nav(MeController()),
    ]
    view.addSubview(customTabBar)
    customTabBar.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(5)
      $0.height.equalTo(73)
    }
    customTabBar.selection = { [weak self] index in self?.selectVisualTab(index) }
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    hideSystemTabBar()
    view.bringSubviewToFront(customTabBar)
  }

  private func hideSystemTabBar() {
    tabBar.isHidden = true
    tabBar.alpha = 0
    tabBar.isUserInteractionEnabled = false
    tabBar.frame = .zero
  }
  private func nav(_ root: UIViewController) -> UINavigationController {
    let n = UINavigationController(rootViewController: root)
    n.navigationBar.tintColor = AppTheme.ink
    n.delegate = self
    return n
  }
  private func selectVisualTab(_ index: Int) {
    if index == 2 {
      if requireLogin() {
        let n = UINavigationController(rootViewController: PublishHubController())
        n.modalPresentationStyle = .fullScreen
        present(n, animated: true)
      }
      return
    }
    if [1, 3, 4].contains(index) && !requireLogin() { return }
    let controllerIndex = index < 2 ? index : index - 1
    selectedIndex = controllerIndex
    previousVisualIndex = index
    customTabBar.isHidden = false
    customTabBar.setSelected(index: index)
    view.bringSubviewToFront(customTabBar)
  }
  private func requireLogin() -> Bool {
    guard !AppRepository.shared.isAuthenticated else { return true }
    customTabBar.setSelected(index: previousVisualIndex)
    presentSignInRequired()
    return false
  }
  func navigationController(
    _ navigationController: UINavigationController, willShow viewController: UIViewController,
    animated: Bool
  ) {
    customTabBar.isHidden = navigationController.viewControllers.first !== viewController
  }
}

final class HomeController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let titleLabel = UIFactory.label("Viraa", size: 27, weight: .bold),
    table = UITableView(frame: .zero, style: .plain), overlay = StateOverlayView()
  private var posts: [Post] = [], category = "All"
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    navigationController?.setNavigationBarHidden(true, animated: false)
    table.backgroundColor = .white
    table.separatorStyle = .none
    table.showsVerticalScrollIndicator = false
    table.contentInset.bottom = 88
    table.rowHeight = UITableView.automaticDimension
    table.estimatedRowHeight = 475
    table.sectionHeaderTopPadding = 0
    table.register(PostCell.self, forCellReuseIdentifier: "post")
    table.dataSource = self
    table.delegate = self
    view.addSubview(titleLabel)
    view.addSubview(table)
    view.addSubview(overlay)
    titleLabel.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide).offset(13)
      $0.leading.equalToSuperview().offset(20)
      $0.height.equalTo(34)
    }
    table.snp.makeConstraints {
      $0.top.equalTo(titleLabel.snp.bottom).offset(5)
      $0.leading.trailing.bottom.equalToSuperview()
    }
    overlay.snp.makeConstraints { $0.edges.equalTo(table) }
    overlay.onRetry = { AppRepository.shared.recoverFromParsingError() }
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
  @objc private func reload() {
    posts = AppRepository.shared.visiblePosts(category: category)
    let repositoryState = AppRepository.shared.state
    overlay.render(repositoryState == .empty ? .content : repositoryState, emptyText: "")
    makeHeader()
    table.reloadData()
  }
  private func makeHeader() {
    let bannerHeight = (view.bounds.width - 40) * 224 / 670
    let header = HomeTopHeader(
      frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: bannerHeight + 112))
    // Keep the initial four story users fixed; later registrations or data changes
    // must not add people to this row.
    let initialStoryIDs = Set(["emma", "lucas", "sofia", "julian"])
    let storyUsers = AppRepository.shared.visibleUsers()
      .filter { initialStoryIDs.contains($0.id) }
    header.configure(users: storyUsers)
    header.aiAction = { [weak self] in
      guard AppRepository.shared.isAuthenticated else {
        self?.loginRequired()
        return
      }
      self?.navigationController?.pushViewController(AIChatController(), animated: true)
    }
    header.userAction = { [weak self] id in
      guard AppRepository.shared.isAuthenticated else {
        self?.presentSignInRequired()
        return
      }
      self?.navigationController?.pushViewController(
        OtherProfileController(userID: id), animated: true)
    }
    table.tableHeaderView = header
  }
  func numberOfSections(in tableView: UITableView) -> Int { 1 }
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    max(posts.count, 1)
  }
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 58 }
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let header = CategoryStrip()
    header.configure(values: AppRepository.shared.categories, selected: category)
    header.selection = { [weak self] value in
      self?.selectCategory(value)
    }
    return header
  }
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard !posts.isEmpty else {
      let cell = UITableViewCell()
      cell.selectionStyle = .none
      cell.backgroundColor = .white
      let label = UIFactory.label("No drops yet", size: 15, color: AppTheme.secondary)
      label.textAlignment = .center
      cell.contentView.addSubview(label)
      label.snp.makeConstraints {
        $0.top.equalToSuperview().offset(110)
        $0.leading.trailing.equalToSuperview().inset(20)
        $0.bottom.equalToSuperview().offset(-110)
      }
      return cell
    }
    let post = posts[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: "post", for: indexPath) as! PostCell
    cell.render(post)
    cell.likeAction = { [weak self] id in
      guard AppRepository.shared.isAuthenticated else {
        self?.loginRequired()
        return
      }
      AppRepository.shared.toggleLike(postID: id)
    }
    cell.authorAction = { [weak self] id in
      self?.navigationController?.pushViewController(
        OtherProfileController(userID: id), animated: true)
    }
    return cell
  }
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard !posts.isEmpty else { return }
    guard AppRepository.shared.isAuthenticated else {
      loginRequired()
      return
    }
    navigationController?.pushViewController(
      PostDetailController(postID: posts[indexPath.row].id), animated: true)
  }
  private func selectCategory(_ value: String) {
    guard category != value else { return }
    let previousOffset = (table.headerView(forSection: 0) as? CategoryStrip)?.horizontalOffset ?? 0
    category = value
    posts = AppRepository.shared.visiblePosts(category: value)
    // Refresh only the post list without animating/rebuilding the category header.
    UIView.performWithoutAnimation {
      table.reloadData()
      table.layoutIfNeeded()
    }
    DispatchQueue.main.async { [weak self] in
      guard let self, let header = self.table.headerView(forSection: 0) as? CategoryStrip
      else { return }
      header.restore(horizontalOffset: previousOffset)
    }
  }
  private func loginRequired() {
    presentSignInRequired()
  }
}

private final class HomeTopHeader: UIView {
  var aiAction: (() -> Void)?, userAction: ((String) -> Void)?
  private let banner = UIButton(type: .custom), scroll = UIScrollView(), row = UIStackView()
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .white
    banner.setBackgroundImage(UIImage(named: "image/ai_bg"), for: .normal)
    banner.adjustsImageWhenHighlighted = false
    banner.clipsToBounds = true
    banner.layer.cornerRadius = 24
    banner.addTarget(self, action: #selector(aiTap), for: .touchUpInside)
    scroll.showsHorizontalScrollIndicator = false
    row.axis = .horizontal
    row.spacing = 14
    scroll.addSubview(row)
    addSubview(banner)
    addSubview(scroll)
    banner.snp.makeConstraints {
      $0.top.equalToSuperview().offset(8)
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.height.equalTo(banner.snp.width).multipliedBy(224.0 / 670.0)
    }
    scroll.snp.makeConstraints {
      $0.top.equalTo(banner.snp.bottom).offset(8)
      $0.leading.trailing.equalToSuperview()
      $0.height.equalTo(96)
    }
    row.snp.makeConstraints {
      $0.top.bottom.equalToSuperview()
      $0.leading.equalToSuperview().offset(20)
      $0.trailing.equalToSuperview().offset(-20)
      $0.height.equalToSuperview()
    }
  }
  required init?(coder: NSCoder) { fatalError() }
  func configure(users: [User]) {
    row.arrangedSubviews.forEach { $0.removeFromSuperview() }
    for user in users {
      let item = UIView()
      let avatar = UIButton(type: .custom)
      let name = UIFactory.label(user.name, size: 11, color: AppTheme.secondary)
      avatar.accessibilityIdentifier = user.id
      let fallback = UIImage(systemName: "person.crop.circle.fill")
      avatar.setImage(
        user.avatar.flatMap { MediaStore.shared.thumbnail(for: $0) } ?? fallback, for: .normal)
      avatar.imageView?.contentMode = .scaleAspectFill
      avatar.tintColor = UIColor(white: 0.62, alpha: 1)
      avatar.layer.cornerRadius = 28
      avatar.layer.borderWidth = 2
      avatar.layer.borderColor = AppTheme.blue.cgColor
      avatar.clipsToBounds = true
      avatar.addTarget(self, action: #selector(userTap(_:)), for: .touchUpInside)
      name.textAlignment = .center
      item.addSubview(avatar)
      item.addSubview(name)
      avatar.snp.makeConstraints {
        $0.top.centerX.equalToSuperview()
        $0.width.height.equalTo(56)
      }
      name.snp.makeConstraints {
        $0.top.equalTo(avatar.snp.bottom).offset(6)
        $0.leading.trailing.bottom.equalToSuperview()
      }
      item.snp.makeConstraints { $0.width.equalTo(60) }
      row.addArrangedSubview(item)
    }
  }
  @objc private func aiTap() { aiAction?() }
  @objc private func userTap(_ sender: UIButton) {
    if let id = sender.accessibilityIdentifier { userAction?(id) }
  }
}

private final class CategoryStrip: UIView {
  var selection: ((String) -> Void)?
  private let scroll = UIScrollView(), row = UIStackView()
  var horizontalOffset: CGFloat { scroll.contentOffset.x }
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .white
    scroll.showsHorizontalScrollIndicator = false
    row.spacing = 8
    scroll.addSubview(row)
    addSubview(scroll)
    scroll.snp.makeConstraints { $0.edges.equalToSuperview() }
    row.snp.makeConstraints {
      $0.leading.equalTo(scroll.contentLayoutGuide).offset(20)
      $0.trailing.equalTo(scroll.contentLayoutGuide).offset(-20)
      $0.centerY.equalTo(scroll.frameLayoutGuide)
      $0.height.equalTo(34)
    }
  }
  required init?(coder: NSCoder) { fatalError() }
  func configure(values: [String], selected: String) {
    row.arrangedSubviews.forEach { $0.removeFromSuperview() }
    for value in values {
      var config = UIButton.Configuration.filled()
      config.title = value
      config.baseBackgroundColor = value == selected ? AppTheme.blue : AppTheme.surface
      config.baseForegroundColor = value == selected ? .white : AppTheme.ink
      config.cornerStyle = .capsule
      config.contentInsets = .init(top: 8, leading: 14, bottom: 8, trailing: 14)
      config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
        incoming in
        var outgoing = incoming
        outgoing.font = .systemFont(ofSize: 13, weight: .regular)
        return outgoing
      }
      let button = UIButton(configuration: config)
      button.titleLabel?.numberOfLines = 1
      button.titleLabel?.lineBreakMode = .byClipping
      button.accessibilityIdentifier = value
      button.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
      let textWidth = ceil(
        (value as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 13)]).width)
      button.snp.makeConstraints { $0.width.equalTo(textWidth + 28) }
      row.addArrangedSubview(button)
    }
  }
  func restore(horizontalOffset: CGFloat) {
    layoutIfNeeded()
    let maxOffset = max(0, scroll.contentSize.width - scroll.bounds.width)
    scroll.setContentOffset(CGPoint(x: min(max(0, horizontalOffset), maxOffset), y: 0), animated: false)
  }
  @objc private func tap(_ sender: UIButton) {
    if let value = sender.accessibilityIdentifier { selection?(value) }
  }
}

final class PostCell: UITableViewCell {
  var likeAction: ((String) -> Void)?, authorAction: ((String) -> Void)?
  private var postID = "", authorID = ""
  private let card = UIView(), hero = UIFactory.image("image/lau", corner: 26),
    play = UIImageView(image: UIImage(systemName: "play.fill")), avatar = UIImageView(),
    author = UIFactory.label(size: 17, weight: .semibold),
    meta = UIFactory.label(size: 12, color: AppTheme.secondary),
    categoryLabel = UIFactory.label(size: 13, weight: .medium, color: AppTheme.blue),
    heading = UIFactory.label(size: 18, weight: .medium),
    body = UIFactory.label(size: 14, lines: 2), like = UIButton(type: .system),
    comment = UIButton(type: .system), more = UIFactory.label("·· More", size: 12, weight: .medium)
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    backgroundColor = .white
    card.backgroundColor = .white
    card.layer.cornerRadius = 26
    card.layer.shadowColor = UIColor.black.cgColor
    card.layer.shadowOpacity = 0.08
    card.layer.shadowOffset = .init(width: 0, height: 8)
    card.layer.shadowRadius = 18
    hero.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    play.tintColor = UIColor.white.withAlphaComponent(0.88)
    play.contentMode = .scaleAspectFit
    avatar.contentMode = .scaleAspectFill
    avatar.clipsToBounds = true
    avatar.layer.cornerRadius = 20
    let authorText = UIStackView(arrangedSubviews: [author, meta])
    authorText.axis = .vertical
    authorText.spacing = 2
    let authorRow = UIStackView(arrangedSubviews: [avatar, authorText])
    authorRow.spacing = 10
    authorRow.alignment = .center
    let actions = UIStackView(arrangedSubviews: [more, UIView(), like, comment])
    actions.spacing = 12
    actions.alignment = .center
    let details = UIStackView(arrangedSubviews: [authorRow, categoryLabel, heading, body, actions])
    details.axis = .vertical
    details.spacing = 7
    details.isLayoutMarginsRelativeArrangement = true
    details.layoutMargins = .init(top: 14, left: 18, bottom: 16, right: 18)
    card.addSubview(hero)
    card.addSubview(play)
    card.addSubview(details)
    contentView.addSubview(card)
    card.snp.makeConstraints {
      $0.top.equalToSuperview().offset(5)
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.bottom.equalToSuperview().offset(-13)
    }
    hero.snp.makeConstraints {
      $0.top.leading.trailing.equalToSuperview()
      $0.height.equalTo(250)
    }
    play.snp.makeConstraints {
      $0.center.equalTo(hero)
      $0.width.equalTo(48)
      $0.height.equalTo(58)
    }
    details.snp.makeConstraints {
      $0.top.equalTo(hero.snp.bottom)
      $0.leading.trailing.bottom.equalToSuperview()
    }
    avatar.snp.makeConstraints { $0.width.height.equalTo(40) }
    like.tintColor = AppTheme.ink
    comment.tintColor = AppTheme.ink
    like.titleLabel?.font = .systemFont(ofSize: 11)
    comment.titleLabel?.font = .systemFont(ofSize: 11)
    like.addTarget(self, action: #selector(likeTap), for: .touchUpInside)
    authorRow.isUserInteractionEnabled = true
    authorRow.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(authorTap)))
  }
  required init?(coder: NSCoder) { fatalError() }
  func render(_ p: Post) {
    postID = p.id
    authorID = p.authorID
    more.isHidden = p.authorID == AppRepository.shared.currentUserID
    let user = AppRepository.shared.user(p.authorID)
    author.text = user?.name
    avatar.image =
      user?.avatar.flatMap { MediaStore.shared.thumbnail(for: $0) }
        ?? UIImage(systemName: "person.crop.circle.fill")
    avatar.tintColor = UIColor(white: 0.62, alpha: 1)
    let formatter = RelativeDateTimeFormatter()
    meta.text = "\(formatter.localizedString(for:p.createdAt,relativeTo:Date())) · \(p.location)"
    categoryLabel.text = "\(p.category)  ·  \(p.difficulty)"
    heading.text = p.title
    body.text = p.body
    let liked = AppRepository.shared.isLiked(p.id)
    like.setImage(UIImage(named: "image/good")?.withRenderingMode(.alwaysTemplate), for: .normal)
    like.tintColor = liked ? AppTheme.blue : AppTheme.ink
    like.setTitle("  \(AppRepository.shared.filteredLikeCount(postID: p.id))", for: .normal)
    like.setTitleColor(liked ? AppTheme.blue : AppTheme.ink, for: .normal)
    comment.setImage(UIImage(named: "image/msg")?.withRenderingMode(.alwaysOriginal), for: .normal)
    comment.setTitle("  Comment  (\(AppRepository.shared.visibleComments(p).count))", for: .normal)
    hero.image =
      p.media.first.flatMap { MediaStore.shared.thumbnail(for: $0) }
      ?? UIImage(named: "image/lau")
    play.isHidden = p.media.first?.kind == .image
  }
  @objc private func likeTap() { likeAction?(postID) }
  @objc private func authorTap() { authorAction?(authorID) }
}

final class MeetCardCell: UITableViewCell {
  static let reuseIdentifier = "meet-card"
  var joinAction: (() -> Void)?
  private let card = UIView(), cover = UIImageView(),
    titleLabel = UIFactory.label(
      size: 18, weight: .semibold)
  private let dateLabel = UIFactory.label(size: 11, weight: .medium, color: AppTheme.blue)
  private let peopleLabel = UIFactory.label(size: 14, color: AppTheme.secondary)
  private let pointLabel = UIFactory.label(size: 14, color: AppTheme.secondary)
  private let hostAvatar = UIImageView(), hostLabel = UIFactory.label(size: 14)
  private let joinButton = UIButton(type: .system)

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    backgroundColor = .white
    card.backgroundColor = .white
    card.layer.cornerRadius = 26
    card.layer.shadowColor = UIColor.black.cgColor
    card.layer.shadowOpacity = 0.07
    card.layer.shadowOffset = .init(width: 0, height: 8)
    card.layer.shadowRadius = 18
    cover.contentMode = .scaleAspectFill
    cover.clipsToBounds = true
    cover.layer.cornerRadius = 26
    cover.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    hostAvatar.contentMode = .scaleAspectFill
    hostAvatar.clipsToBounds = true
    hostAvatar.layer.cornerRadius = 16
    joinButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
    joinButton.layer.cornerRadius = 22
    joinButton.addTarget(self, action: #selector(joinTap), for: .touchUpInside)
    contentView.addSubview(card)
    [cover, titleLabel, dateLabel, peopleLabel, pointLabel, hostAvatar, hostLabel, joinButton]
      .forEach(
        card.addSubview)
    card.snp.makeConstraints {
      $0.top.equalToSuperview().offset(5)
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.bottom.equalToSuperview().inset(13)
    }
    cover.snp.makeConstraints {
      $0.top.leading.trailing.equalToSuperview()
      $0.height.equalTo(205)
    }
    titleLabel.snp.makeConstraints {
      $0.top.equalTo(cover.snp.bottom).offset(17)
      $0.leading.trailing.equalToSuperview().inset(18)
      $0.height.equalTo(23)
    }
    dateLabel.snp.makeConstraints {
      $0.top.equalTo(titleLabel.snp.bottom).offset(6)
      $0.leading.trailing.equalTo(titleLabel)
      $0.height.equalTo(16)
    }
    peopleLabel.snp.makeConstraints {
      $0.top.equalTo(dateLabel.snp.bottom).offset(6)
      $0.leading.trailing.equalTo(titleLabel)
      $0.height.equalTo(19)
    }
    pointLabel.snp.makeConstraints {
      $0.top.equalTo(peopleLabel.snp.bottom).offset(7)
      $0.leading.trailing.equalTo(titleLabel)
      $0.height.equalTo(19)
    }
    hostAvatar.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(18)
      $0.top.equalTo(pointLabel.snp.bottom).offset(15)
      $0.width.height.equalTo(32)
      $0.bottom.equalToSuperview().inset(17)
    }
    hostLabel.snp.makeConstraints {
      $0.leading.equalTo(hostAvatar.snp.trailing).offset(8)
      $0.centerY.equalTo(hostAvatar)
      $0.trailing.lessThanOrEqualTo(joinButton.snp.leading).offset(-10)
    }
    joinButton.snp.makeConstraints {
      $0.trailing.equalToSuperview().inset(18)
      $0.centerY.equalTo(hostAvatar)
      $0.width.equalTo(104)
      $0.height.equalTo(45)
    }
  }

  required init?(coder: NSCoder) { fatalError() }

  func configure(_ meet: Meet) {
    titleLabel.text = meet.title
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE · MMM d · h:mm a"
    dateLabel.text = formatter.string(from: meet.date).uppercased()
    peopleLabel.text =
      "\(meet.capacity) people · \(max(0, meet.capacity - meet.participantIDs.count)) spots left"
    pointLabel.text = "Meet at \(meet.meetingPoint)"
    let host = AppRepository.shared.user(meet.hostID)
    hostLabel.text = "Hosted by \(host?.name ?? "Explorer")"
    if let asset = meet.cover, let image = MediaStore.shared.thumbnail(for: asset) {
      cover.image = image
      cover.contentMode = .scaleAspectFill
      cover.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    } else {
      cover.image = UIImage(named: "Meet")
      cover.contentMode = .scaleToFill
      cover.layer.contentsRect = CGRect(
        x: 20.0 / 375.0, y: 146.0 / 812.0, width: 335.0 / 375.0,
        height: 205.0 / 812.0)
    }
    if let avatar = host?.avatar, let image = MediaStore.shared.thumbnail(for: avatar) {
      hostAvatar.image = image
      hostAvatar.contentMode = .scaleAspectFill
      hostAvatar.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    } else {
      hostAvatar.image = UIImage(named: "Meet")
      hostAvatar.contentMode = .scaleToFill
      hostAvatar.layer.contentsRect = CGRect(
        x: 38.0 / 375.0, y: 485.0 / 812.0, width: 32.0 / 375.0,
        height: 32.0 / 812.0)
    }
    let joined = meet.participantIDs.contains(AppRepository.shared.currentUserID ?? "")
    joinButton.setTitle(joined ? "Joined" : "Join Trip", for: .normal)
    joinButton.backgroundColor =
      joined ? UIColor(red: 0.91, green: 0.95, blue: 1, alpha: 1) : AppTheme.blue
    joinButton.setTitleColor(joined ? AppTheme.blue : .white, for: .normal)
    joinButton.layer.borderWidth = joined ? 1 : 0
    joinButton.layer.borderColor = joined ? AppTheme.blue.cgColor : UIColor.clear.cgColor
  }

  @objc private func joinTap() { joinAction?() }
}

final class MeetsController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let titleLabel = UIFactory.label("Water Meets", size: 27, weight: .bold)
  private let subtitleLabel = UIFactory.label(
    "Small groups. Real places. Safer together.", size: 16, color: AppTheme.secondary)
  private let hostButton = UIButton(type: .system), costBadge = CoinBadgeView()
  private let table = UITableView(frame: .zero, style: .plain), overlay = StateOverlayView()
  private var items: [Meet] = []

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    navigationController?.setNavigationBarHidden(true, animated: false)
    configureHostButton()
    table.backgroundColor = .white
    table.separatorStyle = .none
    table.showsVerticalScrollIndicator = false
    table.contentInset.bottom = 88
    table.rowHeight = UITableView.automaticDimension
    table.estimatedRowHeight = 414
    table.register(MeetCardCell.self, forCellReuseIdentifier: MeetCardCell.reuseIdentifier)
    table.dataSource = self
    table.delegate = self
    [titleLabel, subtitleLabel, hostButton, costBadge, table, overlay].forEach(view.addSubview)
    titleLabel.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide).offset(13)
      $0.leading.equalToSuperview().offset(20)
      $0.height.equalTo(34)
    }
    hostButton.snp.makeConstraints {
      $0.trailing.equalToSuperview().inset(20)
      $0.centerY.equalTo(titleLabel)
      $0.width.equalTo(105)
      $0.height.equalTo(34)
    }
    costBadge.snp.makeConstraints {
      $0.trailing.equalTo(hostButton).offset(1)
      $0.top.equalTo(hostButton).offset(-5)
      $0.width.equalTo(34)
      $0.height.equalTo(12)
    }
    subtitleLabel.snp.makeConstraints {
      $0.top.equalTo(titleLabel.snp.bottom).offset(11)
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.height.equalTo(22)
    }
    table.snp.makeConstraints {
      $0.top.equalTo(subtitleLabel.snp.bottom).offset(8)
      $0.leading.trailing.bottom.equalToSuperview()
    }
    overlay.snp.makeConstraints { $0.edges.equalTo(table) }
    overlay.onRetry = { AppRepository.shared.recoverFromParsingError() }
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

  private func configureHostButton() {
    hostButton.backgroundColor = AppTheme.blue
    hostButton.setTitle("Host a Meet", for: .normal)
    hostButton.setTitleColor(.white, for: .normal)
    hostButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
    hostButton.layer.cornerRadius = 17
    hostButton.addTarget(self, action: #selector(host), for: .touchUpInside)
    costBadge.configure(value: AppRepository.shared.hostMeetCost, fontSize: 7)
  }

  @objc private func reload() {
    items = AppRepository.shared.visibleMeets()
    let state = AppRepository.shared.state
    overlay.render(
      state == .content && items.isEmpty ? .empty : state, emptyText: "No activities yet")
    table.reloadData()
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    items.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell =
      tableView.dequeueReusableCell(
        withIdentifier: MeetCardCell.reuseIdentifier, for: indexPath) as! MeetCardCell
    let meet = items[indexPath.row]
    cell.configure(meet)
    cell.joinAction = { [weak self] in self?.join(meetID: meet.id) }
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    // Water Meet cards are action-only; joining is handled by the button.
  }

  private func join(meetID: String) {
    guard AppRepository.shared.isAuthenticated else {
      presentSignInRequired()
      return
    }
    AppRepository.shared.join(meetID: meetID)
  }

  @objc private func host() {
    guard AppRepository.shared.isAuthenticated else {
      presentSignInRequired()
      return
    }
    let publish = PublishHubController()
    publish.initialMeetMode = true
    let navigation = UINavigationController(rootViewController: publish)
    navigation.modalPresentationStyle = .fullScreen
    present(navigation, animated: true)
  }
}

private final class ConversationListCell: UITableViewCell {
  static let reuseIdentifier = "conversation"
  private let avatarView = UIImageView(), nameLabel = UIFactory.label(size: 16, weight: .medium)
  private let previewLabel = UIFactory.label(size: 14, color: AppTheme.secondary)
  private let timeLabel = UIFactory.label(size: 12, color: AppTheme.secondary)
  private let unreadDot = UIView()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    backgroundColor = .white
    avatarView.contentMode = .scaleAspectFill
    avatarView.clipsToBounds = true
    avatarView.layer.cornerRadius = 26
    previewLabel.lineBreakMode = .byTruncatingTail
    timeLabel.textAlignment = .right
    unreadDot.backgroundColor = AppTheme.danger
    unreadDot.layer.cornerRadius = 4
    [avatarView, nameLabel, previewLabel, timeLabel, unreadDot].forEach(contentView.addSubview)
    avatarView.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(20)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(52)
    }
    nameLabel.snp.makeConstraints {
      $0.leading.equalTo(avatarView.snp.trailing).offset(12)
      $0.top.equalTo(avatarView).offset(5)
      $0.trailing.lessThanOrEqualTo(timeLabel.snp.leading).offset(-12)
    }
    previewLabel.snp.makeConstraints {
      $0.leading.equalTo(nameLabel)
      $0.top.equalTo(nameLabel.snp.bottom).offset(3)
      $0.trailing.lessThanOrEqualTo(timeLabel.snp.leading).offset(-12)
    }
    timeLabel.snp.makeConstraints {
      $0.trailing.equalToSuperview().inset(24)
      $0.top.equalTo(avatarView).offset(7)
      $0.width.greaterThanOrEqualTo(28)
    }
    unreadDot.snp.makeConstraints {
      $0.centerX.equalTo(timeLabel)
      $0.top.equalTo(timeLabel.snp.bottom).offset(8)
      $0.width.height.equalTo(8)
    }
  }

  required init?(coder: NSCoder) { fatalError() }

  func configure(user: User?, message: ChatMessage?, time: String, unread: Bool) {
    nameLabel.text = user?.name ?? "Explorer"
    switch message?.kind {
    case .text: previewLabel.text = message?.body
    case .image: previewLabel.text = "Sent a photo"
    case .voice: previewLabel.text = "Voice message"
    case nil: previewLabel.text = "Start a conversation"
    }
    timeLabel.text = time
    unreadDot.isHidden = !unread
    if let avatar = user?.avatar, let image = MediaStore.shared.thumbnail(for: avatar) {
      avatarView.image = image
    } else {
      avatarView.image =
        UIImage(systemName: "person.crop.circle.fill")
      avatarView.tintColor = UIColor(white: 0.62, alpha: 1)
    }
  }
}

final class MessagesController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let titleLabel = UIFactory.label("Messages", size: 27, weight: .bold)
  private let table = UITableView(frame: .zero, style: .plain), overlay = StateOverlayView()
  private let bannerButton = UIButton(type: .custom)
  private var items: [Conversation] = []
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    navigationController?.setNavigationBarHidden(true, animated: false)
    table.backgroundColor = .white
    table.dataSource = self
    table.delegate = self
    table.separatorStyle = .none
    table.showsVerticalScrollIndicator = false
    table.rowHeight = 90
    table.contentInset.bottom = 88
    table.register(
      ConversationListCell.self, forCellReuseIdentifier: ConversationListCell.reuseIdentifier)
    configureBanner()
    view.addSubview(titleLabel)
    view.addSubview(table)
    view.addSubview(overlay)
    titleLabel.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide).offset(13)
      $0.leading.equalToSuperview().offset(20)
      $0.height.equalTo(34)
    }
    table.snp.makeConstraints {
      $0.top.equalTo(titleLabel.snp.bottom).offset(5)
      $0.leading.trailing.bottom.equalToSuperview()
    }
    overlay.snp.makeConstraints { $0.edges.equalTo(table) }
    overlay.onRetry = { AppRepository.shared.recoverFromParsingError() }
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
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard let header = table.tableHeaderView else { return }
    let height = max(128, (table.bounds.width - 40) * 112 / 335 + 16)
    if header.frame.width != table.bounds.width || header.frame.height != height {
      header.frame = CGRect(x: 0, y: 0, width: table.bounds.width, height: height)
      bannerButton.frame = CGRect(x: 20, y: 8, width: table.bounds.width - 40, height: height - 16)
      table.tableHeaderView = header
    }
  }
  private func configureBanner() {
    bannerButton.setBackgroundImage(UIImage(named: "image/ai_bg"), for: .normal)
    bannerButton.layer.cornerRadius = 24
    bannerButton.clipsToBounds = true
    bannerButton.addTarget(self, action: #selector(openAI), for: .touchUpInside)
    let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 128))
    header.backgroundColor = .white
    bannerButton.frame = CGRect(x: 20, y: 8, width: max(1, view.bounds.width - 40), height: 112)
    header.addSubview(bannerButton)
    table.tableHeaderView = header
  }
  @objc private func openAI() {
    navigationController?.pushViewController(AIChatController(), animated: true)
  }
  @objc private func reload() {
    items = AppRepository.shared.visibleConversations()
    let state = AppRepository.shared.state
    overlay.render(state == .empty ? .content : state, emptyText: "")
    table.reloadData()
  }
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    max(items.count, 1)
  }
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard items.indices.contains(indexPath.row) else {
      let cell = UITableViewCell()
      cell.selectionStyle = .none
      cell.textLabel?.text = "No conversations yet"
      cell.textLabel?.font = .systemFont(ofSize: 15)
      cell.textLabel?.textColor = AppTheme.secondary
      cell.textLabel?.textAlignment = .center
      return cell
    }
    let conversation = items[indexPath.row]
    let other = conversation.participantIDs.first { $0 != AppRepository.shared.currentUserID }
    let message = AppRepository.shared.visibleMessages(conversationID: conversation.id).last
    let unread = conversation.unreadByUser[AppRepository.shared.currentUserID ?? ""] ?? 0
    let cell =
      tableView.dequeueReusableCell(
        withIdentifier: ConversationListCell.reuseIdentifier, for: indexPath)
      as! ConversationListCell
    cell.configure(
      user: other.flatMap { AppRepository.shared.user($0) }, message: message,
      time: message.map { relativeTime($0.createdAt) } ?? "", unread: unread > 0)
    return cell
  }
  private func relativeTime(_ date: Date) -> String {
    let interval = max(0, Date().timeIntervalSince(date))
    if interval < 3600 { return "\(max(1, Int(interval / 60)))m" }
    if interval < 86_400 { return "\(Int(interval / 3600))h" }
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE"
    return formatter.string(from: date)
  }
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard items.indices.contains(indexPath.row) else { return }
    AppRepository.shared.markConversationRead(items[indexPath.row].id)
    navigationController?.pushViewController(
      ChatController(conversation: items[indexPath.row]), animated: true)
  }
}

final class MeController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let titleLabel = UIFactory.label("Me", size: 27, weight: .bold)
  private let table = UITableView(frame: .zero, style: .plain), overlay = StateOverlayView()
  private var showsMeets = false, posts: [Post] = [], meets: [Meet] = []

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    navigationController?.setNavigationBarHidden(true, animated: false)
    table.backgroundColor = .white
    table.separatorStyle = .none
    table.showsVerticalScrollIndicator = false
    table.contentInset.bottom = 88
    table.rowHeight = UITableView.automaticDimension
    table.estimatedRowHeight = 475
    table.register(PostCell.self, forCellReuseIdentifier: "post")
    table.register(MeetCardCell.self, forCellReuseIdentifier: MeetCardCell.reuseIdentifier)
    table.dataSource = self
    table.delegate = self
    view.addSubview(titleLabel)
    view.addSubview(table)
    view.addSubview(overlay)
    titleLabel.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide).offset(13)
      $0.leading.equalToSuperview().offset(20)
      $0.height.equalTo(34)
    }
    table.snp.makeConstraints {
      $0.top.equalTo(titleLabel.snp.bottom).offset(5)
      $0.leading.trailing.bottom.equalToSuperview()
    }
    overlay.snp.makeConstraints { $0.edges.equalTo(table) }
    overlay.onRetry = { AppRepository.shared.recoverFromParsingError() }
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
    guard let header = table.tableHeaderView, header.frame.width != table.bounds.width else {
      return
    }
    header.frame.size.width = table.bounds.width
    table.tableHeaderView = header
  }

  @objc private func refresh() {
    guard AppRepository.shared.state != .parsingError else {
      overlay.render(.parsingError, emptyText: "")
      return
    }
    guard let user = AppRepository.shared.currentUser else {
      overlay.render(.empty, emptyText: "Sign in to view your profile")
      return
    }
    overlay.render(.content, emptyText: "")
    posts = AppRepository.shared.visiblePosts(authorID: user.id)
    meets = AppRepository.shared.visibleJoinedMeets(userID: user.id)
    makeHeader(user)
    table.reloadData()
  }

  private func makeHeader(_ user: User) {
    let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 410))
    header.backgroundColor = .white

    let avatar = UIImageView(
      image: user.avatar.flatMap { MediaStore.shared.thumbnail(for: $0) }
        ?? UIImage(systemName: "person.crop.circle.fill"))
    avatar.contentMode = .scaleAspectFill
    avatar.tintColor = UIColor(white: 0.62, alpha: 1)
    avatar.clipsToBounds = true
    avatar.layer.cornerRadius = 44
    let name = UIFactory.label(user.name, size: 22, weight: .semibold)
    let bio = UIFactory.label(user.bio, size: 16, color: AppTheme.secondary, lines: 2)

    let likes = posts.reduce(0) {
      $0 + AppRepository.shared.filteredLikeCount(postID: $1.id)
    }
    let likesStat = statistic("\(likes)", "Likes")
    let followersStat = statistic(
      compactCount(AppRepository.shared.followersCount(userID: user.id)), "Followers")
    let followingStat = statistic(
      compactCount(AppRepository.shared.followingCount(userID: user.id)), "Following")
    followersStat.isUserInteractionEnabled = true
    followingStat.isUserInteractionEnabled = true
    followersStat.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(openFollowers)))
    followingStat.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(openFollowing)))
    let stats = UIStackView(arrangedSubviews: [likesStat, followersStat, followingStat])
    stats.distribution = .fillEqually

    let settings = profileButton("Settings", action: #selector(settingsTap))
    let edit = profileButton("Edit Profile", action: #selector(editTap))
    let actions = UIStackView(arrangedSubviews: [settings, edit])
    actions.distribution = .fillEqually
    actions.spacing = 8

    let wallet = UIButton(type: .custom)
    wallet.layer.cornerRadius = 24
    wallet.clipsToBounds = true
    wallet.addTarget(self, action: #selector(recharge), for: .touchUpInside)
    let walletBackground = UIImageView(image: UIImage(named: "coin_banner_bg"))
    walletBackground.contentMode = .scaleAspectFill
    walletBackground.clipsToBounds = true
    walletBackground.isUserInteractionEnabled = false
    let balanceTitle = UIFactory.label("COIN BALANCE", size: 11, color: .white)
    let balance = UIFactory.label(
      "\(AppRepository.shared.wallet.coins.formatted()) coins", size: 20, weight: .medium,
      color: .white)
    wallet.addSubview(walletBackground)
    wallet.addSubview(balanceTitle)
    wallet.addSubview(balance)

    let segment = UISegmentedControl(items: ["My Drops", "My Meets"])
    segment.selectedSegmentIndex = showsMeets ? 1 : 0
    segment.selectedSegmentTintColor = .white
    segment.backgroundColor = AppTheme.surface
    segment.setTitleTextAttributes(
      [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: AppTheme.ink], for: .normal)
    segment.setTitleTextAttributes(
      [.font: UIFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: AppTheme.ink],
      for: .selected)
    segment.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)

    [avatar, name, bio, stats, actions, wallet, segment].forEach(header.addSubview)
    avatar.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(20)
      $0.top.equalToSuperview().offset(17)
      $0.width.height.equalTo(88)
    }
    name.snp.makeConstraints {
      $0.leading.equalTo(avatar.snp.trailing).offset(16)
      $0.top.equalTo(avatar).offset(10)
      $0.trailing.equalToSuperview().inset(20)
    }
    bio.snp.makeConstraints {
      $0.leading.trailing.equalTo(name)
      $0.top.equalTo(name.snp.bottom).offset(3)
    }
    stats.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(5)
      $0.top.equalToSuperview().offset(132)
      $0.height.equalTo(45)
    }
    actions.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.top.equalToSuperview().offset(194)
      $0.height.equalTo(44)
    }
    wallet.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.top.equalToSuperview().offset(254)
      $0.height.equalTo(86)
    }
    walletBackground.snp.makeConstraints { $0.edges.equalToSuperview() }
    balanceTitle.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(26)
      $0.top.equalToSuperview().offset(14)
    }
    balance.snp.makeConstraints {
      $0.leading.equalTo(balanceTitle)
      $0.top.equalTo(balanceTitle.snp.bottom).offset(1)
    }
    segment.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.top.equalToSuperview().offset(352)
      $0.height.equalTo(48)
    }
    table.tableHeaderView = header
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

  private func profileButton(_ title: String, action: Selector) -> UIButton {
    let button = UIButton(type: .system)
    button.backgroundColor = AppTheme.surface
    button.setTitle(title, for: .normal)
    button.setTitleColor(AppTheme.ink, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
    button.layer.cornerRadius = 22
    button.addTarget(self, action: action, for: .touchUpInside)
    return button
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    showsMeets ? max(meets.count, 1) : max(posts.count, 1)
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if showsMeets {
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
    let cell = tableView.dequeueReusableCell(withIdentifier: "post", for: indexPath) as! PostCell
    let post = posts[indexPath.row]
    cell.render(post)
    cell.likeAction = { AppRepository.shared.toggleLike(postID: $0) }
    cell.authorAction = { [weak self] _ in
      self?.navigationController?.pushViewController(
        OtherProfileController(userID: post.authorID), animated: true)
    }
    return cell
  }

  private func emptyCell(_ text: String) -> UITableViewCell {
    let cell = UITableViewCell()
    cell.selectionStyle = .none
    cell.textLabel?.text = text
    cell.textLabel?.font = .systemFont(ofSize: 15)
    cell.textLabel?.textColor = AppTheme.secondary
    cell.textLabel?.textAlignment = .center
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if !showsMeets, posts.indices.contains(indexPath.row) {
      navigationController?.pushViewController(
        PostDetailController(postID: posts[indexPath.row].id), animated: true)
    }
  }

  @objc private func segmentChanged(_ sender: UISegmentedControl) {
    showsMeets = sender.selectedSegmentIndex == 1
    // Refresh from the repository so newly joined meets appear immediately.
    refresh()
  }

  @objc private func settingsTap() {
    navigationController?.pushViewController(SettingsController(), animated: true)
  }

  @objc private func openFollowers() {
    guard let id = AppRepository.shared.currentUserID else { return }
    navigationController?.pushViewController(
      UserRelationListController(mode: .followers, userID: id), animated: true)
  }

  @objc private func openFollowing() {
    guard let id = AppRepository.shared.currentUserID else { return }
    navigationController?.pushViewController(
      UserRelationListController(mode: .following, userID: id), animated: true)
  }

  @objc private func editTap() {
    navigationController?.pushViewController(EditProfileController(), animated: true)
  }

  @objc private func recharge() {
    navigationController?.pushViewController(RechargeController(), animated: true)
  }
}
