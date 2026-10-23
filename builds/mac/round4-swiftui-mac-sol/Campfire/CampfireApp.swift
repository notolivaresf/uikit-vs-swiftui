import SwiftUI

@main
struct CampfireApp: App {
    // This precedes data generation and creation of the first view.
    private let launchTime = ContinuousClock.now

    var body: some Scene {
        Window("Campfire", id: "room") {
            RoomView(launchTime: launchTime)
                .frame(minWidth: 393, minHeight: 600)
                .containerBackground(.background, for: .window)
        }
        .windowStyle(.plain)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 393, height: 852)
        .defaultWindowPlacement { _, _ in
            WindowPlacement(.center, size: CGSize(width: 393, height: 852))
        }
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.presented)
    }
}
