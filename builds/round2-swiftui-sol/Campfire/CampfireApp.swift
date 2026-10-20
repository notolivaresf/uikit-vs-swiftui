import SwiftUI

@main
struct CampfireApp: App {
    private let started = ContinuousClock.now

    var body: some Scene {
        WindowGroup {
            RoomView(started: started)
                .statusBarHidden()
        }
    }
}
