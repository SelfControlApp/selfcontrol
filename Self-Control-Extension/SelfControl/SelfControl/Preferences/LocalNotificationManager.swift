//
//  LocalNotificationManager.swift
//  SelfControl
//
//  Created by Satendra Singh on 03/04/26.
//
import UserNotifications

final class LocalNotificationManager {
    class func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
        }
    }
       
    class func scheduleNotification(title: String = "Your SelfControl block has ended!", body: String = "All sites are now accessible.", timeInterval: TimeInterval = 0.1) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .none

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}
