import Foundation

private struct AIReplyRule {
  let keywords: [String]
  let response: String
}

private let aiReplyRules: [AIReplyRule] = [
  AIReplyRule(
    keywords: ["weather", "rain", "storm", "forecast", "temperature"],
    response:
      "Check the latest forecast before leaving, and allow extra time if rain is expected. Conditions can change quickly near the water."
  ),
  AIReplyRule(
    keywords: ["flood", "flash", "warning", "danger", "safe"],
    response:
      "If there is a flood or safety warning, postpone the trip and stay away from fast-moving water. Never cross a swollen stream."
  ),
  AIReplyRule(
    keywords: ["waterfall", "falls", "drop"],
    response:
      "Waterfalls are often slippery and stronger than they look. Keep a wide distance from the edge and use marked paths."
  ),
  AIReplyRule(
    keywords: ["swim", "swimming", "pool", "water level"],
    response:
      "Swim only where it is permitted and conditions are calm. Check the entry and exit points first, and avoid swimming alone."
  ),
  AIReplyRule(
    keywords: ["trail", "hike", "hiking", "route", "path"],
    response:
      "Stay on the marked trail, wear shoes with reliable grip, and turn back if the route becomes unclear or unstable."
  ),
  AIReplyRule(
    keywords: ["when", "morning", "early", "sunset", "time"],
    response:
      "Earlier is usually better for cooler temperatures, clearer light, and more time to return before dark."
  ),
  AIReplyRule(
    keywords: ["gear", "shoes", "jacket", "equipment", "pack"],
    response:
      "Bring grippy footwear, a light layer, water, a charged phone, and a small first-aid kit. Pack for changing conditions."
  ),
  AIReplyRule(
    keywords: ["meet", "group", "people", "join", "trip"],
    response:
      "Agree on a meeting point and a return time before setting out. Keep the group together near slippery or exposed sections."
  ),
  AIReplyRule(
    keywords: ["food", "snack", "drink", "bottle", "hydration"],
    response:
      "Carry more water than you expect to need and pack a simple snack. Refill only from a clearly safe and approved source."
  ),
  AIReplyRule(
    keywords: ["parking", "entry", "entrance", "access"],
    response:
      "Confirm the entry point and parking rules before you go. Keep access routes clear for other visitors and emergency vehicles."
  ),
  AIReplyRule(
    keywords: ["beginner", "first time", "new", "easy"],
    response:
      "For a first visit, choose a short marked route, go with someone experienced, and leave enough daylight for an easy return."
  ),
  AIReplyRule(
    keywords: ["cold", "freezing", "water"],
    response:
      "Cold water can reduce strength quickly. Keep dry layers nearby, enter gradually, and get out immediately if you start shivering."
  ),
  AIReplyRule(
    keywords: ["slippery", "rocks", "rock", "cliff", "edge"],
    response:
      "Wet rocks can be unstable and very slippery. Keep three points of contact and avoid climbing beyond marked viewpoints."
  ),
  AIReplyRule(
    keywords: ["wildlife", "animal", "snake", "bear"],
    response:
      "Give wildlife plenty of space, keep food secured, and never approach or feed an animal. Quiet observation is safest."
  ),
  AIReplyRule(
    keywords: ["photo", "camera", "video", "picture"],
    response:
      "Keep your footing and your distance while taking photos. A secure viewpoint is more important than getting a closer shot."
  ),
  AIReplyRule(
    keywords: ["emergency", "injury", "help", "lost"],
    response:
      "Move to a stable safe place, contact emergency services, and share your last known location. Do not take shortcuts through the water."
  ),
]

private let aiFallbackReply =
  "I can help with general trail planning, water safety, weather, timing, and preparation. Ask about one of those topics for a more useful suggestion."

@MainActor
final class AppRepository {
  static let shared = AppRepository()
  private let defaults = UserDefaults.standard
  private let snapshotKey = "viraa.snapshot.v9"
  private(set) var users: [User] = [], posts: [Post] = [], meets: [Meet] = [],
    conversations: [Conversation] = [], messages: [ChatMessage] = [], reports: [ReportRecord] = [],
    aiMessages: [AIMessage] = []
  private var walletsByUser: [String: Wallet] = [:], followingByUser: [String: Set<String>] = [:],
    blockedByUser: [String: Set<String>] = [:]
  private var processedTransactionIDs: Set<String> = []
  private var presetFollowingInitialized = false
  private var corruptSnapshot: Data?
  private(set) var currentUserID: String?, isGuest = false, state: ViewState = .loading

  var isAuthenticated: Bool { currentUserID != nil && !isGuest }
  var currentUser: User? { users.first { $0.id == currentUserID } }
  var wallet: Wallet {
    walletsByUser[currentUserID ?? "guest"] ?? Wallet(coins: 0, diamonds: 0, freeQuestions: 3)
  }
  var following: Set<String> { followingByUser[currentUserID ?? "guest"] ?? [] }
  var blocked: Set<String> { blockedByUser[currentUserID ?? "guest"] ?? [] }
  var eulaAccepted: Bool { defaults.bool(forKey: "eulaAccepted") }
  let categories = ["All", "Waterfall Hike", "Swimming Hole", "River Adventure"]
  let difficulties = ["Beginner Friendly", "Moderate", "Experienced Only"]
  let hostMeetCost = 300, aiMessageCost = 10

  private init() {
    // Drop the older demo snapshot so the CSV-backed catalog is used on the next launch.
    defaults.removeObject(forKey: "viraa.snapshot.v3")
    defaults.removeObject(forKey: "viraa.snapshot.v4")
    defaults.removeObject(forKey: "viraa.snapshot.v5")
    defaults.removeObject(forKey: "viraa.snapshot.v6")
    defaults.removeObject(forKey: "viraa.snapshot.v7")
    defaults.removeObject(forKey: "viraa.snapshot.v8")
    reloadFromDisk()
  }

  func reloadFromDisk() {
    state = .loading
    notify()
    guard let data = defaults.data(forKey: snapshotKey) else {
      seed()
      persist()
      state = .content
      notify()
      return
    }
    do {
      apply(try JSONDecoder().decode(AppSnapshot.self, from: data))
      ensurePresetCredential()
      state = contentState()
      validateMediaFiles()
    } catch {
      corruptSnapshot = data
      state = .parsingError
    }
    notify()
  }

  func recoverFromParsingError() {
    guard state == .parsingError else {
      reloadFromDisk()
      return
    }
    if let corruptSnapshot {
      defaults.set(
        corruptSnapshot, forKey: "\(snapshotKey).corrupt.\(Int(Date().timeIntervalSince1970))")
    }
    defaults.removeObject(forKey: snapshotKey)
    corruptSnapshot = nil
    seed()
    persist()
    MediaStore.shared.cleanupOrphans(referencedIDs: Set(allMedia().map(\.id)))
    state = .content
    notify()
  }

  func acceptEULA() { defaults.set(true, forKey: "eulaAccepted") }
  func beginGuest() {
    currentUserID = nil
    isGuest = true
    state = contentState()
    notify()
  }
  func prepareSnapshotSession() {
    if users.contains(where: { $0.id == "preset" && $0.isActive }) {
      currentUserID = "preset"
      isGuest = false
      state = contentState()
      notify()
    }
  }

  @discardableResult func signIn(email: String, password: String) -> Bool {
    guard !(email == "123@gmail.com" && defaults.bool(forKey: "presetInvalidated")),
      let user = users.first(where: {
        $0.email.caseInsensitiveCompare(email) == .orderedSame && $0.isActive
      }),
      CredentialStore.shared.verify(password: password, for: user.id)
    else { return false }
    currentUserID = user.id
    isGuest = false
    if user.id == "preset" && !presetFollowingInitialized {
      if let candidate = users.filter({ $0.id != user.id && $0.isActive }).randomElement() {
        followingByUser[user.id, default: []].insert(candidate.id)
      }
      presetFollowingInitialized = true
    }
    persistAndNotify()
    return true
  }

  func signOut() {
    currentUserID = nil
    isGuest = false
    persistAndNotify()
  }

  @discardableResult func register(email: String, password: String) -> Bool {
    guard !users.contains(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) else {
      return false
    }
    let user = User(
      id: UUID().uuidString, email: email, name: "Explorer",
      bio: "Ready for the next water adventure.", location: "", gender: .man, isActive: true,
      profileComplete: false)
    guard CredentialStore.shared.set(password: password, for: user.id) else { return false }
    users.append(user)
    walletsByUser[user.id] = Wallet(coins: 0, diamonds: 0, freeQuestions: 3)
    followingByUser[user.id] = []
    blockedByUser[user.id] = []
    currentUserID = user.id
    isGuest = false
    persistAndNotify()
    return true
  }

  func resetPassword(email: String, password: String) -> Bool {
    guard
      let user = users.first(where: {
        $0.email.caseInsensitiveCompare(email) == .orderedSame && $0.isActive
      })
    else { return false }
    return CredentialStore.shared.set(password: password, for: user.id)
  }

  func updateProfile(
    name: String, bio: String, location: String? = nil, gender: Gender? = nil,
    birthDate: Date? = nil, avatar: MediaAsset? = nil
  ) {
    guard let id = currentUserID, let index = users.firstIndex(where: { $0.id == id }) else {
      return
    }
    let prior = users[index].avatar
    users[index].name = name
    users[index].bio = bio
    if let location { users[index].location = location }
    if let gender { users[index].gender = gender }
    if let birthDate { users[index].birthDate = birthDate }
    if let avatar {
      users[index].avatar = avatar
      if prior?.id != avatar.id { prior.map(MediaStore.shared.delete) }
    }
    users[index].profileComplete = true
    persistAndNotify()
  }

  func deleteAccount() {
    guard let id = currentUserID, let index = users.firstIndex(where: { $0.id == id }) else {
      return
    }
    if users[index].email == "123@gmail.com" { defaults.set(true, forKey: "presetInvalidated") }
    CredentialStore.shared.delete(userID: id)
    users[index].isActive = false
    posts.removeAll { $0.authorID == id }
    meets.removeAll { $0.hostID == id }
    messages.removeAll { $0.senderID == id }
    currentUserID = nil
    isGuest = false
    persistAndNotify()
    MediaStore.shared.cleanupOrphans(referencedIDs: Set(allMedia().map(\.id)))
  }

  func user(_ id: String) -> User? { users.first { $0.id == id } }
  func visibleUsers() -> [User] {
    users.filter { $0.id != currentUserID && !blocked.contains($0.id) && $0.isActive }
  }
  func visibleComments(_ post: Post) -> [Comment] {
    post.comments.filter { !blocked.contains($0.authorID) }
  }
  func visiblePosts(category: String? = nil, authorID: String? = nil) -> [Post] {
    posts.filter {
      !blocked.contains($0.authorID)
        && (category == nil || category == "All" || $0.category == category)
        && (authorID == nil || $0.authorID == authorID)
    }
  }
  func visibleMeets(category: String? = nil, hostID: String? = nil) -> [Meet] {
    meets.filter {
      !blocked.contains($0.hostID)
        && (category == nil || category == "All" || $0.category == category)
        && (hostID == nil || $0.hostID == hostID)
    }
  }
  func visibleJoinedMeets(userID: String) -> [Meet] {
    // My Meets includes both activities hosted by the user and activities they joined.
    visibleMeets().filter {
      $0.hostID == userID || $0.participantIDs.contains(userID)
    }
  }
  func visibleConversations() -> [Conversation] {
    conversations.filter {
      $0.participantIDs.filter { $0 != currentUserID }.allSatisfy { !blocked.contains($0) }
    }
  }
  func visibleMessages(conversationID: String) -> [ChatMessage] {
    messages.filter { $0.conversationID == conversationID && !blocked.contains($0.senderID) }.sorted
    { $0.createdAt < $1.createdAt }
  }
  func followersCount(userID: String) -> Int {
    followingByUser.filter { !$0.value.isDisjoint(with: [userID]) && !blocked.contains($0.key) }
      .count
  }
  func followingCount(userID: String) -> Int {
    (followingByUser[userID] ?? []).filter { !blocked.contains($0) }.count
  }
  func followerUsers(userID: String) -> [User] {
    users.filter { user in
      user.id != currentUserID && user.isActive && !blocked.contains(user.id)
        && (followingByUser[user.id] ?? []).contains(userID)
    }
  }
  func followingUsers(userID: String) -> [User] {
    let ids = followingByUser[userID] ?? []
    return users.filter {
      ids.contains($0.id) && $0.id != currentUserID && $0.isActive && !blocked.contains($0.id)
    }
  }
  func filteredLikeCount(postID: String) -> Int {
    posts.first(where: { $0.id == postID })?.likedBy.filter { !blocked.contains($0) }.count ?? 0
  }
  func isLiked(_ postID: String) -> Bool {
    guard let uid = currentUserID else { return false }
    return posts.first(where: { $0.id == postID })?.likedBy.contains(uid) == true
  }
  func isSaved(_ postID: String) -> Bool {
    guard let uid = currentUserID else { return false }
    return posts.first(where: { $0.id == postID })?.savedBy.contains(uid) == true
  }

  func toggleLike(postID: String) {
    guard let uid = currentUserID, let index = posts.firstIndex(where: { $0.id == postID }) else {
      return
    }
    posts[index].likedBy.formSymmetricDifference([uid])
    persistAndNotify()
  }
  func toggleSave(postID: String) {
    guard let uid = currentUserID, let index = posts.firstIndex(where: { $0.id == postID }) else {
      return
    }
    posts[index].savedBy.formSymmetricDifference([uid])
    persistAndNotify()
  }
  func addComment(postID: String, text: String) {
    guard let uid = currentUserID, let index = posts.firstIndex(where: { $0.id == postID }),
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return }
    posts[index].comments.append(
      Comment(id: UUID().uuidString, postID: postID, authorID: uid, text: text, createdAt: Date()))
    persistAndNotify()
  }
  func toggleFollow(userID: String) {
    guard let uid = currentUserID else { return }
    followingByUser[uid, default: []].formSymmetricDifference([userID])
    persistAndNotify()
  }
  func isFollowing(_ id: String) -> Bool { following.contains(id) }
  func mutuallyFollows(_ id: String) -> Bool {
    guard let uid = currentUserID else { return false }
    return following.contains(id) && (followingByUser[id] ?? []).contains(uid)
  }
  func block(userID: String) {
    guard let uid = currentUserID else { return }
    blockedByUser[uid, default: []].insert(userID)
    persistAndNotify()
  }
  func unblock(userID: String) {
    guard let uid = currentUserID else { return }
    blockedByUser[uid, default: []].remove(userID)
    persistAndNotify()
  }
  func report(targetID: String, reason: String) {
    guard let uid = currentUserID else { return }
    reports.append(
      ReportRecord(
        id: UUID().uuidString, reporterID: uid, targetID: targetID, reason: reason,
        createdAt: Date()))
    persistAndNotify()
  }

  func addPost(
    title: String, body: String, category: String, difficulty: String, media: [MediaAsset]
  ) {
    guard let uid = currentUserID else { return }
    posts.insert(
      Post(
        id: UUID().uuidString, authorID: uid, title: title, body: body, category: category,
        difficulty: difficulty, location: currentUser?.location ?? "", createdAt: Date(),
        likedBy: [], comments: [], media: media), at: 0)
    persistAndNotify()
  }
  func join(meetID: String) {
    guard let uid = currentUserID, let index = meets.firstIndex(where: { $0.id == meetID }) else {
      return
    }
    if meets[index].participantIDs.contains(uid) {
      meets[index].participantIDs.remove(uid)
    } else if meets[index].participantIDs.count < meets[index].capacity
      && meets[index].date > Date()
    {
      meets[index].participantIDs.insert(uid)
    }
    persistAndNotify()
  }
  func hostMeet(
    title: String, date: Date, capacity: Int, point: String, category: String, cover: MediaAsset?,
    cost: Int
  ) -> Bool {
    guard let uid = currentUserID, var wallet = walletsByUser[uid], wallet.coins >= cost,
      date > Date(), capacity > 0, !point.isEmpty
    else { return false }
    wallet.coins -= cost
    walletsByUser[uid] = wallet
    meets.insert(
      Meet(
        id: UUID().uuidString, hostID: uid, title: title, date: date, capacity: capacity,
        participantIDs: [uid], meetingPoint: point, category: category, cost: cost, cover: cover),
      at: 0)
    persistAndNotify()
    return true
  }

  @discardableResult func creditPurchase(
    transactionID: String, productID: String, reward: Int, userID: String?
  ) -> Bool {
    guard !transactionID.isEmpty, !processedTransactionIDs.contains(transactionID), reward > 0,
      let uid = userID ?? currentUserID, users.contains(where: { $0.id == uid && $0.isActive })
    else { return false }
    processedTransactionIDs.insert(transactionID)
    var wallet = walletsByUser[uid] ?? Wallet(coins: 0, diamonds: 0, freeQuestions: 3)
    wallet.coins += reward
    walletsByUser[uid] = wallet
    persistAndNotify()
    return true
  }
  func addCoins(_ amount: Int) {
    guard let uid = currentUserID else { return }
    var wallet = walletsByUser[uid] ?? Wallet(coins: 0, diamonds: 0, freeQuestions: 3)
    wallet.coins += amount
    walletsByUser[uid] = wallet
    persistAndNotify()
  }
  func consumeAIQuestion(text: String) -> Bool {
    guard let uid = currentUserID, var wallet = walletsByUser[uid] else { return false }
    if wallet.freeQuestions > 0 {
      wallet.freeQuestions -= 1
    } else {
      guard wallet.coins >= aiMessageCost else { return false }
      wallet.coins -= aiMessageCost
    }
    walletsByUser[uid] = wallet
    aiMessages.append(
      AIMessage(id: UUID().uuidString, userID: uid, isUser: true, text: text, createdAt: Date()))
    aiMessages.append(
      AIMessage(
        id: UUID().uuidString, userID: uid, isUser: false,
        text: aiReply(for: text),
        createdAt: Date()))
    persistAndNotify()
    return true
  }
  func sendMessage(
    conversationID: String, text: String, kind: MessageKind = .text, media: MediaAsset? = nil
  ) {
    guard let uid = currentUserID, kind != .text || !text.isEmpty else { return }
    messages.append(
      ChatMessage(
        id: UUID().uuidString, conversationID: conversationID, senderID: uid, kind: kind,
        body: text, createdAt: Date(), media: media))
    if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
      for id in conversations[index].participantIDs where id != uid {
        conversations[index].unreadByUser[id, default: 0] += 1
      }
    }
    persistAndNotify()
  }
  func markConversationRead(_ id: String) {
    guard let uid = currentUserID, let index = conversations.firstIndex(where: { $0.id == id })
    else { return }
    conversations[index].unreadByUser[uid] = 0
    persistAndNotify()
  }
  func conversation(with id: String) -> Conversation {
    if let value = conversations.first(where: {
      $0.participantIDs.contains(id) && $0.participantIDs.contains(currentUserID ?? "")
    }) {
      return value
    }
    let value = Conversation(id: UUID().uuidString, participantIDs: [currentUserID ?? "", id])
    conversations.append(value)
    persist()
    return value
  }
  func aiMessagesForCurrentUser() -> [AIMessage] {
    aiMessages.filter { $0.userID == currentUserID }
  }

  private func aiReply(for question: String) -> String {
    let normalized = question.lowercased()
    var bestRule: AIReplyRule?
    var bestScore = 0
    for rule in aiReplyRules {
      let score = rule.keywords.reduce(into: 0) { total, keyword in
        if normalized.contains(keyword) { total += keyword.contains(" ") ? 2 : 1 }
      }
      if score > bestScore {
        bestScore = score
        bestRule = rule
      }
    }
    return bestRule?.response ?? aiFallbackReply
  }

  private func validateMediaFiles() {
    if allMedia().contains(where: { !MediaStore.shared.exists($0) }) { state = .parsingError }
  }
  private func contentState() -> ViewState { posts.isEmpty && meets.isEmpty ? .empty : .content }
  private func notify() { NotificationCenter.default.post(name: .appDataChanged, object: nil) }
  private func persistAndNotify() {
    state = contentState()
    persist()
    notify()
  }
  private func persist() {
    let snapshot = AppSnapshot(
      users: users, posts: posts, meets: meets, conversations: conversations, messages: messages,
      reports: reports, aiMessages: aiMessages, walletsByUser: walletsByUser,
      followingByUser: followingByUser, blockedByUser: blockedByUser, currentUserID: currentUserID,
      processedTransactionIDs: processedTransactionIDs,
      presetFollowingInitialized: presetFollowingInitialized)
    if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: snapshotKey) }
  }
  private func apply(_ snapshot: AppSnapshot) {
    users = snapshot.users
    posts = snapshot.posts
    meets = snapshot.meets
    conversations = snapshot.conversations
    messages = snapshot.messages
    reports = snapshot.reports
    aiMessages = snapshot.aiMessages
    walletsByUser = snapshot.walletsByUser
    followingByUser = snapshot.followingByUser
    blockedByUser = snapshot.blockedByUser
    currentUserID = snapshot.currentUserID
    processedTransactionIDs = snapshot.processedTransactionIDs
    presetFollowingInitialized = snapshot.presetFollowingInitialized
  }
  private func allMedia() -> [MediaAsset] {
    users.compactMap(\.avatar) + posts.flatMap(\.media) + meets.compactMap(\.cover)
      + messages.compactMap(\.media)
  }
  private func ensurePresetCredential() {
    if !defaults.bool(forKey: "presetInvalidated")
      && !CredentialStore.shared.contains(userID: "preset")
    {
      _ = CredentialStore.shared.set(password: "12345678", for: "preset")
    }
  }
  private func seed() {
    defaults.removeObject(forKey: "presetInvalidated")
    func imageAsset(_ filename: String, id: String) -> MediaAsset {
      MediaAsset(id: id, kind: .image, relativePath: filename, createdAt: Date())
    }
    func videoAsset(_ filename: String, id: String) -> MediaAsset {
      MediaAsset(id: id, kind: .video, relativePath: filename, createdAt: Date())
    }

    // The preset login is a separate fresh account, not one of the CSV users.
    let preset = User(
      id: "preset", email: "123@gmail.com", name: "Maya Rivers",
      bio: "Chasing clear water and quiet trails.", location: "Oregon", gender: .madam,
      isActive: true, avatar: nil)
    let emma = User(
      id: "emma", email: "emma@example.com", name: "Emma Vance",
      bio: "Chasing clear water and quiet trails.", location: "Emerald Basin", gender: .madam,
      isActive: true,
      avatar: imageAsset("5299b264ee23ae35173c908850f78d09.jpg", id: "avatar-emma"))
    let lucas = User(
      id: "lucas", email: "lucas@example.com", name: "Lucas Miller",
      bio: "Weekend walks to hidden cascades.", location: "Cedar Falls", gender: .man,
      isActive: true,
      avatar: imageAsset("9da852647572c52d808708502bf2107a.jpg", id: "avatar-lucas"))
    let sofia = User(
      id: "sofia", email: "sofia@example.com", name: "Sofia Rossi",
      bio: "Always looking for a cool swimming hole.", location: "Summer Creek", gender: .madam,
      isActive: true,
      avatar: imageAsset("c117447f681240f8beb609b8ee67880b.jpg", id: "avatar-sofia"))
    let julian = User(
      id: "julian", email: "julian@example.com", name: "Julian Weber",
      bio: "Deep water and canyon days.", location: "Blue Canyon", gender: .man,
      isActive: true,
      avatar: imageAsset("5359174f691281e86593e61dbff70b97.jpg", id: "avatar-julian"))
    let clara = User(
      id: "clara", email: "clara@example.com", name: "Clara Dupont",
      bio: "Finding the best current and the safest line.", location: "Rapid Gorge", gender: .madam,
      isActive: true,
      avatar: imageAsset("19be25819ca5dabb67532a380bc6f040.jpg", id: "avatar-clara"))
    let oliver = User(
      id: "oliver", email: "oliver@example.com", name: "Oliver Smith",
      bio: "Canyoneering, rivers, and big challenges.", location: "Canyon Passage", gender: .man,
      isActive: true,
      avatar: imageAsset("b7973f00724256ece18689dff9771795.jpg", id: "avatar-oliver"))
    let liam = User(
      id: "liam", email: "liam@example.com", name: "Liam Clarke",
      bio: "Early starts and peaceful water.", location: "Mirror Lake", gender: .man,
      isActive: true,
      avatar: imageAsset("fe1c2fdf912c80caf73eafc47ac3fd8e.jpg", id: "avatar-liam"))
    let hannah = User(
      id: "hannah", email: "hannah@example.com", name: "Hannah Fischer",
      bio: "Turquoise lakes and long paddles.", location: "Alpine Lake", gender: .madam,
      isActive: true,
      avatar: imageAsset("53185ecba92e9ec45c6c78d2332c7c5d.jpg", id: "avatar-hannah"))
    let csvUsers = [emma, lucas, sofia, julian, clara, oliver, liam, hannah]
    users = [preset] + csvUsers

    let now = Date()
    posts = [
      Post(
        id: "drop-emma", authorID: emma.id, title: "Behind the cedar veil",
        body: "A quiet two-mile climb, cold mist, and the clearest pool at the base.",
        category: "Waterfall Hike", difficulty: "Moderate", location: "Cedar Falls",
        createdAt: now.addingTimeInterval(-7200), likedBy: [],
        comments: [Comment(
          id: "comment-emma-1", postID: "drop-emma", authorID: lucas.id,
          text: "Pure paradise here!", createdAt: now.addingTimeInterval(-3600))],
        media: [imageAsset("1ef88d48e231433469a0ccf933a8dd28.jpg", id: "media-drop-emma")]),
      Post(
        id: "drop-lucas", authorID: lucas.id, title: "Easy cascade trail for weekends",
        body: "A gentle 15-minute walk to the waterfall platform with scenic views along the stream.",
        category: "Waterfall Hike", difficulty: "Beginner Friendly", location: "Cascade Trail",
        createdAt: now.addingTimeInterval(-14400), likedBy: [], comments: [],
        media: [imageAsset("f83c02899f6977ebec3e8efcadc022f2.jpg", id: "media-drop-lucas")]),
      Post(
        id: "drop-sofia", authorID: sofia.id, title: "Finding the secret summer cooling spot",
        body: "A 30-minute walk along the stream leads to this natural pool with crystal-clear water.",
        category: "Swimming Hole", difficulty: "Beginner Friendly", location: "Summer Creek",
        createdAt: now.addingTimeInterval(-21600), likedBy: [],
        comments: [Comment(
          id: "comment-sofia-1", postID: "drop-sofia", authorID: emma.id,
          text: "Stunning hidden spot!", createdAt: now.addingTimeInterval(-10800))],
        media: [imageAsset("758a9898a4dc442f4045c5fa4e6d4ee1.jpg", id: "media-drop-sofia")]),
      Post(
        id: "drop-julian", authorID: julian.id, title: "Deep canyon cliff plunge pool",
        body: "Requires light climbing to reach; the water is very deep and great for experienced swimmers.",
        category: "Swimming Hole", difficulty: "Experienced Only", location: "Blue Canyon",
        createdAt: now.addingTimeInterval(-28800), likedBy: [],
        comments: [Comment(
          id: "comment-julian-1", postID: "drop-julian", authorID: clara.id,
          text: "Looks super deep!", createdAt: now.addingTimeInterval(-14400))],
        media: [videoAsset("256c7e5a18767c353f8663ac70c62977.mp4", id: "media-drop-julian")]),
      Post(
        id: "drop-clara", authorID: clara.id, title: "Thrilling moments tackling the rapids",
        body: "This white-water rafting trip was super exciting with full guidance from instructors.",
        category: "River Adventure", difficulty: "Experienced Only", location: "Rapid Gorge",
        createdAt: now.addingTimeInterval(-36000), likedBy: [], comments: [],
        media: [imageAsset("bb30e84c3ee29eea30dba41a2692042d.jpg", id: "media-drop-clara")]),
      Post(
        id: "drop-oliver", authorID: oliver.id, title: "Extreme canyon river passage",
        body: "Rushing currents involving cliff jumps and upstream canyoneering; experts only.",
        category: "River Adventure", difficulty: "Experienced Only", location: "Canyon Passage",
        createdAt: now.addingTimeInterval(-43200), likedBy: [],
        comments: [Comment(
          id: "comment-oliver-1", postID: "drop-oliver", authorID: hannah.id,
          text: "Truly next level!", createdAt: now.addingTimeInterval(-21600))],
        media: [videoAsset("a8ac1e73d25ced7a5e91466037537788_720w.mp4", id: "media-drop-oliver")]),
      Post(
        id: "drop-liam", authorID: liam.id, title: "Peaceful morning lake kayaking",
        body: "At 5 AM the lake surface is like a mirror, enjoying peaceful alone time kayaking.",
        category: "River Adventure", difficulty: "Beginner Friendly", location: "Mirror Lake",
        createdAt: now.addingTimeInterval(-50400), likedBy: [], comments: [],
        media: [imageAsset("c8978e0ca9e87f9cadf09b139938b3c7.jpg", id: "media-drop-liam")]),
      Post(
        id: "drop-hannah", authorID: hannah.id, title: "Alpine lake paddle expedition",
        body: "Paddling around an alpine glacial lake with stunning turquoise water.",
        category: "River Adventure", difficulty: "Moderate", location: "Alpine Lake",
        createdAt: now.addingTimeInterval(-57600), likedBy: [], comments: [],
        media: [imageAsset("d7d4227c0b7126151c3c86e9ba1404b4.jpg", id: "media-drop-hannah")]),
    ]
    meets = [
      Meet(
        id: "meet-emerald-basin", hostID: emma.id, title: "Morning Dip at Emerald Basin",
        date: now.addingTimeInterval(259200), capacity: 8,
        participantIDs: [emma.id, sofia.id, julian.id],
        meetingPoint: "Emerald Basin North Trail Parking", category: "Swimming Hole",
        cost: hostMeetCost,
        cover: imageAsset("2ba5337204ad54106c0fa1112a2c8a01.jpg", id: "cover-emerald-basin")),
      Meet(
        id: "meet-blue-lake", hostID: liam.id, title: "Sunset Kayak & Swim Party",
        date: now.addingTimeInterval(345600), capacity: 6,
        participantIDs: [liam.id, hannah.id, clara.id, oliver.id],
        meetingPoint: "Blue Lake West Public Launch Ramp", category: "River Adventure",
        cost: hostMeetCost,
        cover: imageAsset("c3a6383cdfa9d18e5deb0f00868998a2.jpg", id: "cover-blue-lake")),
    ]
    conversations = []
    messages = []
    aiMessages = []
    reports = []
    walletsByUser = Dictionary(uniqueKeysWithValues: users.map {
      ($0.id, Wallet(coins: 0, diamonds: 0, freeQuestions: 3))
    })
    followingByUser = Dictionary(uniqueKeysWithValues: users.map { ($0.id, Set<String>()) })
    // Two CSV users initially follow the fresh preset account. The preset account
    // itself starts with no Following entries.
    let initialFollowers = csvUsers.shuffled().prefix(2)
    initialFollowers.forEach { followingByUser[$0.id] = [preset.id] }
    blockedByUser = Dictionary(uniqueKeysWithValues: users.map { ($0.id, Set<String>()) })
    currentUserID = nil
    processedTransactionIDs = []
    presetFollowingInitialized = false
    ensurePresetCredential()
  }
}
