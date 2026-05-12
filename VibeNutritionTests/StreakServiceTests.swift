import XCTest
@testable import VibeNutrition

final class StreakServiceTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func now() -> Date {
        // Fixed reference so tests aren't time-of-day dependent.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 12; comps.hour = 14
        return cal.date(from: comps)!
    }

    private func daysAgo(_ n: Int, hour: Int = 13) -> Date {
        let base = cal.startOfDay(for: now())
        let d = cal.date(byAdding: .day, value: -n, to: base)!
        return cal.date(byAdding: .hour, value: hour, to: d)!
    }

    func testNoLogsIsZero() {
        XCTAssertEqual(StreakService.computeStreak(loggedAt: [], now: now(), calendar: cal), 0)
    }

    func testTodayOnlyIsOne() {
        XCTAssertEqual(
            StreakService.computeStreak(loggedAt: [daysAgo(0)], now: now(), calendar: cal),
            1
        )
    }

    func testThreeConsecutiveDays() {
        let logs = [daysAgo(0), daysAgo(1), daysAgo(2)]
        XCTAssertEqual(StreakService.computeStreak(loggedAt: logs, now: now(), calendar: cal), 3)
    }

    func testGapBreaksStreak() {
        // Today, then missed yesterday, then 2 days ago — streak is 1 (only today counts).
        let logs = [daysAgo(0), daysAgo(2), daysAgo(3)]
        XCTAssertEqual(StreakService.computeStreak(loggedAt: logs, now: now(), calendar: cal), 1)
    }

    func testStreakRequiresToday() {
        // Yesterday + day before, but nothing today — streak is 0.
        let logs = [daysAgo(1), daysAgo(2)]
        XCTAssertEqual(StreakService.computeStreak(loggedAt: logs, now: now(), calendar: cal), 0)
    }

    func testMultipleLogsSameDayCountOnce() {
        let logs = [daysAgo(0, hour: 8), daysAgo(0, hour: 13), daysAgo(0, hour: 20), daysAgo(1)]
        XCTAssertEqual(StreakService.computeStreak(loggedAt: logs, now: now(), calendar: cal), 2)
    }
}
