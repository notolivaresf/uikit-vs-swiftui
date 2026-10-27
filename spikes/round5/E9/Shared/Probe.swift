import Foundation
import QuartzCore

/// Measurement hooks for the E8 spike, with no UI test attached (so nothing polls the app).
/// `-uvsAutoStream YES`: start the live stream 1.5 s after first content; print the app's own CPU
/// (user + system, from getrusage) for the stream alone, and the number of list updates it made.
/// `-uvsAutoJump YES`: after first content, jump to message 2,500 and back to the latest, 12 times,
/// printing the time from the start of each jump to the next display frame.
/// Lines go to stdout; read them with `simctl launch --stdout=<file>`.
enum Probe {
    static let autoStream = UserDefaults.standard.bool(forKey: "uvsAutoStream")
    static let autoJump = UserDefaults.standard.bool(forKey: "uvsAutoJump")
    /// `-uvsAutoTextSize YES`: jump to 2,500, then three text size steps; prints the top row after each.
    static let autoTextSize = UserDefaults.standard.bool(forKey: "uvsAutoTextSize")
    static var updates = 0
    static var cells = 0
    static var trims = 0
    static var trimSeconds = 0.0
    private static var cpu0 = 0.0
    private static var wall0 = 0.0

    static func cpu() -> Double {
        var u = rusage()
        getrusage(RUSAGE_SELF, &u)
        return Double(u.ru_utime.tv_sec) + Double(u.ru_utime.tv_usec) / 1e6
            + Double(u.ru_stime.tv_sec) + Double(u.ru_stime.tv_usec) / 1e6
    }

    static func say(_ s: String) {
        print(s)
        fflush(stdout)
    }

    static func streamStarted() {
        updates = 0
        cells = 0
        cpu0 = cpu()
        wall0 = CACurrentMediaTime()
        say("PROBE stream start")
    }

    static func streamDone() {
        let m = memory()
        say(String(format: "STREAMCPU %.3f wall %.2f updates %d trims %d trim-ms %.0f cells %d mem-now %.1f mem-peak %.1f", cpu() - cpu0, CACurrentMediaTime() - wall0, updates, trims, trimSeconds * 1000, cells, m.now, m.peak))
    }

    /// Prints the gaps between successive timestamps, in ms, under the given labels.
    static func phases(_ labels: String, _ t: [CFTimeInterval]) {
        let ms = zip(t.dropFirst(), t).map { String(format: "%.1f", ($0 - $1) * 1000) }
        say("PHASE \(labels): \(ms.joined(separator: " "))")
    }

    /// Runs `jump` then `back` `rounds` times; each jump is timed to the next display frame.
    static func runJumps(rounds: Int = 12, jump: @escaping () -> Void, back: @escaping () -> Void) {
        var results: [Int] = []
        final class Tick: NSObject {
            let done: () -> Void
            var link: CADisplayLink?
            init(_ done: @escaping () -> Void) { self.done = done }
            @objc func fire(_ l: CADisplayLink) { l.invalidate(); link = nil; done() }
        }
        var keep: Tick?
        func round(_ n: Int) {
            guard n < rounds else {
                let sorted = results.sorted()
                say("JUMPMS \(results.map(String.init).joined(separator: " ")) median \(sorted[sorted.count / 2])")
                return
            }
            let t0 = CACurrentMediaTime()
            jump()
            let tick = Tick {
                results.append(Int(((CACurrentMediaTime() - t0) * 1000).rounded()))
                keep = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    back()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { round(n + 1) }
                }
            }
            let link = CADisplayLink(target: tick, selector: #selector(Tick.fire(_:)))
            tick.link = link
            keep = tick
            link.add(to: .main, forMode: .common)
        }
        _ = keep
        round(0)
    }
}
