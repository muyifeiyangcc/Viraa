//
//  SceneDelegate.swift
//  Viraa
//
//  Created by myx mac on 2026/8/13.
//

import SnapKit
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    #if DEBUG
      let route = ProcessInfo.processInfo.arguments.drop(while: { $0 != "-snapshotRoute" })
        .dropFirst().first
    #else
      let route: String? = nil
    #endif
    let landing: UIViewController
    if let route {
      landing = SnapshotRouter.controller(for: route)
    } else if AppRepository.shared.isAuthenticated {
      if AppRepository.shared.currentUser?.profileComplete == false {
        landing = UINavigationController(rootViewController: ProfileSetupController())
      } else {
        landing = MainTabController()
      }
    } else {
      landing = UINavigationController(rootViewController: LoginLandingController())
    }
    window.rootViewController = landing
    self.window = window
    window.makeKeyAndVisible()
    if let route {
      DispatchQueue.main.async { SnapshotRouter.presentState(route, over: landing) }
    } else if !AppRepository.shared.eulaAccepted {
      DispatchQueue.main.async { EULAPresenter.present(over: landing) }
    }
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
  }

  func sceneWillResignActive(_ scene: UIScene) {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
  }

}

enum SnapshotRouter {
  static func controller(for route: String) -> UIViewController {
    AppRepository.shared.prepareSnapshotSession()
    let navigation: (UIViewController) -> UIViewController = {
      UINavigationController(rootViewController: $0)
    }
    switch route {
    case "launch": return SnapshotLaunchController()
    case "email": return navigation(EmailAuthController(mode: .signIn))
    case "signup": return navigation(EmailAuthController(mode: .signUp))
    case "reset": return navigation(EmailAuthController(mode: .reset))
    case "profile-setup-man", "profile-setup-madam": return navigation(ProfileSetupController())
    case "post-detail": return navigation(PostDetailController(postID: "post1"))
    case "other-profile": return navigation(OtherProfileController(userID: "theo"))
    case "chat-text", "chat-voice":
      return navigation(
        ChatController(conversation: AppRepository.shared.conversation(with: "theo")))
    case "report": return navigation(ReportController(targetID: "theo"))
    case "settings": return navigation(SettingsController())
    case "edit-profile": return navigation(EditProfileController())
    case "ai-chat": return navigation(AIChatController())
    case "recharge": return navigation(RechargeController())
    case "publish": return navigation(PublishHubController())
    case "host-meet":
      let value = PublishHubController()
      value.initialMeetMode = true
      return navigation(value)
    case "meet-detail": return navigation(MeetDetailController(meetID: "meet1"))
    case "privacy": return navigation(PolicyController(title: "Privacy Policy"))
    case "terms": return navigation(PolicyController(title: "Terms of Service"))
    case "messages":
      let tab = MainTabController()
      tab.selectedIndex = 3
      return tab
    case "me":
      let tab = MainTabController()
      tab.selectedIndex = 4
      return tab
    case "meets":
      let tab = MainTabController()
      tab.selectedIndex = 1
      return tab
    case "home", "feed":
      let tab = MainTabController()
      tab.selectedIndex = 0
      return tab
    default: return navigation(LoginLandingController())
    }
  }

  static func presentState(_ route: String, over root: UIViewController) {
    switch route {
    case "eula": EULAPresenter.present(over: root)
    case "coins-empty":
      root.presentBottomSheet(
        title: "Not Enough Coins", message: "Coins are insufficient. Please recharge first.",
        primary: "OK", secondary: nil
      ) { _ in }
    case "login-required":
      root.presentBottomSheet(
        title: "Sign In Required", message: "Please sign in to use this feature.",
        primary: "Sign In"
      ) { _ in }
    case "delete-account":
      root.presentBottomSheet(
        title: "Delete Account", message: "This action cannot be recovered.", primary: "Delete"
      ) { _ in }
    case "sign-out":
      root.presentBottomSheet(title: "Sign Out", message: "Are you sure you want to sign out?") {
        _ in
      }
    case "ai-confirm":
      root.presentBottomSheet(
        title: "Continue with AI Chat", message: "Continuing will cost 10 coins per message."
      ) { _ in }
    case "host-confirm":
      root.presentBottomSheet(
        title: "Host a Water Meet", message: "Spend 300 coins to host this Water Meet?"
      ) { _ in }
    case "chat-locked":
      root.presentBottomSheet(
        title: "Connect to Chat", message: "Follow each other to unlock messages.", primary: "OK",
        secondary: nil
      ) { _ in }
    default: break
    }
  }
}

final class SnapshotLaunchController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    let background = UIFactory.image("image/lau", corner: 0)
    let shade = UIView()
    let logo = UIFactory.label("VIRAA", size: 52, weight: .bold, color: .white)
    let subtitle = UIFactory.label(
      "W a t e r f a l l   S o c i a l   C l u b", size: 12, weight: .semibold, color: .white)
    shade.backgroundColor = UIColor.black.withAlphaComponent(0.22)
    logo.textAlignment = .center
    subtitle.textAlignment = .center
    view.addSubview(background)
    view.addSubview(shade)
    view.addSubview(logo)
    view.addSubview(subtitle)
    background.snp.makeConstraints { $0.edges.equalToSuperview() }
    shade.snp.makeConstraints { $0.edges.equalToSuperview() }
    logo.snp.makeConstraints {
      $0.center.equalToSuperview()
      $0.leading.trailing.equalToSuperview().inset(20)
    }
    subtitle.snp.makeConstraints {
      $0.top.equalTo(logo.snp.bottom).offset(12)
      $0.centerX.equalToSuperview()
    }
  }
}

enum EULAPresenter {
  static func present(over controller: UIViewController) {
    let eula = EULAController()
    eula.modalPresentationStyle = .overFullScreen
    eula.isModalInPresentation = true
    controller.present(eula, animated: true)
  }
}
