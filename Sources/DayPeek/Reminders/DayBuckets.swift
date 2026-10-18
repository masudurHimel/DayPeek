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
    /// Open, due before the start of today — oldest first. Only filled while
    /// the panel shows today.
    var overdue: [ReminderItem] = []
    /// Open, due on the day being shown — by time.
    var today: [ReminderItem] = []
    /// Completed today (any due date) — most recently completed first. Only
    /// filled while the panel shows today.
    var completed: [ReminderItem] = []

    var remaining: Int { overdue.count + today.count }
    var isEmpty: Bool { overdue.isEmpty && today.isEmpty && completed.isEmpty }

    /// Buckets `items` for the day containing `day`, relative to `now`.
    /// Items that are open but have no due date, or are due on another day,
    /// are dropped. On a future day there is nothing overdue yet, and
    /// completed reminders stay on today's list.
    static func make(_ items: [ReminderItem], day: Date? = nil, now: Date,
                     calendar: Calendar = .current) -> DayBuckets {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDay = max(calendar.startOfDay(for: day ?? now), startOfToday)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let showsToday = startOfDay == startOfToday

        var buckets = DayBuckets()
        for item in items {
            if item.completed {
                if showsToday { buckets.completed.append(item) }
            } else if let due = item.due, due < startOfToday {
                if showsToday { buckets.overdue.append(item) }
            } else if let due = item.due, due >= startOfDay, due < startOfNextDay {
                buckets.today.append(item)
            }
        }
        buckets.overdue.sort { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) }
        buckets.today.sort { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) }
        buckets.completed.sort { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        return buckets
    }
}

/// Header wording for the day the panel shows.
enum DayLabel {
    /// Whole days from today to `day`; 0 for today, never negative.
    static func offset(of day: Date, now: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: day)
        return max(calendar.dateComponents([.day], from: from, to: to).day ?? 0, 0)
    }

    /// "Today", "Tomorrow", the weekday for the rest of the week, then a
    /// short date ("Mon 26 Oct").
    static func title(for day: Date, now: Date, calendar: Calendar = .current) -> String {
        switch offset(of: day, now: now, calendar: calendar) {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...6: return day.formatted(Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(.wide))
        default:
            return day.formatted(Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone)
                .weekday(.abbreviated).day().month(.abbreviated))
        }
    }
}
