import Foundation
import Testing

@testable import DayPeek

private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

/// 2026-09-14 10:00 UTC
private let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 10))!

private func at(_ day: Int, _ hour: Int = 0, month: Int = 9) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}

private func item(_ id: String, due: Date?, completed: Bool = false, completedAt: Date? = nil) -> ReminderItem {
    ReminderItem(id: id, title: id, listName: "L", due: due, allDay: false,
                 completed: completed, completedAt: completedAt)
}

@Test func overdueIsBeforeStartOfTodayOldestFirst() {
    let b = DayBuckets.make([
        item("yesterday", due: at(13, 9)),
        item("lastWeek", due: at(7, 18)),
        item("today", due: at(14, 15)),
    ], now: now, calendar: calendar)
    #expect(b.overdue.map(\.id) == ["lastWeek", "yesterday"])
    #expect(b.today.map(\.id) == ["today"])
}

@Test func todayIsSortedByTimeAndIncludesMidnightAllDay() {
    let b = DayBuckets.make([
        item("evening", due: at(14, 21)),
        item("allDay", due: at(14, 0)),
        item("morning", due: at(14, 8)),
    ], now: now, calendar: calendar)
    #expect(b.today.map(\.id) == ["allDay", "morning", "evening"])
    #expect(b.overdue.isEmpty)
}

@Test func futureAndUndatedOpenItemsAreDropped() {
    let b = DayBuckets.make([
        item("tomorrow", due: at(15, 0)),
        item("undated", due: nil),
        item("today", due: at(14, 12)),
    ], now: now, calendar: calendar)
    #expect(b.today.map(\.id) == ["today"])
    #expect(b.overdue.isEmpty)
    #expect(b.remaining == 1)
}

@Test func completedGoesToCompletedRegardlessOfDueMostRecentFirst() {
    let b = DayBuckets.make([
        item("doneEarly", due: at(15, 0), completed: true, completedAt: at(14, 8)),
        item("doneLate", due: nil, completed: true, completedAt: at(14, 9, month: 9)),
        item("open", due: at(14, 12)),
    ], now: now, calendar: calendar)
    #expect(b.completed.map(\.id) == ["doneLate", "doneEarly"])
    #expect(b.remaining == 1)
    #expect(!b.isEmpty)
}
