import Foundation

public enum FeedEvent: Equatable, Sendable {
    case message(Message)
    case boost(messageID: MessageID, Boost)
    case typingStarted(UserID)
    case typingStopped(UserID)
}

/// A scripted event with the offset (seconds from start) at which it fires.
public struct ScheduledEvent: Equatable, Sendable {
    public let at: TimeInterval
    public let event: FeedEvent
}

/// In-process stand-in for Campfire's websocket. The script is a pure function of the seed, so every run of
/// either build sees identical events; only the timing source differs (`play` sleeps, tests read `script`).
public struct FakeLiveFeed: Sendable {
    public let messagesPerSecond: Double
    public let duration: TimeInterval
    public let script: [ScheduledEvent]

    /// - Parameters:
    ///   - lastMessageID: id of the newest message already in the dataset; new ids continue from it.
    ///   - lastMessageTime: time of that message; new ones are stamped after it, 1/rate apart.
    public init(dataset: Dataset, messagesPerSecond: Double = 20, duration: TimeInterval = 30,
                seed: UInt64 = FakeData.defaultSeed &+ 1) {
        self.messagesPerSecond = messagesPerSecond
        self.duration = duration
        var rng = SeededRandom(seed: seed)
        var nextID = (dataset.messages.last?.id ?? 0) + 1
        var boostID = 1_000_000
        var time = dataset.messages.last?.createdAt ?? FakeData.epoch
        let others = dataset.users.map(\.id).filter { $0 != dataset.currentUserID }
        var events: [ScheduledEvent] = []
        let total = Int(messagesPerSecond * duration)
        var author = others[0]
        var typing: Set<UserID> = []
        for i in 0..<total {
            let at = Double(i) / messagesPerSecond
            if rng.chance(0.3) { author = rng.pick(others) }
            if rng.chance(0.05), !typing.contains(author) {
                typing.insert(author)
                events.append(.init(at: max(0, at - 0.3), event: .typingStarted(author)))
            }
            time = time.addingTimeInterval(1.0 / messagesPerSecond)
            events.append(.init(at: at, event: .message(
                FakeData.makeMessage(id: nextID, creator: author, at: time, rng: &rng, boostID: &boostID))))
            if typing.contains(author) { typing.remove(author); events.append(.init(at: at, event: .typingStopped(author))) }
            if rng.chance(0.1), nextID > 1 {
                let target = rng.int(max(1, nextID - 40)...nextID)
                events.append(.init(at: at + 0.01, event: .boost(messageID: target,
                    Boost(id: boostID, boosterID: rng.pick(others), content: rng.pick(Corpus.reactions)))))
                boostID += 1
            }
            nextID += 1
        }
        script = events.sorted { $0.at < $1.at }
    }

    /// Plays the script in real time. Cancel the consuming task to stop it.
    public func play() -> AsyncStream<FeedEvent> {
        let script = self.script
        return AsyncStream { continuation in
            let task = Task {
                let start = ContinuousClock.now
                for item in script {
                    let due = start + .milliseconds(Int(item.at * 1000))
                    try? await Task.sleep(until: due, clock: .continuous)
                    if Task.isCancelled { break }
                    continuation.yield(item.event)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
