import Foundation
import CampfireKit

/// Placeholder images for Objective-C: PNG bytes, drawn with `[UIImage imageWithData:]`.
@objc public final class CFKPlaceholder: NSObject {
    @objc public static func pngData(width: Int, height: Int, red: Int, green: Int, blue: Int) -> Data {
        Placeholder.pngData(width: width, height: height,
                            color: RGB(r: UInt8(clamping: red), g: UInt8(clamping: green), b: UInt8(clamping: blue)))
    }
}

/// The dataset. Holds the Swift messages; `CFKMessage` objects are made only for the page you ask for.
@objc public final class CFKDataset: NSObject, @unchecked Sendable {
    let dataset: Dataset
    @objc public static let pageSize = Windowing.pageSize
    @objc public static let defaultMessageCount = DatasetSize.k50.rawValue

    /// 50,000 messages from the fixed benchmark seed.
    @objc public override convenience init() { self.init(messageCount: DatasetSize.k50.rawValue) }

    /// Generates `messageCount` messages from the fixed benchmark seed (`FakeData.generate(count:)`).
    @objc public init(messageCount: Int) {
        dataset = FakeData.generate(count: messageCount)
    }

    init(wrapping d: Dataset) { dataset = d }

    @objc public var seed: UInt64 { dataset.seed }
    @objc public var currentUserID: Int { dataset.currentUserID }
    @objc public var roomName: String { dataset.room.name }
    @objc public var messageCount: Int { dataset.messages.count }
    @objc public var firstMessageID: Int { dataset.messages.first?.id ?? 0 }
    @objc public var lastMessageID: Int { dataset.messages.last?.id ?? 0 }

    @objc public lazy var users: [CFKUser] = dataset.users.map(CFKUser.init)

    @objc public func user(withID id: Int) -> CFKUser? { dataset.user(id).map(CFKUser.init) }

    /// Index of a message id; ids are 1-based and contiguous in generated data, with a scan as fallback.
    private func index(of id: Int) -> Int? {
        let m = dataset.messages
        let guess = id - 1
        if guess >= 0, guess < m.count, m[guess].id == id { return guess }
        return m.firstIndex { $0.id == id }
    }

    private func page(_ slice: ArraySlice<Message>) -> CFKPage {
        let previous: Message? = slice.startIndex > 0 ? dataset.messages[slice.startIndex - 1] : nil
        let pres = Grouping.presentations(of: Array(slice), previous: previous, currentUserID: dataset.currentUserID)
        return CFKPage(messages: slice.map(CFKMessage.init), presentations: pres.map(CFKPresentation.init))
    }

    /// The newest `pageSize` messages.
    @objc public func lastPage() -> CFKPage { page(Windowing.lastPage(dataset.messages)) }
    /// The `pageSize` messages before `id` (empty if unknown).
    @objc public func pageBeforeMessageID(_ id: Int) -> CFKPage { page(Windowing.page(before: id, in: dataset.messages)) }
    @objc public func pageAfterMessageID(_ id: Int) -> CFKPage { page(Windowing.page(after: id, in: dataset.messages)) }
    /// Messages id-40 ... id+40.
    @objc public func pageAroundMessageID(_ id: Int) -> CFKPage { page(Windowing.around(id, in: dataset.messages)) }

    @objc public func message(withID id: Int) -> CFKMessage? {
        index(of: id).map { CFKMessage(dataset.messages[$0]) }
    }

    /// Presentation of one message relative to the one before it in the dataset.
    @objc public func presentation(forMessageID id: Int) -> CFKPresentation? {
        guard let i = index(of: id) else { return nil }
        return CFKPresentation(Grouping.presentation(of: dataset.messages[i], after: i > 0 ? dataset.messages[i - 1] : nil,
                                                      currentUserID: dataset.currentUserID))
    }

    /// Presentation of `message` when it follows `previous` (nil = first message). For live messages.
    @objc public func presentation(of message: CFKMessage, after previous: CFKMessage?) -> CFKPresentation {
        CFKPresentation(Grouping.presentation(of: message.swift, after: previous?.swift, currentUserID: dataset.currentUserID))
    }
}

/// Handle returned by `CFKLiveFeed.start`; `cancel` stops the stream (no further callbacks, completion not called).
@objc public final class CFKFeedHandle: NSObject, @unchecked Sendable {
    private let task: Task<Void, Never>
    init(task: Task<Void, Never>) { self.task = task }
    @objc public func cancel() { task.cancel() }
}

@objc public final class CFKLiveFeed: NSObject, @unchecked Sendable {
    let feed: FakeLiveFeed

    /// 20 messages a second for 30 s, continuing after the dataset's last message.
    @objc public init(dataset: CFKDataset) { feed = FakeLiveFeed(dataset: dataset.dataset) }

    @objc public init(dataset: CFKDataset, messagesPerSecond: Double, duration: TimeInterval) {
        feed = FakeLiveFeed(dataset: dataset.dataset, messagesPerSecond: messagesPerSecond, duration: duration)
    }

    @objc public var eventCount: Int { feed.script.count }

    /// Plays the stream in real time. `onEvent` is called on the main queue per event, then `completion` once at the
    /// end (not after `cancel`). Both run on the main queue.
    @objc public func start(onEvent: @escaping @Sendable (CFKFeedEvent) -> Void,
                            completion: @escaping @Sendable () -> Void) -> CFKFeedHandle {
        let stream = feed.play()
        let task = Task { @MainActor in
            for await event in stream {
                if Task.isCancelled { return }
                onEvent(CFKFeedEvent(event))
            }
            if !Task.isCancelled { completion() }
        }
        return CFKFeedHandle(task: task)
    }

    /// Wrapped events of the script in order, without timing (for tests and tools).
    @objc public func scriptedEvents() -> [CFKFeedEvent] { feed.script.map { CFKFeedEvent($0.event) } }
}
