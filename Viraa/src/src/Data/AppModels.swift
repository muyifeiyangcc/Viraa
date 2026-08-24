import Foundation

enum Gender: String, Codable { case man = "Man", madam = "Madam" }
enum MessageKind: String, Codable { case text, image, voice }
enum ViewState: Equatable { case loading, content, empty, parsingError }

enum MediaKind: String, Codable { case image, video, audio }
struct MediaAsset: Codable, Equatable, Identifiable {
    var id: String; var kind: MediaKind; var relativePath: String; var createdAt: Date
    var duration: TimeInterval? = nil
}
struct User: Codable, Equatable, Identifiable {
    var id: String; var email: String; var name: String
    var bio: String; var location: String; var gender: Gender; var isActive: Bool
    var birthDate: Date? = nil; var avatar: MediaAsset? = nil; var profileComplete: Bool = true
}
struct Comment: Codable, Identifiable { var id: String; var postID: String; var authorID: String; var text: String; var createdAt: Date }
struct Post: Codable, Identifiable {
    var id: String; var authorID: String; var title: String; var body: String; var category: String
    var difficulty: String; var location: String; var createdAt: Date; var likedBy: Set<String>; var comments: [Comment]
    var media: [MediaAsset] = []; var savedBy: Set<String>  = []
}
struct Meet: Codable, Identifiable {
    var id: String; var hostID: String; var title: String; var date: Date; var capacity: Int
    var participantIDs: Set<String>; var meetingPoint: String; var category: String; var cost: Int
    var cover: MediaAsset? = nil
}
struct ChatMessage: Codable, Identifiable { var id: String; var conversationID: String; var senderID: String; var kind: MessageKind; var body: String; var createdAt: Date; var media: MediaAsset? = nil }
struct Conversation: Codable, Identifiable { var id: String; var participantIDs: [String]; var unreadByUser: [String:Int] = [:] }
struct ReportRecord: Codable, Identifiable { var id: String; var reporterID: String; var targetID: String; var reason: String; var createdAt: Date }
struct Wallet: Codable { var coins: Int; var diamonds: Int; var freeQuestions: Int }
struct AIMessage: Codable, Identifiable { var id: String; var userID: String; var isUser: Bool; var text: String; var createdAt: Date }
struct PurchaseDisplayProduct: Identifiable { var id: String; var usdPrice: String; var reward: Int }
struct PurchaseConfiguration {
  let productID: String
  let reward: Int
  /// USD display price used by the UI. It is intentionally independent of the device locale.
  let usdPrice: String
}

struct AppSnapshot: Codable {
    var users: [User]; var posts: [Post]; var meets: [Meet]; var conversations: [Conversation]
    var messages: [ChatMessage]; var reports: [ReportRecord]; var aiMessages: [AIMessage]
    var walletsByUser: [String:Wallet]; var followingByUser: [String:Set<String>]; var blockedByUser: [String:Set<String>]
    var currentUserID: String?; var processedTransactionIDs: Set<String>; var presetFollowingInitialized: Bool
}
