import Foundation
import UserNotifications

public class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()
    
    private override init() {
        super.init()
        setup()
    }
    
    public func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    public func showFocusCompletedNotification(sessionName: String, breakMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Focus Complete! 🎉"
        content.body = "Great job finishing '\(sessionName)'. Time for a \(breakMinutes)-minute break."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    public func showBreakCompletedNotification(nextSessionName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Break is Over ☕️"
        content.body = "Ready to start '\(nextSessionName)'? Let's get into flow."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    public func showBlockedNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .none
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
