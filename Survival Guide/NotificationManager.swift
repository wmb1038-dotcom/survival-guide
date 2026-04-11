import Foundation
import UserNotifications
import SwiftUI
import Combine

// MARK: - Notification Manager

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var authStatus: UNAuthorizationStatus = .notDetermined

    func refreshStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = s.authorizationStatus
    }

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            authStatus = granted ? .authorized : .denied
        } catch {
            authStatus = .denied
        }
    }

    // MARK: - Food Expiration

    func scheduleFoodAlerts(itemID: String, name: String, expirationDate: Date) {
        let ids30 = "food_\(itemID)_30"
        let ids7  = "food_\(itemID)_7"
        let ids1  = "food_\(itemID)_1"
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [ids30, ids7, ids1])

        schedule(id: ids30, title: "Food Expiring Soon",
                 body: "\(name) expires in 30 days — rotate or use",
                 fireDate: Calendar.current.date(byAdding: .day, value: -30, to: expirationDate))
        schedule(id: ids7,  title: "Food Expiring This Week",
                 body: "\(name) expires in 7 days",
                 fireDate: Calendar.current.date(byAdding: .day, value: -7, to: expirationDate))
        schedule(id: ids1,  title: "Food Expires Tomorrow",
                 body: "\(name) expires tomorrow — use or donate now",
                 fireDate: Calendar.current.date(byAdding: .day, value: -1, to: expirationDate))
    }

    func cancelFoodAlerts(itemID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["food_\(itemID)_30", "food_\(itemID)_7", "food_\(itemID)_1"]
        )
    }

    // MARK: - Water Rotation

    /// Call once after filling water storage. Fires a reminder after `months` months.
    func scheduleWaterRotation(intervalMonths: Int = 6) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["water_rotation"])
        guard let fire = Calendar.current.date(
            byAdding: .month, value: intervalMonths, to: Date()) else { return }
        schedule(id: "water_rotation",
                 title: "Rotate Water Storage",
                 body: "It's been \(intervalMonths) months — empty, clean, and refill water containers",
                 fireDate: fire)
    }

    // MARK: - Generator Test

    func scheduleGeneratorTest(intervalMonths: Int = 1) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["gen_test"])
        guard let fire = Calendar.current.date(
            byAdding: .month, value: intervalMonths, to: Date()) else { return }
        schedule(id: "gen_test",
                 title: "Generator Test Due",
                 body: "Run your generator 30 min under load and check oil/fuel levels",
                 fireDate: fire)
    }

    // MARK: - Medication Refill

    func scheduleMedRefill(medicationID: String, name: String, refillDate: Date) {
        let id = "med_\(medicationID)"
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
        let warning = Calendar.current.date(byAdding: .day, value: -7, to: refillDate) ?? refillDate
        schedule(id: id,
                 title: "Medication Refill Reminder",
                 body: "\(name) — refill due in 7 days",
                 fireDate: warning)
    }

    // MARK: - Pending List

    func pendingNotifications() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Private

    private func schedule(id: String, title: String, body: String, fireDate: Date?) {
        guard let fireDate, fireDate > Date() else { return }
        let content      = UNMutableNotificationContent()
        content.title    = title
        content.body     = body
        content.sound    = .default
        let comps   = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }
}
