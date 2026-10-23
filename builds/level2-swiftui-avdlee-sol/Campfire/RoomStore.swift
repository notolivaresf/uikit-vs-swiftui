import SwiftUI
import CampfireKit

struct PresentedBoost: Identifiable, Sendable {
    struct ID: Hashable, Sendable { let source: Int; let occurrence: Int }
    let id: ID
    let boost: Boost
}

struct RoomRow: Identifiable, Equatable, Sendable {
    let message: Message
    let presentation: MessagePresentation
    var id: Int { message.id }
    var boosts: [PresentedBoost] {
        // A burst can reuse a package value. Its immutable source ID and occurrence number
        // distinguish each addition; appending never changes an existing pill's identity.
        var occurrences: [Int: Int] = [:]
        return message.boosts.map { boost in
            occurrences[boost.id, default: 0] += 1
            return PresentedBoost(id: .init(source: boost.id, occurrence: occurrences[boost.id]!), boost: boost)
        }
    }
}

@MainActor @Observable
final class RoomStore {
    private(set) var rows: [RoomRow] = []
    private(set) var ready = false
    private(set) var streamRunning = false
    private(set) var streamDone = false
    private(set) var revision = 0
    private(set) var deferredLiveTail = false
    var textSize: DynamicTypeSize?
    @ObservationIgnored private(set) var dataset: Dataset?
    @ObservationIgnored private(set) var all: [Message] = []
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var boostTask: Task<Void, Never>?
    @ObservationIgnored private(set) var users: [Int: User] = [:]
    @ObservationIgnored var beforeMutation: (() -> Void)?
    @ObservationIgnored var followsLiveTail: (() -> Bool)?
    @ObservationIgnored var tailDidChange: ((Bool) -> Void)?
    @ObservationIgnored var visibleAnchorID: (() -> Int)?

    func load() async {
        guard !ready else { return }
        let data = await CampfireApp.datasetTask.value
        dataset = data
        all = data.messages
        users = Dictionary(uniqueKeysWithValues: data.users.map { ($0.id, $0) })
        replace(with: Array(Windowing.lastPage(all)))
        ready = true
    }

    func reset() {
        streamTask?.cancel()
        boostTask?.cancel()
        streamRunning = false
        streamDone = false
        deferredLiveTail = false
        guard let dataset else { return }
        all = dataset.messages
        textSize = nil
        replace(with: Array(Windowing.lastPage(all)))
    }

    func jump() {
        deferredLiveTail = false
        replace(with: Array(Windowing.around(2500, in: all)))
    }

    @discardableResult func loadOlder() -> Bool {
        guard let first = rows.first?.id else { return false }
        let older = Windowing.page(before: first, in: all)
        guard !older.isEmpty else { revision += 1; return false }
        var page = Array(older) + rows.map(\.message)
        if page.count > Windowing.maxLoaded {
            let trimmed = Array(page.prefix(Windowing.maxLoaded))
            // Never evict the row the reader is looking at to satisfy a window-size target.
            if let anchor = visibleAnchorID?(), trimmed.contains(where: { $0.id == anchor }) { page = trimmed }
        }
        replace(with: page)
        return true
    }

    func loadNewer() {
        guard let last = rows.last?.id else { return }
        let newer = Windowing.page(after: last, in: all)
        guard !newer.isEmpty else { return }
        beforeMutation?()
        var page = rows.map(\.message) + newer
        if page.count > Windowing.maxLoaded { page = Array(page.suffix(Windowing.maxLoaded)) }
        replace(with: page)
    }

    func newest() {
        deferredLiveTail = false
        replace(with: Array(Windowing.lastPage(all)))
    }

    func largerText(current: DynamicTypeSize) {
        let steps = DynamicTypeSize.allCases
        let index = steps.firstIndex(of: textSize ?? current) ?? 3
        textSize = index + 1 < steps.count ? steps[index + 1] : current
        revision += 1
    }

    private func replace(with messages: [Message]) {
        let previous = messages.first.flatMap { $0.id > 1 ? all[$0.id - 2] : nil }
        let presentations = Grouping.presentations(of: messages, previous: previous, currentUserID: 1)
        rows = zip(messages, presentations).map { RoomRow(message: $0, presentation: $1) }
        tailDidChange?(rows.last?.id == all.last?.id)
        revision += 1
    }

    private func consume(_ event: FeedEvent) {
        switch event {
        case .message(let message):
            let viewingNewest = rows.last?.id == all.last?.id && (followsLiveTail?() ?? true)
            all.append(message)
            if viewingNewest {
                beforeMutation?()
                var page = rows.map(\.message)
                page.append(message)
                // The live tail only needs one page on screen. Keep the full stream in `all`;
                // older pages can be loaded normally without laying out 300 offscreen rows at 20 Hz.
                if page.count > Windowing.pageSize { page.removeFirst(page.count - Windowing.pageSize) }
                replace(with: page)
            } else {
                // Keep an unpinned history window still; arrivals remain in the package-backed history.
                if deferredLiveTail || rows.last?.id == message.id - 1 { deferredLiveTail = true }
                tailDidChange?(false)
            }
        case .boost(let id, let boost):
            guard id > 0, id <= all.count else { return }
            all[id - 1].boosts.append(boost)
            if let index = rows.firstIndex(where: { $0.id == id }) {
                beforeMutation?()
                rows[index] = RoomRow(message: all[id - 1], presentation: rows[index].presentation)
                revision += 1
            }
        case .typingStarted, .typingStopped: break
        }
    }

    func startStream() {
        guard !streamRunning, !streamDone, let dataset else { return }
        streamRunning = true
        streamDone = false
        streamTask = Task { [weak self] in
            let feed = FakeLiveFeed(dataset: dataset)
            for await event in feed.play() {
                guard !Task.isCancelled else { return }
                // A second playback must never insert duplicate message identities.
                if case .message(let message) = event, message.id <= (self?.all.last?.id ?? 0) { continue }
                self?.consume(event)
            }
            guard !Task.isCancelled else { return }
            self?.streamRunning = false
            self?.streamDone = true
        }
    }

    func boostBurst() {
        guard let target = all.last?.id, let dataset else { return }
        boostTask?.cancel()
        boostTask = Task { [weak self] in
            let contents = ["👍", "🎉", "🔥", "❤️", "😂"]
            for (index, content) in contents.enumerated() {
                if index > 0 { try? await Task.sleep(for: .milliseconds(200)) }
                guard !Task.isCancelled, let self else { return }
                // Reuse package values: CampfireKit intentionally exposes no public Boost initializer.
                if let boost = dataset.messages.lazy.flatMap(\.boosts).first(where: {
                    $0.boosterID == index + 2 && $0.content == content
                }) {
                    self.consume(.boost(messageID: target, boost))
                }
            }
        }
    }
}
