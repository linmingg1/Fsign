//
//  ExpiryNotificationManager.swift
//  Fsign
//
//  证书到期前本地通知 —— 纯端内,无需服务器/推送后台。
//  证书导入时(CertificateFileHandler.addToDatabase)按到期日排程,
//  到期前 3 天 / 1 天 / 当天各弹一条,提醒客户 App 即将掉签。
//

import Foundation
import UserNotifications
import OSLog

enum ExpiryNotificationManager {
	/// 到期前多少天各提醒一次
	private static let leadDays: [Int] = [3, 1]

	/// 为一张证书排程到期提醒。identifier 带证书 uuid,便于换证/续期时取消旧排程。
	static func schedule(certUUID: String, nickname: String?, expiration: Date) {
		let center = UNUserNotificationCenter.current()
		center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
			if let error {
				Logger.misc.error("[ExpiryNotification] auth error: \(error.localizedDescription)")
			}
			guard granted else { return }

			// 先清掉这张证书的旧排程,避免续期后重复提醒
			cancel(certUUID: certUUID)

			let name = (nickname?.isEmpty == false) ? nickname! : "签名证书"
			let now = Date()

			for days in leadDays {
				guard
					let fireDate = Calendar.current.date(byAdding: .day, value: -days, to: expiration),
					fireDate > now
				else { continue }

				let content = UNMutableNotificationContent()
				content.title = "证书即将到期"
				content.body = "「\(name)」将在 \(days) 天后到期,到期后已签名的 App 会掉签无法打开,请及时续签。"
				content.sound = .default

				let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
				let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
				center.add(UNNotificationRequest(identifier: _id(certUUID, days), content: content, trigger: trigger))
			}

			// 到期当天再补一条
			if expiration > now {
				let content = UNMutableNotificationContent()
				content.title = "证书已到期"
				content.body = "「\(name)」已到期,已签名的 App 可能已掉签,请重新签名。"
				content.sound = .default

				let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: expiration)
				let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
				center.add(UNNotificationRequest(identifier: _id(certUUID, 0), content: content, trigger: trigger))
			}

			Logger.misc.info("[ExpiryNotification] scheduled for \(certUUID), expires \(expiration)")
		}
	}

	/// 取消某证书的全部到期排程(删证/换证时调用)
	static func cancel(certUUID: String) {
		let ids = ([0] + leadDays).map { _id(certUUID, $0) }
		UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
	}

	private static func _id(_ uuid: String, _ days: Int) -> String {
		"fsign.expiry.\(uuid).\(days)"
	}
}
