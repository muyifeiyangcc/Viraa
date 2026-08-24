import SnapKit
import UIKit

private final class CoinPackCell: UICollectionViewCell {
  static let reuseIdentifier = "coin-pack"
  private let background = UIImageView(image: UIImage(named: "coin_bg"))
  private let rewardLabel = UIFactory.label(
    size: 24, weight: .semibold, color: UIColor(red: 0.65, green: 0.34, blue: 0.05, alpha: 1))
  private let priceLabel = UIFactory.label(size: 16, weight: .semibold, color: .white)

  override init(frame: CGRect) {
    super.init(frame: frame)
    background.contentMode = .scaleToFill
    rewardLabel.textAlignment = .center
    priceLabel.textAlignment = .center
    contentView.addSubview(background)
    contentView.addSubview(rewardLabel)
    contentView.addSubview(priceLabel)
    background.snp.makeConstraints { $0.edges.equalToSuperview() }
  }

  required init?(coder: NSCoder) { fatalError() }

  override func layoutSubviews() {
    super.layoutSubviews()
    // coin_bg has fixed artwork slots; place dynamic text by image proportions.
    let bounds = contentView.bounds
    rewardLabel.frame = CGRect(
      x: 12, y: bounds.height * 0.665 - 15, width: max(0, bounds.width - 24), height: 30)
    priceLabel.frame = CGRect(
      x: max(0, (bounds.width - 100) / 2), y: bounds.height * 0.854 - 14.5, width: 100,
      height: 29)
  }

  func configure(_ product: PurchaseDisplayProduct, selected: Bool) {
    rewardLabel.text = product.reward.formatted()
    priceLabel.text = product.usdPrice
    contentView.layer.cornerRadius = 14
    contentView.layer.borderWidth = selected ? 3 : 0
    contentView.layer.borderColor = selected ? AppTheme.blue.cgColor : UIColor.clear.cgColor
    contentView.clipsToBounds = true
  }
}

final class RechargeController: UIViewController, UICollectionViewDataSource,
  UICollectionViewDelegateFlowLayout, PurchaseManagerDelegate
{
  private var products: [PurchaseDisplayProduct] = [], selected: PurchaseDisplayProduct?
  private let header = UIView(), titleLabel = UIFactory.label("Recharge Coins", size: 27)
  private let balanceBanner = UIImageView(image: UIImage(named: "coin_banner_bg"))
  private let balanceTitle = UIFactory.label("CURRENT BALANCE", size: 11, color: .white)
  private let balanceValue = UIFactory.label(size: 24, weight: .medium, color: .white)
  private let collection: UICollectionView, buyButton = UIFactory.button("Select a coin pack")
  private let spinner = UIActivityIndicatorView(style: .large), overlay = StateOverlayView()

  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .vertical
    layout.minimumLineSpacing = 21
    layout.minimumInteritemSpacing = 24
    collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    hidesBottomBarWhenPushed = true
  }

  convenience init() { self.init(nibName: nil, bundle: nil) }
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    configurePage()
    NotificationCenter.default.addObserver(
      self, selector: #selector(refreshBalance), name: .appDataChanged, object: nil)
    refreshBalance()
    PurchaseManager.shared.delegate = self
    overlay.render(.loading, emptyText: "")
    PurchaseManager.shared.loadProducts()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: false)
    PurchaseManager.shared.delegate = self
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
    balanceBanner.contentMode = .scaleToFill
    balanceBanner.clipsToBounds = true
    balanceBanner.layer.cornerRadius = 24
    balanceBanner.isUserInteractionEnabled = true
    balanceBanner.addSubview(balanceTitle)
    balanceBanner.addSubview(balanceValue)
    view.addSubview(balanceBanner)
    collection.backgroundColor = .white
    collection.showsVerticalScrollIndicator = false
    collection.contentInset.bottom = 18
    collection.dataSource = self
    collection.delegate = self
    collection.register(CoinPackCell.self, forCellWithReuseIdentifier: CoinPackCell.reuseIdentifier)
    view.addSubview(collection)
    buyButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
    buyButton.isEnabled = false
    buyButton.addTarget(self, action: #selector(buyTap), for: .touchUpInside)
    view.addSubview(buyButton)
    view.addSubview(spinner)
    view.addSubview(overlay)
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
    balanceBanner.snp.makeConstraints {
      $0.top.equalTo(titleLabel.snp.bottom).offset(8)
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.height.equalTo(92)
    }
    balanceTitle.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(18)
      $0.top.equalToSuperview().offset(17)
      $0.height.equalTo(15)
    }
    balanceValue.snp.makeConstraints {
      $0.leading.equalTo(balanceTitle)
      $0.top.equalTo(balanceTitle.snp.bottom).offset(1)
      $0.height.equalTo(31)
    }
    collection.snp.makeConstraints {
      $0.top.equalTo(balanceBanner.snp.bottom).offset(15)
      $0.leading.trailing.equalToSuperview()
      $0.bottom.equalTo(buyButton.snp.top).offset(-20)
    }
    buyButton.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(20)
      $0.bottom.equalTo(view.safeAreaLayoutGuide)
      $0.height.equalTo(52)
    }
    spinner.snp.makeConstraints { $0.center.equalToSuperview() }
    overlay.snp.makeConstraints {
      $0.top.equalTo(balanceBanner.snp.bottom)
      $0.leading.trailing.equalToSuperview()
      $0.bottom.equalTo(buyButton.snp.top)
    }
    overlay.onRetry = { PurchaseManager.shared.loadProducts() }
  }

  @objc private func refreshBalance() {
    balanceValue.text = "\(AppRepository.shared.wallet.coins.formatted()) coins"
  }

  func collectionView(
    _ collectionView: UICollectionView, numberOfItemsInSection section: Int
  ) -> Int { products.count }

  func collectionView(
    _ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let cell =
      collectionView.dequeueReusableCell(
        withReuseIdentifier: CoinPackCell.reuseIdentifier, for: indexPath) as! CoinPackCell
    let product = products[indexPath.item]
    cell.configure(product, selected: product.id == selected?.id)
    return cell
  }

  func collectionView(
    _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize {
    let width = floor((collectionView.bounds.width - 42 - 24) / 2)
    return CGSize(width: width, height: width * 213 / 155)
  }

  func collectionView(
    _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
    insetForSectionAt section: Int
  ) -> UIEdgeInsets { .init(top: 0, left: 21, bottom: 0, right: 21) }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    selected = products[indexPath.item]
    updateBuyButton()
    collectionView.reloadData()
  }

  func purchaseManagerDidUpdateProducts(_ products: [PurchaseDisplayProduct]) {
    self.products = products
    if let selected, !products.contains(where: { $0.id == selected.id }) {
      self.selected = nil
    } else if self.selected == nil {
      self.selected = products.first
    }
    updateBuyButton()
    overlay.render(products.isEmpty ? .empty : .content, emptyText: "No coin packs are available")
    collection.reloadData()
  }

  func purchaseManagerLoading(_ loading: Bool) {
    loading ? spinner.startAnimating() : spinner.stopAnimating()
    buyButton.isEnabled = !loading && selected != nil
  }

  @objc private func buyTap() {
    guard let selected else { return }
    PurchaseManager.shared.buy(productID: selected.id)
  }

  func purchaseManagerDidPurchase(reward: Int) {
    refreshBalance()
    showMessage("Purchase Complete", "\(reward) coins were added.")
  }

  func purchaseManagerDidFail(_ message: String) {
    overlay.render(.empty, emptyText: "Coin packs are unavailable")
    showMessage("Unable to Purchase", message)
  }

  private func updateBuyButton() {
    guard let selected else {
      buyButton.setTitle("Select a coin pack", for: .normal)
      buyButton.isEnabled = false
      return
    }
    buyButton.setTitle(
      "Buy \(selected.reward.formatted()) coins · \(selected.usdPrice)", for: .normal)
    buyButton.isEnabled = true
  }

  @objc private func backTap() { navigationController?.popViewController(animated: true) }
}

final class CoinBadgeView: UIView {
  private let background = UIImageView(image: UIImage(named: "image/coin_bg")),
    valueLabel = UILabel()
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    background.contentMode = .scaleToFill
    valueLabel.textAlignment = .center
    valueLabel.textColor = AppTheme.ink
    addSubview(background)
    addSubview(valueLabel)
    background.snp.makeConstraints { $0.edges.equalToSuperview() }
    valueLabel.snp.makeConstraints {
      $0.leading.equalTo(background.snp.centerX).offset(-2)
      $0.trailing.equalToSuperview().offset(-3)
      $0.centerY.equalToSuperview()
    }
  }
  required init?(coder: NSCoder) { fatalError() }
  func configure(value: Int, fontSize: CGFloat) {
    valueLabel.text = "\(value)"
    valueLabel.font = .systemFont(ofSize: fontSize, weight: .bold)
  }
}

final class PublishHubController: UIViewController, MediaPickerDelegate,
  UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIGestureRecognizerDelegate
{
  var initialMeetMode = false
  private let scroll = UIScrollView(), content = UIStackView(), bottomBar = UIView(),
    publish = UIFactory.button("Share Your Drop"), modeTrack = UIView(),
    dropMode = UIButton(type: .system), meetModeButton = UIButton(type: .system),
    modeCoin = CoinBadgeView(), titleField = UIFactory.field("Title"),
    bodyField = UIFactory.field("Tell the story..."), point = UIFactory.field("Meeting point"),
    count = UIFactory.field("Number of people"), dateButton = UIButton(type: .custom),
    emptyMediaButton = UIButton(type: .system), mediaScroll = UIScrollView(),
    picker = MediaPickerService(), datePicker = UIDatePicker(), mediaRow = UIStackView()
  private var meetMode = false, mediaAssets: [MediaAsset] = [], selectedCategory = "Waterfall Hike",
    selectedDifficulty = "Beginner Friendly"
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    picker.delegate = self
    meetMode = initialMeetMode
    configureCloseButton()
    configureLayout()
    configureModeTrack()
    datePicker.datePickerMode = .dateAndTime
    datePicker.minimumDate = Date()
    configureDateButton()
    count.keyboardType = .numberPad
    publish.addTarget(self, action: #selector(publishTap), for: .touchUpInside)
    renderFields()
  }
  private func configureDateButton() {
    dateButton.backgroundColor = AppTheme.surface
    dateButton.layer.cornerRadius = 17
    dateButton.contentHorizontalAlignment = .left
    dateButton.setTitle("Select date", for: .normal)
    dateButton.setTitleColor(.placeholderText, for: .normal)
    dateButton.titleLabel?.font = .systemFont(ofSize: 14)
    dateButton.contentEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16)
    dateButton.addTarget(self, action: #selector(showDateTimePicker), for: .touchUpInside)
    dateButton.snp.makeConstraints { $0.height.equalTo(54) }
  }
  private func configureCloseButton() {
    navigationItem.leftBarButtonItem = {
      let button = UIButton(type: .custom)
      button.setImage(
        UIImage(
          systemName: "xmark",
          withConfiguration: UIImage.SymbolConfiguration(pointSize: 23, weight: .bold)),
        for: .normal)
      button.tintColor = AppTheme.ink
      button.backgroundColor = .clear
      button.addTarget(self, action: #selector(close), for: .touchUpInside)
      button.snp.makeConstraints { $0.width.height.equalTo(44) }
      let item = UIBarButtonItem(customView: button)
      if #available(iOS 26.0, *) { item.hidesSharedBackground = true }
      return item
    }()
    navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
    navigationController?.navigationBar.shadowImage = UIImage()
    navigationController?.navigationBar.backgroundColor = .white
  }
  private func configureLayout() {
    scroll.showsVerticalScrollIndicator = false
    scroll.alwaysBounceVertical = true
    content.axis = .vertical
    content.spacing = 16
    content.isLayoutMarginsRelativeArrangement = true
    content.layoutMargins = .init(top: 8, left: 20, bottom: 30, right: 20)
    bottomBar.backgroundColor = .white
    mediaScroll.showsHorizontalScrollIndicator = false
    mediaScroll.alwaysBounceHorizontal = true
    mediaRow.axis = .horizontal
    mediaRow.alignment = .fill
    mediaRow.spacing = 10
    view.addSubview(scroll)
    view.addSubview(bottomBar)
    scroll.addSubview(content)
    bottomBar.addSubview(publish)
    mediaScroll.addSubview(mediaRow)
    mediaRow.snp.makeConstraints {
      $0.top.bottom.equalTo(mediaScroll.contentLayoutGuide)
      $0.leading.equalTo(mediaScroll.contentLayoutGuide)
      $0.trailing.equalTo(mediaScroll.contentLayoutGuide)
      $0.height.equalTo(mediaScroll.frameLayoutGuide)
    }
    scroll.snp.makeConstraints {
      $0.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
      $0.bottom.equalTo(bottomBar.snp.top)
    }
    content.snp.makeConstraints { $0.edges.width.equalToSuperview() }
    bottomBar.snp.makeConstraints {
      $0.leading.trailing.bottom.equalToSuperview()
      $0.height.equalTo(105)
    }
    publish.snp.makeConstraints {
      $0.top.equalToSuperview().offset(12)
      $0.leading.trailing.equalToSuperview().inset(24)
      $0.height.equalTo(52)
    }
  }
  private func configureModeTrack() {
    modeTrack.backgroundColor = AppTheme.surface
    modeTrack.layer.cornerRadius = 24
    dropMode.setTitle("Share Your Drop", for: .normal)
    meetModeButton.setTitle("Host a Water Meet", for: .normal)
    [dropMode, meetModeButton].forEach {
      $0.titleLabel?.font = .systemFont(ofSize: 12, weight: .regular)
      $0.setTitleColor(AppTheme.ink, for: .normal)
    }
    dropMode.addTarget(self, action: #selector(selectDrop), for: .touchUpInside)
    meetModeButton.addTarget(self, action: #selector(selectMeet), for: .touchUpInside)
    modeCoin.configure(value: AppRepository.shared.hostMeetCost, fontSize: 7)
    modeTrack.addSubview(dropMode)
    modeTrack.addSubview(meetModeButton)
    modeTrack.addSubview(modeCoin)
    dropMode.snp.makeConstraints {
      $0.top.bottom.leading.equalToSuperview().inset(4)
      $0.width.equalToSuperview().multipliedBy(0.48)
    }
    meetModeButton.snp.makeConstraints {
      $0.top.bottom.trailing.equalToSuperview().inset(4)
      $0.width.equalToSuperview().multipliedBy(0.52)
    }
    modeCoin.snp.makeConstraints {
      $0.top.equalToSuperview().offset(7)
      $0.trailing.equalToSuperview().offset(-14)
      $0.width.equalTo(34)
      $0.height.equalTo(12)
    }
    modeTrack.snp.makeConstraints { $0.height.equalTo(48) }
  }
  private func renderFields() {
    content.arrangedSubviews.forEach { $0.removeFromSuperview() }
    content.addArrangedSubview(modeTrack)
    styleModeButtons()
    if mediaAssets.isEmpty {
      configureEmptyMediaButton()
      content.addArrangedSubview(emptyMediaButton)
    } else {
      renderMediaRow()
      content.addArrangedSubview(mediaScroll)
    }
    content.addArrangedSubview(titleField)
    if meetMode {
      let row = UIStackView(arrangedSubviews: [dateButton, count])
      row.axis = .horizontal
      row.distribution = .fillEqually
      row.spacing = 15
      content.addArrangedSubview(row)
      content.addArrangedSubview(point)
    } else {
      bodyField.snp.remakeConstraints { $0.height.equalTo(92) }
      content.addArrangedSubview(bodyField)
      content.addArrangedSubview(
        makeChoiceSection(
          title: "Category", values: Array(AppRepository.shared.categories.dropFirst()),
          selected: selectedCategory, isCategory: true))
      content.addArrangedSubview(
        makeChoiceSection(
          title: "Difficulty", values: AppRepository.shared.difficulties,
          selected: selectedDifficulty, isCategory: false))
    }
    publish.setTitle(meetMode ? "Publish Meet" : "Share Your Drop", for: .normal)
    updateBottomCoin()
  }
  private func styleModeButtons() {
    for (button, selected) in [(dropMode, !meetMode), (meetModeButton, meetMode)] {
      button.backgroundColor = selected ? .white : .clear
      button.layer.cornerRadius = 20
      button.layer.shadowColor = UIColor.black.cgColor
      button.layer.shadowOpacity = selected ? 0.04 : 0
      button.layer.shadowRadius = 4
    }
  }
  private func makeChoiceSection(
    title: String, values: [String], selected: String, isCategory: Bool
  ) -> UIView {
    let container = UIView()
    let label = UIFactory.label(title, size: 14)
    let scroll = UIScrollView()
    let row = UIStackView()
    scroll.showsHorizontalScrollIndicator = false
    row.spacing = 8
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
      button.accessibilityIdentifier = (isCategory ? "category:" : "difficulty:") + value
      button.titleLabel?.numberOfLines = 1
      button.titleLabel?.lineBreakMode = .byClipping
      button.addTarget(self, action: #selector(choiceTap(_:)), for: .touchUpInside)
      let textWidth = ceil(
        (value as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 13)]).width)
      button.snp.makeConstraints { $0.width.equalTo(textWidth + 28) }
      row.addArrangedSubview(button)
    }
    scroll.addSubview(row)
    container.addSubview(label)
    container.addSubview(scroll)
    label.snp.makeConstraints { $0.top.leading.trailing.equalToSuperview() }
    scroll.snp.makeConstraints {
      $0.top.equalTo(label.snp.bottom).offset(8)
      $0.leading.trailing.bottom.equalToSuperview()
      $0.height.equalTo(36)
    }
    row.snp.makeConstraints {
      $0.leading.trailing.equalTo(scroll.contentLayoutGuide)
      $0.centerY.equalTo(scroll.frameLayoutGuide)
      $0.height.equalTo(34)
    }
    return container
  }
  private func configureEmptyMediaButton() {
    emptyMediaButton.backgroundColor = AppTheme.surface
    emptyMediaButton.layer.cornerRadius = 27
    emptyMediaButton.clipsToBounds = true
    emptyMediaButton.titleLabel?.numberOfLines = 3
    emptyMediaButton.titleLabel?.textAlignment = .center
    let title =
      meetMode ? "+\nUpload 1 cover image" : "+\nAdd photos or video\nUp to 10 items"
    let attributed = NSMutableAttributedString(
      string: title,
      attributes: [.foregroundColor: AppTheme.ink, .font: UIFont.systemFont(ofSize: 16)])
    attributed.addAttribute(
      .font, value: UIFont.systemFont(ofSize: 34, weight: .light),
      range: NSRange(location: 0, length: 1))
    if let primary = title.range(of: meetMode ? "Upload 1 cover image" : "Add photos or video") {
      attributed.addAttribute(
        .font, value: UIFont.systemFont(ofSize: 16, weight: .medium),
        range: NSRange(primary, in: title))
    }
    if !meetMode, let secondary = title.range(of: "Up to 10 items") {
      attributed.addAttributes(
        [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: AppTheme.secondary],
        range: NSRange(secondary, in: title))
    }
    emptyMediaButton.setAttributedTitle(attributed, for: .normal)
    emptyMediaButton.removeTarget(nil, action: nil, for: .allEvents)
    emptyMediaButton.addTarget(self, action: #selector(pickMedia), for: .touchUpInside)
    emptyMediaButton.snp.remakeConstraints { $0.height.equalTo(170) }
  }
  private func updateBottomCoin() {
    bottomBar.subviews.filter { $0.tag == 300 }.forEach { $0.removeFromSuperview() }
    guard meetMode else { return }
    let badge = CoinBadgeView()
    badge.configure(value: AppRepository.shared.hostMeetCost, fontSize: 15)
    badge.tag = 300
    bottomBar.addSubview(badge)
    badge.snp.makeConstraints {
      $0.trailing.equalTo(publish.snp.trailing).offset(-1)
      $0.centerY.equalTo(publish.snp.top)
      $0.width.equalTo(66)
      $0.height.equalTo(22)
    }
  }
  private func renderMediaRow() {
    mediaRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
    for (index, asset) in mediaAssets.enumerated() {
      let container = UIView()
      let image = UIImageView(
        image: MediaStore.shared.thumbnail(for: asset)
          ?? UIImage(systemName: "exclamationmark.triangle"))
      let remove = UIButton(type: .system)
      container.layer.cornerRadius = 18
      container.clipsToBounds = true
      image.contentMode = .scaleAspectFill
      image.clipsToBounds = true
      remove.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
      remove.tintColor = .white
      remove.backgroundColor = UIColor.black.withAlphaComponent(0.38)
      remove.layer.cornerRadius = 14
      remove.tag = index
      remove.addTarget(self, action: #selector(removeMedia(_:)), for: .touchUpInside)
      container.addSubview(image)
      if asset.kind == .video {
        let play = UIImageView(image: UIImage(systemName: "play.circle.fill"))
        play.tintColor = UIColor.white.withAlphaComponent(0.92)
        play.contentMode = .scaleAspectFit
        container.addSubview(play)
        play.snp.makeConstraints {
          $0.center.equalToSuperview()
          $0.width.height.equalTo(38)
        }
      }
      container.addSubview(remove)
      image.snp.makeConstraints { $0.edges.equalToSuperview() }
      remove.snp.makeConstraints {
        $0.top.equalToSuperview().offset(5)
        $0.trailing.equalToSuperview().offset(-5)
        $0.width.height.equalTo(28)
      }
      let previewGesture = UITapGestureRecognizer(target: self, action: #selector(previewMedia(_:)))
      previewGesture.delegate = self
      container.addGestureRecognizer(previewGesture)
      container.tag = index
      container.snp.makeConstraints { $0.width.equalTo(112) }
      mediaRow.addArrangedSubview(container)
    }
    let canAdd =
      meetMode ? mediaAssets.isEmpty : mediaAssets.first?.kind != .video && mediaAssets.count < 10
    if canAdd {
      let add = UIButton(type: .system)
      add.backgroundColor = AppTheme.surface
      add.layer.cornerRadius = 18
      add.tintColor = AppTheme.ink
      add.setImage(
        UIImage(
          systemName: "plus",
          withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .light)),
        for: .normal)
      add.setTitle(meetMode ? "  Add cover" : "  Add media", for: .normal)
      add.setTitleColor(AppTheme.secondary, for: .normal)
      add.titleLabel?.font = .systemFont(ofSize: 12)
      add.addTarget(self, action: #selector(pickMedia), for: .touchUpInside)
      add.snp.makeConstraints { $0.width.equalTo(112) }
      mediaRow.addArrangedSubview(add)
    }
    mediaScroll.snp.remakeConstraints { $0.height.equalTo(112) }
  }
  @objc private func removeMedia(_ sender: UIButton) {
    guard mediaAssets.indices.contains(sender.tag) else { return }
    MediaStore.shared.delete(mediaAssets.remove(at: sender.tag))
    renderFields()
  }
  @objc private func previewMedia(_ sender: UITapGestureRecognizer) {
    guard let index = sender.view?.tag, mediaAssets.indices.contains(index) else { return }
    navigationController?.pushViewController(
      MediaPreviewController(asset: mediaAssets[index]), animated: true)
  }
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch)
    -> Bool
  {
    var target: UIView? = touch.view
    while let view = target, view !== gestureRecognizer.view {
      if view is UIControl { return false }
      target = view.superview
    }
    return true
  }
  @objc private func pickMedia() {
    var options = [
      meetMode ? "Take Cover Photo" : "Take Photo",
      meetMode ? "Choose Cover Photo" : "Choose Photos",
    ]
    if !meetMode { options.append("Choose Video") }
    presentChoiceSheet(options: options) { [weak self] selection in
      guard let self, let selection else { return }
      if selection == 0 {
        guard
          self.meetMode || (self.mediaAssets.first?.kind != .video && self.mediaAssets.count < 10)
        else { return }
        self.openCamera()
      } else if selection == 1 {
        guard
          self.meetMode || (self.mediaAssets.first?.kind != .video && self.mediaAssets.count < 10)
        else { return }
        self.picker.present(
          from: self, limit: self.meetMode ? 1 : min(9, max(1, 10 - self.mediaAssets.count)),
          imagesOnly: true)
      } else {
        guard self.mediaAssets.isEmpty else { return }
        self.picker.present(from: self, limit: 1, videosOnly: true)
      }
    }
  }
  func mediaPicker(_ picker: MediaPickerService, didFinish assets: [MediaAsset]) {
    acceptPickedAssets(assets)
  }
  func mediaPicker(_ picker: MediaPickerService, didFail message: String) {
    showMessage("Media Unavailable", message)
  }
  private func acceptPickedAssets(_ assets: [MediaAsset]) {
    guard !assets.isEmpty else { return }
    if meetMode {
      guard let cover = assets.first(where: { $0.kind == .image }) else {
        assets.forEach(MediaStore.shared.delete)
        showMessage("Photo Required", "Meet cover must be a photo.")
        return
      }
      mediaAssets.forEach(MediaStore.shared.delete)
      mediaAssets = [cover]
      assets.filter { $0.id != cover.id }.forEach(MediaStore.shared.delete)
    } else if let video = assets.first(where: { $0.kind == .video }) {
      guard mediaAssets.isEmpty else {
        assets.forEach(MediaStore.shared.delete)
        showMessage("Video Limit", "Remove selected photos before choosing a video.")
        return
      }
      mediaAssets = [video]
      assets.filter { $0.id != video.id }.forEach(MediaStore.shared.delete)
    } else {
      guard mediaAssets.first?.kind != .video else {
        assets.forEach(MediaStore.shared.delete)
        showMessage("Photo Limit", "Remove the selected video before choosing photos.")
        return
      }
      let capacity = max(0, 10 - mediaAssets.count)
      let accepted = Array(assets.filter { $0.kind == .image }.prefix(capacity))
      let acceptedIDs = Set(accepted.map(\.id))
      assets.filter { !acceptedIDs.contains($0.id) }.forEach(MediaStore.shared.delete)
      mediaAssets.append(contentsOf: accepted)
    }
    renderFields()
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
      showMessage("Media Unavailable", "The photo could not be saved.")
      return
    }
    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "drop-camera-\(UUID().uuidString).jpg")
    do {
      try data.write(to: temporaryURL, options: .atomic)
      let asset = try MediaStore.shared.importFile(temporaryURL, kind: .image)
      try? FileManager.default.removeItem(at: temporaryURL)
      acceptPickedAssets([asset])
    } catch {
      try? FileManager.default.removeItem(at: temporaryURL)
      showMessage("Media Unavailable", "The photo could not be saved.")
    }
  }
  @objc private func close() {
    mediaAssets.forEach(MediaStore.shared.delete)
    dismiss(animated: true)
  }
  @objc private func selectDrop() {
    guard meetMode else { return }
    resetDraft()
    meetMode = false
    renderFields()
  }
  @objc private func selectMeet() {
    guard !meetMode else { return }
    resetDraft()
    meetMode = true
    renderFields()
  }
  private func resetDraft() {
    view.endEditing(true)
    mediaAssets.forEach(MediaStore.shared.delete)
    mediaAssets.removeAll()
    titleField.text = nil
    bodyField.text = nil
    point.text = nil
    count.text = nil
    selectedCategory = AppRepository.shared.categories.dropFirst().first ?? "Waterfall Hike"
    selectedDifficulty = AppRepository.shared.difficulties.first ?? "Beginner Friendly"
    datePicker.date = Date()
    dateButton.setTitle("Select date", for: .normal)
    dateButton.setTitleColor(.placeholderText, for: .normal)
    scroll.setContentOffset(.zero, animated: false)
  }
  @objc private func showDateTimePicker() {
    let sheet = MeetDateTimePickerSheetController(selectedDate: datePicker.date) {
      [weak self] date in
      guard let self else { return }
      self.datePicker.date = date
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .short
      self.dateButton.setTitle(formatter.string(from: date), for: .normal)
      self.dateButton.setTitleColor(AppTheme.ink, for: .normal)
    }
    present(sheet, animated: true)
  }
  @objc private func choiceTap(_ sender: UIButton) {
    guard let value = sender.accessibilityIdentifier else { return }
    if value.hasPrefix("category:") {
      selectedCategory = String(value.dropFirst(9))
    } else {
      selectedDifficulty = String(value.dropFirst(11))
    }
    renderFields()
  }
  @objc private func publishTap() {
    guard let title = titleField.text, !title.trimmingCharacters(in: .whitespaces).isEmpty else {
      showMessage("Title Required", "Please enter a title.")
      return
    }
    if meetMode {
      guard !mediaAssets.isEmpty, let capacity = Int(count.text ?? ""), capacity > 0,
        let p = point.text, !p.trimmingCharacters(in: .whitespaces).isEmpty,
        datePicker.date > Date()
      else {
        showMessage(
          "Meet Details Required", "Add a cover, future date, valid group size, and meeting point.")
        return
      }
      let cost = AppRepository.shared.hostMeetCost
      guard AppRepository.shared.wallet.coins >= cost else {
        presentBottomSheet(
          title: "Not Enough Coins", message: "Coins are insufficient. Please recharge first.",
          primary: "OK", secondary: nil
        ) { _ in }
        return
      }
      presentBottomSheet(
        title: "Host a Water Meet", message: "Spend \(cost) coins to host this Water Meet?"
      ) { ok in
        if ok
          && AppRepository.shared.hostMeet(
            title: title, date: self.datePicker.date, capacity: capacity, point: p,
            category: self.selectedCategory, cover: self.mediaAssets.first, cost: cost)
        {
          self.mediaAssets = []
          self.dismiss(animated: true)
        }
      }
    } else {
      guard !mediaAssets.isEmpty, let body = bodyField.text,
        !body.trimmingCharacters(in: .whitespaces).isEmpty
      else {
        showMessage("Drop Incomplete", "Add media and tell the story.")
        return
      }
      AppRepository.shared.addPost(
        title: title, body: body, category: selectedCategory, difficulty: selectedDifficulty,
        media: mediaAssets)
      mediaAssets = []
      dismiss(animated: true)
    }
  }
}

private final class MeetDateTimePickerSheetController: UIViewController {
  private let picker = UIDatePicker(), selectedDate: Date, completion: (Date) -> Void
  init(selectedDate: Date, completion: @escaping (Date) -> Void) {
    self.selectedDate = selectedDate
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .pageSheet
    if let sheet = sheetPresentationController {
      if #available(iOS 16.0, *) {
        sheet.detents = [.custom { _ in 380 }]
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
    let title = UIFactory.label("Select date and time", size: 20, weight: .semibold)
    let cancel = UIButton(type: .system)
    let done = UIButton(type: .system)
    cancel.setTitle("Cancel", for: .normal)
    done.setTitle("Done", for: .normal)
    cancel.setTitleColor(AppTheme.secondary, for: .normal)
    done.setTitleColor(AppTheme.blue, for: .normal)
    done.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
    cancel.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
    done.addTarget(self, action: #selector(doneTap), for: .touchUpInside)
    let minimumDate = Date()
    picker.datePickerMode = .dateAndTime
    picker.preferredDatePickerStyle = .wheels
    picker.minimumDate = minimumDate
    picker.date = max(selectedDate, minimumDate.addingTimeInterval(60))
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

private final class AIChatBubbleView: UIView {
  init(message: AIMessage) {
    super.init(frame: .zero)
    backgroundColor = message.isUser ? AppTheme.ink : AppTheme.surface
    layer.cornerRadius = 19

    let label = UIFactory.label(
      message.text, size: 14, weight: .regular,
      color: message.isUser ? .white : AppTheme.ink, lines: 0)
    label.setContentCompressionResistancePriority(.required, for: .vertical)
    addSubview(label)
    label.snp.makeConstraints {
      $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
      $0.width.lessThanOrEqualTo(250)
    }
  }

  required init?(coder: NSCoder) { fatalError() }
}

final class AIChatController: UIViewController, UITextFieldDelegate {
  private let backgroundImage = UIImageView(image: UIImage(named: "ai_bg"))
  private let animalImage = UIImageView(image: UIImage(named: "animal"))
  private let speechImage = UIImageView(image: UIImage(named: "chat_bg"))
  private let statusLabel = UIFactory.label(size: 12, weight: .semibold, lines: 5)
  private let coinLabel = UIFactory.label(size: 16, weight: .medium, color: .white)
  private let contentPanel = UIView()
  private let messagesScrollView = UIScrollView()
  private let messagesStack = UIStackView()
  private let composer = UIView()
  private let field = UITextField()
  private let sendButton = UIButton(type: .system)

  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    hidesBottomBarWhenPushed = true
    configureHeaderScene()
    configureConversationPanel()
    configureComposer()
    messagesStack.axis = .vertical
    messagesStack.spacing = 12
    field.delegate = self
    NotificationCenter.default.addObserver(
      self, selector: #selector(render), name: .appDataChanged, object: nil)
    render()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: animated)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(false, animated: animated)
  }

  private func configureHeaderScene() {
    backgroundImage.contentMode = .scaleAspectFill
    backgroundImage.clipsToBounds = true
    animalImage.contentMode = .scaleAspectFit
    speechImage.contentMode = .scaleToFill
    statusLabel.textAlignment = .center

    let backButton = UIButton(type: .system)
    backButton.tintColor = .white
    backButton.setImage(
      UIImage(named: "image/back")?.withRenderingMode(.alwaysTemplate), for: .normal)
    backButton.addTarget(self, action: #selector(backTap), for: .touchUpInside)

    let coinPill = UIView()
    coinPill.backgroundColor = UIColor(red: 0.29, green: 0.36, blue: 0.36, alpha: 0.78)
    coinPill.layer.cornerRadius = 20
    let coinIcon = UIImageView(image: UIImage(named: "coin"))
    coinIcon.contentMode = .scaleAspectFit

    view.addSubview(backgroundImage)
    view.addSubview(animalImage)
    view.addSubview(speechImage)
    view.addSubview(statusLabel)
    view.addSubview(backButton)
    view.addSubview(coinPill)
    coinPill.addSubview(coinIcon)
    coinPill.addSubview(coinLabel)

    backgroundImage.snp.makeConstraints { $0.edges.equalToSuperview() }
    animalImage.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide).offset(13)
      $0.trailing.equalToSuperview().offset(3)
      $0.width.equalTo(174)
      $0.height.equalTo(217)
    }
    speechImage.snp.makeConstraints {
      $0.top.equalTo(view.safeAreaLayoutGuide).offset(4)
      $0.leading.equalToSuperview().offset(82)
      $0.width.equalTo(166)
      $0.height.equalTo(126)
    }
    statusLabel.snp.makeConstraints {
      $0.centerX.equalTo(speechImage).offset(-2)
      $0.centerY.equalTo(speechImage).offset(-2)
      $0.width.equalTo(132)
    }
    backButton.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(10)
      $0.top.equalTo(view.safeAreaLayoutGuide).offset(5)
      $0.width.height.equalTo(44)
    }
    coinPill.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(18)
      $0.top.equalToSuperview().offset(201)
      $0.height.equalTo(40)
      $0.width.greaterThanOrEqualTo(126)
    }
    coinIcon.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(12)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(20)
    }
    coinLabel.snp.makeConstraints {
      $0.leading.equalTo(coinIcon.snp.trailing).offset(7)
      $0.trailing.equalToSuperview().offset(-14)
      $0.centerY.equalToSuperview()
    }
  }

  private func configureConversationPanel() {
    contentPanel.backgroundColor = .white
    contentPanel.layer.cornerRadius = 27
    contentPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    // The conversation remains scrollable, but its system scroll indicators are not part of the design.
    messagesScrollView.showsVerticalScrollIndicator = false
    messagesScrollView.showsHorizontalScrollIndicator = false
    messagesScrollView.backgroundColor = .clear
    view.addSubview(contentPanel)
    contentPanel.snp.makeConstraints {
      $0.top.equalToSuperview().offset(250)
      $0.leading.trailing.bottom.equalToSuperview()
    }

    let disclaimer = UIFactory.label(
      "AI tips are for reference only. Always evaluate current weather\nand flash flood warnings independently",
      size: 12, weight: .regular,
      color: UIColor(red: 0.60, green: 0.64, blue: 0.71, alpha: 1), lines: 2)
    contentPanel.addSubview(disclaimer)
    contentPanel.addSubview(messagesScrollView)
    messagesScrollView.addSubview(messagesStack)
    disclaimer.snp.makeConstraints {
      $0.top.equalToSuperview().offset(21)
      $0.leading.trailing.equalToSuperview().inset(26)
    }
    messagesScrollView.snp.makeConstraints {
      $0.top.equalTo(disclaimer.snp.bottom).offset(20)
      $0.leading.trailing.equalToSuperview().inset(20)
    }
    messagesStack.snp.makeConstraints {
      $0.edges.equalTo(messagesScrollView.contentLayoutGuide)
      $0.width.equalTo(messagesScrollView.frameLayoutGuide)
    }
  }

  private func configureComposer() {
    composer.backgroundColor = AppTheme.surface
    composer.layer.cornerRadius = 27
    field.placeholder = "Ask about a place..."
    field.font = .systemFont(ofSize: 14)
    field.textColor = AppTheme.ink
    field.returnKeyType = .send
    field.clearButtonMode = .never
    field.autocorrectionType = .yes

    let sendImage = UIImage(systemName: "paperplane.fill")
    sendButton.setImage(sendImage, for: .normal)
    sendButton.tintColor = UIColor(red: 0.19, green: 0.21, blue: 0.22, alpha: 1)
    sendButton.addTarget(self, action: #selector(sendTap), for: .touchUpInside)

    contentPanel.addSubview(composer)
    composer.addSubview(field)
    composer.addSubview(sendButton)
    composer.snp.makeConstraints {
      $0.leading.trailing.equalToSuperview().inset(18)
      $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-15)
      $0.height.equalTo(54)
    }
    field.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(22)
      $0.centerY.equalToSuperview()
      $0.trailing.equalTo(sendButton.snp.leading).offset(-8)
      $0.height.equalTo(44)
    }
    sendButton.snp.makeConstraints {
      $0.trailing.equalToSuperview().offset(-12)
      $0.centerY.equalToSuperview()
      $0.width.height.equalTo(38)
    }
    messagesScrollView.snp.makeConstraints {
      $0.bottom.equalTo(composer.snp.top).offset(-16)
    }
  }

  @objc private func render() {
    let repository = AppRepository.shared
    statusLabel.text =
      "\(repository.wallet.freeQuestions) Free\nQuestions\nRemaining\nAfter That: \(repository.aiMessageCost) Coins\nPer Question"
    coinLabel.text = "\(repository.wallet.coins.formatted()) Coins"
    for view in messagesStack.arrangedSubviews { view.removeFromSuperview() }
    for message in repository.aiMessagesForCurrentUser() {
      let row = UIView()
      let bubble = AIChatBubbleView(message: message)
      row.addSubview(bubble)
      bubble.snp.makeConstraints {
        $0.top.bottom.equalToSuperview()
        $0.width.lessThanOrEqualTo(278)
        if message.isUser {
          $0.trailing.equalToSuperview()
          $0.leading.greaterThanOrEqualToSuperview().offset(57)
        } else {
          $0.leading.equalToSuperview()
          $0.trailing.lessThanOrEqualToSuperview().offset(-57)
        }
      }
      messagesStack.addArrangedSubview(row)
    }
    view.layoutIfNeeded()
    scrollMessagesToBottom()
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    submitQuestion()
    return true
  }

  @objc private func sendTap() { submitQuestion() }

  private func submitQuestion() {
    guard let text = field.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty
    else { return }
    if AppRepository.shared.wallet.freeQuestions == 0
      && AppRepository.shared.wallet.coins < AppRepository.shared.aiMessageCost
    {
      presentBottomSheet(
        title: "Not Enough Coins", message: "Coins are insufficient. Please recharge first.",
        primary: "OK", secondary: nil
      ) { _ in }
    } else if AppRepository.shared.wallet.freeQuestions == 0 {
      presentBottomSheet(
        title: "Continue with AI Chat",
        message: "Continuing will cost \(AppRepository.shared.aiMessageCost) coins per message."
      ) { ok in
        if ok {
          _ = AppRepository.shared.consumeAIQuestion(text: text)
          self.field.text = ""
        }
      }
    } else {
      _ = AppRepository.shared.consumeAIQuestion(text: text)
      field.text = ""
    }
  }

  private func scrollMessagesToBottom() {
    let bottom = max(0, messagesScrollView.contentSize.height - messagesScrollView.bounds.height)
    messagesScrollView.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
  }

  @objc private func backTap() { navigationController?.popViewController(animated: true) }
}
