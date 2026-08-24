@preconcurrency import AVFoundation
import AVKit
@preconcurrency import PhotosUI
import SnapKit
import UIKit

@MainActor
final class MediaStore {
  static let shared = MediaStore()
  private let folderName = "ViraaMedia"
  private init() {
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }
  private var directory: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(folderName, isDirectory: true)
  }
  func url(for asset: MediaAsset) -> URL {
    let stored = directory.appendingPathComponent(asset.relativePath)
    if FileManager.default.fileExists(atPath: stored.path) { return stored }
    return bundledURL(for: asset) ?? stored
  }
  func exists(_ asset: MediaAsset) -> Bool {
    FileManager.default.fileExists(atPath: directory.appendingPathComponent(asset.relativePath).path)
      || bundledURL(for: asset) != nil
      || (asset.kind == .image && bundledImage(for: asset) != nil)
  }
  func importFile(_ source: URL, kind: MediaKind, duration: TimeInterval? = nil) throws
    -> MediaAsset
  {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let id = UUID().uuidString
    let ext =
      source.pathExtension.isEmpty ? defaultExtension(kind) : source.pathExtension.lowercased()
    let asset = MediaAsset(
      id: id, kind: kind, relativePath: "\(id).\(ext)", createdAt: Date(), duration: duration)
    try FileManager.default.copyItem(at: source, to: url(for: asset))
    return asset
  }
  func delete(_ asset: MediaAsset) { try? FileManager.default.removeItem(at: url(for: asset)) }
  func cleanupOrphans(referencedIDs: Set<String>) {
    guard
      let files = try? FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil)
    else { return }
    for file in files where !referencedIDs.contains(file.deletingPathExtension().lastPathComponent)
    { try? FileManager.default.removeItem(at: file) }
  }
  func thumbnail(for asset: MediaAsset) -> UIImage? {
    guard exists(asset) else { return nil }
    if asset.kind == .image {
      return UIImage(contentsOfFile: url(for: asset).path) ?? bundledImage(for: asset)
    }
    if asset.kind == .video {
      let generator = AVAssetImageGenerator(asset: AVAsset(url: url(for: asset)))
      generator.appliesPreferredTrackTransform = true
      guard let image = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
      return UIImage(cgImage: image)
    }
    return nil
  }
  private func bundledImage(for asset: MediaAsset) -> UIImage? {
    let name = URL(fileURLWithPath: asset.relativePath).deletingPathExtension().lastPathComponent
    return UIImage(named: name) ?? UIImage(named: asset.relativePath)
  }
  private func bundledURL(for asset: MediaAsset) -> URL? {
    let path = URL(fileURLWithPath: asset.relativePath)
    return Bundle.main.url(
      forResource: path.deletingPathExtension().lastPathComponent,
      withExtension: path.pathExtension,
      subdirectory: "file")
      ?? Bundle.main.url(
        forResource: path.deletingPathExtension().lastPathComponent,
        withExtension: path.pathExtension)
  }
  private func defaultExtension(_ kind: MediaKind) -> String {
    switch kind {
    case .image: return "jpg"
    case .video: return "mov"
    case .audio: return "m4a"
    }
  }
}

protocol MediaPickerDelegate: AnyObject {
  func mediaPicker(_ picker: MediaPickerService, didFinish assets: [MediaAsset])
  func mediaPicker(_ picker: MediaPickerService, didFail message: String)
}
extension MediaPickerDelegate {
  func mediaPicker(_ picker: MediaPickerService, didFail message: String) {}
}
private final class PickerResultsBox: @unchecked Sendable {
  let values: [PHPickerResult]
  init(_ values: [PHPickerResult]) { self.values = values }
}

@MainActor
final class MediaPickerService: NSObject, PHPickerViewControllerDelegate {
  weak var delegate: MediaPickerDelegate?
  private var limit = 1
  func present(
    from controller: UIViewController, limit: Int, imagesOnly: Bool = false,
    videosOnly: Bool = false
  ) {
    self.limit = limit
    var config = PHPickerConfiguration(photoLibrary: .shared())
    config.selectionLimit = limit
    config.selection = .ordered
    config.filter = videosOnly ? .videos : imagesOnly ? .images : .any(of: [.images, .videos])
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    controller.present(picker, animated: true)
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    load(PickerResultsBox(Array(results.prefix(limit))), index: 0, values: [])
  }
  private func load(_ results: PickerResultsBox, index: Int, values: [MediaAsset]) {
    guard index < results.values.count else {
      delegate?.mediaPicker(self, didFinish: values)
      return
    }
    let provider = results.values[index].itemProvider
    let kind: MediaKind =
      provider.hasItemConformingToTypeIdentifier("public.movie") ? .video : .image
    let type = kind == .video ? "public.movie" : "public.image"
    provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, error in
      guard let self else { return }
      guard let url else {
        let message = error?.localizedDescription ?? "The selected media is unavailable."
        Task { @MainActor in
          self.delegate?.mediaPicker(self, didFail: message)
          self.load(results, index: index + 1, values: values)
        }
        return
      }
      let extensionName =
        url.pathExtension.isEmpty ? (kind == .video ? "mov" : "jpg") : url.pathExtension
      let stableTemporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
        "picker-\(UUID().uuidString).\(extensionName)")
      do {
        try FileManager.default.copyItem(at: url, to: stableTemporaryURL)
      } catch {
        Task { @MainActor in
          self.delegate?.mediaPicker(self, didFail: "The selected media could not be saved.")
          self.load(results, index: index + 1, values: values)
        }
        return
      }
      Task { @MainActor in
        var next = values
        defer { try? FileManager.default.removeItem(at: stableTemporaryURL) }
        do { next.append(try MediaStore.shared.importFile(stableTemporaryURL, kind: kind)) } catch {
          self.delegate?.mediaPicker(self, didFail: "The selected media could not be saved.")
        }
        self.load(results, index: index + 1, values: next)
      }
    }
  }
}

protocol AudioRecorderDelegate: AnyObject {
  func audioRecorder(_ recorder: AudioRecorderService, didFinish asset: MediaAsset)
  func audioRecorderPermissionDenied()
  func audioRecorder(_ recorder: AudioRecorderService, didFail message: String)
}
extension AudioRecorderDelegate {
  func audioRecorder(_ recorder: AudioRecorderService, didFail message: String) {}
}

@MainActor
final class AudioRecorderService: NSObject, AVAudioRecorderDelegate {
  weak var delegate: AudioRecorderDelegate?
  private var recorder: AVAudioRecorder?, startedAt: Date?
  func requestAndStart() {
    if #available(iOS 17.0, *) {
      Task { @MainActor [weak self] in
        guard let self else { return }
        let allowed = await AVAudioApplication.requestRecordPermission()
        allowed ? self.start() : self.delegate?.audioRecorderPermissionDenied()
      }
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
        DispatchQueue.main.async { [weak self] in
          guard let self else { return }
          allowed ? self.start() : self.delegate?.audioRecorderPermissionDenied()
        }
      }
    }
  }
  private func start() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
      try session.setActive(true)
      let temp = FileManager.default.temporaryDirectory.appendingPathComponent(
        "\(UUID().uuidString).m4a")
      recorder = try AVAudioRecorder(
        url: temp,
        settings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 12000, AVNumberOfChannelsKey: 1,
          AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ])
      recorder?.delegate = self
      guard recorder?.record() == true else { throw NSError(domain: "AudioRecorder", code: 1) }
      startedAt = Date()
    } catch {
      delegate?.audioRecorder(self, didFail: "Recording could not start. Please try again.")
    }
  }
  func finish(cancelled: Bool) {
    guard let recorder else { return }
    let duration = Date().timeIntervalSince(startedAt ?? Date())
    recorder.stop()
    defer {
      try? FileManager.default.removeItem(at: recorder.url)
      self.recorder = nil
    }
    guard !cancelled, duration >= 0.5 else { return }
    do {
      let asset = try MediaStore.shared.importFile(recorder.url, kind: .audio, duration: duration)
      delegate?.audioRecorder(self, didFinish: asset)
    } catch { delegate?.audioRecorder(self, didFail: "The voice message could not be saved.") }
  }
}

@MainActor
final class AudioPlayerService: NSObject, AVAudioPlayerDelegate {
  static let shared = AudioPlayerService()
  private var player: AVAudioPlayer?
  func toggle(asset: MediaAsset) throws {
    let url = MediaStore.shared.url(for: asset)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw NSError(domain: "Media", code: 404)
    }
    if player?.isPlaying == true {
      player?.stop()
      return
    }
    player = try AVAudioPlayer(contentsOf: url)
    player?.play()
  }
}

@MainActor
final class MediaPreviewController: UIViewController {
  private let asset: MediaAsset
  init(asset: MediaAsset) {
    self.asset = asset
    super.init(nibName: nil, bundle: nil)
    hidesBottomBarWhenPushed = true
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationItem.hidesBackButton = true
    navigationItem.leftBarButtonItem = nil
    navigationController?.setNavigationBarHidden(true, animated: false)
  }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    // The system player is presented full-screen, so the navigation bar may be hidden.
    // Keep an explicit white back control above the player content.
    navigationController?.setNavigationBarHidden(true, animated: false)
    let backButton = UIButton(type: .system)
    backButton.tintColor = .white
    backButton.setImage(
      UIImage(named: "image/back")?.withRenderingMode(.alwaysTemplate), for: .normal)
    backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
    backButton.accessibilityLabel = "Back"
    view.addSubview(backButton)
    backButton.snp.makeConstraints {
      $0.leading.equalToSuperview().offset(16)
      $0.top.equalTo(view.safeAreaLayoutGuide).offset(8)
      $0.width.height.equalTo(44)
    }
    guard MediaStore.shared.exists(asset) else {
      showMessage(
        "Media Unavailable", "This media file is missing. You can remove it and choose another.")
      return
    }
    if asset.kind == .video {
      let player = AVPlayer(url: MediaStore.shared.url(for: asset))
      let child = AVPlayerViewController()
      child.player = player
      addChild(child)
      view.addSubview(child.view)
      child.view.frame = view.bounds
      child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      child.didMove(toParent: self)
      player.play()
    } else {
      let image = UIImageView(image: MediaStore.shared.thumbnail(for: asset))
      image.contentMode = .scaleAspectFit
      view.addSubview(image)
      image.frame = view.bounds
      image.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    view.bringSubviewToFront(backButton)
  }
  @objc private func back() { navigationController?.popViewController(animated: true) }
}
