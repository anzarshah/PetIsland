import XCTest
@testable import IslandPet

final class ReminderPlannerTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 2024-01-15 at the given UTC hour.
    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: hour, minute: minute))!
    }

    /// A day-old pet whose needs are current as of `now`.
    private func pet(fullness: Double, now: Date) -> PetState {
        var pet = PetState(adoptedAt: now.addingTimeInterval(-86_400), species: .cat, coat: .honey, name: "Mochi",
                           needs: Needs(fullness: fullness, energy: 100, cleanliness: 100, mood: 100))
        pet.lastReconciledAt = now
        return pet
    }

    private var settings: ReminderSettings {
        ReminderSettings(enabled: true, frequency: .regular, quietStartHour: 22, quietEndHour: 8)
    }

    func testDisabledRemindersPlanNothing() {
        let now = date(hour: 10)
        XCTAssertNil(ReminderPlanner.plan(for: pet(fullness: 50, now: now), settings: ReminderSettings(), now: now, calendar: calendar))
    }

    func testReminderIsScheduledForWhenTheNeedTurnsLow() throws {
        let now = date(hour: 10)
        // fullness 51 → low (35) in 4 hours at 4/h.
        let plan = try XCTUnwrap(ReminderPlanner.plan(for: pet(fullness: 51, now: now), settings: settings, now: now, calendar: calendar))
        XCTAssertEqual(plan.fireDate, date(hour: 14))
        XCTAssertEqual(plan.need, .fullness)
        XCTAssertTrue(plan.title.contains("Mochi"))
    }

    func testAlreadyLowNeedRemindsSoonButNotImmediately() throws {
        let now = date(hour: 10)
        let plan = try XCTUnwrap(ReminderPlanner.plan(for: pet(fullness: 20, now: now), settings: settings, now: now, calendar: calendar))
        XCTAssertEqual(plan.fireDate, now.addingTimeInterval(ReminderPlanner.alreadyLowLead))
    }

    func testQuietHoursPushTheReminderToTheMorning() throws {
        let now = date(hour: 20)
        // low in 3 hours → 23:00, inside 22:00–08:00 quiet hours → 08:00 next day.
        let plan = try XCTUnwrap(ReminderPlanner.plan(for: pet(fullness: 47, now: now), settings: settings, now: now, calendar: calendar))
        XCTAssertEqual(plan.fireDate, calendar.date(byAdding: .day, value: 1, to: date(hour: 8)))
    }

    func testQuietHoursThatWrapMidnightCoverEarlyMorning() {
        XCTAssertTrue(ReminderPlanner.isQuiet(date(hour: 3), settings: settings, calendar: calendar))
        XCTAssertTrue(ReminderPlanner.isQuiet(date(hour: 23), settings: settings, calendar: calendar))
        XCTAssertFalse(ReminderPlanner.isQuiet(date(hour: 8), settings: settings, calendar: calendar))
        XCTAssertFalse(ReminderPlanner.isQuiet(date(hour: 12), settings: settings, calendar: calendar))
    }

    func testQuietHoursFollowTheCalendarTimeZone() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 20:00 UTC is 05:00 in Tokyo: quiet there, not in UTC.
        let utcEvening = date(hour: 20)
        XCTAssertTrue(ReminderPlanner.isQuiet(utcEvening, settings: settings, calendar: tokyo))
        XCTAssertFalse(ReminderPlanner.isQuiet(utcEvening, settings: settings, calendar: calendar))
        let moved = ReminderPlanner.movedOutsideQuietHours(utcEvening, settings: settings, calendar: tokyo)
        XCTAssertEqual(tokyo.component(.hour, from: moved), 8)
    }

    func testFrequencySpacesRemindersApart() throws {
        let now = date(hour: 10)
        var spaced = settings
        spaced.frequency = .gentle
        spaced.lastFireDate = date(hour: 9)
        let plan = try XCTUnwrap(ReminderPlanner.plan(for: pet(fullness: 51, now: now), settings: spaced, now: now, calendar: calendar))
        // Would fire at 14:00, but gentle spacing requires 20 h after 09:00 → 05:00 next day → quiet → 08:00.
        XCTAssertEqual(plan.fireDate, calendar.date(byAdding: .day, value: 1, to: date(hour: 8)))
    }

    func testFeedingBeforeAReminderMovesItLater() throws {
        let now = date(hour: 10)
        let hungry = pet(fullness: 40, now: now)
        let before = try XCTUnwrap(ReminderPlanner.plan(for: hungry, settings: settings, now: now, calendar: calendar))
        let (fed, _) = PetReducer.apply(.feed, to: hungry, now: now)
        let after = try XCTUnwrap(ReminderPlanner.plan(for: fed, settings: settings, now: now, calendar: calendar))
        XCTAssertGreaterThan(after.fireDate, before.fireDate)
    }

    func testReminderNeverFiresSoonerThanTheMinimumLead() throws {
        let now = date(hour: 10)
        let plan = try XCTUnwrap(ReminderPlanner.plan(for: pet(fullness: 35.1, now: now), settings: settings, now: now, calendar: calendar))
        XCTAssertGreaterThanOrEqual(plan.fireDate.timeIntervalSince(now), ReminderPlanner.minimumLead)
    }
}
