import SwiftUI

/// Walks through the two Shortcuts automations that report folding while Unfold isn't on screen.
/// Apple doesn't let apps ship or share automations, so each user builds them by hand.
struct AutomationGuideView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.tint)
                    Text("Lock When Folded")
                        .font(.title2.bold())
                    Text("Unfold only sees the hinge while it’s open. Two Shortcuts automations tell it when you fold and unfold the rest of the time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("You’ll Make Two") {
                automation(trigger: "Display Closed", action: "Lock Apps", symbol: "lock.fill")
                automation(trigger: "Display Opened", action: "Unlock Apps", symbol: "lock.open.fill")
            }

            Section {
                step(1, "Open **Shortcuts** and go to the **Automation** tab.")
                step(2, "Tap **+**, then choose **Display**.")
                step(3, "Select **Closed**, then choose **Run Immediately** and turn off **Notify When Run**.", warning: "Without Run Immediately, iOS asks every time you fold.")
                step(4, "Tap **Next**, search for **Unfold**, and choose **Lock Apps**.")
                step(5, "Repeat with **Opened** and **Unlock Apps**.")
            } header: {
                Text("Steps")
            } footer: {
                Text("To check, fold your phone during your schedule and open a locked app on the outside screen. It should be blocked.")
            }

            Section {
                Button {
                    if let url = URL(string: "shortcuts://") { openURL(url) }
                } label: {
                    Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle("Automations")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func automation(trigger: String, action: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Label(trigger, systemImage: "iphone")
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
            Label(action, systemImage: symbol)
                .foregroundStyle(.tint)
                .lineLimit(1)
        }
        .font(.subheadline.weight(.medium))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("When \(trigger), run \(action)")
    }

    private func step(_ number: Int, _ text: LocalizedStringKey, warning: LocalizedStringKey? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                if let warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
