import SwiftUI

@main
struct CampfireApp: App {
    init() {
        LaunchClock.mark()
        DataPreload.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    private let arguments = ProcessInfo.processInfo.arguments

    var body: some View {
        if let name = value(after: "-uvsGallery") {
            ReferenceGallery(name: name)
        } else {
            RoomView(benchmark: UserDefaults.standard.bool(forKey: "uvsBenchmark"))
        }
    }

    private func value(after flag: String) -> String? {
        guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }
}
