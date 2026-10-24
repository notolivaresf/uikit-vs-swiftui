import SwiftUI
import CampfireKit

@main
struct CampfireApp: App {
    private let launchedAt: ContinuousClock.Instant
    private let generation: Task<Dataset, Never>

    init() {
        launchedAt = .now
        generation = Task.detached(priority: .userInitiated) { FakeData.generate(size: .k50) }
    }

    var body: some Scene {
        WindowGroup {
            RoomView(launchedAt: launchedAt, generation: generation)
                .statusBarHidden()
        }
    }
}
