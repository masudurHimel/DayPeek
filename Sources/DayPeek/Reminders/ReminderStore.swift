import AppKit
import EventKit
import SwiftUI

/// The only place that talks to EventKit. Fetches the reminders for the day the
/// panel shows — for today, open reminders due up to the end of today plus
/// everything completed today; for a future day, open reminders due that
/// day — publishes them as
/// `ReminderItem`s, and writes the user's edits back: completion toggles,
/// title changes, due-date changes, and deletions.
@MainActor
final class ReminderStore: ObservableObject {
    enum Access { case unknown, denied, granted }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var items: [ReminderItem] = []
    @Published private(set) var buckets = DayBuckets()
    @Published var lastError: String?
    /// Start of the day on screen. Changes together with `buckets`, once that
    /// day's reminders have loaded.
    @Published private(set) var day = Calendar.current.startOfDay(for: Date())
    /// True when the last day change moved forward; picks the slide direction.
    private(set) var movedForward = true

    private let store = EKEventStore()
    /// Backing EKReminder per item id, needed to save toggles.
    private var reminders: [String: EKReminder] = [:]
    private var colors: [String: NSColor] = [:]
    /// Start of the day the user asked for; `day` catches up after the fetch.
    /// Kept as a date, not an offset, so viewing tomorrow across midnight
    /// lands on today rather than sliding a day further out.
    private var targetDay = Calendar.current.startOfDay(for: Date())

    init() {
        // Reflect changes made in Reminders.app (or by our own saves) while
        // the panel is open.
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { await self?.reload() }
        }
    }

    /// The list colour for a reminder, used for its checkbox ring.
    func color(for item: ReminderItem) -> Color {
        if let c = colors[item.id] { return Color(nsColor: c) }
        return .accentColor
    }

    var dayOffset: Int { DayLabel.offset(of: day, now: Date()) }

    /// Shows the day `offset` days after today (never before today).
    func showDay(offset: Int) {
        let cal = Calendar.current
        let newDay = cal.date(byAdding: .day, value: max(offset, 0), to: cal.startOfDay(for: Date()))!
        guard newDay != targetDay else { return }
        targetDay = newDay
        Task { await reload() }
    }

    /// Steps the shown day forward or back from the last requested one.
    func step(by delta: Int) {
        showDay(offset: DayLabel.offset(of: targetDay, now: Date()) + delta)
    }

    func reload() async {
        guard await ensureAccess() else { return }

        let cal = Calendar.current
        let now = Date()
        let target = targetDay
        let startToday = cal.startOfDay(for: now)
        let startDay = max(target, startToday)
        let offset = DayLabel.offset(of: startDay, now: now, calendar: cal)
        let startNextDay = cal.date(byAdding: .day, value: 1, to: startDay)!

        // Today's open fetch starts at nil so it also picks up overdue items.
        let openPredicate = store.predicateForIncompleteReminders(
            withDueDateStarting: offset == 0 ? nil : startDay, ending: startNextDay, calendars: nil)
        let open = await fetch(openPredicate)
        var done: [EKReminder] = []
        if offset == 0 {
            let donePredicate = store.predicateForCompletedReminders(
                withCompletionDateStarting: startToday, ending: startNextDay, calendars: nil)
            done = await fetch(donePredicate)
        }
        // A newer request (a quick second click) owns the screen now.
        guard target == targetDay else { return }

        var byID: [String: EKReminder] = [:]
        var newColors: [String: NSColor] = [:]
        var newItems: [ReminderItem] = []
        for r in open + done {
            let id = r.calendarItemIdentifier
            guard byID[id] == nil else { continue }
            byID[id] = r
            if let c = r.calendar?.color { newColors[id] = c }
            let comps = r.dueDateComponents
            newItems.append(ReminderItem(
                id: id,
                title: r.title ?? "",
                listName: r.calendar?.title ?? "",
                due: comps.flatMap { cal.date(from: $0) },
                allDay: comps?.hour == nil,
                completed: r.isCompleted,
                completedAt: r.completionDate
            ))
        }
        reminders = byID
        colors = newColors
        items = newItems
        let newBuckets = DayBuckets.make(newItems, day: startDay, now: now, calendar: cal)
        if startDay == day {
            buckets = newBuckets
        } else {
            movedForward = startDay > day
            withAnimation(.easeOut(duration: 0.22)) {
                day = startDay
                buckets = newBuckets
            }
        }
    }

    /// Flips completion and saves immediately. The list updates optimistically;
    /// the EKEventStoreChanged notification then reloads the truth.
    func toggle(_ item: ReminderItem) {
        guard let r = reminders[item.id] else { return }
        r.isCompleted.toggle()
        guard save(r, undo: { r.isCompleted.toggle() }) else { return }
        replace(item.id) { old in
            ReminderItem(
                id: old.id, title: old.title, listName: old.listName, due: old.due,
                allDay: old.allDay, completed: r.isCompleted, completedAt: r.completionDate)
        }
    }

    /// Renames a reminder. Blank titles are ignored; the caller trims.
    func rename(_ item: ReminderItem, to title: String) {
        guard let r = reminders[item.id], !title.isEmpty, title != item.title else { return }
        let previous = r.title
        r.title = title
        guard save(r, undo: { r.title = previous }) else { return }
        replace(item.id) { old in
            ReminderItem(
                id: old.id, title: title, listName: old.listName, due: old.due,
                allDay: old.allDay, completed: old.completed, completedAt: old.completedAt)
        }
    }

    /// Moves a reminder's due date. `allDay` drops the time component. A
    /// reminder that already has alarms gets a single alarm at the new time
    /// so its notification moves with it; all-day reminders keep their alarms
    /// as they were.
    func reschedule(_ item: ReminderItem, to due: Date, allDay: Bool) {
        guard let r = reminders[item.id] else { return }
        let cal = Calendar.current
        let units: Set<Calendar.Component> = allDay
            ? [.year, .month, .day]
            : [.year, .month, .day, .hour, .minute]
        var comps = cal.dateComponents(units, from: due)
        comps.calendar = cal
        let previousDue = r.dueDateComponents
        let previousAlarms = r.alarms
        r.dueDateComponents = comps
        if !allDay, r.hasAlarms {
            r.alarms = [EKAlarm(absoluteDate: cal.date(from: comps) ?? due)]
        }
        let undo = {
            r.dueDateComponents = previousDue
            r.alarms = previousAlarms
        }
        guard save(r, undo: undo) else { return }
        let resolved = cal.date(from: comps)
        replace(item.id) { old in
            ReminderItem(
                id: old.id, title: old.title, listName: old.listName, due: resolved,
                allDay: allDay, completed: old.completed, completedAt: old.completedAt)
        }
    }

    /// Removes the reminder from Reminders entirely.
    func delete(_ item: ReminderItem) {
        guard let r = reminders[item.id] else { return }
        do {
            try store.remove(r, commit: true)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            return
        }
        reminders[item.id] = nil
        colors[item.id] = nil
        replace(item.id) { _ in nil }
    }

    /// Commits `r`, reporting failure in `lastError` and rolling the in-memory
    /// object back via `undo` so the UI never shows an unsaved change.
    private func save(_ r: EKReminder, undo: () -> Void) -> Bool {
        do {
            try store.save(r, commit: true)
            lastError = nil
            return true
        } catch {
            undo()
            lastError = error.localizedDescription
            return false
        }
    }

    /// Optimistic list update: swaps (or, for nil, removes) the item with `id`
    /// and re-buckets with the same animation the sections use.
    private func replace(_ id: String, with transform: (ReminderItem) -> ReminderItem?) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        if let updated = transform(items[i]) {
            items[i] = updated
        } else {
            items.remove(at: i)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            buckets = DayBuckets.make(items, day: day, now: Date())
        }
    }

    private func ensureAccess() async -> Bool {
        if access == .granted { return true }
        do {
            let granted = try await store.requestFullAccessToReminders()
            access = granted ? .granted : .denied
        } catch {
            access = .denied
        }
        return access == .granted
    }

    private func fetch(_ predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { cont.resume(returning: $0 ?? []) }
        }
    }
}
