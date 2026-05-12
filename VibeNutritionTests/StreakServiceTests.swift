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

    // MARK: - DST and timezone hardening

    /// In Los Angeles on 2026-03-08, clocks jump from 2am PST to 3am PDT (23-hour day).
    /// A streak crossing the spring-forward boundary must still count consecutive days.
    func testStreakSurvivesDSTSpringForward() {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        // "Now" = noon on 2026-03-09 (the day after spring forward).
        var n = DateComponents(); n.year = 2026; n.month = 3; n.day = 9; n.hour = 12
        let now = la.date(from: n)!

        // Logs at noon on each of the three days that straddle spring forward.
        let day = { (m: Int, d: Int) -> Date in
            var c = DateComponents(); c.year = 2026; c.month = m; c.day = d; c.hour = 12
            return la.date(from: c)!
        }
        let logs = [day(3, 7), day(3, 8), day(3, 9)]
        XCTAssertEqual(StreakService.computeStreak(loggedAt: logs, now: now, calendar: la), 3)
    }

    /// In Los Angeles on 2026-11-01, clocks fall back from 2am PDT to 1am PST (25-hour day).
    /// The streak must still count consecutive wall-clock days, not 24-hour blocks.
    func testStreakSurvivesDSTFallBack() {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        var n = DateComponents(); n.year = 2026; n.month = 11; n.day = 2; n.hour = 12
        let now = la.date(from: n)!

        let day = { (m: Int, d: Int) -> Date in
            var c = DateComponents(); c.year = 2026; c.month = m; c.day = d; c.hour = 12
            return la.date(from: c)!
        }
        let logs = [day(10, 31), day(11, 1), day(11, 2)]
        XCTAssertEqual(StreakService.computeStreak(loggedAt: logs, now: now, calendar: la), 3)
    }

    /// User logs a meal at 11pm in LA on day N, then flies to Tokyo (+17h). The same
    /// absolute timestamp falls on day N+1 in Tokyo. Tokyo "today" is therefore the
    /// same calendar day as the LA log, so a 1-day streak is preserved.
    func testStreakMapsTimestampThroughCurrentTimezone() {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        // LA wall-clock: 2026-05-10 23:00
        var laTs = DateComponents(); laTs.year = 2026; laTs.month = 5; laTs.day = 10; laTs.hour = 23
        let log = la.date(from: laTs)!

        // In Tokyo that absolute moment is 2026-05-11 15:00.
        var tokyoNow = DateComponents(); tokyoNow.year = 2026; tokyoNow.month = 5; tokyoNow.day = 11; tokyoNow.hour = 18
        let now = tokyo.date(from: tokyoNow)!

        XCTAssertEqual(StreakService.computeStreak(loggedAt: [log], now: now, calendar: tokyo), 1)
    }

    /// Defensive: a giant input shouldn't push the streak past maxStreakDays.
    func testStreakCappedAtMaxStreakDays() {
        // 500 consecutive days of logs.
        let logs = (0..<500).map { daysAgo($0) }
        let s = StreakService.computeStreak(loggedAt: logs, now: now(), calendar: cal)
        XCTAssertEqual(s, StreakService.maxStreakDays)
    }
}
