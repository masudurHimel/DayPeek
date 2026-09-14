import Foundation

/// A reminder as the UI sees it — decoupled from EventKit so the bucketing
/// logic is pure and unit-testable.
struct ReminderItem: Identifiable, Equatable {
    let id: String
    let title: String
    let listName: String
    /// Resolved due date (nil for reminders without one).
    let due: Date?
    /// True when the due date has no time component.
    let allDay: Bool
    let completed: Bool
    let completedAt: Date?
}

/// The three sections of the panel, each already sorted for display.
struct DayBuckets: Equatable {
    /// Open, due before the start of today — oldest first.
    var overdue: [ReminderItem] = []
    /// Open, due today — by time.
    var today: [ReminderItem] = []
    /// Completed today (any due date) — most recently completed first.
    var completed: [ReminderItem] = []

    var remaining: Int { overdue.count + today.count }
    var isEmpty: Bool { overdue.isEmpty && today.isEmpty && completed.isEmpty }

    /// Buckets `items` relative to `now`. Items that are open but have no due
    /// date, or are due after today, are dropped — they don't belong on a
    /// "today" list.
    static func make(_ items: [ReminderItem], now: Date, calendar: Calendar = .current) -> DayBuckets {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        var buckets = DayBuckets()
        for item in items {
            if item.completed {
                buckets.completed.append(item)
            } else if let due = item.due, due < startOfToday {
                buckets.overdue.append(item)
            } else if let due = item.due, due < startOfTomorrow {
                buckets.today.append(item)
            }
        }
        buckets.overdue.sort { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) }
        buckets.today.sort { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) }
        buckets.completed.sort { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        return buckets
    }
}
