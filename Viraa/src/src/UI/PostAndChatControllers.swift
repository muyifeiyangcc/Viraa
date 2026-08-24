import AVFoundation
import SnapKit
import UIKit

private final class PostMediaCell: UICollectionViewCell {
  static let reuseIdentifier = "post-media"
  private let imageView = UIImageView(), playView = UIImageView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
    playView.image = UIImage(
      systemName: "play.fill",
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 54, weight: .regular))
    playView.tintColor = UIColor.white.withAlphaComponent(0.86)
    playView.contentMode = .scaleAspectFit
    contentView.addSubview(imageView)
    contentView.addSubview(playView)
    imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
    playView.snp.makeConstraints {
      $0.center.equalToSuperview()
      $0.width.equalTo(72)
      $0.height.equalTo(86)
    }
  }

  required init?(coder: NSCoder) { fatalError() }

  func configure(_ asset: MediaAsset?, fit: Bool = false) {
    if let asset {
      imageView.image = MediaStore.shared.thumbnail(for: asset) ?? UIImage(systemName: "photo")
      imageView.contentMode = fit ? .scaleAspectFit : .scaleAspectFill
      imageView.layer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
      playView.isHidden = asset.kind != .video
    } else {
      imageView.image = UIImage(named: "Meet")
      imageView.contentMode = .scaleToFill
      imageView.layer.contentsRect = CGRect(
        x: 20.0 / 375.0, y: 146.0 / 812.0, width: 335.0 / 375.0,
        height: 205.0 / 812.0)
      playView.isHidden = true
    }
  }
}

private final class MediaGalleryController: UIViewController, UICollectionViewDataSource,
  UICollectionViewDelegateFlowLayout
{
  private let assets: [MediaAsset], initialIndex: Int
  private let collection: UICollectionView, pageControl = UIPageControl()
  private var didSetInitialPosition = false

  init(assets: [MediaAsset], initialIndex: Int) {
    self.assets = assets
    self.initialIndex = min(max(0, initialIndex), max(0, assets.count - 1))
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .horizontal
    layout.minimumLineSpacing = 0
    collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
    super.init(nibName: nil, bundle: nil)
    hidesBottomBarWhenPushed = true
  }

  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    collection.backgroundColor = .black
    collection.isPagingEnabled = true
    collection.showsHorizontalScrollIndicator = false
    collection.dataSource = self
    collection.delegate = self
    collection.register(
      PostMediaCell.self, forCellWithReuseIdentifier: PostMediaCell.reuseIdentifier)
    let back = UIButton(type: .custom)
    back.setImage(UIImage(named: "image/back")?.withRenderingMode(.alwaysTemplate), for: .normal)
    back.tintColor = .white
    back.contentHorizontalAlignment = .left
    back.addTarget(self, action: #selector(backTap), for: .touchUpInside)
    pageControl.numberOfPages = assets.count
    pageControl.currentPage = initialIndex
    pageControl.hidesForSinglePage = true
    [collection, back, pageControl].forEach(view.addSubview)
    collection.snp.makeConstraints { $0.edges.equalToSuperview() }
    back.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide)
      $0.leading.equalToSuperview().offset(20)
      $0.width.height.equalTo(44)
    }
    pageControl.snp.makeConstraints {
      $0.centerX.equalToSuperview()
      $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(18)
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: false)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard !didSetInitialPosition, !assets.isEmpty else { return }
    didSetInitialPosition = true
    collection.setContentOffset(
      CGPoint(x: CGFloat(initialIndex) * collection.bounds.width, y: 0), animated: false)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(false, animated: false)
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
    -> Int
  {
    assets.count
  }

  func collectionView(
    _ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let cell =
      collectionView.dequeueReusableCell(
        withReuseIdentifier: PostMediaCell.reuseIdentifier, for: indexPath) as! PostMediaCell
    cell.configure(assets[indexPath.item], fit: true)
    return cell
  }

  func collectionView(
    _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize { collectionView.bounds.size }

  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    guard scrollView.bounds.width > 0 else { return }
    pageControl.currentPage = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
  }

  @objc private func backTap() { navigationController?.popViewController(animated: true) }
}

private final class PostCommentView: UIView {
  var moreAction: (() -> Void)?

  init(comment: Comment, author: User?, showsMore: Bool) {
    super.init(frame: .zero)
    let avatar = UIImageView(
      image: author?.avatar.flatMap { MediaStore.shared.thumbnail(for: $0) }
        ?? UIImage(systemName: "person.crop.circle.fill"))
    avatar.contentMode = .scaleAspectFill
    avatar.tintColor = UIColor(white: 0.62, alpha: 1)
    avatar.clipsToBounds = true
    avatar.layer.cornerRadius = 26
    let name = UIFactory.label(author?.name ?? "Explorer", size: 15, weight: .semibold)
    let body = UIFactory.label(comment.text, size: 13, lines: 0)
    let more = UIButton(type: .system)
    more.setTitle("••  More", for: .normal)
    more.setTitleColor(AppTheme.muted, for: .normal)
    more.titleLabel?.font = .systemFont(ofSize: 11)
    more.contentHorizontalAlignment = .left
    more.isHidden = !showsMore
    more.addAction(UIAction { [weak self] _ in self?.moreAction?() }, for: .touchUpInside)
    [avatar, name, body, more].forEach(addSubview)
    avatar.snp.makeConstraints {
      $0.top.leading.equalToSuperview()
      $0.width.height.equalTo(52)
    }
    name.snp.makeConstraints {
      $0.top.equalToSuperview().offset(1)
      $0.leading.equalTo(avatar.snp.trailing).offset(11)
      $0.trailing.equalToSuperview()
      $0.height.equalTo(19)
    }
    body.snp.makeConstraints {
      $0.top.equalTo(name.snp.bottom).offset(2)
      $0.leading.trailing.equalTo(name)
    }
    more.snp.makeConstraints {
      $0.top.equalTo(body.snp.bottom).offset(1)
      $0.leading.equalTo(body)
      $0.width.equalTo(70)
      $0.height.equalTo(showsMore ? 20 : 0)
      $0.bottom.equalToSuperview().inset(4)
    }
  }

  required init?(coder: NSCoder) { fatalError() }
}

final class PostDetailController: UIViewController, UICollectionViewDataSource,
  UICollectionViewDelegateFlowLayout, UITextFieldDelegate
{
  private let postID: String, header = UIView(), scroll = UIScrollView()
  private let pageStack = UIStackView(), detailStack = UIStackView(), overlay = StateOverlayView()
  private let field = UITextField(), composer = UIView(), mediaCollection: UICollectionView
  private let pageControl = UIPageControl()
  private let moreButton = UIButton(type: .system)
  private var post: Post?, media: [MediaAsset] = []

  init(postID: String) {
    self.postID = postID
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .horizontal
    layout.minimumLineSpacing = 0
    mediaCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
    super.init(nibName: nil, bundle: nil)
    hidesBottomBarWhenPushed = true
  }

  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    moreButton.isHidden = true
    configureHeader()
    configureComposer()
    configureScroll()
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

  private func configureHeader() {
    let back = UIButton(type: .custom)
    back.setImage(UIImage(named: "image/back")?.withRenderingMode(.alwaysOriginal), for: .normal)
    back.contentHorizontalAlignment = .left
    back.addTarget(self, action: #selector(backTap), for: .touchUpInside)
    moreButton.tintColor = .black
    moreButton.setImage(
      UIImage(
        systemName: "ellipsis",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .bold)),
      for: .normal)
    moreButton.addTarget(self, action: #selector(postMore), for: .touchUpInside)
    view.addSubview(header)
    header.addSubview(back)
    header.addSubview(moreButton)
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
    moreButton.snp.makeConstraints {
      $0.trailing.equalToSuperview().inset(18)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(40)
    }
  }

  private func configureScroll() {
    scroll.showsVerticalScrollIndicator = false
    scroll.keyboardDismissMode = .interactive
    pageStack.axis = .vertical
    detailStack.axis = .vertical
    detailStack.spacing = 7
    detailStack.isLayoutMarginsRelativeArrangement = true
    detailStack.layoutMargins = .init(top: 16, left: 20, bottom: 24, right: 20)
    mediaCollection.backgroundColor = .white
    mediaCollection.isPagingEnabled = true
    mediaCollection.showsHorizontalScrollIndicator = false
    mediaCollection.dataSource = self
    mediaCollection.delegate = self
    mediaCollection.register(
      PostMediaCell.self, forCellWithReuseIdentifier: PostMediaCell.reuseIdentifier)
    let mediaContainer = UIView()
    mediaContainer.addSubview(mediaCollection)
    mediaContainer.addSubview(pageControl)
    mediaCollection.snp.makeConstraints { $0.edges.equalToSuperview() }
    pageControl.snp.makeConstraints {
      $0.centerX.equalToSuperview()
      $0.bottom.equalToSuperview().inset(8)
    }
    mediaContainer.snp.makeConstraints { $0.height.equalTo(285) }
    pageStack.addArrangedSubview(mediaContainer)
    pageStack.addArrangedSubview(detailStack)
    view.addSubview(scroll)
    scroll.addSubview(pageStack)
    view.addSubview(overlay)
    scroll.snp.makeConstraints {
      $0.top.equalTo(header.snp.bottom)
      $0.leading.trailing.equalToSuperview()
      $0.bottom.equalTo(composer.snp.top).offset(-8)
    }
    pageStack.snp.makeConstraints { $0.edges.width.equalToSuperview() }
    overlay.snp.makeConstraints { $0.edges.equalTo(scroll) }
    overlay.onRetry = { AppRepository.shared.recoverFromParsingError() }
  }

  private func configureComposer() {
    composer.backgroundColor = AppTheme.surface
    composer.layer.cornerRadius = 27
    field.placeholder = "Add a comment..."
    field.font = .systemFont(ofSize: 16)
    field.delegate = self
    field.returnKeyType = .send
    field.setLeftPadding(16)
    composer.addSubview(field)
    view.addSubview(composer)
    composer.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(18)
      $0.bottom.equalTo(view.keyboardLayoutGuide.snp.top).offset(-15)
      $0.height.equalTo(54)
    }
    field.snp.makeConstraints { $0.edges.equalToSuperview() }
  }

  @objc private func refresh() {
    guard AppRepository.shared.state != .parsingError else {
      overlay.render(.parsingError, emptyText: "")
      return
    }
    guard let post = AppRepository.shared.visiblePosts().first(where: { $0.id == postID }) else {
      overlay.render(.empty, emptyText: "This drop is no longer available")
      return
    }
    self.post = post
    moreButton.isHidden = post.authorID == AppRepository.shared.currentUserID
    media = post.media
    overlay.render(.content, emptyText: "")
    pageControl.numberOfPages = media.count
    pageControl.hidesForSinglePage = true
    mediaCollection.reloadData()
    detailStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    renderDetails(post)
  }

  private func renderDetails(_ post: Post) {
    let author = AppRepository.shared.user(post.authorID)
    let avatar = UIImageView(
      image: author?.avatar.flatMap { MediaStore.shared.thumbnail(for: $0) }
        ?? UIImage(systemName: "person.crop.circle.fill"))
    avatar.contentMode = .scaleAspectFill
    avatar.tintColor = UIColor(white: 0.62, alpha: 1)
    avatar.clipsToBounds = true
    avatar.layer.cornerRadius = 16
    let authorName = UIFactory.label(author?.name ?? "Explorer", size: 18, weight: .semibold)
    let authorButton = UIControl()
    authorButton.addSubview(avatar)
    authorButton.addSubview(authorName)
    avatar.snp.makeConstraints {
      $0.leading.centerY.equalToSuperview()
      $0.width.height.equalTo(32)
    }
    authorName.snp.makeConstraints {
      $0.leading.equalTo(avatar.snp.trailing).offset(7)
      $0.centerY.equalToSuperview()
      $0.trailing.equalToSuperview()
    }
    authorButton.addAction(
      UIAction { _ in
        self.navigationController?.pushViewController(
          OtherProfileController(userID: post.authorID), animated: true)
      }, for: .touchUpInside)
    let like = UIButton(type: .system)
    let liked = AppRepository.shared.isLiked(post.id)
    like.tintColor = liked ? AppTheme.blue : AppTheme.ink
    like.setImage(UIImage(named: "image/good")?.withRenderingMode(.alwaysTemplate), for: .normal)
    like.setTitle("  \(AppRepository.shared.filteredLikeCount(postID: post.id))", for: .normal)
    like.setTitleColor(liked ? AppTheme.blue : AppTheme.ink, for: .normal)
    like.titleLabel?.font = .systemFont(ofSize: 14)
    like.addTarget(self, action: #selector(likeTap), for: .touchUpInside)
    let authorRow = UIView()
    authorRow.addSubview(authorButton)
    authorRow.addSubview(like)
    authorButton.snp.makeConstraints {
      $0.leading.top.bottom.equalToSuperview()
      $0.height.equalTo(36)
      $0.trailing.lessThanOrEqualTo(like.snp.leading).offset(-10)
    }
    like.snp.makeConstraints {
      $0.trailing.centerY.equalToSuperview()
      $0.height.equalTo(36)
    }
    detailStack.addArrangedSubview(authorRow)

    let category = NSMutableAttributedString(
      string: post.category, attributes: [.foregroundColor: AppTheme.blue])
    category.append(
      NSAttributedString(
        string: "  ·  \(post.difficulty)",
        attributes: [.foregroundColor: UIColor(red: 1, green: 0.18, blue: 0.55, alpha: 1)]))
    let categoryLabel = UIFactory.label(size: 14, weight: .medium)
    categoryLabel.attributedText = category
    detailStack.addArrangedSubview(categoryLabel)
    detailStack.addArrangedSubview(UIFactory.label(post.title, size: 20, weight: .semibold))
    detailStack.addArrangedSubview(UIFactory.label(post.body, size: 16, lines: 0))
    let commentTitle = UIFactory.label("COMMENT", size: 14, color: AppTheme.secondary)
    detailStack.addArrangedSubview(commentTitle)
    for comment in AppRepository.shared.visibleComments(post) {
      let author = AppRepository.shared.user(comment.authorID)
      let isOwnComment = comment.authorID == AppRepository.shared.currentUserID
      let commentView = PostCommentView(
        comment: comment, author: author, showsMore: !isOwnComment)
      if !isOwnComment {
        commentView.moreAction = { [weak self] in self?.commentMore(comment) }
      }
      detailStack.addArrangedSubview(commentView)
    }
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
    -> Int
  {
    max(media.count, 1)
  }

  func collectionView(
    _ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let cell =
      collectionView.dequeueReusableCell(
        withReuseIdentifier: PostMediaCell.reuseIdentifier, for: indexPath) as! PostMediaCell
    cell.configure(media.indices.contains(indexPath.item) ? media[indexPath.item] : nil)
    return cell
  }

  func collectionView(
    _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize { collectionView.bounds.size }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard media.indices.contains(indexPath.item) else { return }
    let asset = media[indexPath.item]
    if asset.kind == .video {
      navigationController?.pushViewController(MediaPreviewController(asset: asset), animated: true)
    } else {
      let images = media.filter { $0.kind == .image }
      let imageIndex = images.firstIndex(of: asset) ?? 0
      navigationController?.pushViewController(
        MediaGalleryController(assets: images, initialIndex: imageIndex), animated: true)
    }
  }

  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    guard scrollView === mediaCollection, scrollView.bounds.width > 0 else { return }
    pageControl.currentPage = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    AppRepository.shared.addComment(postID: postID, text: textField.text ?? "")
    textField.text = ""
    return true
  }

  @objc private func backTap() { navigationController?.popViewController(animated: true) }
  @objc private func likeTap() { AppRepository.shared.toggleLike(postID: postID) }

  private func commentMore(_ comment: Comment) {
    guard comment.authorID != AppRepository.shared.currentUserID else { return }
    presentChoiceSheet(options: ["Report", "Block"]) { [weak self] selection in
      guard let self, let selection else { return }
      if selection == 0 {
        self.navigationController?.pushViewController(
          ReportController(targetID: comment.authorID), animated: true)
      } else {
        AppRepository.shared.block(userID: comment.authorID)
      }
    }
  }

  @objc private func postMore() {
    guard let post, post.authorID != AppRepository.shared.currentUserID else { return }
    presentChoiceSheet(options: ["Report", "Block"]) { [weak self] selection in
      guard let self, let selection else { return }
      if selection == 0 {
        self.navigationController?.pushViewController(
          ReportController(targetID: post.authorID), animated: true)
      } else {
        AppRepository.shared.block(userID: post.authorID)
        self.navigationController?.popViewController(animated: true)
      }
    }
  }
}

private final class ChatBubbleCell: UITableViewCell {
  let messageID: String
  var mediaAction: (() -> Void)?, voiceAction: (() -> Void)?
  private var playButton: UIButton?, progressView: UIProgressView?

  init(message: ChatMessage, outgoing: Bool, progress: Float, playing: Bool) {
    messageID = message.id
    super.init(style: .default, reuseIdentifier: nil)
    selectionStyle = .none
    backgroundColor = .white
    switch message.kind {
    case .text: makeText(message.body, outgoing: outgoing)
    case .image: makeImage(message.media, outgoing: outgoing)
    case .voice:
      makeVoice(message.media, outgoing: outgoing, progress: progress, playing: playing)
    }
  }

  required init?(coder: NSCoder) { fatalError() }

  private func pin(_ view: UIView, outgoing: Bool) {
    contentView.addSubview(view)
    view.snp.makeConstraints {
      $0.top.bottom.equalToSuperview().inset(6)
      if outgoing {
        $0.trailing.equalToSuperview().inset(20)
      } else {
        $0.leading.equalToSuperview().offset(20)
      }
    }
  }

  private func makeText(_ text: String, outgoing: Bool) {
    let bubble = UIView()
    bubble.backgroundColor = outgoing ? AppTheme.ink : AppTheme.surface
    bubble.layer.cornerRadius = 19
    let label = UIFactory.label(
      text, size: 14, color: outgoing ? .white : AppTheme.ink, lines: 0)
    bubble.addSubview(label)
    label.snp.makeConstraints {
      $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
      $0.width.lessThanOrEqualTo(250)
    }
    pin(bubble, outgoing: outgoing)
  }

  private func makeImage(_ asset: MediaAsset?, outgoing: Bool) {
    let button = UIButton(type: .custom)
    button.backgroundColor = AppTheme.surface
    button.layer.cornerRadius = 20
    button.clipsToBounds = true
    button.imageView?.contentMode = .scaleAspectFill
    button.setImage(
      asset.flatMap { MediaStore.shared.thumbnail(for: $0) } ?? UIImage(systemName: "photo"),
      for: .normal)
    button.addAction(UIAction { [weak self] _ in self?.mediaAction?() }, for: .touchUpInside)
    button.snp.makeConstraints {
      $0.width.equalTo(220)
      $0.height.equalTo(145)
    }
    pin(button, outgoing: outgoing)
  }

  private func makeVoice(_ asset: MediaAsset?, outgoing: Bool, progress: Float, playing: Bool) {
    let bubble = UIView()
    bubble.backgroundColor = outgoing ? AppTheme.ink : AppTheme.surface
    bubble.layer.cornerRadius = 18
    let play = UIButton(type: .system)
    play.tintColor = outgoing ? .white : AppTheme.ink
    play.setImage(UIImage(systemName: playing ? "pause.fill" : "play.fill"), for: .normal)
    play.addAction(UIAction { [weak self] _ in self?.voiceAction?() }, for: .touchUpInside)
    let bar = UIProgressView(progressViewStyle: .default)
    bar.trackTintColor =
      outgoing
      ? UIColor.white.withAlphaComponent(0.35)
      : UIColor(
        red: 0.65, green: 0.75, blue: 1, alpha: 1)
    bar.progressTintColor = outgoing ? .white : AppTheme.blue
    bar.progress = progress
    let duration = UIFactory.label(
      "\(max(1, Int((asset?.duration ?? 0).rounded())))s", size: 14, weight: .semibold,
      color: outgoing ? .white : AppTheme.ink)
    [play, bar, duration].forEach(bubble.addSubview)
    play.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(12)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(24)
    }
    bar.snp.makeConstraints {
      $0.leading.equalTo(play.snp.trailing).offset(6)
      $0.centerY.equalToSuperview()
      $0.width.equalTo(94)
    }
    duration.snp.makeConstraints {
      $0.leading.equalTo(bar.snp.trailing).offset(5)
      $0.trailing.equalToSuperview().inset(12)
      $0.centerY.equalToSuperview()
    }
    bubble.snp.makeConstraints {
      $0.width.equalTo(180)
      $0.height.equalTo(44)
    }
    playButton = play
    progressView = bar
    pin(bubble, outgoing: outgoing)
  }

  func updatePlayback(progress: Float, playing: Bool) {
    progressView?.setProgress(progress, animated: true)
    playButton?.setImage(UIImage(systemName: playing ? "pause.fill" : "play.fill"), for: .normal)
  }
}

final class ChatController: UIViewController, UITableViewDataSource, UITextFieldDelegate,
  MediaPickerDelegate, AudioRecorderDelegate, UIImagePickerControllerDelegate,
  UINavigationControllerDelegate, @preconcurrency AVAudioPlayerDelegate
{
  private let conversation: Conversation, header = UIView()
  private let avatarView = UIImageView(), nameLabel = UIFactory.label(size: 17, weight: .medium)
  private let table = UITableView(frame: .zero, style: .plain), overlay = StateOverlayView()
  private let composerHost = UIView(), textComposer = UIView(), voiceComposer = UIView()
  private let field = UITextField(), recordButton = UIButton(type: .custom)
  private let picker = MediaPickerService(), recorder = AudioRecorderService()
  private var items: [ChatMessage] = [], recordCancelled = false
  private var player: AVAudioPlayer?, playbackTimer: Timer?, playingMessageID: String?
  private var playbackProgress: [String: Float] = [:]

  init(conversation: Conversation) {
    self.conversation = conversation
    super.init(nibName: nil, bundle: nil)
    hidesBottomBarWhenPushed = true
  }

  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    picker.delegate = self
    recorder.delegate = self
    configureHeader()
    configureComposers()
    configureTable()
    NotificationCenter.default.addObserver(
      self, selector: #selector(reload), name: .appDataChanged, object: nil)
    AppRepository.shared.markConversationRead(conversation.id)
    reload()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: false)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    stopPlayback()
    navigationController?.setNavigationBarHidden(false, animated: false)
  }

  private func stopPlayback() {
    playbackTimer?.invalidate()
    playbackTimer = nil
    player?.stop()
    player = nil
    playingMessageID = nil
  }

  private func configureHeader() {
    let backButton = UIButton(type: .custom)
    let moreButton = UIButton(type: .system)
    backButton.setImage(
      UIImage(named: "image/back")?.withRenderingMode(.alwaysOriginal), for: .normal)
    backButton.contentHorizontalAlignment = .left
    backButton.addTarget(self, action: #selector(backTap), for: .touchUpInside)
    moreButton.tintColor = .black
    moreButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
    moreButton.addTarget(self, action: #selector(moreTap), for: .touchUpInside)
    avatarView.contentMode = .scaleAspectFill
    avatarView.clipsToBounds = true
    avatarView.layer.cornerRadius = 19
    if let user = otherUser() {
      nameLabel.text = user.name
      avatarView.image =
        user.avatar.flatMap { MediaStore.shared.thumbnail(for: $0) }
        ?? UIImage(systemName: "person.crop.circle.fill")
      avatarView.tintColor = UIColor(white: 0.62, alpha: 1)
    }
    view.addSubview(header)
    [backButton, avatarView, nameLabel, moreButton].forEach(header.addSubview)
    header.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide)
      $0.leading.trailing.equalToSuperview()
      $0.height.equalTo(58)
    }
    backButton.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(20)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(44)
    }
    avatarView.snp.makeConstraints {
      $0.centerY.equalToSuperview()
      $0.centerX.equalToSuperview().offset(-43)
      $0.width.height.equalTo(38)
    }
    nameLabel.snp.makeConstraints {
      $0.leading.equalTo(avatarView.snp.trailing).offset(10)
      $0.centerY.equalToSuperview()
    }
    moreButton.snp.makeConstraints {
      $0.trailing.equalToSuperview().inset(18)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(40)
    }
  }

  private func configureComposers() {
    view.addSubview(composerHost)
    [textComposer, voiceComposer].forEach(composerHost.addSubview)
    composerHost.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(18)
      $0.bottom.equalTo(view.keyboardLayoutGuide.snp.top).offset(-15)
      $0.height.equalTo(54)
    }
    textComposer.snp.makeConstraints { $0.edges.equalToSuperview() }
    voiceComposer.snp.makeConstraints { $0.edges.equalToSuperview() }
    configureTextComposer()
    configureVoiceComposer()
    voiceComposer.isHidden = true
  }

  private func configureTextComposer() {
    textComposer.backgroundColor = AppTheme.surface
    textComposer.layer.cornerRadius = 27
    let microphone = UIButton(type: .system)
    let photo = UIButton(type: .system)
    let send = UIButton(type: .system)
    [microphone, photo, send].forEach { $0.tintColor = UIColor(white: 0.23, alpha: 1) }
    microphone.setImage(UIImage(systemName: "mic.fill"), for: .normal)
    photo.setImage(UIImage(systemName: "photo.circle.fill"), for: .normal)
    send.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
    microphone.addTarget(self, action: #selector(showVoiceComposer), for: .touchUpInside)
    photo.addTarget(self, action: #selector(showPhotoOptions(_:)), for: .touchUpInside)
    send.addTarget(self, action: #selector(sendText), for: .touchUpInside)
    field.placeholder = "Enter..."
    field.font = .systemFont(ofSize: 16)
    field.delegate = self
    field.returnKeyType = .send
    [microphone, field, photo, send].forEach(textComposer.addSubview)
    microphone.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(14)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(26)
    }
    send.snp.makeConstraints {
      $0.trailing.equalToSuperview().inset(14)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(27)
    }
    photo.snp.makeConstraints {
      $0.trailing.equalTo(send.snp.leading).offset(-10)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(27)
    }
    field.snp.makeConstraints {
      $0.leading.equalTo(microphone.snp.trailing).offset(4)
      $0.trailing.equalTo(photo.snp.leading).offset(-8)
      $0.top.bottom.equalToSuperview()
    }
  }

  private func configureVoiceComposer() {
    voiceComposer.backgroundColor = AppTheme.blue
    voiceComposer.layer.cornerRadius = 27
    recordButton.setTitle("Hold to Talk", for: .normal)
    recordButton.setTitleColor(.white, for: .normal)
    recordButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
    recordButton.addTarget(self, action: #selector(recordDown), for: .touchDown)
    recordButton.addTarget(self, action: #selector(recordExit), for: .touchDragExit)
    recordButton.addTarget(self, action: #selector(recordEnter), for: .touchDragEnter)
    recordButton.addTarget(
      self, action: #selector(recordUp), for: [.touchUpInside, .touchUpOutside])
    let keyboard = UIButton(type: .system)
    keyboard.backgroundColor = .white
    keyboard.tintColor = AppTheme.blue
    keyboard.layer.cornerRadius = 7
    keyboard.setImage(UIImage(systemName: "keyboard"), for: .normal)
    keyboard.addTarget(self, action: #selector(showTextComposer), for: .touchUpInside)
    voiceComposer.addSubview(recordButton)
    voiceComposer.addSubview(keyboard)
    recordButton.snp.makeConstraints { $0.edges.equalToSuperview() }
    keyboard.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(23)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(22)
    }
  }

  private func configureTable() {
    table.dataSource = self
    table.separatorStyle = .none
    table.rowHeight = UITableView.automaticDimension
    table.estimatedRowHeight = 70
    table.showsVerticalScrollIndicator = false
    let time = UIFactory.label(conversationTimeTitle(), size: 11, color: AppTheme.secondary)
    time.frame = CGRect(x: 20, y: 12, width: view.bounds.width - 40, height: 20)
    let tableHeader = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 40))
    tableHeader.addSubview(time)
    table.tableHeaderView = tableHeader
    view.addSubview(table)
    view.addSubview(overlay)
    table.snp.makeConstraints {
      $0.top.equalTo(header.snp.bottom)
      $0.leading.trailing.equalToSuperview()
      $0.bottom.equalTo(composerHost.snp.top).offset(-8)
    }
    overlay.snp.makeConstraints { $0.edges.equalTo(table) }
    overlay.onRetry = { AppRepository.shared.recoverFromParsingError() }
  }

  private func otherID() -> String? {
    conversation.participantIDs.first { $0 != AppRepository.shared.currentUserID }
  }
  private func otherUser() -> User? { otherID().flatMap { AppRepository.shared.user($0) } }
  private func conversationTimeTitle() -> String {
    guard
      let date = AppRepository.shared.visibleMessages(conversationID: conversation.id).first?
        .createdAt
    else { return "TODAY" }
    let formatter = DateFormatter()
    formatter.dateFormat = Calendar.current.isDateInToday(date) ? "'TODAY' h:mm a" : "MMM d h:mm a"
    return formatter.string(from: date).uppercased()
  }

  @objc private func backTap() { navigationController?.popViewController(animated: true) }
  @objc private func reload() {
    if AppRepository.shared.state == .parsingError {
      overlay.render(.parsingError, emptyText: "")
      return
    }
    items = AppRepository.shared.visibleMessages(conversationID: conversation.id)
    overlay.render(items.isEmpty ? .empty : .content, emptyText: "No messages yet")
    table.reloadData()
    if !items.isEmpty {
      table.scrollToRow(
        at: IndexPath(row: items.count - 1, section: 0), at: .bottom, animated: false)
    }
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    items.count
  }
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let message = items[indexPath.row]
    let cell = ChatBubbleCell(
      message: message, outgoing: message.senderID == AppRepository.shared.currentUserID,
      progress: playbackProgress[message.id] ?? 0,
      playing: playingMessageID == message.id && player?.isPlaying == true)
    cell.mediaAction = { [weak self] in self?.preview(message) }
    cell.voiceAction = { [weak self] in self?.toggleVoice(message) }
    return cell
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    sendText()
    return true
  }

  @objc private func sendText() {
    let text = (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    AppRepository.shared.sendMessage(conversationID: conversation.id, text: text)
    field.text = ""
  }
  @objc private func showVoiceComposer() {
    field.resignFirstResponder()
    textComposer.isHidden = true
    voiceComposer.isHidden = false
  }
  @objc private func showTextComposer() {
    voiceComposer.isHidden = true
    textComposer.isHidden = false
  }
  @objc private func showPhotoOptions(_ sender: UIButton) {
    field.resignFirstResponder()
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
      "chat-camera-\(UUID().uuidString).jpg")
    do {
      try data.write(to: temporaryURL, options: .atomic)
      defer { try? FileManager.default.removeItem(at: temporaryURL) }
      let asset = try MediaStore.shared.importFile(temporaryURL, kind: .image)
      AppRepository.shared.sendMessage(
        conversationID: conversation.id, text: "Photo", kind: .image, media: asset)
    } catch {
      showMessage("Photo Unavailable", "The captured photo could not be saved.")
    }
  }

  func mediaPicker(_ picker: MediaPickerService, didFinish assets: [MediaAsset]) {
    guard let asset = assets.first else { return }
    AppRepository.shared.sendMessage(
      conversationID: conversation.id, text: "Photo", kind: .image, media: asset)
  }
  func mediaPicker(_ picker: MediaPickerService, didFail message: String) {
    showMessage("Media Unavailable", message)
  }

  @objc private func recordDown() {
    recordCancelled = false
    recordButton.setTitle("Release to Send · Slide Away to Cancel", for: .normal)
    recorder.requestAndStart()
  }
  @objc private func recordExit() {
    recordCancelled = true
    recordButton.setTitle("Release to Cancel", for: .normal)
  }
  @objc private func recordEnter() {
    recordCancelled = false
    recordButton.setTitle("Release to Send", for: .normal)
  }
  @objc private func recordUp() {
    recordButton.setTitle("Hold to Talk", for: .normal)
    recorder.finish(cancelled: recordCancelled)
  }
  func audioRecorder(_ recorder: AudioRecorderService, didFinish asset: MediaAsset) {
    AppRepository.shared.sendMessage(
      conversationID: conversation.id, text: "Voice message", kind: .voice, media: asset)
  }
  func audioRecorderPermissionDenied() {
    showMessage("Microphone Access", "Enable microphone access in Settings to send voice messages.")
  }
  func audioRecorder(_ recorder: AudioRecorderService, didFail message: String) {
    showMessage("Recording Unavailable", message)
  }

  private func toggleVoice(_ message: ChatMessage) {
    guard let asset = message.media else { return }
    if playingMessageID == message.id, let player {
      if player.isPlaying {
        player.pause()
        playbackTimer?.invalidate()
      } else {
        if player.currentTime >= player.duration { player.currentTime = 0 }
        player.play()
        startPlaybackTimer()
      }
      updateVoiceCells()
      return
    }
    do {
      let url = MediaStore.shared.url(for: asset)
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw NSError(domain: "Media", code: 404)
      }
      player?.stop()
      playbackTimer?.invalidate()
      player = try AVAudioPlayer(contentsOf: url)
      player?.delegate = self
      playingMessageID = message.id
      playbackProgress[message.id] = 0
      player?.play()
      startPlaybackTimer()
      updateVoiceCells()
    } catch {
      showMessage("Voice Unavailable", "This voice message cannot be played.")
    }
  }

  private func startPlaybackTimer() {
    playbackTimer?.invalidate()
    playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
      [weak self] _ in
      Task { @MainActor in self?.playbackTick() }
    }
  }
  private func playbackTick() {
    guard let id = playingMessageID, let player, player.duration > 0 else { return }
    playbackProgress[id] = Float(player.currentTime / player.duration)
    updateVoiceCells()
  }
  nonisolated func audioPlayerDidFinishPlaying(
    _ player: AVAudioPlayer, successfully flag: Bool
  ) {
    Task { @MainActor [weak self] in self?.finishPlayback() }
  }
  private func finishPlayback() {
    playbackTimer?.invalidate()
    if let id = playingMessageID { playbackProgress[id] = 1 }
    updateVoiceCells()
  }
  private func updateVoiceCells() {
    for case let cell as ChatBubbleCell in table.visibleCells {
      cell.updatePlayback(
        progress: playbackProgress[cell.messageID] ?? 0,
        playing: cell.messageID == playingMessageID && player?.isPlaying == true)
    }
  }
  private func preview(_ message: ChatMessage) {
    guard let asset = message.media else { return }
    navigationController?.pushViewController(MediaPreviewController(asset: asset), animated: true)
  }
  @objc private func moreTap() {
    guard let id = otherID() else { return }
    presentChoiceSheet(options: ["Report", "Block"]) { [weak self] selection in
      guard let self, let selection else { return }
      if selection == 0 {
        self.navigationController?.pushViewController(
          ReportController(targetID: id), animated: true)
      } else {
        AppRepository.shared.block(userID: id)
        self.navigationController?.popViewController(animated: true)
      }
    }
  }
}
