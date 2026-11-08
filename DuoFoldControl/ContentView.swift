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

    private var statusHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: controller.isEngaged ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(controller.isEngaged ? "Apps locked" : "Apps unlocked")
                .font(.title2.bold())
            Text(statusDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }

    private var statusDetail: String {
        guard controller.isEngaged else { return "Fold your phone to lock them." }
        if controller.selectedCount == 0 { return "No apps chosen yet." }
        if !isAuthorized { return "Screen Time access is off, so nothing is blocked." }
        return "Unfold your phone to use them."
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
            controller.syncShield()
        } catch {
            authError = error.localizedDescription
        }
    }
}
