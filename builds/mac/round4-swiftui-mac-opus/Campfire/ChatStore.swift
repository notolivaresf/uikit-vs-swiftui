import Foundation
import Observation
import CampfireKit

/// One row of the room: a message plus how it sits relative to the message before it.
struct RowModel: Identifiable, Equatable {
    let message: Message
    let presentation: MessagePresentation
    var id: MessageID { message.id }
}

/// Holds the whole dataset in memory and the slice of it the room shows.
@MainActor
@Observable
final class ChatStore {
    let currentUserID: UserID
    let roomName: String
    @ObservationIgnored private let usersByID: [UserID: User]
    @ObservationIgnored private let dataset: Dataset

    /// Every message, oldest first: the generated history plus what the live stream added. Ids are contiguous,
    /// so a message's index is its id minus the first id.
    @ObservationIgnored private var all: [Message]
    @ObservationIgnored private let firstID: MessageID

    /// Indexes into `all` of the loaded slice.
    private(set) var lower: Int = 0
    private(set) var upper: Int = 0
    private(set) var rows: [RowModel] = []
    /// Bumped on every change to the loaded rows.
    private(set) var version = 0
    /// Bumped when the loaded slice is replaced wholesale (not paged or appended to); the room then starts
    /// a fresh scroll view rather than reusing layout estimates for rows that are gone.
    private(set) var generation = 0

    private(set) var textSizeStep = 0
    private(set) var streamDone = false
    private(set) var streaming = false
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var burstTask: Task<Void, Never>?

    init() {
        let dataset = FakeData.generate(size: .k50)
        self.dataset = dataset
        currentUserID = dataset.currentUserID
        roomName = dataset.room.name
        usersByID = Dictionary(uniqueKeysWithValues: dataset.users.map { ($0.id, $0) })
        all = dataset.messages
        firstID = dataset.messages.first?.id ?? 1
        showNewest()
    }

    func user(_ id: UserID) -> User? { usersByID[id] }

    var textScale: CGFloat { TextSize.scales[textSizeStep] }
    var loadedCount: Int { upper - lower }
    var firstLoadedID: MessageID? { rows.first?.id }
    var lastLoadedID: MessageID? { rows.last?.id }
    var hasOlder: Bool { lower > 0 }
    var hasNewer: Bool { upper < all.count }
    var newestID: MessageID? { all.last?.id }

    private func index(of id: MessageID) -> Int? {
        let i = id - firstID
        return all.indices.contains(i) ? i : nil
    }

    // MARK: Loading

    /// The newest page, as the app opens.
    func showNewest() {
        let page = Windowing.lastPage(all)
        replace(lower: page.startIndex, upper: page.endIndex)
    }

    private func replace(lower newLower: Int, upper newUpper: Int) {
        let same = newLower == lower && newUpper == upper
        lower = newLower
        upper = newUpper
        rebuild()
        if !same { generation &+= 1 }
    }

    /// Loads one page before the first loaded message. Returns false when there is nothing older.
    @discardableResult
    func loadOlder() -> Bool {
        guard let first = rows.first, hasOlder else { return false }
        let page = Windowing.page(before: first.id, in: all)
        guard !page.isEmpty else { return false }
        lower = page.startIndex
        rebuild()
        return true
    }

    /// Loads one page after the last loaded message. Returns false when the newest is already loaded.
    @discardableResult
    func loadNewer() -> Bool {
        guard let last = rows.last, hasNewer else { return false }
        let page = Windowing.page(after: last.id, in: all)
        guard !page.isEmpty else { return false }
        upper = page.endIndex
        rebuild()
        return true
    }

    /// Loads a page either side of a message.
    func showAround(_ id: MessageID) {
        let page = Windowing.around(id, in: all)
        guard !page.isEmpty else { return }
        replace(lower: page.startIndex, upper: page.endIndex)
    }

    func isLoaded(_ id: MessageID) -> Bool {
        guard let i = index(of: id) else { return false }
        return i >= lower && i < upper
    }

    private func rebuild() {
        let slice = all[lower..<upper]
        let previous = lower > 0 ? all[lower - 1] : nil
        let presentations = Grouping.presentations(of: Array(slice), previous: previous, currentUserID: currentUserID)
        let new = zip(slice, presentations).map { RowModel(message: $0, presentation: $1) }
        if new != rows {
            rows = new
            version &+= 1
        }
    }

    // MARK: Text size

    func increaseTextSize() {
        textSizeStep = (textSizeStep + 1) % TextSize.scales.count
    }

    func resetTextSize() { textSizeStep = 0 }

    // MARK: Live changes

    /// A message from the live stream. It only shows if the newest messages are loaded.
    func append(_ message: Message) {
        let showing = upper == all.count
        all.append(message)
        if showing {
            upper = all.count
            let previous = rows.last?.message
            let p = Grouping.presentation(of: message, after: previous, currentUserID: currentUserID)
            rows.append(RowModel(message: message, presentation: p))
            version &+= 1
        }
    }

    func addBoost(_ boost: Boost, to id: MessageID) {
        guard let i = index(of: id) else { return }
        all[i].boosts.append(boost)
        if i >= lower && i < upper {
            let r = i - lower
            rows[r] = RowModel(message: all[i], presentation: rows[r].presentation)
            version &+= 1
        }
    }

    func startStream() {
        guard !streaming, !streamDone else { return }
        streaming = true
        let feed = FakeLiveFeed(dataset: dataset)
        streamTask = Task { [weak self] in
            for await event in feed.play() {
                guard let self else { return }
                switch event {
                case .message(let m): self.append(m)
                case .boost(let id, let b): self.addBoost(b, to: id)
                case .typingStarted, .typingStopped: break
                }
            }
            self?.streaming = false
            self?.streamDone = true
        }
    }

    /// Five boosts on the newest message, one every 200 ms, from users 2 to 6.
    func boostBurst() {
        guard let target = all.last?.id else { return }
        let boosts = burstBoosts
        burstTask?.cancel()
        burstTask = Task { [weak self] in
            for (n, boost) in boosts.enumerated() {
                if n > 0 { try? await Task.sleep(for: .milliseconds(200)) }
                if Task.isCancelled { return }
                self?.addBoost(boost, to: target)
            }
        }
    }

    /// CampfireKit keeps Boost's initializer internal, so the burst reuses boosts from the generated history
    /// that have exactly the wanted booster and emoji: users 2 to 6 with 👍 🎉 🔥 ❤️ 😂.
    @ObservationIgnored private lazy var burstBoosts: [Boost] = {
        let wanted: [(UserID, String)] = [(2, "👍"), (3, "🎉"), (4, "🔥"), (5, "❤️"), (6, "😂")]
        var found: [Int: Boost] = [:]
        outer: for message in dataset.messages {
            for boost in message.boosts {
                for (n, w) in wanted.enumerated() where found[n] == nil && boost.boosterID == w.0 && boost.content == w.1 {
                    found[n] = boost
                    if found.count == wanted.count { break outer }
                }
            }
        }
        return wanted.indices.compactMap { found[$0] }
    }()

    // MARK: Text for the clipboard

    func plainText(of message: Message) -> String {
        var out = ""
        for block in message.blocks {
            switch block {
            case .text(let t): out += t
            case .mention(let id): out += user(id)?.name ?? ""
            case .code(_, let source):
                if !out.isEmpty && !out.hasSuffix("\n") { out += "\n" }
                out += source
            }
        }
        if case .file(let name, _)? = message.attachment {
            if !out.isEmpty { out += "\n" }
            out += name
        }
        return out
    }
}
