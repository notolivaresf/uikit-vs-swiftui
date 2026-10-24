#if DEBUG
import Foundation

/// Development aid: `-uvsScript "jump,older,size"` runs debug-bar actions 1.5 s apart and logs the label.
@MainActor
enum DebugScript {
    static func run(store: RoomStore, monitor: BenchmarkMonitor?, textSize: TextSizeSetting) {
        guard let script = UserDefaults.standard.string(forKey: "uvsScript") else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            print("SCRIPT start \(monitor?.label ?? "")")
            for step in script.split(separator: ",") {
                switch step {
                case "jump": store.jump(to: 2500)
                case "older": store.loadOlder()
                case "newest": store.showNewest()
                case "stream": store.startStream()
                case "burst": store.boostBurst()
                case "size": textSize.step(from: textSize.override ?? .large)
                default:
                    if step.hasPrefix("jump:"), let id = Int(step.dropFirst(5)) { store.jump(to: id) }
                }
                try? await Task.sleep(for: .seconds(1.5))
                print("SCRIPT \(step) -> \(monitor?.label ?? "")")
            }
        }
    }
}
#endif
