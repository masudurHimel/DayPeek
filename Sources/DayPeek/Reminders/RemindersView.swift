import AppKit
import SwiftUI

/// Root of the panel's SwiftUI hierarchy: a card in the system window colour
/// (so it follows light / dark mode exactly, and reads darker in dark mode
/// than a translucent material would) with the reminders list on top, popping
/// down from the menu bar on open and retracting up on close.
struct PanelRootView: View {
    @ObservedObject var store: ReminderStore
    @ObservedObject var state: PanelState

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RemindersView(store: store, state: state)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        // Flatten the card into one layer so the transform below moves a
        // single composited surface instead of re-rendering every row.
        .compositingGroup()
        .scaleEffect(state.isPresented ? 1 : 0.86, anchor: .top)
        .offset(y: state.isPresented ? 0 : -14)
        .opacity(state.isPresented ? 1 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: state.isPresented)
        .ignoresSafeArea()
    }
}

/// Header, the Overdue / Today sections, and a collapsed Completed section.
struct RemindersView: View {
    @ObservedObject var store: ReminderStore
    @ObservedObject var state: PanelState
    @State private var showCompleted = false
    @AppStorage(SettingsKey.showRowActions) private var showRowActions = true
    private let topAnchor = "top"

    private var dateLine: String {
        Date().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.6)
            content
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            // Inner stack centres the round button on the title while the
            // outer stack keeps the date column on the title's baseline.
            HStack(alignment: .center, spacing: 8) {
                Text("Today")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                if store.access == .granted {
                    RowActionsToggle(isOn: $showRowActions)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(dateLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                if store.access == .granted {
                    Text(store.buckets.remaining == 0 ? "All done" : "\(store.buckets.remaining) remaining")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch store.access {
        case .unknown:
            Spacer(); ProgressView().controlSize(.small); Spacer()
        case .denied:
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "lock.slash").font(.system(size: 26)).foregroundStyle(.secondary)
                Text("Reminders access is off").font(.headline)
                Text("System Settings › Privacy & Security › Reminders › DayPeek")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        case .granted:
            let b = store.buckets
            ScrollViewReader { proxy in
                ScrollView {
                    // A plain VStack, not a LazyVStack: lazy stacks reuse row views by
                    // id across the flattened list, so a reminder moving between the
                    // Completed and Today sections kept its stale (ticked) look.
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id(topAnchor)
                        if b.overdue.isEmpty && b.today.isEmpty {
                            VStack(spacing: 6) {
                                Text("🎉").font(.system(size: 34))
                                Text("Nothing due today").font(.headline)
                                Text("No open reminders due today or overdue.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }
                        if !b.overdue.isEmpty {
                            SectionHeader(title: "Overdue", count: b.overdue.count, color: .red)
                            ForEach(b.overdue) { item in
                                ReminderRow(item: item, color: store.color(for: item), overdue: true,
                                            state: state, actions: actions(for: item)) {
                                    store.toggle(item)
                                }
                                .id("overdue-" + item.id)
                            }
                        }
                        if !b.today.isEmpty {
                            SectionHeader(title: "Today", count: b.today.count, color: .secondary)
                            ForEach(b.today) { item in
                                ReminderRow(item: item, color: store.color(for: item), overdue: false,
                                            state: state, actions: actions(for: item)) {
                                    store.toggle(item)
                                }
                                .id("today-" + item.id)
                            }
                        }
                        if !b.completed.isEmpty {
                            CompletedHeader(count: b.completed.count, expanded: $showCompleted)
                            if showCompleted {
                                ForEach(b.completed) { item in
                                    // Completed rows get no hover actions for now.
                                    ReminderRow(item: item, color: store.color(for: item), overdue: false,
                                                state: state, actions: nil) {
                                        store.toggle(item)
                                    }
                                    .id("done-" + item.id)
                                }
                            }
                        }
                        if let err = store.lastError {
                            Text(err).font(.caption).foregroundStyle(.red)
                                .padding(.horizontal, 18).padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 10)
                    .animation(.easeInOut(duration: 0.2), value: showCompleted)
                }
                // Reset while hidden so the next open starts at the top, with
                // no visible jump.
                .onChange(of: state.scrollResetToken) { _, _ in
                    proxy.scrollTo(topAnchor, anchor: .top)
                }
            }
        }
    }
}

extension RemindersView {
    /// Hover actions for an open reminder; each writes straight to the store.
    /// Nil when the user has turned them off in Preferences.
    fileprivate func actions(for item: ReminderItem) -> RowActions? {
        guard showRowActions else { return nil }
        return RowActions(
            rename: { store.rename(item, to: $0) },
            reschedule: { store.reschedule(item, to: $0, allDay: $1) },
            delete: { store.delete(item) }
        )
    }
}

struct SectionHeader: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
            if count > 0 {
                Text("\(count)").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 3)
    }
}

/// Collapsed by default; click to expand today's completed reminders.
struct CompletedHeader: View {
    let count: Int
    @Binding var expanded: Bool
    @State private var hovering = false

    var body: some View {
        Button { expanded.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .foregroundStyle(.secondary)
                Text("Completed").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Text("\(count)").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                Spacer()
                if !expanded {
                    Text("show").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 5)
            .contentShape(Rectangle())
            .background(hovering ? Color.primary.opacity(0.04) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// What the three hover buttons do. Nil hides them (completed rows).
struct RowActions {
    let rename: (String) -> Void
    let reschedule: (Date, Bool) -> Void
    let delete: () -> Void
}

/// One reminder: round checkbox in the list colour, title, due line. Only the
/// checkbox toggles completion; the rest of the row is inert. Open rows grow
/// three round buttons on hover — edit title, change date & time, delete —
/// laid over the trailing edge.
struct ReminderRow: View {
    let item: ReminderItem
    let color: Color
    let overdue: Bool
    @ObservedObject var state: PanelState
    let actions: RowActions?
    let action: () -> Void

    @State private var hovering = false
    @State private var draft = ""
    @State private var showDatePopover = false
    @State private var showDeletePopover = false
    @FocusState private var titleFocused: Bool

    /// Width the title yields to the buttons while they are shown.
    private let actionsWidth: CGFloat = 3 * 22 + 2 * 6 + 8

    private var isEditing: Bool { state.editingID == item.id }

    private var showActions: Bool {
        actions != nil && !isEditing && (hovering || showDatePopover || showDeletePopover)
    }

    private var dueText: String {
        guard let due = item.due else { return "No date" }
        let sameDay = Calendar.current.isDateInToday(due)
        if overdue || !sameDay {
            let day = due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            return item.allDay ? day : day + ", " + due.formatted(date: .omitted, time: .shortened)
        }
        return item.allDay ? "All-day" : due.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        VStack(spacing: 0) {
            rowContent
            .overlay(alignment: .trailing) {
                if let actions, showActions {
                    actionButtons(actions)
                        .padding(.trailing, 18)
                        .transition(.opacity.combined(with: .offset(x: 4)))
                }
            }
            .animation(.easeOut(duration: 0.12), value: showActions)
            .onHover { hovering = $0 }

            Divider().opacity(0.5).padding(.leading, 49)
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 11) {
            Button(action: action) {
                ZStack {
                    Circle().strokeBorder(color, lineWidth: 1.5)
                    if item.completed {
                        Circle().fill(color).padding(4)
                    }
                }
                .frame(width: 20, height: 20)
                // A little slack around the ring so it is easy to hit.
                .padding(3)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(-3)
            .padding(.top, 1)
            .help(item.completed ? "Mark as not completed" : "Mark as completed")
            .accessibilityLabel(item.completed ? "Mark as not completed" : "Mark as completed")

            VStack(alignment: .leading, spacing: 1) {
                if isEditing {
                    titleField
                } else {
                    Text(item.title)
                        .font(.system(size: 13))
                        .strikethrough(item.completed, color: .secondary)
                        .foregroundStyle(item.completed ? .secondary : .primary)
                        .lineLimit(2)
                }
                HStack(spacing: 5) {
                    Text(dueText)
                        .foregroundStyle(overdue && !item.completed ? .red : .secondary)
                    if !item.listName.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(item.listName).foregroundStyle(.tertiary)
                    }
                    if isEditing {
                        Spacer(minLength: 4)
                        Text("↩ save · esc cancel")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.system(size: 11))
            }
            .padding(.trailing, showActions ? actionsWidth : 0)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 18)
        .background(hovering || isEditing ? Color.primary.opacity(0.05) : .clear)
        .contentShape(Rectangle())
    }

    // MARK: - Inline title edit

    private var titleField: some View {
        TextField("Title", text: $draft)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 13))
            .focused($titleFocused)
            .onSubmit(commitTitle)
            // Click-away saves. Cancel (Esc) clears `editingID` first, which
            // removes the field and drops focus with `isEditing` already false.
            .onChange(of: titleFocused) { _, focused in
                if !focused && isEditing { commitTitle() }
            }
    }

    private func beginEditing() {
        draft = item.title
        state.editingID = item.id
        DispatchQueue.main.async { titleFocused = true }
    }

    private func commitTitle() {
        guard isEditing else { return }
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        state.editingID = nil
        if !title.isEmpty && title != item.title {
            actions?.rename(title)
        }
    }

    // MARK: - Hover buttons

    private func actionButtons(_ actions: RowActions) -> some View {
        HStack(spacing: 6) {
            RowActionButton(symbol: "pencil", label: "Edit title", action: beginEditing)

            RowActionButton(symbol: "clock", label: "Change date and time", active: showDatePopover) {
                showDatePopover = true
            }
            .popover(isPresented: $showDatePopover, arrowEdge: .bottom) {
                DueDateEditor(due: item.due, allDay: item.allDay) { date, allDay in
                    showDatePopover = false
                    actions.reschedule(date, allDay)
                } onCancel: {
                    showDatePopover = false
                }
            }

            RowActionButton(symbol: "trash", label: "Delete reminder", destructive: true,
                            active: showDeletePopover) {
                // ⌥-click skips the confirmation.
                if NSEvent.modifierFlags.contains(.option) {
                    actions.delete()
                } else {
                    showDeletePopover = true
                }
            }
            .popover(isPresented: $showDeletePopover, arrowEdge: .bottom) {
                DeleteConfirmation(title: item.title) {
                    showDeletePopover = false
                    actions.delete()
                } onCancel: {
                    showDeletePopover = false
                }
            }
        }
    }
}

/// Header button that flips the "Show row actions on hover" preference from
/// the panel itself. Same storage as the Preferences toggle, so the two never
/// disagree. Stays blue while on, grey with a slashed pencil while off.
struct RowActionsToggle: View {
    @Binding var isOn: Bool

    static func symbol(isOn: Bool) -> String { isOn ? "pencil" : "pencil.slash" }
    static func label(isOn: Bool) -> String { isOn ? "Hide row actions" : "Show row actions" }

    var body: some View {
        RowActionButton(symbol: Self.symbol(isOn: isOn), label: Self.label(isOn: isOn), active: isOn) {
            isOn.toggle()
        }
    }
}

/// A 22 pt round icon button. Tints blue (or red when destructive) while the
/// pointer is over it or its popover is open.
struct RowActionButton: View {
    let symbol: String
    let label: String
    var destructive = false
    var active = false
    let action: () -> Void
    @State private var hovering = false

    private var lit: Bool { hovering || active }
    private var tint: Color { destructive ? .red : .blue }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(lit ? tint : Color.secondary)
                .frame(width: 22, height: 22)
                .background(lit ? tint.opacity(0.15) : Color.primary.opacity(0.08), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Popover for the clock button: month grid, quick-pick chips, time, all-day.
struct DueDateEditor: View {
    @State private var date: Date
    @State private var allDay: Bool
    let onSave: (Date, Bool) -> Void
    let onCancel: () -> Void

    init(due: Date?, allDay: Bool, onSave: @escaping (Date, Bool) -> Void, onCancel: @escaping () -> Void) {
        let cal = Calendar.current
        var start = due ?? Date()
        // All-day reminders sit at midnight; offer 9:00 as the time to switch
        // to instead of 12:00 AM.
        if due == nil || allDay {
            start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: start) ?? start
        }
        _date = State(initialValue: start)
        _allDay = State(initialValue: allDay)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MonthGrid(selection: $date)

            HStack(spacing: 6) {
                quickPick("Today", days: 0)
                quickPick("Tomorrow", days: 1)
                quickPick("Next week", days: 7)
            }

            Divider()

            HStack {
                Text("Time").font(.system(size: 12))
                Spacer()
                DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .disabled(allDay)
            }
            Toggle("All-day", isOn: $allDay)
                .font(.system(size: 12))
                .toggleStyle(.switch)
                .controlSize(.small)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Save") { onSave(date, allDay) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 260)
    }

    /// Moves the day to today + `days`, keeping the chosen time of day.
    private func quickPick(_ label: String, days: Int) -> some View {
        Button(label) {
            let cal = Calendar.current
            let day = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: Date()))!
            let time = cal.dateComponents([.hour, .minute], from: date)
            date = cal.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: day) ?? day
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }
}

/// A Reminders / Calendar-style month grid: month title with ‹ › chevrons,
/// weekday initials, round accent highlight on the selected day, today in the
/// accent colour. Changing the day keeps the selection's time of day.
struct MonthGrid: View {
    @Binding var selection: Date
    @State private var visibleMonth: Date
    @State private var hoveredDay: Date?
    private let cal = Calendar.current

    init(selection: Binding<Date>) {
        _selection = selection
        _visibleMonth = State(initialValue: Calendar.current.startOfMonth(for: selection.wrappedValue))
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// Always six rows so the popover never changes height between months.
    private var days: [Date] {
        let first = cal.startOfMonth(for: visibleMonth)
        let offset = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -offset, to: first)!
        return (0..<42).map { cal.date(byAdding: .day, value: $0, to: start)! }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                monthButton("chevron.left", by: -1)
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { visibleMonth = cal.startOfMonth(for: Date()) }
                } label: {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Show this month")
                .accessibilityLabel("Show this month")
                monthButton("chevron.right", by: 1)
            }
            .padding(.horizontal, 2)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(weekdaySymbols.indices, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(height: 16)
                }
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
    }

    private func monthButton(_ symbol: String, by months: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                visibleMonth = cal.date(byAdding: .month, value: months, to: visibleMonth)!
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(months < 0 ? "Previous month" : "Next month")
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = cal.isDate(day, equalTo: visibleMonth, toGranularity: .month)
        let isSelected = cal.isDate(day, inSameDayAs: selection)
        let isToday = cal.isDateInToday(day)
        let isHovered = hoveredDay.map { cal.isDate($0, inSameDayAs: day) } ?? false

        return Button {
            let time = cal.dateComponents([.hour, .minute], from: selection)
            selection = cal.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day) ?? day
            if !inMonth {
                withAnimation(.easeOut(duration: 0.15)) { visibleMonth = cal.startOfMonth(for: day) }
            }
        } label: {
            Text("\(cal.component(.day, from: day))")
                .font(.system(size: 12, weight: isSelected || isToday ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(
                    isSelected ? Color.white
                    : isToday ? Color.accentColor
                    : inMonth ? Color.primary : Color.secondary.opacity(0.5))
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(
                        isSelected ? Color.accentColor
                        : isHovered ? Color.primary.opacity(0.08)
                        : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredDay = $0 ? day : nil }
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date))!
    }
}

/// Popover for the trash button.
struct DeleteConfirmation: View {
    let title: String
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Delete “\(title)”?")
                .font(.system(size: 12, weight: .semibold))
            Text("It is removed from Reminders on every device. This can’t be undone.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Delete", role: .destructive, action: onDelete)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
            .controlSize(.small)
            .padding(.top, 6)
        }
        .padding(12)
        .frame(width: 230)
    }
}
