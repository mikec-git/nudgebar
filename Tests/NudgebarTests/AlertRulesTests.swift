import XCTest
@testable import Nudgebar

final class AlertRuleResolverTests: XCTestCase {
    func testNoRuleUsesGlobals() {
        let settings = AlertRuleResolver.resolve(rule: nil, globalLeadMinutes: 5, globalSound: "Glass")
        XCTAssertEqual(settings, EffectiveAlertSettings(leadMinutes: 5, soundName: "Glass"))
    }

    func testLeadOverrideWins() {
        let rule = CalendarAlertRule(leadMinutesOverride: 15, soundOverride: nil)
        let settings = AlertRuleResolver.resolve(rule: rule, globalLeadMinutes: 5, globalSound: "Glass")
        XCTAssertEqual(settings.leadMinutes, 15)
        XCTAssertEqual(settings.soundName, "Glass")
    }

    func testSoundOverrideWins() {
        let rule = CalendarAlertRule(leadMinutesOverride: nil, soundOverride: "Ping")
        let settings = AlertRuleResolver.resolve(rule: rule, globalLeadMinutes: 5, globalSound: "Glass")
        XCTAssertEqual(settings.leadMinutes, 5)
        XCTAssertEqual(settings.soundName, "Ping")
    }
}

final class AlertDeliveryDeciderTests: XCTestCase {
    func testFullScreenWhenEnabledAndNoFocus() {
        XCTAssertEqual(
            AlertDeliveryDecider.decide(fullScreenEnabled: true, respectFocus: false, focusActive: false, notificationFallback: true),
            .fullScreen
        )
    }

    func testNotificationWhenFullScreenOff() {
        XCTAssertEqual(
            AlertDeliveryDecider.decide(fullScreenEnabled: false, respectFocus: false, focusActive: false, notificationFallback: true),
            .notification
        )
    }

    func testSuppressedWhenFullScreenOffAndNoFallback() {
        XCTAssertEqual(
            AlertDeliveryDecider.decide(fullScreenEnabled: false, respectFocus: false, focusActive: false, notificationFallback: false),
            .suppressed
        )
    }

    func testFocusActiveFallsBackToNotification() {
        XCTAssertEqual(
            AlertDeliveryDecider.decide(fullScreenEnabled: true, respectFocus: true, focusActive: true, notificationFallback: true),
            .notification
        )
    }

    func testFocusActiveSuppressesWhenFallbackOff() {
        XCTAssertEqual(
            AlertDeliveryDecider.decide(fullScreenEnabled: true, respectFocus: true, focusActive: true, notificationFallback: false),
            .suppressed
        )
    }

    func testFocusRespectedButInactiveStaysFullScreen() {
        XCTAssertEqual(
            AlertDeliveryDecider.decide(fullScreenEnabled: true, respectFocus: true, focusActive: false, notificationFallback: true),
            .fullScreen
        )
    }
}
