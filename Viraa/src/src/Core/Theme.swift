import UIKit

enum AppTheme {
    static let blue = UIColor(red: 64/255, green: 125/255, blue: 255/255, alpha: 1)
    static let ink = UIColor(red: 22/255, green: 25/255, blue: 27/255, alpha: 1)
    static let secondary = UIColor(red: 103/255, green: 107/255, blue: 112/255, alpha: 1)
    static let muted = UIColor(red: 156/255, green: 158/255, blue: 163/255, alpha: 1)
    static let surface = UIColor(white: 244/255, alpha: 1)
    static let yellow = UIColor(red: 246/255, green: 183/255, blue: 25/255, alpha: 1)
    static let danger = UIColor(red: 229/255, green: 73/255, blue: 79/255, alpha: 1)
}

extension Notification.Name { static let appDataChanged = Notification.Name("appDataChanged") }

