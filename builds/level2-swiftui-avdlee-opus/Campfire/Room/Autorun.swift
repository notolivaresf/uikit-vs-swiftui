import SwiftUI

/// Development aid: `-uvsAutorun "wait:1,jump:2500,older,textsize,reset,stream,burst,log"` replays debug-bar
/// actions after launch and logs the state label, so behaviours can be checked from the command line.
@MainActor
enum Autorun {
    static func run(_ model: RoomModel) async {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-uvsAutorun"), i + 1 < args.count else { return }
        try? await Task.sleep(for: .seconds(1.5))
        for step in args[i + 1].split(separator: ",") {
            let parts = step.split(separator: ":")
            let name = String(parts[0])
            let value = parts.count > 1 ? String(parts[1]) : ""
            switch name {
            case "wait": try? await Task.sleep(for: .seconds(Double(value) ?? 1))
            case "jump": model.jump(to: Int(value) ?? 2500)
            case "older": model.loadOlderTapped()
            case "textsize": model.textSizeUp()
            case "reset": model.reset()
            case "stream": model.startStream()
            case "burst": model.boostBurst()
            case "bottom": model.jumpToBottom()
            case "scrollby": model.debugScroll(by: CGFloat(Double(value) ?? 0))
            default: break
            }
            RoomModel.log.notice("autorun \(name, privacy: .public) -> \(model.stateLabel, privacy: .public)")
        }
        try? await Task.sleep(for: .seconds(0.5))
        RoomModel.log.notice("autorun done -> \(model.stateLabel, privacy: .public)")
    }
}
