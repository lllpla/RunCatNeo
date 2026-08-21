/*
 AlertService.swift
 Model

 Created by Takuto Nakamura on 2026/08/21.
 Copyright 2026 Kyome22 (Takuto Nakamura)

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import DataSource
import Foundation
import UserNotifications

struct AlertService {
    private let userNotificationClient: UserNotificationClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let dateClient: DateClient

    // Fixed alert threshold (option ② per PM/team): notify when CPU ≥ 90%.
    // The B4' configurable-threshold UI was cancelled by user decision, so the
    // threshold stays a constant — promoting it to a setting later is trivial.
    static let alertThreshold = 0.9
    // Cooldown between alerts: sustained load must not spam the notification center.
    static let alertCooldown: TimeInterval = 15 * 60

    init(_ appDependencies: AppDependencies) {
        userNotificationClient = appDependencies.userNotificationClient
        userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        dateClient = appDependencies.dateClient
    }

    /// Pure decision logic (unit-tested without side effects).
    static func shouldAlert(now: Date, lastAlertAt: Date?, cpuPercentage: Double?) -> Bool {
        guard let cpuPercentage, cpuPercentage >= alertThreshold else { return false }
        guard let lastAlertAt else { return true }
        return now.timeIntervalSince(lastAlertAt) >= alertCooldown
    }

    func checkAndNotify(cpuPercentage: Double?) {
        guard userDefaultsRepository.showsLoadAlert, let cpuPercentage else { return }
        let now = dateClient.now()
        guard Self.shouldAlert(now: now, lastAlertAt: userDefaultsRepository.lastLoadAlertDate, cpuPercentage: cpuPercentage) else {
            return
        }
        userDefaultsRepository.lastLoadAlertDate = now
        // Notification copy is intentionally hardcoded Chinese: Model must not
        // reference the UI string catalog, and there is no model-layer
        // localization precedent in this codebase.
        let content = UNMutableNotificationContent()
        content.title = "CPU 负载过高"
        content.body = String(format: "当前 CPU 使用率 %.0f%%，请留意后台进程。", cpuPercentage * 100)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        Task { await userNotificationClient.add(request) }
    }
}
