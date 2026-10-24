import CampfireKit

/// One loaded message and how it sits against the message before it.
struct RowModel: Identifiable, Equatable {
    let message: Message
    let presentation: MessagePresentation
    /// The message's boosts plus any added on this device.
    let boosts: [BoostItem]

    var id: MessageID { message.id }
}

/// A boost as the row draws it. CampfireKit's `Boost` has no public initialiser, so boosts made in the app
/// (the debug bar's burst) use this too.
struct BoostItem: Identifiable, Hashable {
    let id: Int
    let boosterID: UserID
    let content: String

    init(id: Int, boosterID: UserID, content: String) {
        self.id = id
        self.boosterID = boosterID
        self.content = content
    }

    init(_ boost: Boost) {
        self.init(id: boost.id, boosterID: boost.boosterID, content: boost.content)
    }
}
