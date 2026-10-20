import SwiftUI

@main
struct CampfireApp: App {
    @State private var room: RoomStore

    init() {
        let started = ContinuousClock.now
        _room = State(initialValue: RoomStore(started: started))
    }

    var body: some Scene {
        WindowGroup {
            RoomView(store: room)
                .statusBarHidden()
        }
    }
}
