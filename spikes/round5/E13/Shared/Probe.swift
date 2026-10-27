import Foundation
import QuartzCore
import UIKit

/// Measurement hooks for the E13 spike, with no UI test attached (nothing polls the app).
/// Each mode is a launch argument; lines go to stdout (`simctl launch --stdout=<file>`).
/// `-uvsAutoJump YES`      12 x (latest page, then jump to 2,500), each jump timed to the next frame.
/// `-uvsAutoOlder YES`     12 x (latest page, then load older), timed the same way.
/// `-uvsAutoTextBottom YES` 12 x (latest page, then one text size step).
/// `-uvsAutoTextMid YES`   12 x (jump to 2,500, then one text size step).
/// `-uvsAutoStream YES`    the 30 s live stream; CPU, peak memory, and arrival-to-applied latency.
///                         `-uvsFeedRate <n>` sets messages per second (default 20).
/// `-uvsAutoFling YES`     scrolls up through history at a fixed speed, loading older pages as it goes;
///                         frame gaps, cells made off screen, prefetch calls, CPU and peak memory.
/// `-uvsAutoCallback YES`  logs whether the layout's targetContentOffset(forProposedContentOffset:) runs
///                         after a plain invalidation, after reloadData, and after an empty batch update.
enum Probe {
    static let d = UserDefaults.standard
    static let autoJump = d.bool(forKey: "uvsAutoJump")
    static let autoOlder = d.bool(forKey: "uvsAutoOlder")
    static let autoTextBottom = d.bool(forKey: "uvsAutoTextBottom")
    static let autoTextMid = d.bool(forKey: "uvsAutoTextMid")
    static let autoStream = d.bool(forKey: "uvsAutoStream")
    static let autoFling = d.bool(forKey: "uvsAutoFling")
    static let autoCallback = d.bool(forKey: "uvsAutoCallback")
    static var feedRate: Double { let r = d.double(forKey: "uvsFeedRate"); return r > 0 ? r : 20 }

    static var updates = 0
    static var cells = 0
    static var offscreenCells = 0
    static var prefetchCalls = 0
    static var trims = 0
    static var trimSeconds = 0.0
    static var targetCalls = 0
    static var cellsCreated = 0
    private static var cpu0 = 0.0
    private static var wall0 = 0.0

    // Latency: arrival time per message id, applied time per id.
    static var arrived: [Int: CFTimeInterval] = [:]
    static var latencies: [Double] = []
    static func arrive(_ id: Int) { arrived[id] = CACurrentMediaTime() }
    static func applied(_ ids: [Int]) {
        let now = CACurrentMediaTime()
        for id in ids { if let t = arrived.removeValue(forKey: id) { latencies.append((now - t) * 1000) } }
    }

    static func cpu() -> Double {
        var u = rusage()
        getrusage(RUSAGE_SELF, &u)
        return Double(u.ru_utime.tv_sec) + Double(u.ru_utime.tv_usec) / 1e6
            + Double(u.ru_stime.tv_sec) + Double(u.ru_stime.tv_usec) / 1e6
    }

    static func say(_ s: String) { print(s); fflush(stdout) }

    static func streamStarted() {
        updates = 0; cells = 0; cellsCreated = 0
        cpu0 = cpu(); wall0 = CACurrentMediaTime()
        say("PROBE stream start rate \(feedRate)")
    }

    static func streamDone() {
        let m = memory()
        let l = latencies.sorted()
        func pct(_ p: Double) -> Double { l.isEmpty ? 0 : l[min(l.count - 1, Int(Double(l.count) * p))] }
        say(String(format: "STREAMCPU %.3f wall %.2f updates %d trims %d trim-ms %.0f cells %d created %d mem-now %.1f mem-peak %.1f lat-med %.1f lat-p95 %.1f lat-max %.1f n %d",
                   cpu() - cpu0, CACurrentMediaTime() - wall0, updates, trims, trimSeconds * 1000, cells, cellsCreated, m.now, m.peak, pct(0.5), pct(0.95), l.last ?? 0, l.count))
    }

    // Phase marks inside one timed action.
    private static var t0: CFTimeInterval = 0
    private static var marks: [(String, CFTimeInterval)] = []
    private static var phaseRounds: [[(String, Double)]] = []
    static func mark(_ label: String) { if t0 > 0 { marks.append((label, CACurrentMediaTime())) } }

    final class Tick: NSObject {
        let done: () -> Void
        init(_ done: @escaping () -> Void) { self.done = done }
        @objc func fire(_ l: CADisplayLink) { l.invalidate(); done() }
    }
    private static var keep: [Tick] = []
    static func nextFrame(_ done: @escaping () -> Void) {
        let tick = Tick { done() }
        keep.append(tick)
        CADisplayLink(target: tick, selector: #selector(Tick.fire(_:))).add(to: .main, forMode: .common)
    }

    /// Runs `setup`, waits, then times `action` to the next display frame; `rounds` times.
    static func timed(_ tag: String, rounds: Int = 12, setup: @escaping () -> Void, action: @escaping () -> Void) {
        var results: [Double] = []
        phaseRounds = []
        func round(_ n: Int) {
            guard n < rounds else {
                let sorted = results.sorted()
                say("\(tag) \(results.map { String(format: "%.1f", $0) }.joined(separator: " ")) median \(String(format: "%.1f", sorted[sorted.count / 2]))")
                // Median of each phase across rounds (phase = time from the previous mark).
                if let first = phaseRounds.first {
                    var parts: [String] = []
                    for (i, (label, _)) in first.enumerated() {
                        let v = phaseRounds.compactMap { $0.count > i ? $0[i].1 : nil }.sorted()
                        parts.append("\(label) \(String(format: "%.1f", v[v.count / 2]))")
                    }
                    say("PHASES \(tag): \(parts.joined(separator: " | "))")
                }
                sayMemory("after-\(tag)")
                return
            }
            setup()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                marks = []
                t0 = CACurrentMediaTime()
                action()
                mark("action-returned")
                nextFrame {
                    let end = CACurrentMediaTime()
                    results.append((end - t0) * 1000)
                    var prev = t0
                    var row: [(String, Double)] = []
                    for (label, t) in marks { row.append((label, (t - prev) * 1000)); prev = t }
                    row.append(("to-frame", (end - prev) * 1000))
                    phaseRounds.append(row)
                    t0 = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { round(n + 1) }
                }
            }
        }
        round(0)
    }

    /// Frame-gap recorder for the fling.
    final class Fling: NSObject {
        var link: CADisplayLink?
        var last: CFTimeInterval = 0
        var gaps: [Double] = []
        var frames = 0
        var step: () -> Bool = { false }
        var finish: () -> Void = {}
        @objc func fire(_ l: CADisplayLink) {
            if last > 0 { gaps.append((l.timestamp - last) * 1000) }
            last = l.timestamp
            frames += 1
            if !step() { l.invalidate(); link = nil; finish() }
        }
    }
    static var fling: Fling?
    static func runFling(step: @escaping () -> Bool) {
        let f = Fling()
        let c0 = cpu()
        cells = 0; offscreenCells = 0; prefetchCalls = 0; cellsCreated = 0
        f.step = step
        f.finish = {
            let nominal = 1000.0 / 60.0
            let hitches = f.gaps.filter { $0 > nominal * 1.5 }
            let hitchMs = hitches.reduce(0) { $0 + ($1 - nominal) }
            let total = f.gaps.reduce(0, +)
            let m = memory()
            say(String(format: "FLING frames %d hitches %d hitch-ms %.0f hitch-ratio %.1f ms/s worst %.1f cpu %.3f cells %d offscreen %d created %d prefetch-calls %d mem-peak %.1f",
                       f.frames, hitches.count, hitchMs, hitchMs / (total / 1000), f.gaps.max() ?? 0, cpu() - c0, cells, offscreenCells, cellsCreated, prefetchCalls, m.peak))
            fling = nil
        }
        fling = f
        let link = CADisplayLink(target: f, selector: #selector(Fling.fire(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        f.link = link
        link.add(to: .main, forMode: .common)
    }
}
