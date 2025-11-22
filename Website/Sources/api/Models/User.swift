import Fluent
import Vapor

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "email")
    var email: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Field(key: "user_type")
    var userType: String  // e.g., "Indie", "Pro" (from dashboard "Indie License")

    // A user can publish multiple games
    @Children(for: \.$user)
    var games: [Game]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil, username: String, email: String, passwordHash: String,
        userType: String = "Indie"
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.userType = userType
    }
}
