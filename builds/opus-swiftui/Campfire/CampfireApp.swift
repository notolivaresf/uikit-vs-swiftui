import SwiftUI

enum Launch {
    /// Set by the first line of the app's own code; the launch "ms" in the debug label counts from here.
    nonisolated(unsafe) static var start = ContinuousClock.now
    static let isBenchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")
    static let verbose = UserDefaults.standard.bool(forKey: "uvsVerbose")
}

@main
struct CampfireApp: App {
    @State private var store: RoomStore

    init() {
        Launch.start = .now
        _store = State(initialValue: RoomStore())
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "uvsFixtureRow") {
                FixtureRowView()
            } else {
                RoomView().environment(store).environment(store.selection)
            }
            #else
            RoomView().environment(store).environment(store.selection)
            #endif
        }
    }
}
