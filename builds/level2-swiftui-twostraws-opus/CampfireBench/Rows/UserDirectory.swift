import CampfireKit
import SwiftUI

/// Read-only lookup of the room's people, shared through the environment.
final class UserDirectory: Sendable {
    private let users: [UserID: User]

    init(_ users: [User]) {
        self.users = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    func name(_ id: UserID) -> String { users[id]?.name ?? "Unknown" }

    static let empty = UserDirectory([])
}

extension EnvironmentValues {
    @Entry var users = UserDirectory.empty
}
