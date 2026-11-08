import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject private var controller: FoldLockController
    @ObservedObject private var authorization = AuthorizationCenter.shared
    @State private var hinge: DeviceHinge?
    @State private var authError: String?
    @State private var showPicker = false
    @State private var isFlapping = false

    /// Developer tools show in every Debug build (what Xcode and `devicectl` install), however
    /// the app is opened, and never in Release.
    #if DEBUG
    private let showsDebug = true
    #else
    private let showsDebug = false
    #endif

    var body: some View {
        NavigationStack {
            // Re-evaluated every minute so the status and the settings lock follow the schedule
            // while Unfold stays open.
            TimelineView(.everyMinute) { context in
                let isLocked = controller.settings.isLocking(at: context.date)
                List {
                    statusHeader(at: context.date, isLocked: isLocked)

                    if !isAuthorized {
                        Section {
                            Button("Allow Screen Time Access") { Task { await requestAuthorization() } }
                        } footer: {
                            Text(authError ?? "Unfold uses Screen Time to lock the apps you choose.")
                        }
                    }

                    // Settings only change while apps are unlocked, so they can't be used to escape.
                    Group {
                        Section {
                            Button { showPicker = true } label: {
                                LabeledContent("Apps to Lock", value: controller.selectedCount == 0 ? "None" : "\(controller.selectedCount) selected")
                            }
                        } footer: {
                            Text(isLocked ? "Settings can only be changed while your apps are unlocked." : "These stay locked while your phone is folded.")
                        }
                        scheduleSection
                        flapRuleSection
                    }
                    .disabled(isLocked)

                    Section {
                        NavigationLink {
                            AutomationGuideView()
                        } label: {
                            Label("Lock When Folded", systemImage: "wand.and.sparkles")
                        }
                    } footer: {
                        Text("Set up two Shortcuts automations so folding locks apps even when Unfold isn’t open.")
                    }

                    if showsDebug { debugSection }
                }
            }
            .navigationTitle("Unfold")
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $controller.selection)
        .fullScreenCover(isPresented: $isFlapping) {
            FlapUnlockView().environmentObject(controller)
        }
        .onChange(of: controller.flapUnlockRequested, initial: true) { _, requested in
            guard requested else { return }
            controller.flapUnlockRequested = false
            if controller.settings.canFlapUnlock(at: .now) { isFlapping = true }
        }
        .onHingeChange(isEnabled: !isFlapping) { _, new in
            hinge = new.hinge
            controller.follow(hinge)
        }
    }

    /// Sits on the list background rather than in a card, like a Settings header.
    private func statusHeader(at date: Date, isLocked: Bool) -> some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(isLocked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(height: 64)
                VStack(spacing: 4) {
                    Text(isLocked ? "Apps Locked" : "Apps Unlocked")
                        .font(.title.bold())
                    statusDetail(at: date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if controller.settings.canFlapUnlock(at: date) {
                    Button { isFlapping = true } label: {
                        Label("Flap Unlock", systemImage: "bird.fill")
                            .font(.headline)
                            // The header's tint style otherwise reaches the symbol, drawing it
                            // blue on the blue button.
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private func statusDetail(at date: Date) -> Text {
        let settings = controller.settings
        if settings.debugOverride != nil { return Text("Debug override is on.") }
        if let until = settings.flapUnlockedUntil, date < until {
            return Text("Flap Unlock ends in \(Text(until, style: .timer)).")
        }
        guard settings.isLocking(at: date) else {
            return Text(controller.schedule.allows(date) ? "Fold your phone to lock them." : "Outside your schedule, so folding won’t lock them.")
        }
        if controller.selectedCount == 0 { return Text("No apps chosen yet.") }
        if !isAuthorized { return Text("Screen Time access is off, so nothing is blocked.") }
        return Text("Unfold your phone to use them.")
    }

    private var scheduleSection: some View {
        Section {
            Toggle("Only on a Schedule", isOn: $controller.schedule.isEnabled)
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
        guard controller.schedule.isEnabled else { return "Folding locks apps at any time, and unfolding unlocks them." }
        if controller.schedule.weekdays.isEmpty { return "Pick at least one day, or folding won’t lock anything." }
        let rule = "Folding locks apps only during these hours. Outside them, folding has no effect."
        return controller.schedule.isOvernight ? rule + " Runs overnight, from the evening of each chosen day." : rule
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
            LabeledContent("Override", value: controller.settings.debugOverride.map { $0 ? "Locked" : "Unlocked" } ?? "Off")
            Button("Force Lock") { controller.overrideLock(true) }
            Button("Force Unlock") { controller.overrideLock(false) }
            Button("Clear Override") { controller.overrideLock(nil) }
                .disabled(controller.settings.debugOverride == nil && controller.settings.flapUnlockedUntil == nil)
        }
    }

    private var flapRuleSection: some View {
        Section {
            Stepper(value: $controller.flapRule.flaps, in: 1...50) {
                LabeledContent("Flaps Needed", value: "\(controller.flapRule.flaps)")
            }
            Picker("Unlocks For", selection: $controller.flapRule.minutes) {
                ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                    Text(Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide)))
                        .tag(minutes)
                }
            }
        } header: {
            Text("Flap Unlock")
        } footer: {
            Text(controller.flapUnlockError ?? "When your apps are locked, close and reopen your phone this many times in Unfold to unlock them for a while.")
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
