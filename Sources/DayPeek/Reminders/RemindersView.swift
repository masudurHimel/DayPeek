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
            Text("Today")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
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
                                ReminderRow(item: item, color: store.color(for: item), overdue: true) {
                                    store.toggle(item)
                                }
                                .id("overdue-" + item.id)
                            }
                        }
                        if !b.today.isEmpty {
                            SectionHeader(title: "Today", count: b.today.count, color: .secondary)
                            ForEach(b.today) { item in
                                ReminderRow(item: item, color: store.color(for: item), overdue: false) {
                                    store.toggle(item)
                                }
                                .id("today-" + item.id)
                            }
                        }
                        if !b.completed.isEmpty {
                            CompletedHeader(count: b.completed.count, expanded: $showCompleted)
                            if showCompleted {
                                ForEach(b.completed) { item in
                                    ReminderRow(item: item, color: store.color(for: item), overdue: false) {
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

/// One reminder: round checkbox in the list colour, title, due line.
struct ReminderRow: View {
    let item: ReminderItem
    let color: Color
    let overdue: Bool
    let action: () -> Void
    @State private var hovering = false

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
            Button(action: action) {
                HStack(alignment: .top, spacing: 11) {
                    ZStack {
                        Circle().strokeBorder(color, lineWidth: 1.5)
                        if item.completed {
                            Circle().fill(color).padding(4)
                        }
                    }
                    .frame(width: 20, height: 20)
                    .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 13))
                            .strikethrough(item.completed, color: .secondary)
                            .foregroundStyle(item.completed ? .secondary : .primary)
                            .lineLimit(2)
                        HStack(spacing: 5) {
                            Text(dueText)
                                .foregroundStyle(overdue && !item.completed ? .red : .secondary)
                            if !item.listName.isEmpty {
                                Text("·").foregroundStyle(.tertiary)
                                Text(item.listName).foregroundStyle(.tertiary)
                            }
                        }
                        .font(.system(size: 11))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 18)
                .background(hovering ? Color.primary.opacity(0.05) : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }

            Divider().opacity(0.5).padding(.leading, 49)
        }
    }
}
