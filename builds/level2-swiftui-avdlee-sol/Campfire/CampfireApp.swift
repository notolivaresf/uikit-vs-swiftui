import SwiftUI
import CampfireKit

@main
struct CampfireApp: App {
    static let startedAt = ContinuousClock.now

    static let datasetTask = Task.detached(priority: .userInitiated) { FakeData.generate(size: .k50) }

    init() {
        _ = Self.startedAt
        _ = Self.datasetTask
    }

    var body: some Scene {
        WindowGroup {
            RoomView()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
