import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject private var controller: FoldLockController
    @ObservedObject private var authorization = AuthorizationCenter.shared
    @State private var hinge: DeviceHinge?
    @State private var authError: String?
    @State private var showPicker = false

    /// Pass `-UnfoldDebug YES` as a launch argument (enabled in the shared scheme) to show developer tools.
    private let showsDebug = UserDefaults.standard.bool(forKey: "UnfoldDebug")

    var body: some View {
        NavigationStack {
            List {
                Section { statusHeader }

                if !isAuthorized {
                    Section {
                        Button("Allow Screen Time Access") { Task { await requestAuthorization() } }
                    } footer: {
                        Text(authError ?? "Unfold uses Screen Time to lock the apps you choose.")
                    }
                }

                Section {
                    Button { showPicker = true } label: {
                        LabeledContent("Apps to lock", value: controller.selectedCount == 0 ? "None" : "\(controller.selectedCount) selected")
                    }
                } footer: {
                    Text("These stay locked while your phone is folded.")
                }

                scheduleSection

                Section {
                    Text("""
                    In Shortcuts, tap Automation → + → Display → Opened or Closed, and set each to Run Immediately:
                    • Closed → Lock Apps
                    • Opened → Unlock Apps
                    """)
                    .font(.footnote)
                } header: {
                    Text("Lock automatically when folded")
                }

                if showsDebug { debugSection }
            }
            .navigationTitle("Unfold")
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $controller.selection)
        .onHingeChange { _, new in
            hinge = new.hinge
            followHinge()
        }
    }

    /// Re-evaluated every minute so the header follows the schedule while the app stays open.
    private var statusHeader: some View {
        TimelineView(.everyMinute) { context in
            let isLocking = controller.settings.isLocking(at: context.date)
            VStack(spacing: 8) {
                Image(systemName: isLocking ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text(isLocking ? "Apps locked" : "Apps unlocked")
                    .font(.title2.bold())
                Text(statusDetail(at: context.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    private func statusDetail(at date: Date) -> String {
        if !controller.schedule.allows(date) { return "Outside your schedule, so folding won’t lock them." }
        guard controller.settings.isEngaged else { return "Fold your phone to lock them." }
        if controller.selectedCount == 0 { return "No apps chosen yet." }
        if !isAuthorized { return "Screen Time access is off, so nothing is blocked." }
        return "Unfold your phone to use them."
    }

    private var scheduleSection: some View {
        Section {
            Toggle("Only on a schedule", isOn: $controller.schedule.isEnabled)
            if controller.schedule.isEnabled {
                DatePicker("From", selection: time(\.start), displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: time(\.end), displayedComponents: .hourAndMinute)
                weekdayPicker
            }
        } footer: {
            Text(scheduleFooter)
        }
    }

    private var scheduleFooter: String {
        // Before authorization every window is rejected; the Screen Time section already says why.
        if isAuthorized, let error = controller.scheduleError { return error }
        guard controller.schedule.isEnabled else { return "Folding locks apps at any time." }
        if controller.schedule.weekdays.isEmpty { return "Pick at least one day, or folding won’t lock anything." }
        if controller.schedule.isOvernight { return "Runs overnight, from the evening of each chosen day." }
        return "Folding locks apps only during these hours."
    }

    private var weekdayPicker: some View {
        let calendar = Calendar.current
        // Calendar weekday numbers (1 is Sunday), ordered from the locale's first weekday.
        let days = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        return HStack {
            ForEach(days, id: \.self) { day in
                let isOn = controller.schedule.weekdays.contains(day)
                Button(calendar.veryShortWeekdaySymbols[day - 1]) {
                    if isOn {
                        controller.schedule.weekdays.remove(day)
                    } else {
                        controller.schedule.weekdays.insert(day)
                    }
                }
                .font(.subheadline.bold())
                .frame(width: 36, height: 36)
                .background(isOn ? Color.accentColor : Color(.tertiarySystemFill), in: Circle())
                .foregroundStyle(isOn ? .white : .primary)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(calendar.weekdaySymbols[day - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .buttonStyle(.plain)
    }

    /// Bridges a minutes-after-midnight field to the Date a DatePicker edits.
    private func time(_ field: WritableKeyPath<LockSchedule, Int>) -> Binding<Date> {
        let calendar = Calendar.current
        return Binding {
            let minutes = controller.schedule[keyPath: field]
            return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now)!
        } set: { date in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            controller.schedule[keyPath: field] = parts.hour! * 60 + parts.minute!
        }
    }

    private var debugSection: some View {
        Section("Debug") {
            LabeledContent("Hinge", value: hingeLabel)
            LabeledContent("Screen Time", value: authLabel)
            LabeledContent("Last event", value: controller.lastEvent ?? "—")
            Button("Lock Now") { controller.engage(source: "Debug") }
            Button("Unlock Now") { controller.release(source: "Debug") }
        }
    }

    private func followHinge() {
        guard let status = hinge?.status else { return }
        // Only definite states move the lock; anything unknown leaves it untouched.
        if status == .closed {
            controller.engage(source: "Hinge (in app)")
        } else if status == .partiallyOpen || status == .fullyOpen {
            controller.release(source: "Hinge (in app)")
        }
    }

    private var isAuthorized: Bool {
        [.approved, .approvedWithDataAccess].contains(authorization.authorizationStatus)
    }

    private var hingeLabel: String {
        guard let status = hinge?.status else { return "No hinge" }
        if status == .closed { return "Closed" }
        if status == .partiallyOpen { return "Partially open" }
        if status == .fullyOpen { return "Fully open" }
        return "Unknown"
    }

    private var authLabel: String {
        switch authorization.authorizationStatus {
        case .approved, .approvedWithDataAccess: "Approved"
        case .denied: "Denied"
        case .notDetermined: "Not requested"
        @unknown default: "Unknown"
        }
    }

    private func requestAuthorization() async {
        authError = nil
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            controller.sync()
        } catch {
            authError = error.localizedDescription
        }
    }
}
