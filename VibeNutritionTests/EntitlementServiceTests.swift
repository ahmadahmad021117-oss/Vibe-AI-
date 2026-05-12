import XCTest
@testable import VibeNutrition

final class EntitlementServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_780_000_000) // fixed reference

    func testFreeTierIsNotPremium() {
        XCTAssertFalse(EntitlementService.isPremium(tier: .free, expiresAt: nil, now: now))
        XCTAssertFalse(
            EntitlementService.isPremium(
                tier: .free,
                expiresAt: now.addingTimeInterval(86_400),
                now: now
            )
        )
    }

    func testPremiumWithFutureExpiryIsPremium() {
        XCTAssertTrue(
            EntitlementService.isPremium(
                tier: .premium,
                expiresAt: now.addingTimeInterval(3600),
                now: now
            )
        )
    }

    func testPremiumWithPastExpiryIsNotPremium() {
        XCTAssertFalse(
            EntitlementService.isPremium(
                tier: .premium,
                expiresAt: now.addingTimeInterval(-1),
                now: now
            )
        )
    }

    func testPremiumWithoutExpiryIsLifetime() {
        XCTAssertTrue(
            EntitlementService.isPremium(tier: .premium, expiresAt: nil, now: now)
        )
    }

    func testFreeDailyScanLimitIsThree() {
        XCTAssertEqual(EntitlementService.freeDailyScanLimit, 3)
    }
}
