/*
 AlertServiceTests.swift
 ModelTests

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

import AllocatedUnfairLock
import DataSource
import Foundation
import Testing
@testable import DataSource
@testable import Model
import UserNotifications

@Suite
struct AlertServiceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Pure decision logic

    @Test
    func shouldAlert_is_false_below_threshold() {
        #expect(!AlertService.shouldAlert(now: now, lastAlertAt: nil, cpuPercentage: 0.5))
    }

    @Test
    func shouldAlert_is_true_at_threshold() {
        #expect(AlertService.shouldAlert(now: now, lastAlertAt: nil, cpuPercentage: 0.9))
    }

    @Test
    func shouldAlert_is_true_above_threshold_without_previous_alert() {
        #expect(AlertService.shouldAlert(now: now, lastAlertAt: nil, cpuPercentage: 0.95))
    }

    @Test
    func shouldAlert_is_false_within_cooldown() {
        let last = now.addingTimeInterval(-5 * 60)
        #expect(!AlertService.shouldAlert(now: now, lastAlertAt: last, cpuPercentage: 0.95))
    }

    @Test
    func shouldAlert_is_true_after_cooldown() {
        let last = now.addingTimeInterval(-16 * 60)
        #expect(AlertService.shouldAlert(now: now, lastAlertAt: last, cpuPercentage: 0.95))
    }

    @Test
    func shouldAlert_is_false_when_cpuInfo_is_nil() {
        #expect(!AlertService.shouldAlert(now: now, lastAlertAt: nil, cpuPercentage: nil))
    }

    // MARK: - Integration

    @MainActor @Test
    func checkAndNotify_posts_once_and_persists_timestamp() async {
        let adds = AllocatedUnfairLock(initialState: 0)
        let lastAlertStored = AllocatedUnfairLock(initialState: 0.0)
        let sut = AlertService(.testDependencies(
            dateClient: testDependency(of: DateClient.self) { $0.now = { self.now } },
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.bool = { $0 == "SHOWS_LOAD_ALERT" }
                $0.double = { _ in 0 }  // no previous alert
                $0.set = { value, key in
                    if key == "LAST_LOAD_ALERT_DATE", let value = value as? Double {
                        lastAlertStored.withLock { $0 = value }
                    }
                }
            },
            userNotificationClient: testDependency(of: UserNotificationClient.self) {
                $0.add = { _ in adds.withLock { $0 += 1 } }
            }
        ))

        sut.checkAndNotify(cpuPercentage: 0.95)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(adds.withLock(\.self) == 1)
        #expect(lastAlertStored.withLock(\.self) == now.timeIntervalSince1970)
    }

    @MainActor @Test
    func checkAndNotify_respects_cooldown() async {
        let adds = AllocatedUnfairLock(initialState: 0)
        let lastAlert = now.addingTimeInterval(-5 * 60)
        let sut = AlertService(.testDependencies(
            dateClient: testDependency(of: DateClient.self) { $0.now = { self.now } },
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.bool = { $0 == "SHOWS_LOAD_ALERT" }
                $0.double = { _ in lastAlert.timeIntervalSince1970 }
            },
            userNotificationClient: testDependency(of: UserNotificationClient.self) {
                $0.add = { _ in adds.withLock { $0 += 1 } }
            }
        ))

        sut.checkAndNotify(cpuPercentage: 0.95)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(adds.withLock(\.self) == 0)
    }

    @MainActor @Test
    func checkAndNotify_does_nothing_when_toggle_is_off() async {
        let adds = AllocatedUnfairLock(initialState: 0)
        let sut = AlertService(.testDependencies(
            dateClient: testDependency(of: DateClient.self) { $0.now = { self.now } },
            userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                $0.bool = { _ in false }  // SHOWS_LOAD_ALERT off
            },
            userNotificationClient: testDependency(of: UserNotificationClient.self) {
                $0.add = { _ in adds.withLock { $0 += 1 } }
            }
        ))

        sut.checkAndNotify(cpuPercentage: 0.95)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(adds.withLock(\.self) == 0)
    }
}
