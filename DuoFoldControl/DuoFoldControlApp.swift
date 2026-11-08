import SwiftUI

@main
struct DuoFoldControlApp: App {
    @StateObject private var controller = FoldLockController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
        }
    }
}
