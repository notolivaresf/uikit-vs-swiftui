import CampfireKit
import SwiftUI

@main
struct CampfireBenchApp: App {
    @State private var store: RoomStore
    @State private var monitor: BenchmarkMonitor?
    private let users: UserDirectory

    init() {
        LaunchClock.markStart()
        let dataset = FakeData.generate(size: .k50)
        let store = RoomStore(dataset: dataset, scroller: RoomScroller())
        _store = State(initialValue: store)
        _monitor = State(initialValue: LaunchOptions.isBenchmark ? BenchmarkMonitor(store: store) : nil)
        users = UserDirectory(dataset.users)
    }

    var body: some Scene {
        WindowGroup {
            RoomView(store: store, monitor: monitor, users: users)
        }
    }
}
