import SwiftUI

/// The Flap Unlock ritual: close and reopen the phone `flapRule.flaps` times while this is on
/// screen, then it unlocks and dismisses itself.
struct FlapUnlockView: View {
    @EnvironmentObject private var controller: FoldLockController
    @Environment(\.dismiss) private var dismiss
    @State private var flaps = 0
    @State private var isClosed = false
    @State private var isUnlocked = false

    private var target: Int { controller.flapRule.flaps }

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                ring
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2.bold())
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("Flap Unlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isUnlocked {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .sensoryFeedback(.increase, trigger: flaps)
        .sensoryFeedback(.success, trigger: isUnlocked)
        // ContentView stops following the hinge while this covers it, so this keeps the fold
        // state current as well as counting.
        .onHingeChange { old, new in
            controller.follow(new.hinge)
            guard !isUnlocked, let status = new.hinge?.status else { return }
            let isOpen = status == .partiallyOpen || status == .fullyOpen
            isClosed = status == .closed
            if old.hinge?.status == .closed, isOpen { countFlap() }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemFill), lineWidth: 18)
            Circle()
                .trim(from: 0, to: Double(flaps) / Double(target))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if isUnlocked {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.tint)
                    .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    Text("\(flaps)")
                        .font(.system(size: 76, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(flaps)))
                    Text("of \(target)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 240, height: 240)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isUnlocked ? "Unlocked" : "\(flaps) of \(target) flaps")
    }

    private var title: String {
        if isUnlocked { return "Unlocked" }
        return isClosed ? "Now Open It" : "Close Your Phone"
    }

    private var subtitle: String {
        if isUnlocked { return "Your apps are open for \(controller.flapRule.minutes) minutes." }
        if flaps == 0 { return "Each close and reopen counts as one flap. Keep Unfold open." }
        let left = target - flaps
        return left == 1 ? "One more." : "\(left) to go."
    }

    private func countFlap() {
        withAnimation(.snappy) { flaps += 1 }
        guard flaps >= target else { return }
        controller.flapUnlock()
        withAnimation(.spring) { isUnlocked = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        }
    }
}
